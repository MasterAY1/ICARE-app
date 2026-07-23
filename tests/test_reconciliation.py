"""
Phase 8.1 — Automated Tests: Reconciliation Wizard
Tests self-healing projection repair wizard.
"""
import unittest
from datetime import date
from services.financial_reconciliation_service import FinancialReconciliationService
from database.repositories.unit_of_work import SupabaseUnitOfWork


class TestReconciliationWizard(unittest.TestCase):

    def test_reconciliation_wizard_repair(self):
        """Reconciliation wizard rebuilds cashbooks and returns verification status."""
        with SupabaseUnitOfWork() as uow:
            b_id = "7ca8250a-9077-4bef-8cf3-78cf26c30705"
            res = FinancialReconciliationService.run_reconciliation_wizard_repair(uow, b_id, date.today())
            self.assertIn("rebuilt_officer_count", res)
            self.assertIn("master_cashbook_rebuilt", res)
            self.assertTrue(res["master_cashbook_rebuilt"])
            self.assertIn("verification_after_repair", res)


if __name__ == "__main__":
    unittest.main()
