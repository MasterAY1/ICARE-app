"""
Phase 8 — Automated Tests: Audit Ledger Repositories
Tests that all 19 audit ledger repositories are accessible from UnitOfWork
and can perform basic operations against the STI backing tables.
"""
import unittest
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork


class TestAuditLedgerRepositories(unittest.TestCase):
    """Verify all 19 audit ledger repositories are wired to UnitOfWork."""

    def setUp(self):
        self.uow = SupabaseUnitOfWork()

    # === Fee-type Audit Ledgers (backed by public.fees) ===
    
    def test_processing_fees_repository_exists(self):
        """Processing Fees repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.processing_fees)
        self.assertEqual(self.uow.processing_fees.fee_type, "PROCESSING_FEE")

    def test_passbook_fees_repository_exists(self):
        """Passbook Fees repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.passbook_fees)
        self.assertEqual(self.uow.passbook_fees.fee_type, "PASSBOOK")

    def test_credit_forms_repository_exists(self):
        """Credit Forms repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.credit_forms)
        self.assertEqual(self.uow.credit_forms.fee_type, "CREDIT_FORM")

    def test_credit_form_damage_repository_exists(self):
        """Credit Form Damage repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.credit_form_damage)
        self.assertEqual(self.uow.credit_form_damage.fee_type, "CREDIT_FORM_DAMAGE")

    def test_bonus_transactions_repository_exists(self):
        """Bonus Transactions repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.bonus_transactions)
        self.assertEqual(self.uow.bonus_transactions.fee_type, "BONUS")

    def test_misc_fees_repository_exists(self):
        """Misc Fees repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.misc_fees)
        self.assertEqual(self.uow.misc_fees.fee_type, "MISC_FEE")

    def test_contingency_transactions_repository_exists(self):
        """Contingency Transactions repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.contingency_transactions)
        self.assertEqual(self.uow.contingency_transactions.fee_type, "CONTINGENCY")

    def test_markup_11_transactions_repository_exists(self):
        """Markup 11% Transactions repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.markup_11_transactions)
        self.assertEqual(self.uow.markup_11_transactions.fee_type, "MARKUP_11")

    def test_markup_20_transactions_repository_exists(self):
        """Markup 20% Transactions repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.markup_20_transactions)
        self.assertEqual(self.uow.markup_20_transactions.fee_type, "MARKUP_20")

    # === Treasury-type Audit Ledgers (backed by public.treasury_transactions) ===

    def test_bank_deposits_repository_exists(self):
        """Bank Deposits repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.bank_deposits)

    def test_bank_withdrawals_repository_exists(self):
        """Bank Withdrawals repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.bank_withdrawals)

    def test_office_expenses_repository_exists(self):
        """Office Expenses repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.office_expenses)

    def test_staff_salary_repository_exists(self):
        """Staff Salary repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.staff_salary_transactions)

    def test_head_office_transfer_repository_exists(self):
        """Head Office Transfer repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.head_office_transfers)

    def test_branch_transfer_repository_exists(self):
        """Branch Transfer repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.branch_transfers)

    def test_other_area_transfer_repository_exists(self):
        """Other Area Transfer repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.other_area_transfers)

    def test_asset_program_repository_exists(self):
        """Asset Program repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.asset_program_transactions)

    def test_product_finance_repository_exists(self):
        """Product Finance repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.product_finance_transactions)

    def test_cashbook_adjustment_repository_exists(self):
        """Cashbook Adjustment repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.cashbook_adjustments)

    # === Collection Performance ===

    def test_collection_performance_repository_exists(self):
        """Collection Performance repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.collection_performance)

    # === Backward Compatibility Aliases ===

    def test_backward_compatible_aliases(self):
        """Phase 7 aliases still work."""
        self.assertIs(self.uow.processing_fee, self.uow.processing_fees)
        self.assertIs(self.uow.passbook, self.uow.passbook_fees)
        self.assertIs(self.uow.credit_form, self.uow.credit_forms)
        self.assertIs(self.uow.bonus, self.uow.bonus_transactions)
        self.assertIs(self.uow.misc_fee, self.uow.misc_fees)
        self.assertIs(self.uow.contingency, self.uow.contingency_transactions)
        self.assertIs(self.uow.markup_11, self.uow.markup_11_transactions)
        self.assertIs(self.uow.markup_20, self.uow.markup_20_transactions)
        self.assertIs(self.uow.bank_deposit, self.uow.bank_deposits)
        self.assertIs(self.uow.bank_withdrawal, self.uow.bank_withdrawals)
        self.assertIs(self.uow.office_expense, self.uow.office_expenses)

    # === STI Query Tests ===

    def test_fee_repo_query_by_branch_and_date(self):
        """Fee repositories can query by branch and date without error."""
        # Use a branch_id that exists in the system
        results = self.uow.processing_fees.find_by_branch_and_date(
            "7ca8250a-9077-4bef-8cf3-78cf26c30705", date.today()
        )
        self.assertIsInstance(results, list)

    def test_treasury_repo_query_by_branch_and_date(self):
        """Treasury repositories can query by branch and date without error."""
        results = self.uow.staff_salary_transactions.find_by_branch_and_date(
            "7ca8250a-9077-4bef-8cf3-78cf26c30705", date.today()
        )
        self.assertIsInstance(results, list)


if __name__ == "__main__":
    unittest.main()
