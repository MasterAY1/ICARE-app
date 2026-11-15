import unittest
from datetime import date
from unittest.mock import MagicMock
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

class TestCoCashbookProjectionBuilder(unittest.TestCase):
    def setUp(self):
        self.mock_uow = MagicMock()
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = []

    def test_bank_withdrawal_is_inflow(self):
        # Ledger entry for BankWithdrawn: DR 1000, CR 1050
        entries = [{
            "account_code": "1000",
            "side": "Debit",
            "amount": 50000.0,
            "financial_transactions": {
                "officer_id": "off-01",
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "BankWithdrawn"}
            }
        }]
        
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 7, 31)
        )

        self.assertEqual(result["bank_withdrawal"], 50000.0)
        self.assertEqual(result["total_inflows"], 50000.0)
        self.assertEqual(result["total_outflows"], 0.0)
        self.assertEqual(result["closing_balance"], 50000.0)

    def test_savings_withdrawal_no_double_counting(self):
        # Cash withdrawal from vault: DR 2000, CR 1000 -> reduces vault cash, NO phantom bank withdrawal
        entries = [{
            "account_code": "1000",
            "side": "Credit",
            "amount": 10000.0,
            "financial_transactions": {
                "officer_id": "off-01",
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "SavingsWithdrawn"}
            }
        }]

        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 7, 31)
        )

        self.assertEqual(result["savings_withdrawal"], 10000.0)
        self.assertEqual(result["product_withdrawal"], 10000.0)
        self.assertEqual(result["bank_withdrawal"], 0.0)
        # Vault cash drop must equal -10000 (no phantom bank_withdrawal cancelling it out)
        self.assertEqual(result["total_outflows"], 10000.0)
        self.assertEqual(result["total_inflows"], 0.0)
        self.assertEqual(result["closing_balance"], -10000.0)

    def test_loan_offset_and_laps_transfer_zero_cash_impact(self):
        # LoanOffsetFromSavings (DR 2000, CR 1200) & LapsTransferred (DR 2000, CR 2030)
        # NEITHER has account_code == "1000"
        entries = [{
            "account_code": "2000",
            "side": "Debit",
            "amount": 15000.0,
            "financial_transactions": {
                "officer_id": "off-01",
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "LoanOffsetFromSavings"}
            }
        }]

        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 7, 31)
        )

        # Dual-sided non-cash offset: Left (inflow) = 15000, Right (outflow) = 15000, Net vault cash = 0
        self.assertEqual(result["total_inflows"], 15000.0)
        self.assertEqual(result["total_outflows"], 15000.0)
        self.assertEqual(result["closing_balance"], 0.0)

    def test_cash_laps_payout_impact(self):
        # Physical cash LapsPaidOut: DR 2030, CR 1000
        entries = [{
            "account_code": "1000",
            "side": "Credit",
            "amount": 7500.0,
            "financial_transactions": {
                "officer_id": "off-01",
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "LapsPaidOut"}
            }
        }]

        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 7, 31)
        )

        self.assertEqual(result["laps_returns"], 7500.0)
        self.assertEqual(result["total_outflows"], 7500.0)
        self.assertEqual(result["closing_balance"], -7500.0)

    def test_auto_deducted_upfront_fees_does_not_inflate_bank_withdrawal(self):
        # Auto-deduction from savings for loan upfront fees: DR 2000, CR 1000
        entries = [{
            "account_code": "2000",
            "side": "Debit",
            "amount": 26000.0,
            "financial_transactions": {
                "officer_id": "off-01",
                "posting_date": "2026-09-02",
                "event_store": {
                    "event_type": "SavingsWithdrawn",
                    "payload": {"narration": "Auto-deducted Upfront Fees (Interest: 24000.0, Gap: 2000.0) for Loan App"}
                }
            }
        }]

        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 9, 2)
        )

        # Must record product_withdrawal (Right side) but NOT bank_withdrawal (Left side)
        self.assertEqual(result["product_withdrawal"], 26000.0)
        self.assertEqual(result["bank_withdrawal"], 0.0)
        self.assertEqual(result["total_inflows"], 0.0)
        self.assertEqual(result["total_outflows"], 26000.0)

    def test_asset_loan_disbursement_routes_to_asset_credit_sales(self):
        # Asset loan disbursement: DR 1200, CR 1000
        entries = [{
            "account_code": "1000",
            "side": "Credit",
            "amount": 68000.0,
            "financial_transactions": {
                "officer_id": "off-01",
                "posting_date": "2026-09-02",
                "event_store": {
                    "event_type": "LoanDisbursed",
                    "payload": {
                        "amount": 68000.0,
                        "active_credit": 48000.0,
                        "product_type": "Weekly 12W Asset",
                        "product_category": "Asset",
                        "narration": "Loan disbursement of 68,000.00 (Weekly 12W Asset) for client Jimoh Fatimoh"
                    }
                }
            }
        }]

        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 9, 2)
        )

        # Asset loan must route to asset_credit_sales and active credit disb_12w, NOT bank_withdrawal or fund_to_product_finance
        self.assertEqual(result["asset_credit_sales"], 68000.0)
        self.assertEqual(result["disb_12w"], 48000.0)
        self.assertEqual(result["bank_withdrawal"], 0.0)
        self.assertEqual(result["fund_to_product_finance"], 0.0)

    def test_finance_loan_active_credit_net_of_gap_fee_and_principal_symmetry(self):
        # Finance Daily 60D loan: Principal = 100k, Gap Fee = 2k, Active Credit = 98k, Markup = 11k
        entries = [
            {
                "account_code": "1000",
                "side": "Credit",
                "amount": 100000.0,
                "financial_transactions": {
                    "event_id": "ev-fin-disb",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-18",
                    "event_store": {
                        "event_type": "LoanDisbursed",
                        "payload": {
                            "amount": 100000.0,
                            "active_credit": 98000.0,
                            "product_type": "Daily 60 Days Finance",
                            "repayment_cycle": "Daily",
                            "duration": 60,
                            "product_category": "Finance",
                            "narration": "Finance Daily 60D Loan",
                        },
                    },
                },
            },
            {
                "account_code": "1000",
                "side": "Debit",
                "amount": 11000.0,
                "financial_transactions": {
                    "event_id": "ev-fin-markup",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-18",
                    "narration": "Daily 11% Markup",
                    "event_store": {
                        "event_type": "FeeCharged",
                        "payload": {"narration": "Daily 11% Markup"},
                    },
                },
            },
            {
                "account_code": "2000",
                "side": "Debit",
                "amount": 13000.0,
                "financial_transactions": {
                    "event_id": "ev-fin-upfront",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-18",
                    "event_store": {
                        "event_type": "SavingsWithdrawn",
                        "payload": {"narration": "Auto-deducted Upfront Fees (Markup: 11000.0, Gap: 2000.0)"},
                    },
                },
            },
        ]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 10, 18)
        )

        self.assertEqual(result["disb_60d"], 98000.0)
        self.assertEqual(result["_finance_loan_principal"], 100000.0)
        self.assertEqual(result["fund_to_product_finance"], 100000.0)
        self.assertEqual(result["daily_11_pct"], 11000.0)
        self.assertEqual(result["product_withdrawal"], 13000.0)
        self.assertEqual(result["bank_withdrawal"], 100000.0)
        # CO Cashbook balanced on Finance Loan: Left (100k + 11k = 111k) == Right (98k + 13k = 111k)
        self.assertEqual(result["total_inflows"], 111000.0)
        self.assertEqual(result["total_outflows"], 111000.0)
        self.assertEqual(result["closing_balance"], 0.0)

    def test_misc_savings_and_misc_fee_route_into_savings_deposit(self):
        entries = [
            {
                "account_code": "1000",
                "side": "Debit",
                "amount": 3500.0,
                "aggregate_type": "MiscSavings",
                "financial_transactions": {
                    "event_id": "ev-misc-1",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-18",
                    "event_store": {
                        "event_type": "SavingsDeposited",
                        "aggregate_type": "MiscSavings",
                        "payload": {"classification": "MISC_FEE", "narration": "Misc savings"},
                    },
                },
            },
            {
                "account_code": "1000",
                "side": "Debit",
                "amount": 1500.0,
                "financial_transactions": {
                    "event_id": "ev-misc-2",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-18",
                    "narration": "MISC_FEE",
                    "event_store": {"event_type": "FeeCharged", "payload": {"narration": "MISC_FEE"}},
                },
            },
            {
                "account_code": "1000",
                "side": "Debit",
                "amount": 500.0,
                "financial_transactions": {
                    "event_id": "ev-pen-1",
                    "officer_id": "off-01",
                    "posting_date": "2026-10-18",
                    "event_store": {"event_type": "PenaltyCharged", "payload": {}},
                },
            },
        ]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 10, 18)
        )

        self.assertEqual(result["savings_deposit"], 5000.0)
        self.assertEqual(result["credit_form_damage"], 500.0)
        self.assertEqual(result["misc_fees"], 0.0)
        self.assertEqual(result["total_inflows"], 5500.0)

    def test_manual_opening_balance_applied(self):
        # When manual_opening_balance is provided, it is applied directly
        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 9, 1), manual_opening_balance=25000.0
        )
        self.assertEqual(result["opening_balance"], 25000.0)
        self.assertEqual(result["total_inflows"], 25000.0)
        self.assertEqual(result["closing_balance"], 25000.0)

    def test_inception_opening_balance_preserved(self):
        # When no manual_opening_balance is provided and no prior day exists,
        # but co_cashbooks already has a non-zero opening balance for this date, preserve it
        mock_table = MagicMock()
        mock_select = MagicMock()
        mock_eq1 = MagicMock()
        mock_eq2 = MagicMock()
        mock_eq3 = MagicMock()
        
        # Setup mock return for co_cashbooks select
        self.mock_uow.client.table.return_value = mock_table
        mock_table.select.return_value = mock_select
        mock_select.eq.return_value = mock_eq1
        mock_eq1.eq.return_value = mock_eq2
        mock_eq2.eq.return_value = mock_eq3
        mock_eq3.execute.return_value.data = [{"opening_balance": 35000.0}]

        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, "branch-01", "off-01", date(2026, 9, 1)
        )
        self.assertEqual(result["opening_balance"], 35000.0)
        self.assertEqual(result["total_inflows"], 35000.0)
        self.assertEqual(result["closing_balance"], 35000.0)

if __name__ == "__main__":
    unittest.main()

