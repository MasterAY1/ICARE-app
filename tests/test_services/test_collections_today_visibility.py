"""
Collections Today Visibility Tests (BIA-CO-COLLECTIONS-TODAY-008)
Verifies:
1. CollectionSheetMember and SingleClientOption schema definitions for today's collection visibility.
2. ISO timestamp range queries correctly identify today's recorded repayments and savings.
3. Collection sheet and single-client endpoints attribute today_repayment, today_savings, today_status, and today_collected_total without modifying business logic.
"""

import unittest
from unittest.mock import MagicMock, patch
from datetime import date

from api.schemas.collections import (
    CollectionSheetMember,
    SingleClientOption,
    SingleClientOptionsResponse,
    CollectionSheetResponse,
)
from api.dependencies import CurrentUser


class TestCollectionsTodayVisibility(unittest.TestCase):

    def setUp(self):
        self.mock_user = CurrentUser(
            id="usr-co-01",
            username="officer_john",
            role="CO",
            branch="Ikorodu",
            branch_id="br-001"
        )
        self.mock_uow = MagicMock()

    def test_schema_attributes_present(self):
        """Verify schemas have today_repayment, today_savings, today_status, and today_collected_total."""
        member = CollectionSheetMember(
            client_id="c-001",
            client_code="CLI-001",
            client_name="Test Client",
            loan_product="Standard",
            active_credit=100000.0,
            remaining_balance=50000.0,
            expected_repayment=2500.0,
            savings_balance=10000.0,
            today_repayment=2500.0,
            today_savings=500.0,
            today_status="PAID",
            today_collected_total=3000.0,
        )
        self.assertEqual(member.today_repayment, 2500.0)
        self.assertEqual(member.today_savings, 500.0)
        self.assertEqual(member.today_status, "PAID")
        self.assertEqual(member.today_collected_total, 3000.0)

        sc_opt = SingleClientOption(
            client_id="c-001",
            client_code="CLI-001",
            client_name="Test Client",
            group_name="Alpha",
            is_in_group=True,
            personal_savings_balance=10000.0,
            group_savings_balance=5000.0,
            loans=[],
            today_repayment=5000.0,
            today_savings=1000.0,
            today_collected=True,
            today_status="PAID",
            today_collected_total=6000.0,
        )
        self.assertTrue(sc_opt.today_collected)
        self.assertEqual(sc_opt.today_repayment, 5000.0)
        self.assertEqual(sc_opt.today_savings, 1000.0)
        self.assertEqual(sc_opt.today_status, "PAID")
        self.assertEqual(sc_opt.today_collected_total, 6000.0)

    @patch("api.routes.co.collections.BusinessDateService.is_operational_open")
    def test_get_collection_sheet_today_visibility(self, mock_is_open):
        """Verify get_collection_sheet accurately returns today's recorded repayment and savings."""
        from api.routes.co.collections import get_collection_sheet

        mock_is_open.return_value = (True, "Open")
        self.mock_uow.loans._resolve_officer_id.return_value = "usr-co-01"

        # Mock group lookup
        mock_group_table = MagicMock()
        mock_group_table.select.return_value.execute.return_value.data = [
            {"group_id": "grp-1", "name": "Solidarity Alpha", "meeting_day": "Friday"}
        ]

        # Mock clients in group
        mock_clients_table = MagicMock()
        mock_clients_table.select.return_value.eq.return_value.execute.return_value.data = [
            {"client_id": "c-001", "client_code": "CL-001", "name": "Adebayo Olawale", "group_id": "grp-1", "branch_id": "br-001"}
        ]

        # Mock repayments table with today's payment (ISO format with T)
        mock_reps_table = MagicMock()
        mock_reps_table.select.return_value.gte.return_value.lte.return_value.eq.return_value.execute.return_value.data = [
            {"client_id": "c-001", "loan_id": "loan-001", "amount_paid": 5000.0, "payment_status": "PAID", "date": "2026-10-31T10:00:00+00:00"}
        ]

        # Mock individual_savings table with today's deposit
        mock_sav_table = MagicMock()
        mock_sav_table.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
            {"client_id": "c-001", "deposit_amount": 1000.0}
        ]

        # Mock loans table
        mock_loans_table = MagicMock()
        mock_loans_table.select.return_value.in_.return_value.in_.return_value.execute.return_value.data = [
            {"loan_id": "loan-001", "client_id": "c-001", "loan_amount": 50000.0, "active_credit": 50000.0, "total_due": 50000.0, "loan_repay": 5000.0, "product_category": "Standard"}
        ]

        def router(name):
            if name == "groups": return mock_group_table
            if name == "clients": return mock_clients_table
            if name == "repayments": return mock_reps_table
            if name == "individual_savings": return mock_sav_table
            if name == "loans": return mock_loans_table
            return MagicMock()

        self.mock_uow.client.table.side_effect = router

        resp = get_collection_sheet(
            group_name="Solidarity Alpha",
            date_str="2026-10-31",
            current_user=self.mock_user,
            uow=self.mock_uow
        )

        self.assertEqual(len(resp.members), 1)
        m = resp.members[0]
        self.assertEqual(m.client_id, "c-001")
        self.assertEqual(m.today_repayment, 5000.0)
        self.assertEqual(m.today_savings, 1000.0)
        self.assertEqual(m.today_status, "PAID")
        self.assertEqual(m.today_collected_total, 6000.0)

    def test_get_single_client_options_today_visibility(self):
        """Verify get_single_client_options accurately returns today's collection status for each client."""
        from api.routes.co.collections import get_single_client_options

        self.mock_uow.loans._resolve_officer_id.return_value = "usr-co-01"

        mock_clients_table = MagicMock()
        mock_clients_table.select.return_value.eq.return_value.execute.return_value.data = [
            {"client_id": "c-001", "client_code": "CL-001", "name": "Adebayo Olawale", "group_id": "grp-1", "groups": {"name": "Alpha"}}
        ]

        # Mock repayments table with today's payment
        mock_reps_table = MagicMock()
        mock_reps_table.select.return_value.gte.return_value.lte.return_value.eq.return_value.execute.return_value.data = [
            {"client_id": "c-001", "amount_paid": 5000.0, "payment_status": "PAID", "date": "2026-10-31T09:30:00+00:00"}
        ]

        # Mock savings table with today's deposit
        mock_sav_table = MagicMock()
        mock_sav_table.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
            {"client_id": "c-001", "deposit_amount": 1000.0}
        ]

        def router(name):
            if name == "clients": return mock_clients_table
            if name == "repayments": return mock_reps_table
            if name == "individual_savings": return mock_sav_table
            return MagicMock()

        self.mock_uow.client.table.side_effect = router

        resp = get_single_client_options(
            current_user=self.mock_user,
            uow=self.mock_uow
        )

        self.assertEqual(len(resp.clients), 1)
        c = resp.clients[0]
        self.assertEqual(c.client_id, "c-001")
        self.assertTrue(c.today_collected)
        self.assertEqual(c.today_repayment, 5000.0)
        self.assertEqual(c.today_savings, 1000.0)
        self.assertEqual(c.today_status, "PAID")
        self.assertEqual(c.today_collected_total, 6000.0)


if __name__ == "__main__":
    unittest.main()
