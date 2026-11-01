"""
tests/test_am_batch_summary.py
Unit tests for AreaManagerService.get_regional_summary batch query optimization.
Verifies fail-closed behavior, batch querying, and Account 1000 vault cash aggregation.
"""
import unittest
from unittest.mock import MagicMock
from datetime import date
from services.area_manager_service import AreaManagerService


class TestAMBatchSummary(unittest.TestCase):

    def test_get_regional_summary_unassigned_am_returns_zeroes(self):
        """Unassigned Area Manager must fail closed and return zeroes immediately without DB queries."""
        uow = MagicMock()
        uow.users.load_am_assignments.return_value = []
        uow.users.find_by_id.return_value = None

        summary = AreaManagerService.get_regional_summary(uow, "am_unassigned_id", target_date=date(2026, 11, 2))

        self.assertEqual(summary["branches_count"], 0)
        self.assertEqual(summary["open_branches_count"], 0)
        self.assertEqual(summary["active_clients"], 0)
        self.assertEqual(summary["active_credit"], 0.0)
        self.assertEqual(summary["vault_cash_acct_1000"], 0.0)
        self.assertEqual(summary["defaulters_count"], 0)
        self.assertEqual(summary["assigned_branches"], [])
        # Must not call client table queries
        uow.client.table.assert_not_called()

    def test_get_regional_summary_batch_aggregation(self):
        """Assigned AM executes consolidated batch queries for closures, loans, and Account 1000 vault cash."""
        uow = MagicMock()
        uow.users.load_am_assignments.return_value = [
            {"branch_id": "b1", "name": "Ogijo"},
            {"branch_id": "b2", "name": "Ikorodu"},
            {"branch_id": "b3", "name": "Kola"}
        ]

        # Setup mock PostgREST builder
        table_mock = MagicMock()
        uow.client.table.return_value = table_mock

        # Helper to route table calls
        def table_router(table_name):
            builder = MagicMock()
            builder.select.return_value = builder
            builder.lte.return_value = builder
            builder.gte.return_value = builder
            builder.or_.return_value = builder
            builder.in_.return_value = builder
            builder.eq.return_value = builder

            if table_name == "branch_closures":
                # Simulate Kola (b3) is closed, others open
                builder.execute.return_value = MagicMock(data=[
                    {"branch_id": "b3", "reason": "Renovation"}
                ])
            elif table_name == "loans":
                # Return batch loans for b1, b2, b3
                builder.execute.return_value = MagicMock(data=[
                    {"loan_id": "l1", "client_id": "c1", "branch_id": "b1", "active_credit": 150000.0, "status": "ACTIVE"},
                    {"loan_id": "l2", "client_id": "c2", "branch_id": "b1", "active_credit": 200000.0, "status": "Active"},
                    {"loan_id": "l3", "client_id": "c3", "branch_id": "b2", "active_credit": 100000.0, "status": "Approved"},
                    {"loan_id": "l4", "client_id": "c4", "branch_id": "b2", "active_credit": 50000.0, "status": "DEFAULTER"},
                    {"loan_id": "l5", "client_id": "c5", "branch_id": "b3", "active_credit": 75000.0, "status": "Defaulter"}
                ])
            elif table_name == "financial_ledger_entries":
                # Return batch Account 1000 entries
                # b1: debit 300,000, credit 100,000 -> net 200,000
                # b2: debit 150,000, credit 50,000 -> net 100,000
                # b3: debit 50,000, credit 60,000 -> net -10,000 clamped to 0
                # Total expected vault cash = 300,000
                builder.execute.return_value = MagicMock(data=[
                    {"branch_id": "b1", "amount": 300000.0, "side": "Debit"},
                    {"branch_id": "b1", "amount": 100000.0, "side": "Credit"},
                    {"branch_id": "b2", "amount": 150000.0, "side": "Debit"},
                    {"branch_id": "b2", "amount": 50000.0, "side": "Credit"},
                    {"branch_id": "b3", "amount": 50000.0, "side": "Debit"},
                    {"branch_id": "b3", "amount": 60000.0, "side": "Credit"}
                ])
            else:
                builder.execute.return_value = MagicMock(data=[])

            return builder

        uow.client.table.side_effect = table_router

        # Run on a Monday (not weekend)
        target_test_date = date(2026, 11, 2)
        summary = AreaManagerService.get_regional_summary(uow, "am_area_1_id", target_date=target_test_date)

        # Verification:
        # 3 branches total, b3 closed, so 2 open
        self.assertEqual(summary["branches_count"], 3)
        self.assertEqual(summary["open_branches_count"], 2)

        # Active loans: l1 (150k), l2 (200k), l3 (100k) = 450,000 active credit
        self.assertEqual(summary["active_credit"], 450000.0)
        self.assertEqual(summary["active_clients"], 3)

        # Defaulters: l4, l5 = 2
        self.assertEqual(summary["defaulters_count"], 2)

        # Account 1000 Vault Cash: b1(200k) + b2(100k) + b3(0) = 300,000
        self.assertEqual(summary["vault_cash_acct_1000"], 300000.0)


if __name__ == "__main__":
    unittest.main()
