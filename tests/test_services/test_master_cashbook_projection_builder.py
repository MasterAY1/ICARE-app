import unittest
from datetime import date
from unittest.mock import MagicMock
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder

class TestMasterCashbookProjectionBuilder(unittest.TestCase):
    def setUp(self):
        self.mock_uow = MagicMock()
        # Default mock responses for database table queries
        self.mock_uow.client.table().select().eq().eq().execute().data = []

    def test_bank_withdrawal_is_inflow_in_master_cashbook(self):
        # Mock co_cashbooks data containing bank_withdrawal
        co_data = [{
            "rep_daily": 10000.0,
            "savings_deposit": 5000.0,
            "bank_withdrawal": 40000.0,
            "savings_withdrawal": 2000.0,
            "product_withdrawal": 2000.0,
            "bank_deposit": 0.0
        }]
        
        self.mock_uow.client.table().select().eq().eq().execute().data = co_data
        self.mock_uow.client.table().select().eq().execute().data = [] # treasury & loans empty

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 7, 31)
        )

        self.assertEqual(result["bank_withdrawal"], 40000.0)
        # Inflows = rep_daily (10000) + savings_deposit (5000) + bank_withdrawal (40000) = 55000
        self.assertEqual(result["total_inflows"], 55000.0)
        # Outflows = savings_withdrawal (2000) ONLY (product_withdrawal NOT double counted)
        self.assertEqual(result["total_outflows"], 2000.0)
        self.assertEqual(result["closing_balance"], 53000.0)

    def test_treasury_and_loan_disbursements_aggregation(self):
        co_data = [{
            "rep_daily": 20000.0,
            "bank_withdrawal": 0.0,
            "savings_withdrawal": 1000.0,
            "product_withdrawal": 1000.0
        }]

        # Mock treasury transactions
        treasury_data = [
            {"transaction_type": "HO_TRANSFER_IN", "amount": 50000.0, "created_at": "2026-07-31T10:00:00"},
            {"transaction_type": "OFFICE_EXPENSE", "amount": 3000.0, "created_at": "2026-07-31T11:00:00"}
        ]

        # Mock loan disbursements
        loan_data = [
            {"amount": 15000.0, "product_category": "Finance", "disbursement_date": "2026-07-31"}
        ]

        def table_side_effect(table_name):
            mock_table = MagicMock()
            if table_name == "co_cashbooks":
                mock_table.select().eq().eq().execute().data = co_data
            elif table_name == "treasury_transactions":
                mock_table.select().eq().execute().data = treasury_data
            elif table_name == "loans":
                mock_table.select().eq().eq().execute().data = loan_data
            else:
                mock_table.select().eq().eq().execute().data = []
            return mock_table

        self.mock_uow.client.table.side_effect = table_side_effect

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 7, 31)
        )

        self.assertEqual(result["funds_received_ho"], 50000.0)
        self.assertEqual(result["office_expenses"], 3000.0)
        self.assertEqual(result["fund_to_product_finance"], 15000.0)

        # Inflows = 20000 (rep_daily) + 50000 (funds_received_ho) = 70000
        self.assertEqual(result["total_inflows"], 70000.0)
        # Outflows = 1000 (savings_withdrawal) + 15000 (loan disbursement) + 3000 (office expenses) = 19000
        self.assertEqual(result["total_outflows"], 19000.0)
        self.assertEqual(result["closing_balance"], 51000.0)

if __name__ == "__main__":
    unittest.main()
