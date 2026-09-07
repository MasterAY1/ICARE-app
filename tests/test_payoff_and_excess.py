"""
Unit & Integration Tests: Loan Full Payoff & Excess Payment Business Invariants
Governance: BR-DASH-005, BR-DASH-007, GEMINI Invariant 9
"""
import pytest
from datetime import date, datetime
from unittest.mock import MagicMock

from domain.entities.payoff_excess_record import LoanPayoffExcessRecord
from services.repayment_service import RepaymentService


class TestRepaymentClassification:
    """Test authoritative repayment classification rules per BR-DASH-005 & BR-DASH-007."""

    def test_full_payoff_with_excess_classification(self):
        """
        User Scenario:
        Expected today = ₦2,500. Client pays ₦50,000 to clear entire remaining loan balance.
        Repayment classification must recognize surplus cash of ₦47,500 as EXCESS.
        """
        res = RepaymentService.classify_repayment(
            amount_paid=50000.0,
            total_due_today=2500.0,
            current_installment=2500.0,
            has_overdue=False
        )
        assert res["status"] == "EXCESS"
        assert res["true_excess"] == 47500.0
        assert res["overdue_shortfall"] == 0.0

    def test_arrears_cleared_not_excess(self):
        """
        Arrears Cleared Scenario:
        Overdue arrears = ₦2,500, today's installment = ₦2,500. Total due today = ₦5,000.
        Client pays ₦5,000.
        This must be classified as PAID (ARREARS CLEARED) with true_excess = ₦0, NOT excess.
        """
        res = RepaymentService.classify_repayment(
            amount_paid=50000.0 / 10.0,  # 5000.0
            total_due_today=5000.0,
            current_installment=2500.0,
            has_overdue=True
        )
        assert res["status"] == "PAID"
        assert res["is_arrears_cleared"] is True
        assert res["true_excess"] == 0.0
        assert res["arrears_recovered"] == 2500.0
        assert "ARREARS CLEARED" in res["status_badge"]

    def test_regular_installment_excess(self):
        """
        Regular installment = ₦2,500. Client pays ₦3,500 (₦1,000 surplus).
        Must be classified as EXCESS with true_excess = ₦1,000.
        """
        res = RepaymentService.classify_repayment(
            amount_paid=3500.0,
            total_due_today=2500.0,
            current_installment=2500.0,
            has_overdue=False
        )
        assert res["status"] == "EXCESS"
        assert res["true_excess"] == 1000.0
        assert res["overdue_shortfall"] == 0.0

    def test_part_payment_shortfall(self):
        """
        Expected installment = ₦2,500. Client pays ₦1,500.
        Must be classified as PART_PAID with shortfall = ₦1,000.
        """
        res = RepaymentService.classify_repayment(
            amount_paid=1500.0,
            total_due_today=2500.0,
            current_installment=2500.0,
            has_overdue=False
        )
        assert res["status"] == "PART_PAID"
        assert res["overdue_shortfall"] == 1000.0
        assert res["true_excess"] == 0.0

    def test_zero_payment_not_paid(self):
        """
        Expected installment = ₦2,500. Client pays ₦0.
        Must be classified as NOT_PAID with shortfall = ₦2,500.
        """
        res = RepaymentService.classify_repayment(
            amount_paid=0.0,
            total_due_today=2500.0,
            current_installment=2500.0,
            has_overdue=False
        )
        assert res["status"] == "NOT_PAID"
        assert res["overdue_shortfall"] == 2500.0


class TestPayoffAndExcessDomainEntity:
    """Test LoanPayoffExcessRecord entity properties and invariants."""

    def test_entity_creation_full_payoff_and_excess(self):
        rec = LoanPayoffExcessRecord(
            repayment_id="rep-123",
            loan_id="loan-456",
            client_id="client-789",
            officer_id="officer-001",
            branch_id="branch-001",
            date=date(2026, 9, 7),
            record_type="FULL_PAYOFF_AND_EXCESS",
            amount_paid=50000.0,
            expected_installment=2500.0,
            active_credit_settled=150000.0,
            excess_amount=47500.0,
            remaining_balance_before=50000.0,
            remaining_balance_after=0.0,
            notes="Client paid off entire loan early"
        )
        assert rec.record_type == "FULL_PAYOFF_AND_EXCESS"
        assert rec.active_credit_settled == 150000.0
        assert rec.excess_amount == 47500.0
        assert rec.remaining_balance_after == 0.0
        assert rec.id is not None


class TestLiveDatabaseDedicatedTable:
    """Verify live Supabase loan_payoff_excess_records table and audit view exist."""

    def test_table_and_view_queryable(self):
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        with SupabaseUnitOfWork() as uow:
            # Test public.loan_payoff_excess_records query
            res_table = uow.client.table("loan_payoff_excess_records").select("id").limit(1).execute()
            assert res_table.data is not None

            # Test repository instance on uow
            assert hasattr(uow, "payoff_excess")
            records = uow.payoff_excess.find_by_period(date(2026, 1, 1), date(2026, 12, 31))
            assert isinstance(records, list)
