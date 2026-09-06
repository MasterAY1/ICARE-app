"""
Unit tests for Collection Performance Audit View and Enricher.
Verifies fallback from collection_performance to repayments, group name resolution,
branch resolution fallback, and compliance ratio derivation.
"""
import unittest
from unittest.mock import MagicMock
from database.repositories.audit_view_repository import SupabaseAuditViewRepository
from services.audit_enricher_service import AuditEnricher


class TestCollectionPerformanceAudit(unittest.TestCase):

    def setUp(self):
        self.mock_client = MagicMock()
        self.repo = SupabaseAuditViewRepository(self.mock_client)

    def test_get_collection_performance_direct_hit(self):
        """When collection_performance table has records, returns them directly."""
        mock_cp_table = MagicMock()
        mock_cp_query = MagicMock()
        mock_cp_table.select.return_value = mock_cp_query
        mock_cp_query.order.return_value = mock_cp_query
        mock_cp_query.limit.return_value = mock_cp_query
        mock_cp_query.execute.return_value.data = [
            {
                "id": "cp-1",
                "client_id": "c-1",
                "loan_id": "l-1",
                "officer_id": "o-1",
                "meeting_date": "2026-09-04",
                "expected_amount": 5000.0,
                "amount_paid": 5000.0,
                "status": "PAID"
            }
        ]

        self.mock_client.table.side_effect = lambda t: mock_cp_table if t == "collection_performance" else MagicMock()

        records = self.repo.get_collection_performance(limit=10)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["id"], "cp-1")
        self.assertEqual(records[0]["status"], "PAID")

    def test_get_collection_performance_fallback_to_repayments(self):
        """When collection_performance is empty, falls back seamlessly to repayments table."""
        mock_cp_table = MagicMock()
        mock_cp_query = MagicMock()
        mock_cp_table.select.return_value = mock_cp_query
        mock_cp_query.order.return_value = mock_cp_query
        mock_cp_query.limit.return_value = mock_cp_query
        mock_cp_query.execute.return_value.data = []  # Empty collection_performance

        mock_rep_table = MagicMock()
        mock_rep_query = MagicMock()
        mock_rep_table.select.return_value = mock_rep_query
        mock_rep_query.order.return_value = mock_rep_query
        mock_rep_query.limit.return_value = mock_rep_query
        mock_rep_query.execute.return_value.data = [
            {
                "id": "rep-99",
                "client_id": "c-99",
                "loan_id": "l-99",
                "officer_id": "o-1",
                "branch_id": "b-1",
                "date": "2026-09-03 00:00:00+00",
                "expected_amount": 10000.0,
                "amount_paid": 10000.0,
                "payment_status": "PAID",
                "note": "Field collection"
            }
        ]

        def route_table(tbl_name):
            if tbl_name == "collection_performance":
                return mock_cp_table
            if tbl_name == "repayments":
                return mock_rep_table
            return MagicMock()

        self.mock_client.table.side_effect = route_table

        records = self.repo.get_collection_performance(limit=10)
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["id"], "rep-99")
        self.assertEqual(records[0]["amount_paid"], 10000.0)
        self.assertEqual(records[0]["expected_amount"], 10000.0)
        self.assertEqual(records[0]["status"], "PAID")
        self.assertEqual(records[0]["meeting_date"], "2026-09-03")

    def test_enrich_collection_records_with_fallbacks_and_group(self):
        """Enricher resolves group name, fallback branch, and computes compliance ratio."""
        mock_uow = MagicMock()
        enricher = AuditEnricher(uow=mock_uow)

        # Pre-seed enricher lookup caches
        enricher._clients_by_id["c-1"] = {"code": "CLI-001", "name": "Alhaji Musa", "group_id": "g-1", "full_label": "CLI-001 — Alhaji Musa"}
        enricher._groups_by_id["g-1"] = {"code": "GRP-01", "name": "Idera Group"}
        enricher._branches_by_id["b-1"] = "Ogijo"
        enricher._officer_branches["o-1"] = "b-1"
        enricher._users_by_id["o-1"] = "Mrs. Dorcas"
        enricher._is_loaded = True

        raw_records = [
            {
                "id": "rec-1",
                "client_id": "c-1",
                "loan_id": "l-1",
                "officer_id": "o-1",
                "branch_id": None,  # Test fallback branch resolution via officer
                "meeting_date": "2026-09-04",
                "expected_amount": 5000.0,
                "amount_paid": 4000.0
            }
        ]

        enriched = enricher.enrich_collection_records(raw_records)
        self.assertEqual(len(enriched), 1)
        row = enriched[0]

        self.assertEqual(row["Client Code"], "CLI-001")
        self.assertEqual(row["Client Name"], "Alhaji Musa")
        self.assertEqual(row["Group"], "Idera Group")
        self.assertEqual(row["Branch"], "Ogijo")
        self.assertEqual(row["Officer"], "Mrs. Dorcas")
        self.assertEqual(row["Compliance %"], "80.0%")
        self.assertEqual(row["Status_Raw"], "PART_PAYMENT")
        self.assertEqual(row["Expected_Raw"], 5000.0)
        self.assertEqual(row["Paid_Raw"], 4000.0)


if __name__ == "__main__":
    unittest.main()
