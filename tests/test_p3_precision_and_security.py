"""
tests/test_p3_precision_and_security.py
Priority 3 verification suite covering:
1. Fixed-precision Decimal banking arithmetic (`core/money.py`), `LedgerEntry` Decimal typing,
   `FinancialPostingEngine` exact Decimal amounts & formatted RPC strings, and `SupabaseLedgerRepository`
   exact Decimal debit=credit validation & Decimal entity reads.
2. Distributed shared `AuthenticationRateLimiter` across simulated backend instances & restarts.
3. Distributed atomic `MFAReplayStore` across instances with fail-closed behavior on DB errors.
4. Tightened global session cache TTL (<= 15.0s) and immediate invalidation across
   `products/assign`, `am-assignments`, and `officer-turnover` mutations.
Complies with Strict Zero-Emoji Governance.
"""
from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from api.main import app
from api.dependencies import get_uow, get_current_user
from auth.mfa import MFAReplayStore, clear_replay_cache
from auth.session_cache import (
    _GLOBAL_SESSION_CACHE,
    _resolve_default_session_cache_ttl,
    get_cached_user,
    invalidate_user_session_cache,
    set_cached_user,
)
from core.exceptions import RepositoryError
from core.money import MONEY_QUANT, assert_positive_money, format_money_str, sum_money, to_decimal
from database.repositories.ledger_repository import SupabaseLedgerRepository
from domain.entities.event_store import DomainEvent
from domain.entities.ledger import FinancialTransaction, LedgerEntry
from domain.entities.posting_rule import PostingRule
from models.user import CurrentUser
from services.posting_engine import FinancialPostingEngine
from services.rate_limiter import AuthenticationRateLimiter, get_auth_rate_limiter


client = TestClient(app)


class _FakeRateLimitQuery:
    def __init__(self, store_dict):
        self._store = store_dict
        self._key = None
        self._op = None
        self._payload = None

    def select(self, *_args, **_kwargs):
        self._op = "select"
        return self

    def eq(self, _col, val):
        self._key = val
        return self

    def limit(self, *_args, **_kwargs):
        return self

    def upsert(self, payload, on_conflict=None):
        self._op = "upsert"
        self._payload = dict(payload)
        return self

    def delete(self):
        self._op = "delete"
        return self

    def execute(self):
        if self._op == "upsert":
            self._store[self._payload["limit_key"]] = dict(self._payload)
            return SimpleNamespace(data=[self._store[self._payload["limit_key"]]])
        if self._op == "delete":
            self._store.pop(self._key, None)
            return SimpleNamespace(data=[])
        row = self._store.get(self._key)
        return SimpleNamespace(data=[dict(row)] if row else [])


class _FakeDistributedSecurityClient:
    def __init__(self):
        self.rate_limit_rows = {}
        self.mfa_nonces = set()
        self.fail_rpc = False

    def table(self, name: str):
        assert name == "auth_rate_limit_state"
        return _FakeRateLimitQuery(self.rate_limit_rows)

    def rpc(self, fn_name: str, params: dict):
        assert fn_name == "consume_mfa_totp_nonce"
        client = self

        class _RpcCall:
            def execute(self_inner):
                if client.fail_rpc:
                    raise ConnectionError("Simulated database outage during MFA replay check")
                rkey = params["p_replay_key"]
                if rkey in client.mfa_nonces:
                    return SimpleNamespace(data=False)
                client.mfa_nonces.add(rkey)
                return SimpleNamespace(data=True)

        return _RpcCall()


@pytest.fixture(autouse=True)
def clean_p3_state():
    app.dependency_overrides.clear()
    get_auth_rate_limiter().clear_all()
    clear_replay_cache()
    invalidate_user_session_cache()
    yield
    app.dependency_overrides.clear()
    get_auth_rate_limiter().clear_all()
    clear_replay_cache()
    invalidate_user_session_cache()


