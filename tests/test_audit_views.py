"""
Phase 8.1 — Automated Tests: Audit Views
Verifies that SupabaseAuditViewRepository can query fee, treasury, loan, and savings virtual ledgers.
"""
import unittest
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork


class TestAuditViews(unittest.TestCase):

    def setUp(self):
        self.uow = SupabaseUnitOfWork()

    def test_audit_views_repository_registered(self):
        """AuditViewRepository is registered on UnitOfWork."""
        self.assertIsNotNone(self.uow.audit_views)

    def test_get_fee_ledger_processing(self):
        """Query processing fee ledger returns a list."""
        records = self.uow.audit_views.get_fee_ledger("PROCESSING_FEE", limit=10)
        self.assertIsInstance(records, list)

    def test_get_fee_ledger_all(self):
        """Query all fee ledgers returns a list."""
        records = self.uow.audit_views.get_fee_ledger("ALL", limit=10)
        self.assertIsInstance(records, list)

    def test_get_treasury_ledger_bank_deposit(self):
        """Query bank deposit treasury ledger returns a list."""
        records = self.uow.audit_views.get_treasury_ledger("BANK_DEPOSIT", limit=10)
        self.assertIsInstance(records, list)

    def test_get_loan_disbursements(self):
        """Query loan disbursements returns a list."""
        records = self.uow.audit_views.get_loan_disbursements(limit=10)
        self.assertIsInstance(records, list)

    def test_get_loan_repayments(self):
        """Query loan repayments returns a list."""
        records = self.uow.audit_views.get_loan_repayments(limit=10)
        self.assertIsInstance(records, list)

    def test_get_savings_ledger(self):
        """Query individual savings ledger returns a list."""
        records = self.uow.audit_views.get_savings_ledger("individual_savings", limit=10)
        self.assertIsInstance(records, list)

    def test_audit_views_read_only_safeguard(self):
        """Audit views enforce read-only mutation safeguards."""
        with self.assertRaises(NotImplementedError):
            self.uow.audit_views.create({})
        with self.assertRaises(NotImplementedError):
            self.uow.audit_views.update({})
        with self.assertRaises(NotImplementedError):
            self.uow.audit_views.delete("dummy_id")


if __name__ == "__main__":
    unittest.main()
