"""
Phase 8.1 — Automated Tests: Audit Reports
Tests AuditReportingService summary calculations and multi-level drill-down data generators.
"""
import unittest
from services.audit_reporting_service import AuditReportingService
from database.repositories.unit_of_work import SupabaseUnitOfWork


class TestAuditReports(unittest.TestCase):

    def test_summary_metrics_calculation_empty(self):
        """Empty records return default summary metrics."""
        m = AuditReportingService.calculate_summary_metrics([])
        self.assertEqual(m["total_amount"], 0.0)
        self.assertEqual(m["total_count"], 0)
        self.assertEqual(m["average_amount"], 0.0)
        self.assertEqual(m["last_transaction_date"], "N/A")
        self.assertEqual(m["highest_amount"], 0.0)

    def test_summary_metrics_calculation_with_data(self):
        """Records return accurate summary metrics."""
        sample_records = [
            {"amount": 1000.0, "posting_date": "2026-07-20"},
            {"amount": 2500.0, "posting_date": "2026-07-22"},
            {"amount": 1500.0, "posting_date": "2026-07-21"}
        ]
        m = AuditReportingService.calculate_summary_metrics(sample_records)
        self.assertEqual(m["total_amount"], 5000.0)
        self.assertEqual(m["total_count"], 3)
        self.assertEqual(m["average_amount"], 1666.67)
        self.assertEqual(m["last_transaction_date"], "2026-07-22")
        self.assertEqual(m["highest_amount"], 2500.0)

    def test_multi_level_drilldown(self):
        """Drill-down breakdown aggregates by branch, officer, and client."""
        with SupabaseUnitOfWork() as uow:
            res = AuditReportingService.get_multi_level_drilldown(uow, "FEE", "PROCESSING_FEE")
            self.assertIn("total", res)
            self.assertIn("by_branch", res)
            self.assertIn("by_officer", res)
            self.assertIn("by_client", res)


if __name__ == "__main__":
    unittest.main()