class TestFixedPrecisionMonetaryArithmetic:

    def test_money_helpers_exact_decimal_and_half_up_rounding(self):
        # Float 0.1 + 0.2 famously yields 0.30000000000000004 in IEEE-754
        assert to_decimal("0.1") + to_decimal("0.2") == Decimal("0.30")
        assert sum_money([0.1, 0.2, "10.055"]) == Decimal("10.36")

        # Explicit commercial ROUND_HALF_UP rules
        assert to_decimal("100.125") == Decimal("100.13")
        assert to_decimal("100.124") == Decimal("100.12")
        assert format_money_str(Decimal("25000.3")) == "25000.30"
        assert assert_positive_money("0.01") == Decimal("0.01")

        # Invalid / dangerous inputs must fail closed
        for bad in [None, True, False, float("nan"), float("inf"), float("-inf"), "", "not-a-number"]:
            with pytest.raises(ValueError):
                to_decimal(bad)

        for non_pos in [0, "0.00", -10, "-0.01"]:
            with pytest.raises(ValueError):
                assert_positive_money(non_pos)

    def test_ledger_entry_and_posting_engine_use_exact_decimal_and_rpc_strings(self):
        # LedgerEntry coerces float/string/int inputs into quantized Decimal
        e_from_float = LedgerEntry(
            entry_id=None,
            transaction_id="",
            branch_id="b-1",
            account_code="1000",
            side="Debit",
            amount=1500.3,
            aggregate_type="Repayment",
            aggregate_id="agg-1",
        )
        assert isinstance(e_from_float.amount, Decimal)
        assert e_from_float.amount == Decimal("1500.30")
        assert e_from_float.amount.as_tuple().exponent == MONEY_QUANT.as_tuple().exponent

        mock_uow = MagicMock()
        mock_uow.posting_rules.get_rule.return_value = PostingRule(
            id="r-rep",
            event_type="RepaymentPosted",
            debit_account="1000",
            credit_account="1200",
            version=1,
            enabled=True,
        )
        mock_uow.event_store.is_processed.return_value = False
        mock_uow.ledger.create_transaction.return_value = "tx-dec-1"

        event = DomainEvent(
            event_id="evt-dec-1",
            aggregate_id="agg-dec-1",
            aggregate_type="Repayment",
            event_type="RepaymentPosted",
            payload={
                "branch": "00000000-0000-0000-0000-000000000001",
                "officer": "00000000-0000-0000-0000-000000000002",
                "amount": 25000.3,
                "narration": "Decimal precision test",
            },
        )

        # 1. defer_commit=True emits exact fixed-point strings ("25000.30") without float drift
        tx_id, op = FinancialPostingEngine.post_event(mock_uow, event, defer_commit=True)
        assert tx_id
        entries_payload = op["record"]["entries_payload"]
        assert len(entries_payload) == 2
        assert all(isinstance(row["amount"], str) and row["amount"] == "25000.30" for row in entries_payload)

        # 2. defer_commit=False passes Decimal LedgerEntry objects
        FinancialPostingEngine.post_event(mock_uow, event, defer_commit=False)
        _, posted_entries = mock_uow.ledger.create_transaction.call_args[0]
        assert all(isinstance(entry.amount, Decimal) and entry.amount == Decimal("25000.30") for entry in posted_entries)

    def test_ledger_repository_enforces_exact_decimal_balance_and_returns_decimals(self):
        mock_client = MagicMock()
        mock_client.rpc.return_value.execute.return_value = SimpleNamespace(data="tx-uuid-1")
        repo = SupabaseLedgerRepository(mock_client)

        tx = FinancialTransaction(
            transaction_id=None,
            event_id=None,
            posting_date="2026-11-19",
            branch_id="b-1",
            officer_id="o-1",
            narration="Balanced decimal test",
            reference="REF-1",
        )

        # Balanced: 0.10 + 0.20 == 0.30
        d1 = LedgerEntry(None, "", "b-1", "1000", "Debit", "0.10", "Repayment", "a-1")
        d2 = LedgerEntry(None, "", "b-1", "1000", "Debit", "0.20", "Repayment", "a-1")
        c1 = LedgerEntry(None, "", "b-1", "1200", "Credit", "0.30", "Repayment", "a-1")
        assert repo.create_transaction(tx, [d1, d2, c1]) == "tx-uuid-1"

        rpc_name, rpc_payload = mock_client.rpc.call_args[0]
        assert rpc_name == "post_financial_transaction"
        assert [row["amount"] for row in rpc_payload["entries_payload"]] == ["0.10", "0.20", "0.30"]

        # Unbalanced by 1 kobo (0.01) must fail closed
        c_off = LedgerEntry(None, "", "b-1", "1200", "Credit", "0.31", "Repayment", "a-1")
        with pytest.raises(RepositoryError):
            repo.create_transaction(tx, [d1, d2, c_off])

        # Reads deserialize as Decimal
        mock_client.table.return_value.select.return_value.execute.return_value = SimpleNamespace(
            data=[{
                "entry_id": "e-1",
                "transaction_id": "tx-1",
                "branch_id": "b-1",
                "account_code": "1000",
                "side": "Debit",
                "amount": 1234.56,
                "aggregate_type": "Repayment",
                "aggregate_id": "a-1",
            }]
        )
        entries = repo.get_ledger_entries()
        assert len(entries) == 1
        assert isinstance(entries[0].amount, Decimal)
        assert entries[0].amount == Decimal("1234.56")

        mock_client.table.return_value.select.return_value.eq.return_value.execute.return_value = SimpleNamespace(
            data=[{
                "entry_id": "e-2",
                "transaction_id": "tx-1",
                "branch_id": "b-1",
                "account_code": "1200",
                "side": "Credit",
                "amount": "1234.56",
                "aggregate_type": "Repayment",
                "aggregate_id": "a-1",
            }]
        )
        tx_entries = repo.get_transaction_entries("tx-1")
        assert len(tx_entries) == 1
        assert isinstance(tx_entries[0].amount, Decimal)
        assert tx_entries[0].amount == Decimal("1234.56")


