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
        # Ledger entry for SavingsWithdrawn: DR 2000, CR 1000
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
        # CRITICAL VERIFICATION: total_outflows must equal 10000 (NOT 20000 double-counted)
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

        # Asset loan must route to asset_credit_sales, NOT bank_withdrawal
        self.assertEqual(result["asset_credit_sales"], 68000.0)
        self.assertEqual(result["bank_withdrawal"], 0.0)
        self.assertEqual(result["fund_to_product_finance"], 48000.0)

if __name__ == "__main__":
    unittest.main()

