"""
Unit & Integration Tests: Loan Overdue Recovery System & Permanent Audit Logging
Governance: BR-DASH-004, BR-DASH-005, Invariants 8 & 9
"""
import pytest
from datetime import date, datetime
from unittest.mock import MagicMock, patch
from uuid import uuid4

from domain.entities.overdue_recovery_record import LoanOverdueRecoveryRecord
from domain.entities.repayment import Repayment
from services.repayment_service import RepaymentService


class TestOverdueRecoveryEntity:
    """Test domain entity instantiation and defaults."""

    def test_overdue_recovery_record_defaults(self):
        rec = LoanOverdueRecoveryRecord(
            repayment_id="rep-123",
            loan_id="loan-456",
            client_id="client-789",
            recovered_amount=5000.0,
            overdue_before=10000.0,
            overdue_after=5000.0,
            total_repayment_amount=5000.0,
            recovery_type="PARTIAL_RECOVERY"
        )
        assert rec.id is not None
        assert rec.recovery_date == date.today()
        assert rec.recovery_timestamp is not None
        assert rec.recovered_amount == 5000.0
        assert rec.overdue_after == 5000.0
        assert rec.recovery_type == "PARTIAL_RECOVERY"


class TestOverdueRecoveryProcessing:
    """Test automated overdue recovery detection and recording during repayment posting."""

    def test_record_full_overdue_recovery(self):
        """
        Scenario: Loan has ₦10,000 overdue arrears. Client pays ₦10,000.
        Must record FULL_RECOVERY: recovered = ₦10,000, overdue_after = ₦0.
        """
        mock_uow = MagicMock()
        mock_uow.overdue_recoveries = MagicMock()
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []

        rep = Repayment(
            id=str(uuid4()),
            loan_id="loan-101",
            client_id="c-202",
            amount_paid=10000.0,
            savings_amount=0.0,
            loan_repayment_amount=10000.0,
            withdrawal_amount=0.0,
            others_amount=0.0,
            recovery_amount=0.0,
            initial_payment=0.0,
            payment_date=date(2026, 11, 1),
            transaction_type="Loan",
            branch="Test Branch",
            credit_officer="Officer Mighty"
        )

        preloaded_loan = {
            "loan_id": "loan-101",
            "client_id": "c-202",
            "active_credit": 50000.0,
            "total_due": 50000.0,
            "loan_amount": 50000.0,
            "loan_repay": 2500.0,
            "branch_id": str(uuid4()),
            "officer_id": str(uuid4()),
            "status": "Active"
        }

        # Mock ScheduleService.calculate_total_due returning ₦10,000 overdue arrears
        with patch("services.schedule_service.ScheduleService.calculate_total_due") as mock_due:
            mock_due.return_value = {
                "overdue_arrears": 10000.0,
                "current_installment": 2500.0,
                "total_due_today": 12500.0
            }

            RepaymentService._record_overdue_recovery_if_applicable(
                mock_uow,
                rep,
                preloaded_loan=preloaded_loan,
                preloaded_repayments=[]
            )

            assert mock_uow.overdue_recoveries.record_event.called
            recorded = mock_uow.overdue_recoveries.record_event.call_args[0][0]
            assert isinstance(recorded, LoanOverdueRecoveryRecord)
            assert recorded.recovered_amount == 10000.0
            assert recorded.overdue_before == 10000.0
            assert recorded.overdue_after == 0.0
            assert recorded.recovery_type == "FULL_RECOVERY"

    def test_record_partial_overdue_recovery(self):
        """
        Scenario: Loan has ₦15,000 overdue arrears. Client pays ₦5,000.
        Must record PARTIAL_RECOVERY: recovered = ₦5,000, overdue_after = ₦10,000.
        """
        mock_uow = MagicMock()
        mock_uow.overdue_recoveries = MagicMock()
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []

        rep = Repayment(
            id=str(uuid4()),
            loan_id="loan-102",
            client_id="c-203",
            amount_paid=5000.0,
            savings_amount=0.0,
            loan_repayment_amount=5000.0,
            withdrawal_amount=0.0,
            others_amount=0.0,
            recovery_amount=0.0,
            initial_payment=0.0,
            payment_date=date(2026, 11, 1),
            transaction_type="Loan",
            branch="Test Branch",
            credit_officer="Officer Mighty"
        )

        preloaded_loan = {
            "loan_id": "loan-102",
            "client_id": "c-203",
            "active_credit": 60000.0,
            "total_due": 60000.0,
            "loan_amount": 60000.0,
            "loan_repay": 3000.0,
            "branch_id": str(uuid4()),
            "officer_id": str(uuid4()),
            "status": "Active"
        }

        with patch("services.schedule_service.ScheduleService.calculate_total_due") as mock_due:
            mock_due.return_value = {
                "overdue_arrears": 15000.0,
                "current_installment": 3000.0,
                "total_due_today": 18000.0
            }

            RepaymentService._record_overdue_recovery_if_applicable(
                mock_uow,
                rep,
                preloaded_loan=preloaded_loan,
                preloaded_repayments=[]
            )

            assert mock_uow.overdue_recoveries.record_event.called
            recorded = mock_uow.overdue_recoveries.record_event.call_args[0][0]
            assert recorded.recovered_amount == 5000.0
            assert recorded.overdue_before == 15000.0
            assert recorded.overdue_after == 10000.0
            assert recorded.recovery_type == "PARTIAL_RECOVERY"

    def test_no_recovery_when_overdue_is_zero(self):
        """
        Scenario: Loan has ₦0 overdue arrears (regular on-schedule payment).
        Must NOT create any recovery record.
        """
        mock_uow = MagicMock()
        mock_uow.overdue_recoveries = MagicMock()

        rep = Repayment(
            id=str(uuid4()),
            loan_id="loan-103",
            client_id="c-204",
            amount_paid=2500.0,
            savings_amount=0.0,
            loan_repayment_amount=2500.0,
            withdrawal_amount=0.0,
            others_amount=0.0,
            recovery_amount=0.0,
            initial_payment=0.0,
            payment_date=date(2026, 11, 1),
            transaction_type="Loan",
            branch="Test Branch",
            credit_officer="Officer Mighty"
        )

        preloaded_loan = {
            "loan_id": "loan-103",
            "client_id": "c-204",
            "active_credit": 50000.0,
            "total_due": 50000.0,
            "loan_amount": 50000.0,
            "loan_repay": 2500.0,
            "status": "Active"
        }

        with patch("services.schedule_service.ScheduleService.calculate_total_due") as mock_due:
            mock_due.return_value = {
                "overdue_arrears": 0.0,
                "current_installment": 2500.0,
                "total_due_today": 2500.0
            }

            RepaymentService._record_overdue_recovery_if_applicable(
                mock_uow,
                rep,
                preloaded_loan=preloaded_loan,
                preloaded_repayments=[]
            )

            assert not mock_uow.overdue_recoveries.record_event.called

    def test_reverse_repayment_purges_recovery_record(self):
        """
        Scenario: A repayment is reversed. The associated overdue recovery record must be deleted.
        """
        mock_uow = MagicMock()
        mock_uow.overdue_recoveries = MagicMock()
        mock_uow.payoff_excess = MagicMock()

        target_rep_id = str(uuid4())
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [{
            "id": target_rep_id,
            "amount_paid": 5000.0,
            "loan_id": "loan-999",
            "branch_id": str(uuid4()),
            "officer_id": str(uuid4())
        }]
        mock_uow.client.table.return_value.select.return_value.lt.return_value.execute.return_value.data = []

        with patch("services.posting_engine.FinancialPostingEngine.post_event", return_value=("tx-1", {})):
            with patch("services.schedule_service.ScheduleService.reverse_repayment_schedule"):
                RepaymentService.reverse_repayment(
                    mock_uow,
                    original_repayment_id=target_rep_id,
                    reason="Test reversal",
                    reversed_by="Admin"
                )

        assert mock_uow.overdue_recoveries.delete_by_repayment_id.called
        mock_uow.overdue_recoveries.delete_by_repayment_id.assert_called_with(target_rep_id)
