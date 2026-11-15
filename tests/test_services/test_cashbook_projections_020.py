import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from api.dependencies import CurrentUser
from api.routes.bm.cashbook import save_master_cashbook_manual_entries
from api.routes.co.cashbook import EodAdjustmentsInput, submit_eod_adjustments
from api.schemas.master_cashbook import MasterCashbookManualInputsRequest
from domain.entities.event_store import DomainEvent
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
from services.posting_engine import FinancialPostingEngine


class _ChainTableMock:
    """Flexible Supabase query chain mock returning configured rows for table operations."""

    def __init__(self, data=None):
        self._data = list(data or [])
        self.upserted_payloads = []
        self.inserted_payloads = []
        self.updated_payloads = []

    def select(self, *args, **kwargs):
        return self

    def eq(self, *args, **kwargs):
        return self

    def neq(self, *args, **kwargs):
        return self

    def in_(self, *args, **kwargs):
        return self

    def lt(self, *args, **kwargs):
        return self

    def gte(self, *args, **kwargs):
        return self

    def lte(self, *args, **kwargs):
        return self

    def ilike(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def upsert(self, payload, *args, **kwargs):
        self.upserted_payloads.append(payload)
        return self

    def insert(self, payload, *args, **kwargs):
        self.inserted_payloads.append(payload)
        return self

    def update(self, payload, *args, **kwargs):
        self.updated_payloads.append(payload)
        return self

    def execute(self):
        return SimpleNamespace(data=self._data)


class TestCashbookProjections020(unittest.TestCase):
    def test_120_days_vs_12_weeks_and_completed_loan_classification(self):
        self.assertEqual(
            CoCashbookProjectionBuilder._classify_loan_product("Daily 120 Days Finance", "Daily", 120),
            "120d",
        )
        self.assertEqual(
            CoCashbookProjectionBuilder._classify_loan_product("Weekly 12W Finance", "Weekly", 12),
            "12w",
        )

        # Completed 120-day loan without payload metadata must still resolve from DB
        loans_tbl = _ChainTableMock([
            {
                "product_type": "Daily 120 Days Finance",
                "repayment_cycle": "Daily",
                "duration": 120,
                "status": "Completed",
            }
        ])
        entries = [
            {
                "account_code": "1000",
                "side": "Debit",
                "amount": 25000.0,
                "aggregate_id": "loan-completed-120",
                "financial_transactions": {
                    "event_id": "ev-rep-120",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-15",
                    "event_store": {
                        "event_type": "RepaymentReceived",
                        "payload": {"loan_id": "loan-completed-120", "narration": "Full payoff"},
                    },
                },
            },
            {
                "account_code": "1000",
                "side": "Credit",
                "amount": 100000.0,
                "aggregate_id": "loan-new-120",
                "financial_transactions": {
                    "event_id": "ev-disb-120",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-15",
                    "event_store": {
                        "event_type": "LoanDisbursed",
                        "payload": {
                            "amount": 100000.0,
                            "active_credit": 98000.0,
                            "product_type": "Daily 120 Days Finance",
                            "repayment_cycle": "Daily",
                            "duration": 120,
                            "product_category": "Finance",
                            "narration": "Loan disbursement 120 days",
                        },
                    },
                },
            },
            {
                "account_code": "1000",
                "side": "Debit",
                "amount": 20000.0,
                "aggregate_id": "loan-new-120",
                "financial_transactions": {
                    "event_id": "ev-fee-120",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-15",
                    "narration": "Daily 20% Markup",
                    "event_store": {
                        "event_type": "FeeCharged",
                        "payload": {"narration": "Daily 20% Markup"},
                    },
                },
            },
        ]

        mock_uow = MagicMock()

        def table_router(name):
            if name == "financial_ledger_entries":
                return _ChainTableMock(entries)
            if name == "loans":
                return loans_tbl
            return _ChainTableMock([])

        mock_uow.client.table.side_effect = table_router

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            mock_uow, "branch-01", "off-01", date(2026, 10, 15)
        )

        self.assertEqual(res["rep_120_days"], 25000.0)
        self.assertEqual(res["rep_12_weeks"], 0.0)
        self.assertEqual(res["disb_120d"], 98000.0)
        self.assertEqual(res["disb_12w"], 0.0)
        self.assertEqual(res["daily_20_pct"], 20000.0)
        self.assertEqual(res["bank_withdrawal"], 100000.0)
        self.assertEqual(res["_finance_loan_principal"], 100000.0)
        self.assertEqual(res["fund_to_product_finance"], 100000.0)
        # Inflows: rep_120_days (25k) + daily_20_pct (20k) + bank_withdrawal (100k) = 145k
        self.assertEqual(res["total_inflows"], 145000.0)
        # CO Outflows use Active Credit disb_120d (98k, Principal Net of Gap Fee)
        self.assertEqual(res["total_outflows"], 98000.0)
        self.assertEqual(res["closing_balance"], 47000.0)

    def test_savings_withdrawal_order_independent_and_master_dedup(self):
        # Verify SavingsWithdrawn behaves identically regardless of Account 2000 vs 1000 row order
        row_2000 = {
            "account_code": "2000",
            "side": "Debit",
            "amount": 15000.0,
            "financial_transactions": {
                "event_id": "ev-swd-01",
                "officer_id": "off-01",
                "posting_date": "2026-10-15",
                "event_store": {"event_type": "SavingsWithdrawn", "payload": {}},
            },
        }
        row_1000 = {
            "account_code": "1000",
            "side": "Credit",
            "amount": 15000.0,
            "financial_transactions": {
                "event_id": "ev-swd-01",
                "officer_id": "off-01",
                "posting_date": "2026-10-15",
                "event_store": {"event_type": "SavingsWithdrawn", "payload": {}},
            },
        }

        for ordered_entries in ([row_2000, row_1000], [row_1000, row_2000]):
            mock_uow = MagicMock()
            mock_uow.client.table.side_effect = lambda name, e=ordered_entries: (
                _ChainTableMock(e) if name == "financial_ledger_entries" else _ChainTableMock([])
            )
            co_res = CoCashbookProjectionBuilder.rebuild_co_projection(
                mock_uow, "branch-01", "off-01", date(2026, 10, 15)
            )
            # Cash withdrawal (DR 2000, CR 1000) must NOT fabricate phantom bank_withdrawal
            self.assertEqual(co_res["bank_withdrawal"], 0.0)
            self.assertEqual(co_res["product_withdrawal"], 15000.0)
            self.assertEqual(co_res["savings_withdrawal"], 15000.0)
            self.assertEqual(co_res["total_inflows"], 0.0)
            self.assertEqual(co_res["total_outflows"], 15000.0)
            self.assertEqual(co_res["closing_balance"], -15000.0)

        # Master Cashbook: combine Finance 120d loan + Asset loan + Savings Withdrawal
        # Master bank_withdrawal aggregates full CO bank_withdrawal without deducting Finance principal;
        # CO asset_credit_sales rolls out into loan_received_asset with zero double counting;
        # and disb_* + fund_to_product_finance (Finance Principal) both count in total_outflows.
        co_rows = [
            {
                "officer_id": "off-01",
                "rep_120_days": 25000.0,
                "daily_20_pct": 20000.0,
                "weekly_20_pct": 10000.0,
                "asset_credit_sales": 50000.0,
                "bank_withdrawal": 115000.0,  # 100k Finance loan principal + 15k savings withdrawal
                "_finance_loan_principal": 100000.0,
                "fund_to_product_finance": 100000.0,
                "disb_120d": 98000.0,
                "disb_12w": 50000.0,
                "product_withdrawal": 15000.0,
                "savings_withdrawal": 15000.0,
            }
        ]
        mock_master_uow = MagicMock()
        mock_master_uow.client.table.side_effect = lambda name: (
            _ChainTableMock(co_rows) if name == "co_cashbooks" else _ChainTableMock([])
        )

        mb_res = MasterCashbookProjectionBuilder.rebuild_master_projection(
            mock_master_uow, "branch-01", date(2026, 10, 15)
        )

        self.assertEqual(mb_res["loan_received_finance"], 100000.0)
        self.assertEqual(mb_res["fund_to_product_finance"], 100000.0)
        self.assertEqual(mb_res["loan_received_asset"], 50000.0)
        self.assertEqual(mb_res["asset_credit_sales"], 0.0)
        self.assertEqual(mb_res["bank_withdrawal"], 115000.0)
        self.assertEqual(mb_res["product_withdrawal"], 15000.0)
        self.assertEqual(mb_res["savings_withdrawal"], 15000.0)
        self.assertEqual(mb_res["disb_120d"], 98000.0)
        self.assertEqual(mb_res["disb_12w"], 50000.0)
        # Inflows = rep_120_days(25k) + loan_received_asset(50k) + loan_received_finance(100k)
        #         + daily_20_pct(20k) + weekly_20_pct(10k) + bank_withdrawal(115k) = 320k
        self.assertEqual(mb_res["total_inflows"], 320000.0)
        # Outflows = disb_120d(98k) + disb_12w(50k) + fund_to_product_finance(100k)
        #          + max(product_withdrawal, savings_withdrawal)(15k) = 263k
        self.assertEqual(mb_res["total_outflows"], 263000.0)
        self.assertEqual(mb_res["closing_balance"], 57000.0)

    def test_posting_engine_synthetic_reversal_rules_and_master_zeroing(self):
        mock_uow = MagicMock()
        mock_uow.event_store.is_processed.return_value = False
        mock_uow.posting_rules.get_rule.return_value = None
        mock_uow.client.table.side_effect = lambda name: _ChainTableMock([])

        reversal_specs = [
            ("FeeReversed", "3000", "1000"),
            ("ExpenseReversed", "1000", "4000"),
            ("BankDepositReversed", "1000", "1050"),
            ("BankWithdrawalReversed", "1050", "1000"),
            ("SalaryReversed", "1000", "4100"),
            ("SavingsDepositReversed", "2000", "1000"),
            ("SavingsWithdrawalReversed", "1000", "2000"),
            ("CashTransferred_HO_In_Reversed", "3100", "1000"),
            ("CashTransferred_HO_Out_Reversed", "1000", "3100"),
        ]

        branch_uuid = "11111111-1111-1111-1111-111111111111"
        officer_uuid = "22222222-2222-2222-2222-222222222222"

        for idx, (ev_type, expected_dr, expected_cr) in enumerate(reversal_specs):
            ev = DomainEvent(
                event_id=f"ev-{idx}",
                aggregate_id=f"agg-{idx}",
                aggregate_type="Cashbook",
                event_type=ev_type,
                payload={
                    "amount": 500.0,
                    "branch": branch_uuid,
                    "branch_id": branch_uuid,
                    "officer": officer_uuid,
                    "officer_id": officer_uuid,
                    "date": "2026-10-15",
                    "posting_date": "2026-10-15",
                },
            )
            FinancialPostingEngine.post_event(mock_uow, ev)

        calls = mock_uow.ledger.create_transaction.call_args_list
        self.assertEqual(len(calls), len(reversal_specs))
        for idx, (ev_type, expected_dr, expected_cr) in enumerate(reversal_specs):
            _, pair = calls[idx].args
            dr = next(e for e in pair if e.side == "Debit")
            cr = next(e for e in pair if e.side == "Credit")
            self.assertEqual(dr.account_code, expected_dr, f"{ev_type} debit mismatch")
            self.assertEqual(cr.account_code, expected_cr, f"{ev_type} credit mismatch")

        # Verify manual_opening_balance=0.0 on CO cashbook clears non-zero existing opening_balance down to 0.0
        mock_co_zero_uow = MagicMock()
        mock_co_zero_uow.client.table.side_effect = lambda name: (
            _ChainTableMock([{"opening_balance": 35000.0}]) if name == "co_cashbooks" else _ChainTableMock([])
        )
        co_zero = CoCashbookProjectionBuilder.rebuild_co_projection(
            mock_co_zero_uow, branch_uuid, officer_uuid, date(2026, 10, 15), manual_opening_balance=0.0
        )
        self.assertEqual(co_zero["opening_balance"], 0.0)

    def test_eod_misc_fee_routes_via_savings_service_and_supports_reversal_and_zeroing(self):
        mock_uow = MagicMock()
        mock_uow.cashbook._resolve_branch_id.return_value = "br-1"
        mock_uow.loans._resolve_officer_id.return_value = "off-01"
        mock_uow.client.table.side_effect = lambda name: (
            _ChainTableMock([{"id": "off-01", "username": "co1", "full_name": "CO One"}])
            if name == "app_users"
            else _ChainTableMock([])
        )
        user = CurrentUser(
            id="co-id-1",
            username="co1",
            role="Credit Officer",
            branch="Branch A",
            branch_id="br-1",
            full_name="CO One",
        )

        # Case 1: Increase misc_fee (0 -> 5000) & zero opening_balance (manual_opening_balance=0.0)
        with patch("api.routes.co.cashbook.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("api.routes.co.cashbook._get_eod_misc_fee_tracked", return_value=0.0), \
             patch("services.co_cashbook_projection_builder.CoCashbookProjectionBuilder.rebuild_co_projection", return_value={
                 "opening_balance": 10000.0,
                 "office_expenses": 0.0,
                 "bank_deposit": 0.0,
                 "app_fee": 0.0,
                 "passbook": 0.0,
                 "credit_form_damage": 0.0,
                 "bonus": 0.0,
                 "misc_fees": 0.0,
             }) as mock_rebuild, \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection"), \
             patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value=("mgr-01", "mgr_co")), \
             patch("services.savings_service.SavingsService.post_misc_savings") as mock_post_misc, \
             patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_event:

            payload = EodAdjustmentsInput(
                date="2026-10-15",
                officer="co1",
                opening_balance=0.0,
                misc_fee=5000.0,
            )
            submit_eod_adjustments(payload=payload, current_user=user, uow=mock_uow)

            mock_post_misc.assert_called_once()
            _, kwargs = mock_post_misc.call_args
            self.assertEqual(kwargs.get("deposit_amount"), 5000.0)
            mock_post_event.assert_not_called()
            # rebuild called twice (initial + after adjustment); last call must forward manual_opening_balance=0.0
            self.assertEqual(mock_rebuild.call_args_list[-1].kwargs.get("manual_opening_balance"), 0.0)

        # Case 2: Decrease misc_fee (5000 -> 2000), app_fee (2000 -> 0), expenses (1000 -> 0), bank_deposit (3000 -> 0)
        with patch("api.routes.co.cashbook.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("api.routes.co.cashbook._get_eod_misc_fee_tracked", return_value=5000.0), \
             patch("services.co_cashbook_projection_builder.CoCashbookProjectionBuilder.rebuild_co_projection", return_value={
                 "opening_balance": 10000.0,
                 "office_expenses": 1000.0,
                 "bank_deposit": 3000.0,
                 "app_fee": 2000.0,
                 "passbook": 0.0,
                 "credit_form_damage": 0.0,
                 "bonus": 0.0,
                 "misc_fees": 5000.0,
             }), \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection"), \
             patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value=("mgr-01", "mgr_co")), \
             patch("services.savings_service.SavingsService.post_misc_savings") as mock_post_misc_down, \
             patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_event_down:

            payload_down = EodAdjustmentsInput(
                date="2026-10-15",
                officer="co1",
                opening_balance=0.0,
                office_expenses=0.0,
                bank_deposit=0.0,
                app_fee=0.0,
                misc_fee=2000.0,
            )
            submit_eod_adjustments(payload=payload_down, current_user=user, uow=mock_uow)

            emitted = {call.args[1].event_type: call.args[1].payload["amount"] for call in mock_post_event_down.call_args_list}
            self.assertEqual(emitted.get("ExpenseReversed"), 1000.0)
            self.assertEqual(emitted.get("BankDepositReversed"), 3000.0)
            self.assertEqual(emitted.get("FeeReversed"), 2000.0)
            self.assertTrue(
                mock_post_misc_down.called or (emitted.get("SavingsDepositReversed") == 3000.0),
                "Downward misc_fee adjustment must reverse via SavingsService or SavingsDepositReversed",
            )

    def test_bm_manual_entries_support_downward_reversal_and_zeroing(self):
        mb_tbl = _ChainTableMock([])
        mock_uow = MagicMock()
        mock_uow.cashbook._resolve_branch_id.return_value = "br-1"
        mock_uow.client.table.side_effect = lambda name: mb_tbl if name == "master_cashbook" else _ChainTableMock([])

        bm_user = CurrentUser(
            id="bm-1",
            username="bm1",
            role="Branch Manager",
            branch="Branch A",
            branch_id="br-1",
            full_name="BM One",
        )

        with patch("api.routes.bm.cashbook.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection", return_value={
                 "funds_received_ho": 50000.0,
                 "funds_received_other_branch": 0.0,
                 "funds_received_other_area": 0.0,
                 "fund_transferred_other_branch": 0.0,
                 "fund_transferred_ho": 0.0,
                 "fund_to_other_area": 0.0,
                 "staff_salaries": 20000.0,
                 "adjustment_in": 1000.0,
                 "adjustment_out": 500.0,
             }), \
             patch("api.routes.bm.cashbook.TreasuryService._resolve_officer_id", return_value="bm-1"), \
             patch("api.routes.bm.cashbook.TreasuryService.post_treasury_transaction") as mock_treasury, \
             patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_event:

            req = MasterCashbookManualInputsRequest(
                date="2026-10-15",
                funds_received_ho=0.0,
                staff_salaries=5000.0,
                adjustment_in=0.0,
                adjustment_out=0.0,
                adjustment_reason="",
            )
            save_master_cashbook_manual_entries(payload=req, current_user=bm_user, uow=mock_uow)

            mock_treasury.assert_not_called()
            emitted = {call.args[1].event_type: call.args[1].payload["amount"] for call in mock_post_event.call_args_list}
            self.assertEqual(emitted.get("CashTransferred_HO_In_Reversed"), 50000.0)
            self.assertEqual(emitted.get("SalaryReversed"), 15000.0)
            self.assertTrue(any(
                p.get("adjustment_in") == 0.0 and p.get("adjustment_out") == 0.0
                for p in mb_tbl.upserted_payloads
            ))

    def test_bm_manual_entries_fund_to_asset_program_treasury_and_reversal(self):
        mb_tbl = _ChainTableMock([])
        mock_uow = MagicMock()
        mock_uow.cashbook._resolve_branch_id.return_value = "br-1"
        mock_uow.client.table.side_effect = lambda name: mb_tbl if name == "master_cashbook" else _ChainTableMock([])

        bm_user = CurrentUser(
            id="bm-1",
            username="bm1",
            role="Branch Manager",
            branch="Branch A",
            branch_id="br-1",
            full_name="BM One",
        )

        # Upward delta on fund_to_asset_program (25k -> 75k = +50k ASSET_PROGRAM treasury transaction)
        with patch("api.routes.bm.cashbook.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection", return_value={
                 "funds_received_ho": 0.0,
                 "funds_received_other_branch": 0.0,
                 "funds_received_other_area": 0.0,
                 "fund_transferred_other_branch": 0.0,
                 "fund_transferred_ho": 0.0,
                 "fund_to_other_area": 0.0,
                 "fund_to_asset_program": 25000.0,
                 "staff_salaries": 0.0,
                 "adjustment_in": 0.0,
                 "adjustment_out": 0.0,
             }), \
             patch("api.routes.bm.cashbook.TreasuryService._resolve_officer_id", return_value="bm-1"), \
             patch("api.routes.bm.cashbook.TreasuryService.post_treasury_transaction") as mock_treasury, \
             patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_event:

            req_up = MasterCashbookManualInputsRequest(
                date="2026-10-15",
                fund_to_asset_program=75000.0,
            )
            save_master_cashbook_manual_entries(payload=req_up, current_user=bm_user, uow=mock_uow)

            mock_treasury.assert_called_once()
            args = mock_treasury.call_args.args
            self.assertEqual(args[1], "ASSET_PROGRAM")
            self.assertEqual(args[2], 50000.0)
            mock_post_event.assert_not_called()

        # Downward delta on fund_to_asset_program (75k -> 20k = 55k CashTransferred_HO_Out_Reversed)
        with patch("api.routes.bm.cashbook.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection", return_value={
                 "funds_received_ho": 0.0,
                 "funds_received_other_branch": 0.0,
                 "funds_received_other_area": 0.0,
                 "fund_transferred_other_branch": 0.0,
                 "fund_transferred_ho": 0.0,
                 "fund_to_other_area": 0.0,
                 "fund_to_asset_program": 75000.0,
                 "staff_salaries": 0.0,
                 "adjustment_in": 0.0,
                 "adjustment_out": 0.0,
             }), \
             patch("api.routes.bm.cashbook.TreasuryService._resolve_officer_id", return_value="bm-1"), \
             patch("api.routes.bm.cashbook.TreasuryService.post_treasury_transaction") as mock_treasury_down, \
             patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_event_down:

            req_down = MasterCashbookManualInputsRequest(
                date="2026-10-15",
                fund_to_asset_program=20000.0,
            )
            save_master_cashbook_manual_entries(payload=req_down, current_user=bm_user, uow=mock_uow)

            mock_treasury_down.assert_not_called()
            emitted = [(c.args[1].event_type, c.args[1].payload["amount"]) for c in mock_post_event_down.call_args_list]
            self.assertEqual(emitted, [("CashTransferred_HO_Out_Reversed", 55000.0)])


