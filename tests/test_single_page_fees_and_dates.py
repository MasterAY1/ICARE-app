from datetime import date, datetime
from unittest.mock import MagicMock, patch
import uuid

from fastapi import HTTPException
import pytest

from api.routes.co.cashbook import EodAdjustmentsInput, submit_eod_adjustments
from api.routes.co.collections import get_collections_history, submit_batch_collections, submit_single_client
from api.schemas.collections import SingleClientSubmitInput
from api.schemas.financial_writes import BatchCollectionInput, BatchCollectionItem
from models.user import CurrentUser
from services.business_date_service import BusinessDateService
from services.collection_batch_service import _is_explicit_unpaid_loan_mark, save_repayment
from services.financial_reconciliation_service import FinancialReconciliationService


class _ChainMock:
    def __init__(self, data=None):
        self._data = data if data is not None else []

    def select(self, *args, **kwargs):
        return self

    def eq(self, *args, **kwargs):
        return self

    def neq(self, *args, **kwargs):
        return self

    def in_(self, *args, **kwargs):
        return self

    def gte(self, *args, **kwargs):
        return self

    def lte(self, *args, **kwargs):
        return self

    def gt(self, *args, **kwargs):
        return self

    def lt(self, *args, **kwargs):
        return self

    def ilike(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def execute(self):
        res = MagicMock()
        res.data = self._data
        return res


BRANCH_UUID = "997d504e-7f5c-4772-887d-fdd5a4c1183b"
OFFICER_UUID = "c32125e1-c7e5-4a85-8948-12d05b40eaa9"
CLIENT_UUID = "a24ebe27-7567-41de-a505-d05dfe34de9c"


@pytest.fixture(autouse=True)
def _clear_business_date_cache():
    BusinessDateService._operational_cache.clear()
    yield
    BusinessDateService._operational_cache.clear()


def _co_user() -> CurrentUser:
    return CurrentUser(
        id=OFFICER_UUID,
        username="OGI_CO2",
        role="Credit Officer",
        branch="Ogijo",
        branch_id=BRANCH_UUID,
        full_name="Mr. Ayomide",
    )


def test_business_date_future_drift_falls_back_when_today_open():
    mock_uow = MagicMock()

    def table_side_effect(name):
        if name == "branches":
            return _ChainMock([
                {"branch_id": BRANCH_UUID, "cashbook_defaults": {"business_date": "2026-12-02"}},
            ])
        if name == "master_cashbook":
            return _ChainMock([])  # Today 2026-11-27 is NOT closed
        return _ChainMock([])

    mock_uow.client.table.side_effect = table_side_effect

    with patch("services.business_date_service.datetime") as mock_dt, \
         patch(
             "services.business_date_service.BusinessDateService.is_working_day",
             side_effect=lambda d, custom_closures=None: (d.weekday() < 5, "Working Day"),
         ):
        mock_dt.now.return_value = datetime(2026, 11, 27, 9, 0, 0)
        resolved = BusinessDateService.get_business_date(mock_uow, BRANCH_UUID)
        assert resolved == date(2026, 11, 27)


def test_business_date_allows_next_working_day_when_today_is_closed():
    mock_uow = MagicMock()

    def table_side_effect(name):
        if name == "branches":
            return _ChainMock([
                {"branch_id": BRANCH_UUID, "cashbook_defaults": {"business_date": "2026-11-30"}},
            ])
        if name == "master_cashbook":
            return _ChainMock([{"status": "Closed"}])  # Today 2026-11-27 IS closed
        return _ChainMock([])

    mock_uow.client.table.side_effect = table_side_effect

    with patch("services.business_date_service.datetime") as mock_dt, \
         patch(
             "services.business_date_service.BusinessDateService.is_working_day",
             side_effect=lambda d, custom_closures=None: (d.weekday() < 5, "Working Day"),
         ):
        mock_dt.now.return_value = datetime(2026, 11, 27, 9, 0, 0)
        resolved = BusinessDateService.get_business_date(mock_uow, BRANCH_UUID)
        assert resolved == date(2026, 11, 30)


def test_unpaid_loan_guard_skips_savings_and_fee_only_but_keeps_explicit_mark():
    assert _is_explicit_unpaid_loan_mark({
        "Payment Status": "NOT_PAID",
        "Repayment Amount": 0.0,
        "Individual Savings Deposit": 2000.0,
    }) is False
    assert _is_explicit_unpaid_loan_mark({
        "Payment Status": "NOT_PAID",
        "Repayment Amount": 0.0,
        "Bonus": 500.0,
    }) is False
    assert _is_explicit_unpaid_loan_mark({
        "Payment Status": "NOT_PAID",
        "mark_not_paid": True,
        "Individual Savings Deposit": 2000.0,
    }) is True
    assert _is_explicit_unpaid_loan_mark({
        "Payment Status": "NOT_PAID",
        "Transaction Type": "Loan",
        "Repayment Amount": 0.0,
    }) is True


def test_group_batch_savings_only_without_loan_posts_cleanly():
    mock_uow = MagicMock()
    mock_uow.cashbook._resolve_branch_id.return_value = BRANCH_UUID
    mock_uow.loans._resolve_officer_id.return_value = OFFICER_UUID

    def batch_table(name):
        if name == "clients":
            return _ChainMock([{"client_id": CLIENT_UUID, "branch_id": BRANCH_UUID, "name": "Ojei Elizabeth"}])
        if name == "groups":
            return _ChainMock([{"group_id": "grp-1", "name": "Favour", "branch_id": BRANCH_UUID}])
        return _ChainMock([])

    mock_uow.client.table.side_effect = batch_table

    captured_records = []

    def fake_save_repayments(records, **kwargs):
        captured_records.extend(records)
        return {
            "total_repayment": 0.0,
            "total_savings": 2000.0,
            "total_fees": 0.0,
            "total_cash": 2000.0,
            "total_submitted": len(records),
            "new_processed": len(records),
            "already_saved": 0,
            "items": [],
        }

    payload = BatchCollectionInput(
        group_name="Favour",
        date="2026-11-27",
        idempotency_key="BATCH-FAVOUR-SAV-ONLY-1",
        collections=[
            BatchCollectionItem(
                client_id=CLIENT_UUID,
                client_name="Ojei Elizabeth",
                loan_id=None,
                savings_deposit_amount=2000.0,
                loan_repayment_amount=0.0,
                mark_not_paid=False,
            )
        ],
    )

    with patch("api.routes.co.collections._resolve_target_date", return_value=date(2026, 11, 27)), \
         patch("services.rate_limiter.get_financial_rate_limiter") as mock_lim, \
         patch("services.collection_batch_service.save_repayments", side_effect=fake_save_repayments):
        mock_lim.return_value.check_rate_limit.return_value = (False, 0)
        resp = submit_batch_collections(payload=payload, current_user=_co_user(), uow=mock_uow)

    assert resp.success is True
    assert len(captured_records) == 1
    assert captured_records[0]["Transaction Type"] == "Individual Savings Deposit"
    assert captured_records[0]["Payment Status"] == "PAID"


def test_single_client_all_five_fees_submission_and_misc_fee_audit_and_recon():
    mock_uow = MagicMock()
    mock_uow.cashbook._resolve_branch_id.return_value = BRANCH_UUID
    mock_uow.loans._resolve_branch_id.return_value = BRANCH_UUID
    mock_uow.loans._resolve_officer_id.return_value = OFFICER_UUID

    captured_rpc_ops = []

    def fake_table(name):
        if name == "clients":
            return _ChainMock([{"client_id": CLIENT_UUID, "branch_id": BRANCH_UUID, "name": "Orija Temitope", "client_code": "OGI-20-008"}])
        if name == "branches":
            return _ChainMock([{"branch_id": BRANCH_UUID, "name": "Ogijo"}])
        if name == "app_users":
            return _ChainMock([{"id": OFFICER_UUID, "username": "OGI_CO2", "full_name": "Mr. Ayomide"}])
        return _ChainMock([])

    mock_uow.client.table.side_effect = fake_table
    mock_uow.client.rpc.side_effect = lambda fn, params: (
        captured_rpc_ops.extend(params.get("p_operations") or []) or _ChainMock([])
    )

    # 1. Route accepts all 5 fees with zero loan/savings (fee-only)
    captured_batch = []

    def fake_save_batch(records, **kwargs):
        captured_batch.extend(records)
        return {"total_repayment": 0.0, "total_savings": 0.0, "total_fees": 2500.0, "total_cash": 2500.0}

    sc_payload = SingleClientSubmitInput(
        client_id=CLIENT_UUID,
        client_code="OGI-20-008",
        client_name="Orija Temitope",
        group_name="Peace",
        savings_deposit=0.0,
        group_savings_deposit=0.0,
        loan_repayment=0.0,
        app_fee=500.0,
        passbook_fee=500.0,
        misc_fee=1000.0,
        credit_form_damage=200.0,
        bonus=300.0,
        idempotency_key="SC-ALL-FEES-001",
    )

    with patch("api.routes.co.collections._resolve_target_date", return_value=date(2026, 11, 27)), \
         patch("services.rate_limiter.get_financial_rate_limiter") as mock_lim, \
         patch("services.collection_batch_service.save_repayments", side_effect=fake_save_batch):
        mock_lim.return_value.check_rate_limit.return_value = (False, 0)
        sc_resp = submit_single_client(payload=sc_payload, current_user=_co_user(), uow=mock_uow)

    assert sc_resp.success is True
    assert sc_resp.receipt["total_fees"] == 2500.0
    assert sc_resp.receipt["total_cash"] == 2500.0
    assert len(sc_resp.receipt["fees_breakdown"]) == 5

    # 2. Save repayment writes 4 revenue fees + 1 mirrored MISC_FEE + 5 audit_logs + 5 user_audit_logs,
    #    routes MISC_FEE via SavingsService.post_misc_savings, and emits ZERO FeeCharged for MISC_FEE.
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
         patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value=("60fa48a4-16a2-4ab8-b9c5-d13d72a040cc", "OGI_CO3")), \
         patch("services.savings_service.SavingsService.post_misc_savings") as mock_misc_sav, \
         patch("services.posting_engine.FinancialPostingEngine.post_event", side_effect=lambda u, ev, **kw: (ev.event_id, {"type": "insert", "table": "financial_transactions", "record": {"transaction_id": ev.event_id}})) as mock_post_ev:
        save_repayment(captured_batch[0], override_uow=mock_uow)

    mock_misc_sav.assert_called_once()
    assert mock_misc_sav.call_args.args[5] == 1000.0

    # FeeCharged only for 4 revenue fees (NOT MISC_FEE!)
    fee_events = [c.args[1].payload["classification"] for c in mock_post_ev.call_args_list if c.args[1].event_type == "FeeCharged"]
    assert set(fee_events) == {"PROCESSING_FEE", "PASSBOOK", "CREDIT_FORM_DAMAGE", "BONUS"}

    fees_inserts = [op["record"] for op in captured_rpc_ops if op.get("table") == "fees"]
    audit_inserts = [op["record"] for op in captured_rpc_ops if op.get("table") == "audit_logs"]
    user_audit_inserts = [op["record"] for op in captured_rpc_ops if op.get("table") == "user_audit_logs"]
    assert {r["fee_type"] for r in fees_inserts} == {"PROCESSING_FEE", "PASSBOOK", "MISC_FEE", "CREDIT_FORM_DAMAGE", "BONUS"}
    assert len(audit_inserts) == 5
    assert len(user_audit_inserts) == 5
    assert all(r["status"] == "SUCCESS" for r in user_audit_inserts)
    misc_ua = next(r for r in user_audit_inserts if r["new_value"]["fee_type"] == "MISC_FEE")
    assert misc_ua["new_value"]["collecting_officer"] == "OGI_CO2"
    assert misc_ua["new_value"]["managing_officer"] == "OGI_CO3"

    # 3. 6-way Reconciliation excludes mirrored MISC_FEE row so MISC_FEE + internal_savings is NEVER double-counted
    recon_uow = MagicMock()

    def recon_table(name):
        if name == "financial_ledger_entries":
            return _ChainMock([
                {"side": "Debit", "amount": 1000.0},   # Misc Savings (Account 1000 Dr / 2000 Cr)
                {"side": "Debit", "amount": 1500.0},   # 4 Revenue Fees (500+500+200+300)
            ])
        if name == "internal_savings":
            return _ChainMock([{"deposit_amount": 1000.0}])
        if name == "fees":
            return _ChainMock([
                {"amount": 500.0, "fee_type": "PROCESSING_FEE"},
                {"amount": 500.0, "fee_type": "PASSBOOK"},
                {"amount": 200.0, "fee_type": "CREDIT_FORM_DAMAGE"},
                {"amount": 300.0, "fee_type": "BONUS"},
                {"amount": 1000.0, "fee_type": "MISC_FEE"},  # Must be excluded in recon fee sum
            ])
        if name == "co_cashbooks":
            return _ChainMock([{"officer_id": OFFICER_UUID, "opening_balance": 0.0, "total_inflows": 2500.0, "total_outflows": 0.0}])
        if name == "master_cashbook":
            return _ChainMock([{"opening_balance": 0.0, "total_inflows": 2500.0, "total_outflows": 0.0}])
        if name == "financial_transactions":
            return _ChainMock([
                {"transaction_id": "t1", "reference": "r1", "financial_ledger_entries": [{"account_code": "1000", "side": "Debit", "amount": 2500.0}]},
            ])
        return _ChainMock([])

    recon_uow.client.table.side_effect = recon_table
    recon = FinancialReconciliationService.verify_6way_financial_integrity(recon_uow, BRANCH_UUID, date(2026, 11, 27))
    assert recon["is_balanced"] is True
    assert recon["audit_views_total"] == 2500.0
    assert recon["dashboard_total"] == 2500.0


