"""
Phase 8.1 — Automated Tests: Financial Integrity
Tests FinancialReconciliationService 6-way integrity verification.
"""
import unittest
from datetime import date
from services.financial_reconciliation_service import FinancialReconciliationService
from database.repositories.unit_of_work import SupabaseUnitOfWork


class TestFinancialIntegrity(unittest.TestCase):

    def test_6way_integrity_check_structure(self):
        """6-way financial integrity check returns expected structure and metrics."""
        with SupabaseUnitOfWork() as uow:
            b_id = "7ca8250a-9077-4bef-8cf3-78cf26c30705"  # Valid test branch
            res = FinancialReconciliationService.verify_6way_financial_integrity(uow, b_id, date.today())
            
            self.assertIn("is_balanced", res)
            self.assertIn("status_text", res)
            self.assertIn("ledger_total", res)
            self.assertIn("audit_views_total", res)
            self.assertIn("co_cashbooks_total", res)
            self.assertIn("master_cashbook_total", res)
            self.assertIn("dashboard_total", res)
            self.assertIn("reports_total", res)
            self.assertIn("variances", res)


if __name__ == "__main__":
    unittest.main()
