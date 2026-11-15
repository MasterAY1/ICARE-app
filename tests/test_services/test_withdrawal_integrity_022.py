"""
End-to-end verification tests for BIA-CO-WITHDRAW-022 Option 1:
- Canonical SavingsService.execute_approved_withdrawal across all 4 savings buckets & operation types
- 4-table SavingsService.reverse_savings with unique REV- idempotency & SavingsWithdrawalReversed event
- Bank-funded CR 1050 withdrawals & order-independent reversal netting in CoCashbook & MasterCashbook
- FinancialReconciliationService exception checks #4-#7
- FastAPI CO Withdrawal, Reversal Options, and Audit Withdrawal Lifecycle endpoints
"""
import os
import sys
import uuid
import unittest
from datetime import date, datetime
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from fastapi.testclient import TestClient
from api.main import app
from api.dependencies import get_uow, get_current_user
from auth.authorization import PERMISSIONS
from models.user import CurrentUser
from services.posting_engine import DomainEvent, FinancialPostingEngine
from services.savings_service import SavingsService
from services.withdrawal_classification_engine import WithdrawalClassificationEngine
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
from services.financial_reconciliation_service import FinancialReconciliationService


WEEKDAY = date(2026, 8, 12)
BRANCH_UUID = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"
OFFICER_UUID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
CLIENT_UUID = "c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33"
CLIENT2_UUID = "c1eebc99-9c0b-4ef8-bb6d-6bb9bd380a44"
GROUP_UUID = "g0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55"
LOAN_UUID = "l0eebc99-9c0b-4ef8-bb6d-6bb9bd380a66"


