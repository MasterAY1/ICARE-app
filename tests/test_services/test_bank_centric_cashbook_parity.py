import unittest
from datetime import date
from unittest.mock import MagicMock

from domain.entities.event_store import DomainEvent
from domain.enums import TransactionClassification
from services.posting_engine import FinancialPostingEngine
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
from services.withdrawal_classification_engine import WithdrawalClassificationEngine
from services.financial_reconciliation_service import FinancialReconciliationService


def _get_nested(row: dict, dotted_key: str):
    cur = row
    for part in dotted_key.split("."):
        if not isinstance(cur, dict):
            return None
        cur = cur.get(part)
    return cur


class _ChainMock:
    """Deterministic Supabase query chain mock supporting dotted filter predicates."""

    def __init__(self, rows=None):
        self._rows = list(rows or [])
        self._eq_filters = []
        self._lt_filters = []
        self._in_filters = []

    def select(self, *args, **kwargs):
        return self

    def eq(self, col, val):
        self._eq_filters.append((col, val))
        return self

    def neq(self, *args, **kwargs):
        return self

    def lt(self, col, val):
        self._lt_filters.append((col, val))
        return self

    def in_(self, col, vals):
        self._in_filters.append((col, set(vals or [])))
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def upsert(self, *args, **kwargs):
        return self

    def insert(self, *args, **kwargs):
        return self

    def update(self, *args, **kwargs):
        return self

    def execute(self):
        out = []
        for row in self._rows:
            if not isinstance(row, dict):
                continue
            ok = True
            for col, val in self._eq_filters:
                if _get_nested(row, col) != val:
                    ok = False
                    break
            if not ok:
                continue
            for col, val in self._lt_filters:
                if str(_get_nested(row, col) or "") >= str(val):
                    ok = False
                    break
            if not ok:
                continue
            for col, vals in self._in_filters:
                if _get_nested(row, col) not in vals:
                    ok = False
                    break
            if ok:
                out.append(row)
        return MagicMock(data=out)


