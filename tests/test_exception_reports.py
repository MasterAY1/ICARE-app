"""
Phase 8.1 — Automated Tests: Exception Reports
Tests 15 automated audit exception rules engine.
"""
import unittest
from services.financial_reconciliation_service import FinancialReconciliationService
from database.repositories.unit_of_work import SupabaseUnitOfWork


class TestExceptionReports(unittest.TestCase):

    def test_run_15_exception_reports(self):
        """Exception report engine evaluates 15 rules and returns detailed anomaly structure."""
        with SupabaseUnitOfWork() as uow:
            res = FinancialReconciliationService.run_15_exception_reports(uow)
            self.assertEqual(res["exception_rules_evaluated"], 15)
            self.assertIn("total_exceptions", res)
            self.assertIn("details", res)
            self.assertEqual(len(res["details"]), 15)


if __name__ == "__main__":
    unittest.main()
