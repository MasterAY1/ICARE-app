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

        self.assertEqual(result["total_inflows"], 0.0)
        self.assertEqual(result["total_outflows"], 0.0)
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
        self.assertEqual(result["product_withdrawal"], 7500.0)
        self.assertEqual(result["total_outflows"], 7500.0)
        self.assertEqual(result["closing_balance"], -7500.0)

if __name__ == "__main__":
    unittest.main()