class TestBankCentricCashbookParity(unittest.TestCase):
    BRANCH_ID = "11111111-1111-1111-1111-111111111111"
    CO_ID = "22222222-2222-2222-2222-222222222222"
    BM_ID = "33333333-3333-3333-3333-333333333333"

    def test_posting_engine_bank_vs_vault_routing_and_reversal_symmetry(self):
        from types import SimpleNamespace
        uow = MagicMock()
        uow.event_store.is_processed.return_value = False
        db_rules = {
            "LoanDisbursed": SimpleNamespace(debit_account="1200", credit_account="1050", enabled=True),
            "FeeOffsetFromSavings": SimpleNamespace(debit_account="2000", credit_account="3000", enabled=True),
            "GapFeeOffsetFromSavings": SimpleNamespace(debit_account="2000", credit_account="1200", enabled=True),
            "CashTransferred_HO_In": SimpleNamespace(debit_account="1050", credit_account="3100", enabled=True),
            "CashTransferred_HO_Out": SimpleNamespace(debit_account="3100", credit_account="1050", enabled=True),
            "SalaryPaid": SimpleNamespace(debit_account="4100", credit_account="1050", enabled=True),
            "BankDeposited": SimpleNamespace(debit_account="1050", credit_account="1000", enabled=True),
            "ExpenseRecorded": SimpleNamespace(debit_account="4000", credit_account="1000", enabled=True),
            "VaultAdjusted_In": SimpleNamespace(debit_account="1000", credit_account="3100", enabled=True),
            "SavingsWithdrawn": SimpleNamespace(debit_account="2000", credit_account="1050", enabled=True),
            "LapsPaidOut": SimpleNamespace(debit_account="2030", credit_account="1050", enabled=True),
        }
        uow.posting_rules.get_rule.side_effect = lambda ev_type, ver=1: db_rules.get(ev_type)
        uow.client.table.side_effect = lambda name: _ChainMock([])

        specs = [
            # Asset loan credits Inventory (1300); Finance loan credits Bank (1050)
            ("LoanDisbursed", {"product_category": "Asset"}, "1200", "1300"),
            ("LoanDisbursed", {"product_category": "Finance"}, "1200", "1050"),
            # Upfront Finance fee & gap offsets from savings never touch 1000 or 1050
            ("FeeOffsetFromSavings", {}, "2000", "3000"),
            ("GapFeeOffsetFromSavings", {}, "2000", "1200"),
            # Corporate Bank transfers & Salaries route through 1050
            ("CashTransferred_HO_In", {"transaction_type": "HO_TRANSFER_IN"}, "1050", "3100"),
            ("CashTransferred_HO_Out", {"transaction_type": "INTER_AREA_OUT"}, "3100", "1050"),
            ("SalaryPaid", {}, "4100", "1050"),
            # Physical vault sweeps, float, and branch cash expenses touch 1000
            ("BankDeposited", {}, "1050", "1000"),
            ("ExpenseRecorded", {}, "4000", "1000"),
            ("VaultAdjusted_In", {}, "1000", "3100"),
            # Option A: Direct savings withdrawals & LAPS payouts enforce Bank (1050)
            ("SavingsWithdrawn", {"cash_paid": True}, "2000", "1050"),
            ("LapsPaidOut", {"cash_paid": True}, "2030", "1050"),
            # Symmetry on reversals: default 1050, pre-cutover override 1000
            ("SavingsWithdrawalReversed", {}, "1050", "2000"),
            ("SavingsWithdrawalReversed", {"original_cash_account": "1000"}, "1000", "2000"),
            ("CashTransferred_HO_In_Reversed", {"original_cash_account": "1000"}, "3100", "1000"),
            ("VaultAdjusted_In_Reversed", {}, "3100", "1000"),
            ("LapsPaidOutReversed", {}, "1050", "2030"),
        ]

        for idx, (ev_type, extra, exp_dr, exp_cr) in enumerate(specs):
            payload = {
                "amount": 5000.0,
                "branch_id": self.BRANCH_ID,
                "branch": self.BRANCH_ID,
                "officer_id": self.CO_ID,
                "officer": self.CO_ID,
                "date": "2026-11-24",
                "posting_date": "2026-11-24",
                **extra,
            }
            ev = DomainEvent(
                event_id=f"ev-{idx}",
                aggregate_id=f"agg-{idx}",
                aggregate_type="Cashbook",
                event_type=ev_type,
                payload=payload,
            )
            FinancialPostingEngine.post_event(uow, ev)

        calls = uow.ledger.create_transaction.call_args_list
        self.assertEqual(len(calls), len(specs))
        for idx, (ev_type, extra, exp_dr, exp_cr) in enumerate(specs):
            _, pair = calls[idx].args
            dr = next(e for e in pair if e.side == "Debit")
            cr = next(e for e in pair if e.side == "Credit")
            self.assertEqual(dr.account_code, exp_dr, f"{ev_type} ({extra}) DR mismatch")
            self.assertEqual(cr.account_code, exp_cr, f"{ev_type} ({extra}) CR mismatch")
            self.assertEqual(dr.amount, cr.amount)

    def test_co_cashbook_upfront_finance_fee_gap_offset_and_option_a_pairing(self):
        # Authoritative Daily 60D Finance loan (Principal 100k -> active_credit 99k, gap_fee 1k,
        # markup 11k, contingency 1k => total_upfront_required = 13,000 cash deposited into Vault 1000).
        p_date = "2026-11-24"
        ledger_rows = [
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1000", "side": "Debit", "amount": 13000.0,
                "transaction_id": "t-sav-dep",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {"event_type": "SavingsDeposited", "payload": {}},
                },
            },
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1050", "side": "Credit", "amount": 100000.0,
                "transaction_id": "t-loan",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {
                        "event_type": "LoanDisbursed",
                        "payload": {
                            "product_category": "Finance",
                            "product_type": "Daily 60 Days",
                            "amount": 100000.0,
                            "active_credit": 99000.0,
                        },
                    },
                },
            },
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "2000", "side": "Debit", "amount": 11000.0,
                "transaction_id": "t-markup-off",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {
                        "event_type": "FeeOffsetFromSavings",
                        "payload": {"amount": 11000.0, "product_type": "Daily 60 Days", "fee_type": "MARKUP_11"},
                    },
                },
            },
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "2000", "side": "Debit", "amount": 1000.0,
                "transaction_id": "t-cont-off",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {
                        "event_type": "FeeOffsetFromSavings",
                        "payload": {"amount": 1000.0, "product_type": "Daily 60 Days", "fee_type": "CONTINGENCY"},
                    },
                },
            },
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "2000", "side": "Debit", "amount": 1000.0,
                "transaction_id": "t-gap-off",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {"event_type": "GapFeeOffsetFromSavings", "payload": {"amount": 1000.0}},
                },
            },
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1050", "side": "Credit", "amount": 4000.0,
                "transaction_id": "t-sav-wth",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {"event_type": "SavingsWithdrawn", "payload": {"amount": 4000.0}},
                },
            },
        ]

        uow = MagicMock()
        uow.client.table.side_effect = lambda name: (
            _ChainMock(ledger_rows) if name == "financial_ledger_entries" else _ChainMock([])
        )

        co_proj = CoCashbookProjectionBuilder.rebuild_co_projection(
            uow, self.BRANCH_ID, self.CO_ID, date(2026, 11, 24)
        )

        # Upfront cash deposit stays 13,000; markup hits daily_11_pct; contingency hits contingency
        self.assertEqual(co_proj["savings_deposit"], 13000.0)
        self.assertEqual(co_proj["daily_11_pct"], 11000.0)
        self.assertEqual(co_proj["contingency"], 1000.0)
        # Auto bank_withdrawal = 100,000 (Finance Principal) + 4,000 (Bank Savings Withdrawal)
        self.assertEqual(co_proj["bank_withdrawal"], 104000.0)
        self.assertEqual(co_proj["disb_60d"], 99000.0)
        self.assertEqual(co_proj["active_loan_daily"], 99000.0)
        # Right product_withdrawal includes Markup (11k) + Cont (1k) + GapFeeOffset (1k) + Bank Sav Withdrawal (4k) = 17,000
        self.assertEqual(co_proj["product_withdrawal"], 17000.0)
        # Repayments untouched by gap fee
        self.assertEqual(co_proj["rep_daily"], 0.0)
        # Exact Account 1000 parity: 13,000 physical cash deposited, 0 physical cash paid out -> closing_balance = +13,000.0
        self.assertEqual(co_proj["closing_balance"], 13000.0)

    def test_master_cashbook_pairs_bank_flows_carries_negative_and_excludes_bm_rows(self):
        p_date = "2026-11-24"
        app_users_rows = [
            {"id": self.CO_ID, "role": "Credit Officer", "username": "co1_kola", "branch_id": self.BRANCH_ID},
            {"id": self.BM_ID, "role": "Branch Manager", "username": "bm_kola", "branch_id": self.BRANCH_ID},
        ]
        # Yesterday closed at -12,500 (Excess Banked) -> must carry forward unaltered (never clamped to 0!)
        master_rows = [
            {"branch_id": self.BRANCH_ID, "date": "2026-11-23", "closing_balance": -12500.0}
        ]
        # Bogus legacy BM row in co_cashbooks must be ignored cleanly
        co_rows_in_db = [
            {"branch_id": self.BRANCH_ID, "officer_id": self.BM_ID, "date": p_date, "rep_daily": 999999.0, "closing_balance": 999999.0}
        ]
        ledger_rows = [
            # CO field repayment cash (+50,000 Vault 1000)
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1000", "side": "Debit", "amount": 50000.0, "transaction_id": "t-rep",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {"event_type": "RepaymentReceived", "payload": {"product_type": "Daily 60 Days"}},
                },
            },
            # CO physical vault cash banked (-20,000 Vault 1000)
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1000", "side": "Credit", "amount": 20000.0, "transaction_id": "t-bnk-dep",
                "financial_transactions": {
                    "officer_id": self.CO_ID, "posting_date": p_date,
                    "event_store": {"event_type": "BankDeposited", "payload": {}},
                },
            },
            # BM HO transfer IN (+500,000 Bank 1050) -> pairs Left funds_received_ho & Right bank_deposit (Net 0)
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1050", "side": "Debit", "amount": 500000.0, "transaction_id": "t-ho-in",
                "financial_transactions": {
                    "officer_id": None, "posting_date": p_date,
                    "event_store": {"event_type": "CashTransferred_HO_In", "payload": {"transaction_type": "HO_TRANSFER_IN"}},
                },
            },
            # BM Inter-Area Out (-120,000 Bank 1050) -> pairs Left bank_withdrawal & Right fund_to_other_area (Net 0)
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1050", "side": "Credit", "amount": 120000.0, "transaction_id": "t-area-out",
                "financial_transactions": {
                    "officer_id": None, "posting_date": p_date,
                    "event_store": {"event_type": "CashTransferred_HO_Out", "payload": {"transaction_type": "INTER_AREA_OUT"}},
                },
            },
            # BM Salary (-45,000 Bank 1050) -> pairs Left bank_withdrawal & Right staff_salaries (Net 0)
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1050", "side": "Credit", "amount": 45000.0, "transaction_id": "t-sal",
                "financial_transactions": {
                    "officer_id": None, "posting_date": p_date,
                    "event_store": {"event_type": "SalaryPaid", "payload": {"transaction_type": "SALARY"}},
                },
            },
            # BM Non-CO direct Finance Loan Disbursement (-80,000 Bank 1050) -> pairs bank_withdrawal & fund_to_product_finance
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1050", "side": "Credit", "amount": 80000.0, "transaction_id": "t-bm-loan",
                "financial_transactions": {
                    "officer_id": None, "posting_date": p_date,
                    "event_store": {"event_type": "LoanDisbursed", "payload": {"product_category": "Finance", "product_type": "Weekly 12W"}},
                },
            },
            # BM Direct Bank-routed Savings Withdrawal (-15,000 Bank 1050) -> pairs bank_withdrawal & product_withdrawal
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1050", "side": "Credit", "amount": 15000.0, "transaction_id": "t-bm-sav",
                "financial_transactions": {
                    "officer_id": None, "posting_date": p_date,
                    "event_store": {"event_type": "SavingsWithdrawn", "payload": {"amount": 15000.0}},
                },
            },
            # BM Office Cash Expense (-5,000 Vault 1000) -> Right office_expenses ONLY
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1000", "side": "Credit", "amount": 5000.0, "transaction_id": "t-exp",
                "financial_transactions": {
                    "officer_id": None, "posting_date": p_date,
                    "event_store": {"event_type": "ExpenseRecorded", "payload": {}},
                },
            },
            # BM Vault Float Adjustment IN (+10,000 Vault 1000) -> Left adjustment_in ONLY
            {
                "branch_id": self.BRANCH_ID,
                "account_code": "1000", "side": "Debit", "amount": 10000.0, "transaction_id": "t-flt",
                "financial_transactions": {
                    "officer_id": None, "posting_date": p_date,
                    "event_store": {"event_type": "VaultAdjusted_In", "payload": {"transaction_type": "FLOAT"}},
                },
            },
        ]

        uow = MagicMock()
        uow.client.table.side_effect = lambda name: (
            _ChainMock(app_users_rows) if name == "app_users"
            else _ChainMock(master_rows) if name == "master_cashbook"
            else _ChainMock(co_rows_in_db) if name == "co_cashbooks"
            else _ChainMock(ledger_rows) if name == "financial_ledger_entries"
            else _ChainMock([])
        )

        mb = MasterCashbookProjectionBuilder.rebuild_master_projection(
            uow, self.BRANCH_ID, date(2026, 11, 24)
        )

        self.assertEqual(mb["opening_balance"], -12500.0)
        self.assertEqual(mb["rep_daily"], 50000.0)
        self.assertEqual(mb["funds_received_ho"], 500000.0)
        self.assertEqual(mb["bank_deposit"], 520000.0)  # 500k HO IN pair + 20k vault sweep
        self.assertEqual(mb["bank_withdrawal"], 260000.0)  # 120k + 45k + 80k + 15k (100% auto)
        self.assertEqual(mb["fund_to_other_area"], 120000.0)
        self.assertEqual(mb["staff_salaries"], 45000.0)
        self.assertEqual(mb["fund_to_product_finance"], 80000.0)
        self.assertEqual(mb["product_withdrawal"], 15000.0)
        self.assertEqual(mb["office_expenses"], 5000.0)
        self.assertEqual(mb["adjustment_in"], 10000.0)

        # Vault Balance check: -12,500 + 50,000 + 10,000 - 20,000 - 5,000 = +22,500.0
        self.assertEqual(mb["closing_balance"], 22500.0)
        self.assertEqual(round(mb["total_inflows"] - mb["total_outflows"], 2), 22500.0)

    def test_financial_reconciliation_ignores_bm_co_cashbook_and_uses_net_1000(self):
        uow = MagicMock()
        app_users_rows = [
            {"id": self.CO_ID, "role": "Credit Officer", "username": "co1"},
            {"id": self.BM_ID, "role": "Branch Manager", "username": "bm1"},
        ]
        # Withdrawal classification enforces Option A unconditionally
        wd = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_PAYOUT, 5000.0, is_cash_paid=True
        )
        self.assertEqual(wd["cash_withdrawal"], 0.0)
        self.assertEqual(wd["bank_withdrawal"], 5000.0)
        self.assertFalse(wd["affects_cash_vault"])

        uow.client.table.side_effect = lambda name: (
            _ChainMock(app_users_rows) if name == "app_users" else _ChainMock([])
        )
        res = FinancialReconciliationService.run_reconciliation_wizard_repair(uow, self.BRANCH_ID, date(2026, 11, 24))
        self.assertIsInstance(res, dict)


if __name__ == "__main__":
    unittest.main()