class TestDistributedRateLimiterAndMfaReplay:

    def test_auth_rate_limiter_shares_failures_and_resets_across_instances(self):
        shared_db = _FakeDistributedSecurityClient()
        inst_a = AuthenticationRateLimiter(max_attempts=5, window_seconds=300, lockout_seconds=900, client_provider=lambda: shared_db)
        inst_b = AuthenticationRateLimiter(max_attempts=5, window_seconds=300, lockout_seconds=900, client_provider=lambda: shared_db)

        for _ in range(3):
            locked, _ = inst_a.record_failure("co_shared_test")
            assert locked is False

        assert inst_b.is_locked_out("co_shared_test")[0] is False
        locked_b1, _ = inst_b.record_failure("co_shared_test")
        assert locked_b1 is False
        locked_b2, retry_b = inst_b.record_failure("co_shared_test")
        assert locked_b2 is True
        assert retry_b > 0

        # Instance A observes lockout from shared DB even if its L1 dict was wiped (restart)
        inst_a.clear_all()
        locked_a, retry_a = inst_a.is_locked_out("co_shared_test")
        assert locked_a is True
        assert retry_a > 0

        # Reset on Instance B clears Instance A's lockout
        inst_b.reset("co_shared_test")
        assert inst_a.is_locked_out("co_shared_test")[0] is False

    def test_mfa_replay_store_blocks_cross_instance_replay_and_fails_closed(self):
        shared_db = _FakeDistributedSecurityClient()
        inst_a = MFAReplayStore(client_provider=lambda: shared_db)
        inst_b = MFAReplayStore(client_provider=lambda: shared_db)

        now = 1700000100.0
        assert inst_a.check_and_record("usr-mfa-1", 5666670, now) is False  # First use accepted
        assert inst_b.check_and_record("usr-mfa-1", 5666670, now) is True   # Cross-instance replay blocked

        # Fail closed when DB RPC fails on an unseen counter
        shared_db.fail_rpc = True
        assert inst_b.check_and_record("usr-mfa-1", 5666671, now) is True


class TestSessionCacheHardening:

    def test_session_cache_default_ttl_is_reduced_and_mutations_invalidate(self, monkeypatch):
        monkeypatch.delenv("ICARE_SESSION_CACHE_TTL_SECONDS", raising=False)
        assert _resolve_default_session_cache_ttl() <= 15.0
        assert _GLOBAL_SESSION_CACHE._default_ttl <= 15.0

        admin = CurrentUser(
            id="usr-admin-p3",
            username="admin_p3",
            role="Super Admin",
            branch="Head Office",
            branch_id="b-hq",
        )
        app.dependency_overrides[get_current_user] = lambda: admin
        mock_uow = MagicMock()
        app.dependency_overrides[get_uow] = lambda: mock_uow

        # 1. Product assignment evicts CO session cache
        co_cached = CurrentUser(
            id="usr-co-p3",
            username="co_p3",
            role="Credit Officer",
            branch="Ikeja",
            branch_id="b-ikeja",
        )
        set_cached_user("usr-co-p3", co_cached)
        set_cached_user("co_p3", co_cached)
        mock_uow.users.find_by_username.return_value = SimpleNamespace(
            id="usr-co-p3",
            username="co_p3",
            branch_id="b-ikeja",
        )
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value = SimpleNamespace(
            data=[{"extra_fields": {}}]
        )

        res_prod = client.post(
            "/api/v1/users/products/assign",
            json={"username": "co_p3", "allowed_products": ["Daily 60 Days"]},
        )
        assert res_prod.status_code == 200
        assert get_cached_user("usr-co-p3") is None
        assert get_cached_user("co_p3") is None

        # 2. Officer turnover evicts officer session cache
        set_cached_user("usr-co-p3", co_cached)
        set_cached_user("co_p3", co_cached)
        with patch("api.routes.users.UserService.update_officer_name", return_value={
            "success": True,
            "message": "Updated.",
            "user_id": "usr-co-p3",
            "username": "co_p3",
        }):
            res_turn = client.post(
                "/api/v1/users/officer-turnover",
                json={"username": "co_p3", "new_name": "Updated Officer"},
            )
        assert res_turn.status_code == 200
        assert get_cached_user("usr-co-p3") is None
        assert get_cached_user("co_p3") is None

        # 3. AM branch assignment evicts AM session cache
        am_cached = CurrentUser(
            id="usr-am-p3",
            username="am_p3",
            role="Area Manager",
            branch="Ikeja",
            branch_id="b-ikeja",
        )
        set_cached_user("usr-am-p3", am_cached)
        set_cached_user("am_p3", am_cached)
        with patch("api.routes.users.UserService.save_am_assignments", return_value={
            "success": True,
            "message": "Assigned.",
            "user_id": "usr-am-p3",
            "username": "am_p3",
        }):
            res_am = client.post(
                "/api/v1/users/am-assignments",
                json={"am_id": "usr-am-p3", "branch_ids": ["b1", "b2", "b3", "b4", "b5"]},
            )
        assert res_am.status_code == 200
        assert get_cached_user("usr-am-p3") is None
        assert get_cached_user("am_p3") is None