def test_collections_history_includes_itemized_fees_and_eod_rejects_fees():
    mock_uow = MagicMock()
    mock_uow.loans._resolve_officer_id.return_value = OFFICER_UUID
    mock_uow.cashbook._resolve_branch_id.return_value = BRANCH_UUID
    mock_uow.users.get_all_users.return_value = [
        MagicMock(id=OFFICER_UUID, username="OGI_CO2", full_name="Mr. Ayomide", role="Credit Officer", branch_id=BRANCH_UUID)
    ]

    def hist_table(name):
        if name == "fees":
            return _ChainMock([
                {
                    "id": str(uuid.uuid4()),
                    "posting_date": "2026-11-27",
                    "client_id": CLIENT_UUID,
                    "officer_id": OFFICER_UUID,
                    "fee_type": "MISC_FEE",
                    "amount": 1000.0,
                    "remarks": "Recorded Misc Fee (Misc Savings Custody: OGI_CO3 | Collector: OGI_CO2) for Orija",
                    "reference": "SC-ALL-FEES-001",
                    "clients": {"name": "Orija Temitope", "client_code": "OGI-20-008"},
                },
                {
                    "id": str(uuid.uuid4()),
                    "posting_date": "2026-11-27",
                    "client_id": CLIENT_UUID,
                    "officer_id": OFFICER_UUID,
                    "fee_type": "PASSBOOK",
                    "amount": 500.0,
                    "remarks": "Passbook fee from Orija Temitope",
                    "reference": "SC-ALL-FEES-001",
                    "clients": {"name": "Orija Temitope", "client_code": "OGI-20-008"},
                },
            ])
        return _ChainMock([])

    mock_uow.client.table.side_effect = hist_table

    with patch("api.routes.co.collections._resolve_target_date", return_value=date(2026, 11, 27)):
        hist = get_collections_history(date_str="2026-11-27", officer=None, search=None, current_user=_co_user(), uow=mock_uow)

    assert hist.total_fees == 1500.0
    assert len(hist.fees) == 2
    misc_row = next(f for f in hist.fees if f.fee_type == "MISC_FEE")
    assert misc_row.managing_officer == "OGI_CO3"
    assert "OGI_CO2" in (misc_row.collecting_officer or "")

    # Verify EOD adjustments rejects all fee fields
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
         patch("services.co_cashbook_projection_builder.CoCashbookProjectionBuilder.rebuild_co_projection", return_value={}):
        for field_name in ("app_fee", "passbook", "misc_fee", "credit_form_damage", "bonus"):
            with pytest.raises(HTTPException) as exc_info:
                submit_eod_adjustments(
                    payload=EodAdjustmentsInput(date="2026-11-27", **{field_name: 100.0}),
                    current_user=_co_user(),
                    uow=mock_uow,
                )
            assert exc_info.value.status_code == 400