class TestCashbookActiveCreditAndMisc021(unittest.TestCase):
    def test_co_daily_cashbook_folds_misc_fees_into_savings_and_preserves_eod_misc_fee(self):
        from types import SimpleNamespace
        from unittest.mock import MagicMock, patch
        from models.user import CurrentUser
        from api.routes.co.cashbook import get_co_cashbook
        from api.schemas.cashbook import CollectionArrearsTally

        user = CurrentUser(
            id="co-1",
            username="officer1",
            role="CO",
            branch="Ogijo",
            branch_id="br-1",
            full_name="Officer One",
        )
        uow = MagicMock()
        uow.loans._resolve_officer_id.return_value = "co-1"
        uow.cashbook._resolve_branch_id.return_value = "br-1"
        # Minimal fluent query mock in case EOD / ledger reversal tables are queried
        query = MagicMock()
        for m in ("select", "eq", "gte", "lte", "order", "limit", "in_"):
            getattr(query, m).return_value = query
        query.execute.return_value = SimpleNamespace(data=[])
        uow.client.table.return_value = query

        proj = {
            "opening_balance": 0.0,
            "savings_deposit": 10000.0,
            "misc_fees": 2500.0,
            "total_inflows": 12500.0,
            "total_outflows": 0.0,
            "closing_balance": 12500.0,
        }
        tally = CollectionArrearsTally()

        with patch("api.routes.co.cashbook.check_branch_access"), \
             patch("api.routes.co.cashbook.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
             patch("services.co_cashbook_projection_builder.CoCashbookProjectionBuilder.rebuild_co_projection", return_value=proj), \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection"), \
             patch("services.financial_reconciliation_service.FinancialReconciliationService.get_daily_collection_arrears_tally", return_value={}), \
             patch("api.routes.co.cashbook._get_eod_misc_fee_tracked", return_value=2500.0):
            resp = get_co_cashbook(
                date_str="2026-02-10",
                officer="officer1",
                branch="Ogijo",
                current_user=user,
                uow=uow,
            )

        self.assertEqual(resp.inflows.misc_fees, 0.0)
        self.assertEqual(resp.inflows.eod_misc_fee, 2500.0)
        self.assertEqual(resp.inflows.savings_deposit, 12500.0)
        self.assertEqual(resp.total_inflows, 12500.0)

    def test_finance_loan_origination_active_credit_net_of_gap_fee(self):
        from types import SimpleNamespace
        from unittest.mock import MagicMock, patch
        from domain.entities.client import Client
        from models.user import CurrentUser
        from api.schemas.origination import ApplyLoanInput
        from api.routes.co.origination import apply_for_loan

        user = CurrentUser(
            id="co-1",
            username="officer1",
            role="CO",
            branch="Ogijo",
            branch_id="br-1",
            full_name="Officer One",
        )
        client = Client(
            id="cl-1",
            name="Test Client",
            client_code="CL-001",
            branch_id="br-1",
            group_id="grp-1",
            officer_id="co-1",
            status="Registered",
        )

        # Build query mocks by table name so savings & group/product lookups succeed cleanly
        def make_table(name):
            q = MagicMock()
            for m in ("select", "eq", "neq", "in_", "order", "limit", "gte", "lte", "is_"):
                getattr(q, m).return_value = q
            if name == "individual_savings":
                q.execute.return_value = SimpleNamespace(data=[{"deposit_amount": 50000.0, "withdrawal_amount": 0.0}])
            elif name == "groups":
                q.execute.return_value = SimpleNamespace(data=[{"group_id": "grp-1", "name": "Group A", "meeting_day": "Monday"}])
            elif name == "loan_products":
                q.execute.return_value = SimpleNamespace(data=[{
                    "product_id": "prod-1",
                    "name": "Daily 60 Days Finance",
                    "category": "Finance",
                    "repayment_cycle": "Daily",
                    "installments": 60,
                    "is_active": True,
                }])
            else:
                q.execute.return_value = SimpleNamespace(data=[])
            return q

        uow = MagicMock()
        uow.clients.find_by_id.return_value = client
        uow.client.table.side_effect = make_table
        uow.loans.find_by_client.return_value = []
        uow.loans._resolve_officer_id.return_value = "co-1"
        uow.loans.create.side_effect = lambda loan: loan
        uow.savings = MagicMock()

        payload = ApplyLoanInput(
            client_id="cl-1",
            product_category="Finance",
            product_type="Daily 60 Days Finance",
            requested_amount=100000.0,
            gap_fee=2000.0,
            application_date="2026-02-10",
        )

        with patch("api.routes.co.origination.check_branch_access"), \
             patch("api.routes.co.origination.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
             patch("api.routes.co.origination.RenewalService.check_eligibility", return_value=(True, [], [])), \
             patch("api.routes.co.origination.ScheduleService.generate_schedule", return_value=[]):
            resp = apply_for_loan(payload=payload, current_user=user, uow=uow)

        uow.client.rpc.assert_called_once()
        p_ops = uow.client.rpc.call_args.args[1]["p_operations"]
        loan_rec = next(op["record"] for op in p_ops if op.get("table") == "loans" and op.get("type") == "insert")
        self.assertEqual(loan_rec["loan_amount"], 100000.0)
        self.assertEqual(loan_rec["total_due"], 98000.0)
        self.assertEqual(loan_rec["active_credit"], 98000.0)
        self.assertEqual(loan_rec["extra_fields"]["active_credit"], 98000.0)
        self.assertEqual(loan_rec["extra_fields"]["total_due"], 98000.0)
        self.assertEqual(resp.active_credit, 98000.0)


class TestWaveA5CashbookIntegrity023(unittest.TestCase):
    def test_co_cashbook_skips_closed_rebuild_filters_non_co_and_exposes_120d_breakdown(self):
        from types import SimpleNamespace
        from api.routes.co.cashbook import get_co_cashbook

        uow = MagicMock()
        uow.cashbook._resolve_branch_id.return_value = "br-1"
        uow.loans._resolve_officer_id.return_value = "off-1"

        closed_row = {
            "date": "2026-10-15",
            "branch_id": "br-1",
            "officer_id": "off-1",
            "status": "Closed",
            "opening_balance": 2000.0,
            "savings_deposit": 5000.0,
            "disb_60d": 10000.0,
            "disb_120d": 49000.0,
            "disb_12w": 20000.0,
            "disb_24w": 0.0,
            "disb_mth": 15000.0,
        }
        users_rows = [
            {"username": "co_one", "full_name": "CO One", "role": "CO"},
            {"username": "bm_one", "full_name": "BM One", "role": "BM"},
            {"username": "admin_one", "full_name": "Admin One", "role": "Admin"},
        ]

        def table_router(name):
            if name == "co_cashbooks":
                return _ChainTableMock([closed_row])
            if name == "app_users":
                return _ChainTableMock(users_rows)
            return _ChainTableMock([])

        uow.client.table.side_effect = table_router
        bm_user = SimpleNamespace(
            id="bm-1",
            username="bm_one",
            role="BM",
            branch="Ibadan",
            branch_id="br-1",
        )

        with patch("api.routes.co.cashbook.check_branch_access"), \
             patch("api.routes.co.cashbook.BusinessDateService.is_operational_open", return_value=(False, "Closed Date")), \
             patch("api.routes.co.cashbook._get_eod_misc_fee_tracked", return_value=0.0), \
             patch("services.co_cashbook_projection_builder.CoCashbookProjectionBuilder.rebuild_co_projection") as mock_co_rebuild, \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection") as mock_mb_rebuild:
            resp = get_co_cashbook(
                date_str="2026-10-15",
                officer="co_one",
                branch=None,
                current_user=bm_user,
                uow=uow,
            )

        mock_co_rebuild.assert_not_called()
        mock_mb_rebuild.assert_not_called()
        self.assertEqual([o.username for o in resp.officers], ["co_one"])
        self.assertEqual(resp.active_loan_breakdown["daily"], 10000.0)
        self.assertEqual(resp.active_loan_breakdown["120d"], 49000.0)
        self.assertEqual(resp.active_loan_breakdown["12w"], 20000.0)
        self.assertEqual(resp.active_loan_breakdown["monthly"], 15000.0)

    def test_arrears_tally_includes_all_4_savings_tables_and_part_paid_shortfalls(self):
        from services.financial_reconciliation_service import FinancialReconciliationService

        uow = MagicMock()
        reps_rows = [
            {
                "id": "r1",
                "client_id": "c1",
                "amount_paid": 0.0,
                "expected_amount": 1500.0,
                "overdue_amount": 1500.0,
                "payment_status": "NOT_PAID",
                "clients": {"name": "Unpaid Client", "client_code": "CL-001"},
            },
            {
                "id": "r2",
                "client_id": "c2",
                "amount_paid": 1200.0,
                "expected_amount": 2000.0,
                "overdue_amount": 800.0,
                "payment_status": "PART_PAID",
                "clients": {"name": "Partial Client", "client_code": "CL-002"},
            },
        ]

        def table_router(name):
            if name == "repayments":
                return _ChainTableMock(reps_rows)
            if name == "individual_savings":
                return _ChainTableMock([{"deposit_amount": 1000.0}])
            if name == "group_savings":
                return _ChainTableMock([{"deposit_amount": 2000.0}])
            if name == "internal_savings":
                return _ChainTableMock([{"deposit_amount": 500.0}])
            if name == "laps_savings":
                return _ChainTableMock([{"deposit_amount": 750.0}])
            if name == "co_cashbooks":
                return _ChainTableMock([{"bank_deposit": 0.0, "closing_balance": 5450.0}])
            return _ChainTableMock([])

        uow.client.table.side_effect = table_router

        res = FinancialReconciliationService.get_daily_collection_arrears_tally(
            uow=uow,
            branch_id="br-1",
            posting_date=date(2026, 10, 15),
            officer_id="off-1",
        )

        self.assertEqual(res["actual_savings"], 4250.0)
        self.assertEqual(res["actual_repayments"], 1200.0)
        self.assertEqual(res["actual_cash_collected"], 5450.0)
        self.assertEqual(res["not_paid_count"], 2)
        self.assertEqual(res["not_paid_amount"], 2300.0)
        partial_row = next(c for c in res["not_paid_clients"] if c["code"] == "CL-002")
        self.assertTrue(partial_row["is_partial"])
        self.assertEqual(partial_row["shortfall"], 800.0)

    def test_treasury_bank_withdrawal_reversal_and_projection_deduction(self):
        from services.treasury_service import TreasuryService

        uow = MagicMock()
        tx_row = {
            "id": "tx-bank-wd-1",
            "branch_id": "br-1",
            "officer_id": "off-1",
            "transaction_type": "BANK_WITHDRAWAL",
            "amount": 30000.0,
            "posting_date": "2026-10-15",
            "source_account": "1050",
            "destination_account": "1000",
            "reference": "BWD-001",
            "narration": "Bank withdrawal from Zenith",
        }
        uow.client.table.side_effect = lambda name: (
            _ChainTableMock([tx_row]) if name == "treasury_transactions"
            else _ChainTableMock([{"name": "Ibadan"}]) if name == "branches"
            else _ChainTableMock([{"username": "co_one"}]) if name == "app_users"
            else _ChainTableMock([])
        )

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
             patch(
                 "services.posting_engine.FinancialPostingEngine.post_event",
                 return_value=("tx-rev-1", {"type": "post_financial_transaction", "table": "financial_transactions", "record": {}}),
             ) as mock_post:
            TreasuryService.reverse_treasury_transaction(
                uow=uow,
                original_tx_id="tx-bank-wd-1",
                reason="Wrong bank withdrawal amount",
                reversed_by="bm-1",
            )

        self.assertEqual(mock_post.call_count, 1)
        rev_event = mock_post.call_args.args[1]
        self.assertEqual(rev_event.event_type, "BankWithdrawalReversed")
        self.assertEqual(rev_event.payload["date"], "2026-10-15")

        # Verify CoCashbookProjectionBuilder deducts BankWithdrawalReversed from bank_withdrawal
        uow_proj = MagicMock()
        ledger_rows = [
            {
                "amount": 50000.0,
                "side": "Debit",
                "account_code": "1000",
                "transaction_id": "tx-1",
                "financial_transactions": {
                    "officer_id": "off-1",
                    "posting_date": "2026-10-15",
                    "event_store": {"event_type": "BankWithdrawn", "payload": {"branch_id": "br-1", "officer_id": "off-1", "date": "2026-10-15"}},
                },
            },
            {
                "amount": 20000.0,
                "side": "Credit",
                "account_code": "1000",
                "transaction_id": "tx-2",
                "financial_transactions": {
                    "officer_id": "off-1",
                    "posting_date": "2026-10-15",
                    "event_store": {"event_type": "BankWithdrawalReversed", "payload": {"branch_id": "br-1", "officer_id": "off-1", "date": "2026-10-15"}},
                },
            },
        ]
        uow_proj.client.table.side_effect = lambda name: (
            _ChainTableMock(ledger_rows) if name == "financial_ledger_entries"
            else _ChainTableMock([])
        )
        proj = CoCashbookProjectionBuilder.rebuild_co_projection(
            uow_proj, "br-1", "off-1", date(2026, 10, 15)
        )
        self.assertEqual(proj["bank_withdrawal"], 30000.0)
        self.assertEqual(proj["total_inflows"], 30000.0)

    def test_get_eod_misc_fee_tracked_and_record_client_fee_atomic_rpc(self):
        from types import SimpleNamespace
        from api.routes.co.cashbook import _get_eod_misc_fee_tracked, record_client_fee, RecordClientFeeInput

        uow = MagicMock()
        uow.cashbook._resolve_branch_id.return_value = "br-1"
        uow.loans._resolve_officer_id.return_value = "off-1"

        internal_rows = [
            {"deposit_amount": 3500.0, "withdrawal_amount": 0.0, "remarks": "[EOD_MISC_FEE:co_one]", "posting_date": "2026-10-15"},
            {"deposit_amount": 0.0, "withdrawal_amount": 1000.0, "remarks": "[EOD_MISC_FEE:co_one] [EOD_REVERSAL]", "posting_date": "2026-10-15"},
        ]

        def table_router(name):
            if name == "internal_savings":
                return _ChainTableMock(internal_rows)
            if name == "clients":
                return _ChainTableMock([{"client_id": "cl-1", "client_code": "IBA-01-001", "name": "Test Client", "branch_id": "br-1"}])
            if name == "branches":
                return _ChainTableMock([{"branch_id": "br-1", "name": "Ibadan"}])
            if name == "app_users":
                return _ChainTableMock([{"id": "off-1", "username": "co_one"}])
            return _ChainTableMock([])

        uow.client.table.side_effect = table_router
        net_misc = _get_eod_misc_fee_tracked(uow, "Ibadan", "2026-10-15", "co_one", branch_id="br-1")
        self.assertEqual(net_misc, 2500.0)

        user = SimpleNamespace(
            id="off-1",
            username="co_one",
            role="CO",
            branch="Ibadan",
            branch_id="br-1",
        )
        payload = RecordClientFeeInput(
            client_id="cl-1",
            fee_type="Passbook Fee",
            amount=1000.0,
            date="2026-10-15",
        )
        with patch("api.routes.co.cashbook.check_branch_access"), \
             patch("api.routes.co.cashbook.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
             patch("services.posting_engine.FinancialPostingEngine._resolve_branch_id", return_value="br-1"), \
             patch("services.posting_engine.FinancialPostingEngine._resolve_officer_id", return_value="off-1"), \
             patch("services.master_cashbook_projection_builder.MasterCashbookProjectionBuilder.rebuild_master_projection") as mock_mb_rebuild:
            resp = record_client_fee(payload=payload, current_user=user, uow=uow)

        self.assertTrue(resp.success)
        self.assertEqual(resp.fee_type, "PASSBOOK")
        uow.client.rpc.assert_called_once()
        p_ops = uow.client.rpc.call_args.args[1]["p_operations"]
        tables = {op.get("table") for op in p_ops}
        self.assertTrue({"event_store", "financial_transactions", "fees", "audit_logs"}.issubset(tables))
        uow.cashbook.rebuild_projection.assert_called_once()
        mock_mb_rebuild.assert_called_once()


if __name__ == "__main__":
    unittest.main()