class _FakeQuery:
    def __init__(self, data=None):
        self._data = list(data) if data is not None else []

    def select(self, *args, **kwargs):
        return self

    def eq(self, col, val, *args, **kwargs):
        if "." not in str(col) and any(isinstance(r, dict) and col in r for r in self._data):
            self._data = [r for r in self._data if isinstance(r, dict) and r.get(col) == val]
        return self

    def neq(self, col, val, *args, **kwargs):
        if "." not in str(col) and any(isinstance(r, dict) and col in r for r in self._data):
            self._data = [r for r in self._data if isinstance(r, dict) and r.get(col) != val]
        return self

    def lt(self, col, val, *args, **kwargs):
        self._data = [
            r for r in self._data
            if isinstance(r, dict) and col in r and r.get(col) is not None and r.get(col) < val
        ]
        return self

    def gt(self, col, val, *args, **kwargs):
        self._data = [
            r for r in self._data
            if isinstance(r, dict) and col in r and r.get(col) is not None and r.get(col) > val
        ]
        return self

    def in_(self, col, vals, *args, **kwargs):
        if "." not in str(col) and any(isinstance(r, dict) and col in r for r in self._data):
            val_set = set(vals or [])
            self._data = [r for r in self._data if isinstance(r, dict) and r.get(col) in val_set]
        return self

    def gte(self, *args, **kwargs):
        return self

    def lte(self, *args, **kwargs):
        return self

    def is_(self, *args, **kwargs):
        return self

    def or_(self, *args, **kwargs):
        return self

    def ilike(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def filter(self, *args, **kwargs):
        return self

    def update(self, *args, **kwargs):
        return self

    def insert(self, *args, **kwargs):
        return self

    def execute(self):
        return MagicMock(data=self._data)


def _make_uow():
    uow = MagicMock()
    uow.event_store.is_processed.return_value = False
    uow.client.rpc.return_value.execute.return_value = MagicMock(data={"success": True})

    def _rule_lookup(ev_type, version=1):
        rules = {
            "SavingsWithdrawn": ("2000", "1000"),
            "SavingsDeposited": ("1000", "2000"),
            "LoanOffsetFromSavings": ("2000", "1200"),
            "FeeOffsetFromSavings": ("2000", "3000"),
            "SavingsTransferred": ("2000", "2000"),
            "LapsTransferred": ("2000", "2030"),
            "LapsPaidOut": ("2030", "1000"),
            "LapsRestoredToSavings": ("2030", "2000"),
        }
        if ev_type in rules:
            r = MagicMock()
            r.debit_account, r.credit_account = rules[ev_type]
            return r
        return None

    uow.posting_rules.get_rule.side_effect = _rule_lookup
    uow.individual_savings.get_total_balance.return_value = 100000.0
    uow.group_savings.get_total_balance.return_value = 80000.0
    uow.misc_savings.get_total_balance.return_value = 60000.0
    uow.laps_savings.get_total_balance.return_value = 40000.0
    uow.client.table.return_value = _FakeQuery([])
    return uow


class TestWithdrawalExecutionAndReversal022(unittest.TestCase):
    def setUp(self):
        FinancialPostingEngine._rules_cache.clear()

    def tearDown(self):
        FinancialPostingEngine._rules_cache.clear()

    def _run_with_patches(self, fn):
        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch.object(FinancialPostingEngine, "_resolve_branch_id", return_value=BRANCH_UUID), \
             patch.object(FinancialPostingEngine, "_resolve_officer_id", return_value=OFFICER_UUID):
            return fn()

    def _last_rpc_ops(self, uow):
        calls = [c for c in uow.client.rpc.call_args_list if c.args[0] == "atomic_execute_operations"]
        self.assertTrue(calls, "Expected atomic_execute_operations RPC call")
        return calls[-1].args[1]["p_operations"]

    def test_execute_approved_withdrawal_individual_cash_vs_bank_and_rpc_binding(self):
        # Cash withdrawal -> CR 1000, executed_record_id attached to withdrawal_requests update op
        uow = _make_uow()
        wr_id = str(uuid.uuid4())
        extra = [{
            "type": "update",
            "table": "withdrawal_requests",
            "match": {"id": wr_id},
            "record": {"status": "APPROVED", "approved_by": "bm_ogijo"},
        }]
        res_cash = self._run_with_patches(lambda: SavingsService.execute_approved_withdrawal(
            uow=uow,
            wr_item={
                "id": wr_id,
                "savings_type": "Individual",
                "operation_type": "Cash Withdrawal",
                "client_id": CLIENT_UUID,
                "client_name": "Ada Obi",
                "requested_by": "co_ayo",
                "amount": 15000.0,
                "reference": "REF-WTH-CASH",
                "remarks": "Cash payout",
            },
            branch="Ogijo",
            op_date=WEEKDAY,
            actor_username="bm_ogijo",
            actor_role="Branch Manager",
            extra_operations=extra,
        ))
        self.assertEqual(res_cash["executed_table"], "individual_savings")
        self.assertTrue(res_cash["cash_paid"])
        ops = self._last_rpc_ops(uow)
        wr_upd = [o for o in ops if o.get("table") == "withdrawal_requests"][0]["record"]
        self.assertEqual(wr_upd["executed_table"], "individual_savings")
        self.assertEqual(wr_upd["executed_record_id"], res_cash["executed_record_id"])
        fin = [o for o in ops if o.get("type") == "post_financial_transaction"][0]
        cr_codes = [e["account_code"] for e in fin["record"]["entries_payload"] if e["side"] == "Credit"]
        self.assertIn("1000", cr_codes)

        # Bank Transfer -> CR 1050, cash_paid=False
        uow_bank = _make_uow()
        res_bank = self._run_with_patches(lambda: SavingsService.execute_approved_withdrawal(
            uow=uow_bank,
            wr_item={
                "id": str(uuid.uuid4()),
                "savings_type": "Individual",
                "operation_type": "Client Bank Account (Transfer)",
                "client_id": CLIENT_UUID,
                "client_name": "Ada Obi",
                "requested_by": "co_ayo",
                "amount": 22000.0,
                "reference": "REF-WTH-BANK",
                "remarks": "Bank transfer",
            },
            branch="Ogijo",
            op_date=WEEKDAY,
            actor_username="bm_ogijo",
            actor_role="Branch Manager",
        ))
        self.assertFalse(res_bank["cash_paid"])
        fin_b = [o for o in self._last_rpc_ops(uow_bank) if o.get("type") == "post_financial_transaction"][0]
        cr_b = [e["account_code"] for e in fin_b["record"]["entries_payload"] if e["side"] == "Credit"]
        self.assertEqual(cr_b, ["1050"])

    def test_execute_approved_withdrawal_group_variants_and_fail_closed_checks(self):
        # 1. Group Member Debt Offset "(Member Debt)" label
        uow = _make_uow()
        res_off = self._run_with_patches(lambda: SavingsService.execute_approved_withdrawal(
            uow=uow,
            wr_item={
                "id": str(uuid.uuid4()),
                "savings_type": "Group",
                "operation_type": "Loan Repayment / Asset Debt Offset (Member Debt)",
                "group_id": GROUP_UUID,
                "group_name": "Unity Group",
                "client_id": CLIENT_UUID,
                "loan_id": LOAN_UUID,
                "requested_by": "co_ayo",
                "amount": 12000.0,
                "reference": "REF-GRP-OFF",
            },
            branch="Ogijo",
            op_date=WEEKDAY,
            actor_username="bm_ogijo",
            actor_role="Branch Manager",
        ))
        self.assertEqual(res_off["status"], "SUCCESS")
        self.assertEqual(res_off["executed_table"], "groupsavings")
        self.assertFalse(res_off["cash_paid"])
        tables = [o.get("table") for o in self._last_rpc_ops(uow)]
        self.assertIn("group_savings", tables)
        self.assertIn("repayments", tables)

        # 2. Group Savings Transfer normalizing "Group Account" -> "GroupSavings"
        uow_tr = _make_uow()
        DEST_GRP = "g1eebc99-9c0b-4ef8-bb6d-6bb9bd380a99"
        res_tr = self._run_with_patches(lambda: SavingsService.execute_approved_withdrawal(
            uow=uow_tr,
            wr_item={
                "id": str(uuid.uuid4()),
                "savings_type": "Group",
                "operation_type": "Another Member or Group Savings",
                "group_id": GROUP_UUID,
                "group_name": "Unity Group",
                "destination_id": DEST_GRP,
                "destination_name": "Hope Group",
                "destination_type": "Group Account",
                "requested_by": "co_ayo",
                "amount": 9000.0,
                "reference": "REF-GRP-TRF",
            },
            branch="Ogijo",
            op_date=WEEKDAY,
            actor_username="bm_ogijo",
            actor_role="Branch Manager",
        ))
        self.assertEqual(res_tr["executed_table"], "savings_transfer")
        grp_ops = [o for o in self._last_rpc_ops(uow_tr) if o.get("table") == "group_savings"]
        self.assertEqual(len(grp_ops), 2)

        # 3. Group LAPS Reserve fail-closed without beneficiary client_id
        uow_laps_bad = _make_uow()
        with self.assertRaises(ValueError):
            self._run_with_patches(lambda: SavingsService.execute_approved_withdrawal(
                uow=uow_laps_bad,
                wr_item={
                    "id": str(uuid.uuid4()),
                    "savings_type": "Group",
                    "operation_type": "LAPS Reserve (Group Closed)",
                    "group_id": GROUP_UUID,
                    "group_name": "Unity Group",
                    "requested_by": "co_ayo",
                    "amount": 5000.0,
                    "reference": "REF-GRP-LAPS-BAD",
                },
                branch="Ogijo",
                op_date=WEEKDAY,
                actor_username="bm_ogijo",
                actor_role="Branch Manager",
            ))

        # 4. Insufficient balance fail-closed
        uow_low = _make_uow()
        uow_low.individual_savings.get_total_balance.return_value = 500.0
        with self.assertRaises(ValueError):
            self._run_with_patches(lambda: SavingsService.execute_approved_withdrawal(
                uow=uow_low,
                wr_item={
                    "id": str(uuid.uuid4()),
                    "savings_type": "Individual",
                    "operation_type": "Cash Withdrawal",
                    "client_id": CLIENT_UUID,
                    "client_name": "Ada Obi",
                    "requested_by": "co_ayo",
                    "amount": 5000.0,
                },
                branch="Ogijo",
                op_date=WEEKDAY,
                actor_username="bm_ogijo",
                actor_role="Branch Manager",
            ))

    def test_reverse_savings_supports_all_4_tables_and_posts_reversing_event(self):
        for tbl, row in [
            ("individual_savings", {"id": str(uuid.uuid4()), "client_id": CLIENT_UUID, "client_name": "Ada", "branch": "Ogijo", "officer": "co_ayo", "deposit_amount": 0.0, "withdrawal_amount": 7500.0, "reference": "REF-I1", "remarks": "Cash", "idempotency_key": "K-I1"}),
            ("group_savings", {"id": str(uuid.uuid4()), "group_id": GROUP_UUID, "group_name": "Unity", "branch": "Ogijo", "officer": "co_ayo", "deposit_amount": 0.0, "withdrawal_amount": 8500.0, "reference": "REF-G1", "remarks": "Bank transfer", "idempotency_key": "K-G1"}),
            ("internal_savings", {"id": str(uuid.uuid4()), "client_name": "Branch Misc", "branch": "Ogijo", "officer": "bm_ogijo", "deposit_amount": 0.0, "withdrawal_amount": 4000.0, "reference": "REF-M1", "remarks": "Misc payout", "idempotency_key": "K-M1"}),
            ("laps_savings", {"id": str(uuid.uuid4()), "client_id": CLIENT2_UUID, "client_name": "Tunde", "branch": "Ogijo", "officer": "co_ayo", "deposit_amount": 0.0, "withdrawal_amount": 11000.0, "reference": "REF-L1", "remarks": "LAPS Bank Transfer", "idempotency_key": "K-L1"}),
        ]:
            uow = _make_uow()
            def _table_dispatch(tname, target_tbl=tbl, target_row=row):
                if tname == target_tbl:
                    return _FakeQuery([target_row])
                if tname == "financial_transactions":
                    return _FakeQuery([{"event_id": str(uuid.uuid4())}])
                return _FakeQuery([])
            uow.client.table.side_effect = _table_dispatch

            res = self._run_with_patches(lambda: SavingsService.reverse_savings(
                uow=uow,
                original_savings_id=row["id"],
                reason="Wrong payout entry",
                reversed_by="bm_ogijo",
                reversal_date=WEEKDAY,
            ))
            self.assertEqual(res["status"], "SUCCESS")
            self.assertEqual(res["event_type"], "SavingsWithdrawalReversed")
            self.assertEqual(res["amount"], float(row["withdrawal_amount"]))
            ops = self._last_rpc_ops(uow)
            sav_ins = [o["record"] for o in ops if o.get("table") == tbl and o.get("type") == "insert"][0]
            self.assertEqual(sav_ins["withdrawal_amount"], -float(row["withdrawal_amount"]))
            self.assertTrue(str(sav_ins["idempotency_key"]).startswith("REV-"))
            evt_op = [o["record"] for o in ops if o.get("table") == "event_store"][0]
            self.assertEqual(evt_op["event_type"], "SavingsWithdrawalReversed")

    def test_cashbook_projections_bank_1050_and_order_independent_reversal(self):
        # 1. CO Cashbook: Bank-funded SavingsWithdrawn (CR 1050 / DR 2000) + Bank Withdrawal Reversal (DR 1050 / CR 2000) + Cash Reversal
        co_uow = MagicMock()
        tx_1, tx_2, tx_3, tx_4 = "tx-bank-wth", "tx-bank-rev", "tx-cash-wth", "tx-cash-rev"
        p_iso = WEEKDAY.isoformat()

        def _tx_join(ev_id, ref, narr, ev_type, payload, officer_id=OFFICER_UUID):
            return {
                "event_id": ev_id,
                "posting_date": p_iso,
                "narration": narr,
                "reference": ref,
                "officer_id": officer_id,
                "event_store": {"event_type": ev_type, "payload": payload},
            }

        # Reverse order of ledger entries to prove order-independence: DR 1050 appears BEFORE CR 1050
        le_rows = [
            {
                "entry_id": "le-2a", "transaction_id": tx_2, "account_code": "1050", "side": "Debit", "amount": 25000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e2", "REV-BW1", "REVERSAL of REF-BW1", "SavingsWithdrawalReversed", {"amount": 25000.0, "cash_paid": False, "payout_method": "Bank"}),
            },
            {
                "entry_id": "le-2b", "transaction_id": tx_2, "account_code": "2000", "side": "Credit", "amount": 25000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e2", "REV-BW1", "REVERSAL of REF-BW1", "SavingsWithdrawalReversed", {"amount": 25000.0, "cash_paid": False, "payout_method": "Bank"}),
            },
            {
                "entry_id": "le-1a", "transaction_id": tx_1, "account_code": "1050", "side": "Credit", "amount": 25000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e1", "REF-BW1", "Bank transfer savings payout", "SavingsWithdrawn", {"amount": 25000.0, "cash_paid": False, "payout_method": "Bank"}),
            },
            {
                "entry_id": "le-1b", "transaction_id": tx_1, "account_code": "2000", "side": "Debit", "amount": 25000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e1", "REF-BW1", "Bank transfer savings payout", "SavingsWithdrawn", {"amount": 25000.0, "cash_paid": False, "payout_method": "Bank"}),
            },
            {
                "entry_id": "le-4a", "transaction_id": tx_4, "account_code": "1000", "side": "Debit", "amount": 10000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e4", "REV-CW1", "REVERSAL of REF-CW1", "SavingsWithdrawalReversed", {"amount": 10000.0, "cash_paid": True, "payout_method": "Cash"}),
            },
            {
                "entry_id": "le-4b", "transaction_id": tx_4, "account_code": "2000", "side": "Credit", "amount": 10000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e4", "REV-CW1", "REVERSAL of REF-CW1", "SavingsWithdrawalReversed", {"amount": 10000.0, "cash_paid": True, "payout_method": "Cash"}),
            },
            {
                "entry_id": "le-3a", "transaction_id": tx_3, "account_code": "1000", "side": "Credit", "amount": 10000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e3", "REF-CW1", "Cash withdrawal", "SavingsWithdrawn", {"amount": 10000.0, "cash_paid": True, "payout_method": "Cash"}),
            },
            {
                "entry_id": "le-3b", "transaction_id": tx_3, "account_code": "2000", "side": "Debit", "amount": 10000.0, "branch_id": BRANCH_UUID,
                "financial_transactions": _tx_join("e3", "REF-CW1", "Cash withdrawal", "SavingsWithdrawn", {"amount": 10000.0, "cash_paid": True, "payout_method": "Cash"}),
            },
        ]

        def _co_tbl(t):
            if t == "financial_ledger_entries":
                return _FakeQuery(le_rows)
            return _FakeQuery([])

        co_uow.client.table.side_effect = _co_tbl
        co_proj = CoCashbookProjectionBuilder.rebuild_co_projection(co_uow, BRANCH_UUID, OFFICER_UUID, WEEKDAY)
        self.assertEqual(co_proj["bank_withdrawal"], 0.0)
        self.assertEqual(co_proj["product_withdrawal"], 0.0)
        self.assertEqual(co_proj["savings_withdrawal"], 0.0)

        # 2. Master Cashbook: Non-CO BM Bank Transfer LAPS Payout (CR 1050) without reversal
        bm_uow = MagicMock()
        bm_le = [{
            "entry_id": "le-bm-1",
            "transaction_id": "tx-bm-laps",
            "account_code": "1050",
            "side": "Credit",
            "amount": 14000.0,
            "branch_id": BRANCH_UUID,
            "financial_transactions": _tx_join("ebm1", "REF-LAPS-B", "BM LAPS Bank Payout", "LapsPaidOut", {"amount": 14000.0, "cash_paid": False}, officer_id=None),
        }]

        def _bm_tbl(t):
            if t == "financial_ledger_entries":
                return _FakeQuery(bm_le)
            return _FakeQuery([])

        bm_uow.client.table.side_effect = _bm_tbl
        m_proj = MasterCashbookProjectionBuilder.rebuild_master_projection(bm_uow, BRANCH_UUID, WEEKDAY)
        self.assertEqual(m_proj["laps_returns"], 14000.0)
        self.assertEqual(m_proj["bank_withdrawal"], 14000.0)

    def test_exception_reports_rules_4_to_7(self):
        uow = MagicMock()
        def _recon_tbl(tbl):
            if tbl == "event_store":
                return _FakeQuery([{"aggregate_id": "ok-id", "event_type": "SavingsWithdrawn", "payload": {"reference": "REF-OK"}}])
            if tbl == "financial_transactions":
                return _FakeQuery([{"reference": "REF-OK", "amount": 1000.0, "branch_id": BRANCH_UUID}])
            if tbl == "individual_savings":
                return _FakeQuery([
                    {"id": "w1", "client_id": "c-missing", "branch_id": BRANCH_UUID, "deposit_amount": 0.0, "withdrawal_amount": 5000.0, "reference": "REF-DUP", "posting_date": "2026-08-12"},
                    {"id": "w2", "client_id": "c-missing", "branch_id": BRANCH_UUID, "deposit_amount": 0.0, "withdrawal_amount": 2000.0, "reference": "REF-DUP", "posting_date": "2026-08-12"},
                ])
            if tbl == "repayments":
                return _FakeQuery([
                    {"id": "r1", "receipt_number": "RCP-99", "branch_id": BRANCH_UUID},
                    {"id": "r2", "receipt_number": "RCP-99", "branch_id": BRANCH_UUID},
                ])
            return _FakeQuery([])

        uow.client.table.side_effect = _recon_tbl
        ex = FinancialReconciliationService.run_15_exception_reports(uow, BRANCH_UUID)
        details = ex["details"]
        self.assertEqual(len(details["savings_withdrawal_no_ledger"]), 2)
        self.assertEqual(len(details["negative_savings_balance"]), 1)
        self.assertEqual(details["negative_savings_balance"][0]["net_balance"], -7000.0)
        self.assertEqual(len(details["duplicate_receipt_numbers"]), 1)
        self.assertEqual(len(details["duplicate_transaction_references"]), 1)


class TestWithdrawalApi022(unittest.TestCase):
    def setUp(self):
        self.uow = _make_uow()
        self.bm_user = CurrentUser(
            id=OFFICER_UUID,
            username="bm_ogijo",
            full_name="BM Ogijo",
            role="Branch Manager",
            branch="Ogijo",
            branch_id=BRANCH_UUID,
            permissions=PERMISSIONS.get("Branch Manager", set()) | PERMISSIONS.get("Credit Officer", set()),
        )
        app.dependency_overrides[get_uow] = lambda: self.uow
        app.dependency_overrides[get_current_user] = lambda: self.bm_user
        self.client = TestClient(app)

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_daily_withdrawals_covers_4_tables_reversals_and_tag_stripping(self):
        wid1 = str(uuid.uuid4())
        wid2 = str(uuid.uuid4())
        gid1 = GROUP_UUID
        self.uow.loans._resolve_officer_id.return_value = OFFICER_UUID

        def _tbl(name):
            if name == "groups":
                return _FakeQuery([{"group_id": gid1, "name": "Unity Group", "branch_id": BRANCH_UUID, "officer_id": OFFICER_UUID}])
            if name == "clients":
                return _FakeQuery([{"client_id": CLIENT_UUID, "client_code": "IC-001", "name": "Ada Obi", "branch_id": BRANCH_UUID, "officer_id": OFFICER_UUID, "group_id": gid1}])
            if name == "individual_savings":
                return _FakeQuery([
                    {"id": wid1, "client_id": CLIENT_UUID, "client_name": "Ada Obi", "withdrawal_amount": 5000.0, "deposit_amount": 0.0, "posting_date": "2026-08-12", "reference": "REF-IND-1", "remarks": "[DEST_ID:xyz][FEE:passbook] Cash payout", "officer": "co_ayo", "branch": "Ogijo"},
                    {"id": wid2, "client_id": CLIENT_UUID, "client_name": "Ada Obi", "withdrawal_amount": -5000.0, "deposit_amount": 0.0, "posting_date": "2026-08-12", "reference": "REV-REF-IND-1", "remarks": "REVERSAL of REF-IND-1: Mistake", "officer": "co_ayo", "branch": "Ogijo"},
                ])
            if name == "group_savings":
                return _FakeQuery([{"id": str(uuid.uuid4()), "group_id": gid1, "group_name": "Unity Group", "withdrawal_amount": 8000.0, "deposit_amount": 0.0, "posting_date": "2026-08-12", "reference": "REF-GRP-1", "remarks": "Group payout", "officer": "co_ayo", "branch": "Ogijo"}])
            if name == "internal_savings":
                return _FakeQuery([{"id": str(uuid.uuid4()), "client_name": "Branch Misc", "withdrawal_amount": 3000.0, "deposit_amount": 0.0, "posting_date": "2026-08-12", "reference": "REF-MISC-1", "remarks": "Misc payout", "officer": "bm_ogijo", "branch": "Ogijo"}])
            if name == "laps_savings":
                return _FakeQuery([{"id": str(uuid.uuid4()), "client_id": CLIENT_UUID, "client_name": "Ada Obi", "withdrawal_amount": 2000.0, "deposit_amount": 0.0, "posting_date": "2026-08-12", "reference": "REF-LAPS-1", "remarks": "LAPS cash", "officer": "co_ayo", "branch": "Ogijo"}])
            if name == "withdrawal_requests":
                return _FakeQuery([])
            return _FakeQuery([])

        self.uow.client.table.side_effect = _tbl
        resp = self.client.get("/api/v1/co/withdrawals/daily-withdrawals?date=2026-08-12")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        # Net: 5000 - 5000 + 8000 + 3000 + 2000 = 13000.0
        self.assertEqual(data["kpis"]["total_withdrawn"], 13000.0)
        statuses = {r["reference"]: r["status"] for r in data["all_records"]}
        self.assertEqual(statuses["REF-IND-1"], "REVERSED")
        self.assertEqual(statuses["REV-REF-IND-1"], "REVERSAL")
        self.assertEqual(statuses["REF-GRP-1"], "ACTIVE")
        self.assertEqual(statuses["REF-MISC-1"], "ACTIVE")
        self.assertEqual(statuses["REF-LAPS-1"], "ACTIVE")
        ind_det = [r["details"] for r in data["all_records"] if r["reference"] == "REF-IND-1"][0]
        self.assertNotIn("[DEST_ID:", ind_det)
        self.assertNotIn("[FEE:", ind_det)

    def test_approve_reject_guards_and_audit_withdrawals_endpoint(self):
        wr_id = str(uuid.uuid4())
        # Cannot reject an already APPROVED request -> 409 Conflict
        self.uow.client.table.side_effect = lambda t: _FakeQuery([{"id": wr_id, "status": "APPROVED", "branch_id": BRANCH_UUID}]) if t == "withdrawal_requests" else _FakeQuery([])
        bad_rej = self.client.post("/api/v1/co/withdrawals/reject", json={"request_id": wr_id, "rejection_reason": "Late"})
        self.assertEqual(bad_rej.status_code, 409)

        # GET /api/v1/audit/withdrawals
        self.uow.client.table.side_effect = lambda t: (
            _FakeQuery([{
                "id": wr_id,
                "operational_date": "2026-08-12",
                "client_name": "Ada Obi",
                "savings_type": "Individual",
                "operation_type": "Cash Withdrawal",
                "payout_method": "Cash",
                "amount": 10000.0,
                "requested_by": "co_ayo",
                "approved_by": "bm_ogijo",
                "status": "APPROVED",
                "reference": "REF-WTH-1",
                "remarks": "[FEE:passbook] Clean withdrawal",
            }]) if t == "withdrawal_requests" else
            _FakeQuery([{
                "timestamp": "2026-08-12T10:00:00",
                "username": "bm_ogijo",
                "role": "Branch Manager",
                "action": "WITHDRAWAL_APPROVED",
                "display_name": "Ada Obi",
                "branch": "Ogijo",
                "status": "SUCCESS",
            }]) if t == "user_audit_logs" else _FakeQuery([])
        )
        aud_resp = self.client.get("/api/v1/audit/withdrawals?date_from=2026-08-01&date_to=2026-08-31")
        self.assertEqual(aud_resp.status_code, 200)
        aud_data = aud_resp.json()
        self.assertEqual(aud_data["summary"]["total_requests"], 1)
        self.assertEqual(aud_data["summary"]["approved_count"], 1)
        self.assertNotIn("[FEE:", aud_data["requests"][0]["Remarks"])
        self.assertEqual(len(aud_data["audit_events"]), 1)

    def test_collections_reversal_options_savings_withdrawals(self):
        self.uow.loans._resolve_officer_id.return_value = OFFICER_UUID
        w_id = str(uuid.uuid4())

        def _col_tbl(name):
            if name == "clients":
                return _FakeQuery([{"client_id": CLIENT_UUID, "client_code": "IC-001", "name": "Ada Obi"}])
            if name == "individual_savings":
                return _FakeQuery([{
                    "id": w_id,
                    "client_id": CLIENT_UUID,
                    "officer_id": OFFICER_UUID,
                    "branch_id": BRANCH_UUID,
                    "withdrawal_amount": 4500.0,
                    "posting_date": "2026-08-12",
                    "reference": "REF-IND-W9",
                    "remarks": "Cash payout",
                    "clients": {"name": "Ada Obi", "client_code": "IC-001"},
                }])
            return _FakeQuery([])

        self.uow.client.table.side_effect = _col_tbl
        resp = self.client.get("/api/v1/co/collections/reversal-options?category=Savings%20Withdrawals&date=2026-08-12")
        self.assertEqual(resp.status_code, 200)
        items = resp.json()["items"]
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["ref_id"], w_id)
        self.assertEqual(items[0]["category"], "Individual Withdrawal")

    def _run_with_patches(self, fn):
        from unittest.mock import patch
        from services.savings_service import FinancialPostingEngine
        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch.object(FinancialPostingEngine, "_resolve_branch_id", return_value=BRANCH_UUID), \
             patch.object(FinancialPostingEngine, "_resolve_officer_id", return_value=OFFICER_UUID):
            return fn()

    def _last_rpc_ops(self, uow):
        calls = [c for c in uow.client.rpc.call_args_list if c.args[0] == "atomic_execute_operations"]
        self.assertTrue(calls, "Expected atomic_execute_operations RPC call")
        return calls[-1].args[1]["p_operations"]

    def test_dynamic_misc_savings_officer_resolution_fail_closed(self):
        # Empty branch or unconfigured branch must fail closed ("", "") with zero hardcoded fallback
        uow_empty = _make_uow()
        uow_empty.client.table.side_effect = lambda t: _FakeQuery([])
        self.assertEqual(SavingsService.get_branch_misc_savings_officer(uow_empty, ""), ("", ""))
        self.assertEqual(SavingsService.get_branch_misc_savings_officer(uow_empty, "UnconfiguredBranch"), ("", ""))

        # Primary lookup: branches.officer_assignments with is_misc_savings_manager=True
        uow_oa = _make_uow()
        uow_oa.client.table.side_effect = lambda t: (
            _FakeQuery([{
                "branch_id": BRANCH_UUID,
                "name": "Ikorodu",
                "officer_assignments": [
                    {"officer_id": "other-id", "full_name": "Regular CO", "is_misc_savings_manager": False},
                    {"officer_id": OFFICER_UUID, "full_name": "Designated Misc Manager", "is_misc_savings_manager": True},
                ],
            }])
            if t == "branches" else _FakeQuery([])
        )
        self.assertEqual(
            SavingsService.get_branch_misc_savings_officer(uow_oa, "Ikorodu"),
            (OFFICER_UUID, "Designated Misc Manager"),
        )

        # Secondary lookup: app_users.extra_fields.is_misc_savings_manager
        uow_usr = _make_uow()
        uow_usr.client.table.side_effect = lambda t: (
            _FakeQuery([{"branch_id": BRANCH_UUID, "name": "Ikorodu", "officer_assignments": []}])
            if t == "branches"
            else _FakeQuery([{
                "id": OFFICER_UUID,
                "username": "co_misc",
                "full_name": "App Misc Officer",
                "is_active": True,
                "extra_fields": {"is_misc_savings_manager": True},
            }]) if t == "app_users"
            else _FakeQuery([])
        )
        self.assertEqual(
            SavingsService.get_branch_misc_savings_officer(uow_usr, BRANCH_UUID),
            (OFFICER_UUID, "App Misc Officer"),
        )

    def test_withdrawal_classification_engine_is_cash_paid_variants(self):
        from domain.enums import TransactionClassification
        cls_bank = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.CUSTOMER_CASH_WITHDRAWAL, 10000.0, is_cash_paid=False
        )
        self.assertEqual(cls_bank["product_withdrawal"], 10000.0)
        self.assertEqual(cls_bank["cash_withdrawal"], 0.0)
        self.assertFalse(cls_bank["affects_cash_vault"])

        cls_default = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.CUSTOMER_CASH_WITHDRAWAL, 10000.0, is_cash_paid=None
        )
        self.assertEqual(cls_default["product_withdrawal"], 10000.0)
        self.assertEqual(cls_default["cash_withdrawal"], 10000.0)
        self.assertTrue(cls_default["affects_cash_vault"])

    def test_execute_approved_withdrawal_all_6_non_direct_branches_and_atomic_effects(self):
        from services.client_status_service import ClientStatusService
        ClientStatusService._status_cache = {
            "Registered": {"status_id": "st-reg", "name": "Registered"},
            "Completed": {"status_id": "st-comp", "name": "Completed"},
        }
        try:
            cases = [
                (
                    "loan_offset",
                    {
                        "savings_type": "Individual",
                        "operation_type": "Loan Offset",
                        "client_id": CLIENT_UUID,
                        "client_name": "Ada Obi",
                        "loan_id": LOAN_UUID,
                        "amount": 50000.0,
                        "reference": "REF-LO-1",
                    },
                    "individual_savings",
                    "individualsavings",
                ),
                (
                    "fee_offset_group",
                    {
                        "savings_type": "Group",
                        "operation_type": "Fee Payment",
                        "group_id": "d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55",
                        "group_name": "Unity Group",
                        "fee_type": "Passbook",
                        "amount": 1000.0,
                        "reference": "REF-FEE-1",
                    },
                    "group_savings",
                    "fees",
                ),
                (
                    "savings_transfer",
                    {
                        "savings_type": "Individual",
                        "operation_type": "Savings Transfer",
                        "client_id": CLIENT_UUID,
                        "client_name": "Ada Obi",
                        "destination_id": CLIENT2_UUID,
                        "destination_name": "Bisi Ade",
                        "destination_type": "Individual",
                        "amount": 5000.0,
                        "reference": "REF-TR-1",
                    },
                    "individual_savings",
                    "savings_transfer",
                ),
                (
                    "laps_transfer",
                    {
                        "savings_type": "Individual",
                        "operation_type": "LAPS Transfer",
                        "client_id": CLIENT_UUID,
                        "client_name": "Ada Obi",
                        "amount": 8000.0,
                        "reference": "REF-LT-1",
                    },
                    "laps_savings",
                    "laps_savings",
                ),
                (
                    "laps_return",
                    {
                        "savings_type": "LAPS",
                        "operation_type": "Return to Savings",
                        "client_id": CLIENT_UUID,
                        "client_name": "Ada Obi",
                        "amount": 4000.0,
                        "reference": "REF-LR-1",
                    },
                    "laps_savings",
                    "laps_savings",
                ),
                (
                    "laps_payout",
                    {
                        "savings_type": "LAPS",
                        "operation_type": "LAPS Payout",
                        "client_id": CLIENT_UUID,
                        "client_name": "Ada Obi",
                        "payout_method": "Bank Transfer",
                        "amount": 3000.0,
                        "reference": "REF-LP-1",
                    },
                    "laps_savings",
                    "laps_savings",
                ),
            ]
            for label, wr_item, expected_db_tbl, expected_ret_tbl in cases:
                uow = _make_uow()
                if label == "loan_offset":
                    def _lo_tbl(t):
                        if t == "loans":
                            return _FakeQuery([{
                                "loan_id": LOAN_UUID,
                                "client_id": CLIENT_UUID,
                                "officer_id": OFFICER_UUID,
                                "branch_id": BRANCH_UUID,
                                "product_category": "Product",
                                "product_type": "Weekly 12",
                                "repayment_cycle": "Weekly",
                                "duration": 12,
                                "active_credit": 50000.0,
                                "total_due": 50000.0,
                                "loan_amount": 50000.0,
                                "loan_repay": 2500.0,
                                "status": "Active",
                            }])
                        if t == "loan_schedule":
                            return _FakeQuery([{
                                "id": "sched-1",
                                "loan_id": LOAN_UUID,
                                "installment_number": 1,
                                "total_due": 2500.0,
                                "paid_amount": 0.0,
                                "status": "Pending",
                            }])
                        if t == "clients":
                            return _FakeQuery([{"client_id": CLIENT_UUID, "status": "On Loan", "status_id": "st-on"}])
                        return _FakeQuery([])
                    uow.client.table.side_effect = _lo_tbl
                elif label == "laps_return":
                    uow.client.table.side_effect = lambda t: (
                        _FakeQuery([{"client_id": CLIENT_UUID, "status": "Closed", "status_id": "st-cl"}])
                        if t == "clients" else _FakeQuery([])
                    )

                wr_id = str(uuid.uuid4())
                full_wr = {"id": wr_id, "requested_by": "co_ayo", **wr_item}
                extra = [{
                    "type": "update",
                    "table": "withdrawal_requests",
                    "match": {"id": wr_id},
                    "record": {"status": "APPROVED", "approved_by": "bm_ogijo"},
                }]
                res = self._run_with_patches(lambda: SavingsService.execute_approved_withdrawal(
                    uow=uow,
                    wr_item=full_wr,
                    branch="Ogijo",
                    op_date=WEEKDAY,
                    actor_username="bm_ogijo",
                    actor_role="Branch Manager",
                    extra_operations=extra,
                ))
                self.assertEqual(res["executed_table"], expected_ret_tbl, label)
                self.assertTrue(res.get("executed_record_id"), label)
                ops = self._last_rpc_ops(uow)
                wr_upds = [o["record"] for o in ops if o.get("table") == "withdrawal_requests" and o.get("type") == "update"]
                self.assertEqual(len(wr_upds), 1, label)
                self.assertEqual(wr_upds[0]["executed_record_id"], res["executed_record_id"], label)
                self.assertEqual(wr_upds[0]["executed_table"], expected_db_tbl, label)

                if label == "loan_offset":
                    self.assertTrue(any(o.get("table") == "loan_payoff_excess_records" and o["record"]["excess_amount"] == 47500.0 for o in ops))
                    self.assertTrue(any(o.get("table") == "loans" and o.get("type") == "update" and o["record"].get("status") == "Completed" for o in ops))
                    self.assertTrue(any(o.get("table") == "loan_schedule" and o.get("type") == "update" and o["record"].get("status") == "Paid" for o in ops))
                    self.assertTrue(any(o.get("table") == "clients" and o.get("type") == "update" and o["record"].get("status") == "Completed" for o in ops))
                elif label == "fee_offset_group":
                    fee_ins = [o["record"] for o in ops if o.get("table") == "fees" and o.get("type") == "insert"][0]
                    self.assertEqual(fee_ins["group_id"], "d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55")
                    self.assertIsNone(fee_ins["client_id"])
                elif label == "laps_return":
                    self.assertTrue(any(o.get("table") == "clients" and o.get("type") == "update" and o["record"].get("status") == "Registered" for o in ops))
        finally:
            ClientStatusService._status_cache = {}

    def test_reverse_savings_fails_closed_on_compound_transactions(self):
        for ev_type in ("LoanOffsetFromSavings", "FeeOffsetFromSavings", "SavingsTransferred", "LapsTransferred", "LapsRestoredToSavings"):
            uow = _make_uow()
            w_id = str(uuid.uuid4())
            uow.client.table.side_effect = lambda t, wid=w_id, et=ev_type: (
                _FakeQuery([{
                    "id": wid, "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID,
                    "deposit_amount": 0.0, "withdrawal_amount": 5000.0, "reference": "REF-CMP",
                    "remarks": "Compound entry", "posting_date": WEEKDAY.isoformat(),
                }]) if t == "individual_savings"
                else _FakeQuery([{"event_type": et, "aggregate_id": wid, "payload": {"reference": "REF-CMP"}}]) if t == "event_store"
                else _FakeQuery([])
            )
            with self.assertRaises(ValueError, msg=f"Expected ValueError for {ev_type}"):
                self._run_with_patches(lambda: SavingsService.reverse_savings(
                    uow=uow,
                    original_savings_id=w_id,
                    reason="Should fail",
                    reversed_by="bm_ogijo",
                    reversal_date=WEEKDAY,
                ))

        # Compound withdrawal_requests.operation_type must also fail closed even without event_store match
        uow_wr = _make_uow()
        w_id2 = str(uuid.uuid4())
        uow_wr.client.table.side_effect = lambda t, wid=w_id2: (
            _FakeQuery([{
                "id": wid, "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID,
                "deposit_amount": 0.0, "withdrawal_amount": 5000.0, "reference": "LAPS-RET-1234",
                "remarks": "Compound WR", "posting_date": WEEKDAY.isoformat(),
            }]) if t == "laps_savings"
            else _FakeQuery([{"operation_type": "Return to Savings", "executed_record_id": wid, "reference": "LAPS-RET-1234"}]) if t == "withdrawal_requests"
            else _FakeQuery([])
        )
        with self.assertRaises(ValueError):
            self._run_with_patches(lambda: SavingsService.reverse_savings(
                uow=uow_wr,
                original_savings_id=w_id2,
                reason="Should fail",
                reversed_by="bm_ogijo",
                reversal_date=WEEKDAY,
            ))

    def test_withdrawals_api_rbac_4eyes_idempotency_pending_and_visibility_guards(self):
        from fastapi.testclient import TestClient
        from fastapi import HTTPException
        from unittest.mock import patch
        from api.main import app
        from api.dependencies import get_uow, get_current_user
        from models.user import CurrentUser
        from api.schemas.withdrawals import CreateWithdrawalRequestInput, ApproveWithdrawalInput, RejectWithdrawalInput
        from api.routes.co.withdrawals import (
            create_withdrawal_request,
            get_individual_options,
            get_daily_withdrawals,
            approve_withdrawal,
            reject_withdrawal,
        )

        # 1. Director must receive 403 across CO withdrawal routes
        director_user = CurrentUser(
            id=OFFICER_UUID, username="dir_user", full_name="Director",
            role="Director", branch="Ogijo", branch_id=BRANCH_UUID, permissions=set()
        )
        uow_dir = _make_uow()
        app.dependency_overrides[get_uow] = lambda: uow_dir
        app.dependency_overrides[get_current_user] = lambda: director_user
        client = TestClient(app)
        try:
            self.assertEqual(client.get("/api/v1/co/withdrawals/individual-options").status_code, 403)
            self.assertEqual(client.get("/api/v1/co/withdrawals/requests").status_code, 403)
            self.assertEqual(
                client.post(
                    "/api/v1/co/withdrawals/request",
                    json={"savings_type": "Individual", "operation_type": "Cash Withdrawal", "client_id": CLIENT_UUID, "amount": 1000.0},
                ).status_code,
                403,
            )
        finally:
            app.dependency_overrides.clear()

        co_user = CurrentUser(
            id=OFFICER_UUID, username="co_ayo", full_name="Ayo CO",
            role="Credit Officer", branch="Ogijo", branch_id=BRANCH_UUID, permissions=set()
        )
        bm_user = CurrentUser(
            id=str(uuid.uuid4()), username="bm_ogijo", full_name="BM Ogijo",
            role="Branch Manager", branch="Ogijo", branch_id=BRANCH_UUID, permissions=set()
        )

        # 2. 4-Eyes: self-approve and self-reject raise 403
        uow_4e = _make_uow()
        uow_4e.client.table.side_effect = lambda t: (
            _FakeQuery([{
                "id": "wr-self", "branch_id": BRANCH_UUID, "status": "PENDING",
                "savings_type": "Individual", "operation_type": "Cash Withdrawal",
                "client_id": CLIENT_UUID, "client_name": "Ada Obi",
                "amount": 5000.0, "requested_by": "bm_ogijo",
            }]) if t == "withdrawal_requests" else _FakeQuery([])
        )
        with self.assertRaises(HTTPException) as ctx_app:
            approve_withdrawal(ApproveWithdrawalInput(request_id="wr-self"), current_user=bm_user, uow=uow_4e)
        self.assertEqual(ctx_app.exception.status_code, 403)
        with self.assertRaises(HTTPException) as ctx_rej:
            reject_withdrawal(RejectWithdrawalInput(request_id="wr-self", rejection_reason="test"), current_user=bm_user, uow=uow_4e)
        self.assertEqual(ctx_rej.exception.status_code, 403)

        # 3. Idempotency deduplication returns existing request instead of creating duplicate
        uow_idem = _make_uow()
        uow_idem.loans._resolve_officer_id.return_value = OFFICER_UUID
        uow_idem.client.table.side_effect = lambda t: (
            _FakeQuery([{
                "id": "wr-existing-1", "reference": "WR-REQ-EXIST1", "status": "PENDING", "idempotency_key": "WR-REQ-idem-abc",
            }]) if t == "withdrawal_requests" else _FakeQuery([])
        )
        with patch("api.routes.co.withdrawals.BusinessDateService.is_operational_open", return_value=(True, "Open")):
            resp_idem = create_withdrawal_request(
                CreateWithdrawalRequestInput(
                    savings_type="Individual", operation_type="Cash Withdrawal",
                    client_id=CLIENT_UUID, amount=2000.0, idempotency_key="idem-abc"
                ),
                current_user=co_user, uow=uow_idem,
            )
        self.assertEqual(resp_idem.request_id, "wr-existing-1")
        self.assertEqual(resp_idem.reference, "WR-REQ-EXIST1")

        # 4. Pending balance deduction & overdraft rejection
        uow_pend = _make_uow()
        uow_pend.loans._resolve_officer_id.return_value = OFFICER_UUID
        uow_pend.individual_savings.get_total_balance.return_value = 10000.0
        def _pend_tbl(t):
            if t == "clients":
                return _FakeQuery([{"client_id": CLIENT_UUID, "name": "Ada Obi", "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID}])
            if t == "withdrawal_requests":
                return _FakeQuery([{
                    "id": "wr-other", "idempotency_key": "other-key", "savings_type": "Individual",
                    "client_id": CLIENT_UUID, "amount": 7000.0, "status": "PENDING",
                }])
            return _FakeQuery([])
        uow_pend.client.table.side_effect = _pend_tbl
        with patch("api.routes.co.withdrawals.BusinessDateService.is_operational_open", return_value=(True, "Open")):
            with self.assertRaises(HTTPException) as ctx_ovd:
                create_withdrawal_request(
                    CreateWithdrawalRequestInput(
                        savings_type="Individual", operation_type="Cash Withdrawal",
                        client_id=CLIENT_UUID, amount=4000.0, idempotency_key="new-key"
                    ),
                    current_user=co_user, uow=uow_pend,
                )
            self.assertEqual(ctx_ovd.exception.status_code, 400)
            self.assertIn("Insufficient available balance", str(ctx_ovd.exception.detail))
            self.assertIn("3,000.00", str(ctx_ovd.exception.detail))

        # 5. Pending loans excluded from get_individual_options & rejected on offset + excess offset rejected
        uow_loan = _make_uow()
        uow_loan.loans._resolve_officer_id.return_value = OFFICER_UUID
        uow_loan.individual_savings.get_total_balance.return_value = 50000.0
        def _loan_tbl(t):
            if t == "clients":
                return _FakeQuery([{"client_id": CLIENT_UUID, "client_code": "C001", "name": "Ada Obi", "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID}])
            if t == "loans":
                return _FakeQuery([
                    {"loan_id": "ln-pending", "client_id": CLIENT_UUID, "status": "Pending", "active_credit": 20000.0, "total_due": 20000.0, "loan_amount": 20000.0},
                    {"loan_id": LOAN_UUID, "client_id": CLIENT_UUID, "status": "Active", "active_credit": 10000.0, "total_due": 10000.0, "loan_amount": 10000.0},
                ])
            if t == "individual_savings":
                return _FakeQuery([{"client_id": CLIENT_UUID, "deposit_amount": 50000.0, "withdrawal_amount": 0.0}])
            return _FakeQuery([])
        uow_loan.client.table.side_effect = _loan_tbl
        opts = get_individual_options(current_user=co_user, uow=uow_loan)
        self.assertEqual(len(opts.clients), 1)
        self.assertEqual([ln.loan_id for ln in opts.clients[0].eligible_loans], [LOAN_UUID])

        with patch("api.routes.co.withdrawals.BusinessDateService.is_operational_open", return_value=(True, "Open")):
            uow_loan.client.table.side_effect = lambda t: (
                _FakeQuery([{"loan_id": "ln-pending", "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID, "status": "Pending", "active_credit": 20000.0, "total_due": 20000.0, "loan_amount": 20000.0}])
                if t == "loans"
                else _FakeQuery([{"client_id": CLIENT_UUID, "name": "Ada Obi", "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID}]) if t == "clients"
                else _FakeQuery([])
            )
            with self.assertRaises(HTTPException) as ctx_pl:
                create_withdrawal_request(
                    CreateWithdrawalRequestInput(
                        savings_type="Individual", operation_type="Loan Offset",
                        client_id=CLIENT_UUID, loan_id="ln-pending", amount=5000.0
                    ),
                    current_user=co_user, uow=uow_loan,
                )
            self.assertEqual(ctx_pl.exception.status_code, 400)

            uow_loan.client.table.side_effect = lambda t: (
                _FakeQuery([{"loan_id": LOAN_UUID, "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID, "status": "Active", "active_credit": 10000.0, "total_due": 10000.0, "loan_amount": 10000.0}])
                if t == "loans"
                else _FakeQuery([{"client_id": CLIENT_UUID, "name": "Ada Obi", "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID}]) if t == "clients"
                else _FakeQuery([])
            )
            with self.assertRaises(HTTPException) as ctx_ex:
                create_withdrawal_request(
                    CreateWithdrawalRequestInput(
                        savings_type="Individual", operation_type="Loan Offset",
                        client_id=CLIENT_UUID, loan_id=LOAN_UUID, amount=15000.0
                    ),
                    current_user=co_user, uow=uow_loan,
                )
            self.assertEqual(ctx_ex.exception.status_code, 400)

        # 6. get_daily_withdrawals: cross-date REVERSED, LAPS Reserve KPI isolation, & CO hidden BM internal_savings
        uow_dw = _make_uow()
        uow_dw.loans._resolve_officer_id.return_value = OFFICER_UUID
        def _dw_tbl(t):
            if t == "individual_savings":
                return _FakeQuery([
                    {
                        "id": "w-orig-1", "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID,
                        "withdrawal_amount": 12000.0, "posting_date": WEEKDAY.isoformat(),
                        "reference": "REF-W1", "remarks": "Cash withdrawal",
                        "clients": {"name": "Ada Obi", "client_code": "C001", "groups": {"name": "Unity"}},
                    },
                    {
                        "id": "w-rev-later", "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID,
                        "withdrawal_amount": -12000.0, "posting_date": "2026-08-15",
                        "reference": "REV-REF-W1", "remarks": "REVERSAL of REF-W1",
                    },
                    {
                        "id": "w-laps-res", "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID,
                        "withdrawal_amount": 6000.0, "posting_date": WEEKDAY.isoformat(),
                        "reference": "LAPS-XFER-1", "remarks": "[LAPS TRANSFER] Reserve closed balance",
                        "clients": {"name": "Ada Obi", "client_code": "C001", "groups": {"name": "Unity"}},
                    },
                ])
            if t == "internal_savings":
                return _FakeQuery([{
                    "id": "int-bm-1", "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID,
                    "withdrawal_amount": 20000.0, "posting_date": WEEKDAY.isoformat(),
                    "reference": "REF-MISC-BM1", "remarks": "[BM DIRECT EXECUTION] Branch vault expense",
                }])
            return _FakeQuery([])
        uow_dw.client.table.side_effect = _dw_tbl
        dw_resp = get_daily_withdrawals(
            target_date=WEEKDAY.isoformat(),
            show_all=False,
            category_filter=None,
            search=None,
            current_user=co_user,
            uow=uow_dw,
        )
        by_ref = {r.reference: r for r in dw_resp.all_records}
        self.assertEqual(by_ref["REF-W1"].status, "REVERSED")
        self.assertEqual(by_ref["LAPS-XFER-1"].category, "LAPS Reserve")
        self.assertNotIn("REF-MISC-BM1", by_ref)
        self.assertEqual(dw_resp.kpis.laps_reserved, 6000.0)
        self.assertEqual(dw_resp.kpis.cash_bank_paid, 12000.0)
        self.assertEqual(dw_resp.kpis.total_withdrawn, 18000.0)

    def test_collections_get_reversal_options_excludes_compound_withdrawals(self):
        from api.routes.co.collections import get_reversal_options
        from models.user import CurrentUser
        co_user = CurrentUser(
            id=OFFICER_UUID, username="co_ayo", full_name="Ayo CO",
            role="Credit Officer", branch="Ogijo", branch_id=BRANCH_UUID, permissions=set()
        )
        uow = _make_uow()
        uow.loans._resolve_officer_id.return_value = OFFICER_UUID
        w_cash_id = str(uuid.uuid4())
        w_cmp_id = str(uuid.uuid4())
        w_wr_id = str(uuid.uuid4())
        def _col_tbl(t):
            if t == "individual_savings":
                return _FakeQuery([
                    {"id": w_cash_id, "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID, "withdrawal_amount": 5000.0, "posting_date": WEEKDAY.isoformat(), "reference": "REF-CASH-1", "remarks": "Cash payout", "clients": {"name": "Ada Obi", "client_code": "C001"}},
                    {"id": w_cmp_id, "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID, "withdrawal_amount": 7000.0, "posting_date": WEEKDAY.isoformat(), "reference": "LOAN-OFFSET-1", "remarks": "Offset entry", "clients": {"name": "Ada Obi", "client_code": "C001"}},
                    {"id": w_wr_id, "client_id": CLIENT_UUID, "officer_id": OFFICER_UUID, "branch_id": BRANCH_UUID, "withdrawal_amount": 3000.0, "posting_date": WEEKDAY.isoformat(), "reference": "REF-BY-WR", "remarks": "Normal remarks", "clients": {"name": "Ada Obi", "client_code": "C001"}},
                ])
            if t == "event_store":
                return _FakeQuery([{"aggregate_id": w_cmp_id, "event_type": "LoanOffsetFromSavings"}])
            if t == "withdrawal_requests":
                return _FakeQuery([{"reference": "REF-BY-WR", "operation_type": "LAPS Transfer"}])
            return _FakeQuery([])
        uow.client.table.side_effect = _col_tbl
        cand = get_reversal_options(category="Savings Withdrawals", date_str=WEEKDAY.isoformat(), all_recent=False, search=None, current_user=co_user, uow=uow)
        cand_ids = [it.ref_id for it in cand.items]
        self.assertEqual(cand_ids, [w_cash_id])


if __name__ == "__main__":
    unittest.main()
