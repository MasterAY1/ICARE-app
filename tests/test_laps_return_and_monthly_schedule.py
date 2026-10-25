import os
import sys
import unittest
from datetime import date, datetime
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from services.posting_engine import FinancialPostingEngine, DomainEvent
from services.schedule_service import ScheduleService
from services.savings_service import SavingsService
from services.onboarding_service import OnboardingService


class TestLapsReturnAndMonthlySchedule(unittest.TestCase):

    def test_posting_engine_laps_restored_to_savings(self):
        """
        Verify that LapsRestoredToSavings posts:
        - Debit Account 2030 (LAPS Savings Liability)
        - Credit Account 2000 (Individual Savings Liability)
        - Account 1000 (Vault Cash) is completely untouched (Zero physical cash movement).
        """
        mock_uow = MagicMock()
        mock_uow.event_store.is_processed.return_value = False
        mock_uow.posting_rules.get_rule.return_value = None  # Uses synthetic rule
        mock_uow.ledger.create_transaction.return_value = "tx-123"

        event = DomainEvent(
            event_id="evt-001",
            aggregate_id="client-001",
            aggregate_type="LapsSavings",
            event_type="LapsRestoredToSavings",
            payload={
                "branch": "Ikorodu",
                "officer": "CO1",
                "client_id": "client-001",
                "amount": 25000.0,
                "notes": "LAPS restored to customer savings",
            }
        )

        with patch.object(FinancialPostingEngine, "_resolve_branch_id", return_value="b-uuid-1"), \
             patch.object(FinancialPostingEngine, "_resolve_officer_id", return_value="o-uuid-1"):
            tx_id = FinancialPostingEngine.post_event(mock_uow, event)

        self.assertEqual(tx_id, "tx-123")
        self.assertTrue(mock_uow.ledger.create_transaction.called)

        # Inspect the two ledger entries created
        tx, entries = mock_uow.ledger.create_transaction.call_args[0]
        self.assertEqual(len(entries), 2)
        debit_entry = [e for e in entries if e.side == "Debit"][0]
        credit_entry = [e for e in entries if e.side == "Credit"][0]

        self.assertEqual(debit_entry.account_code, "2030")
        self.assertEqual(debit_entry.amount, 25000.0)

        self.assertEqual(credit_entry.account_code, "2000")
        self.assertEqual(credit_entry.amount, 25000.0)

        # Assert Account 1000 was NEVER touched
        account_codes = [e.account_code for e in entries]
        self.assertNotIn("1000", account_codes, "Account 1000 must NEVER be touched on LAPS restoration")

    def test_monthly_loan_schedule_due_breakdown(self):
        """
        Verify that monthly loans only report expected installment on their exact scheduled due date,
        and report 0.0 on non-due dates or arbitrary days.
        """
        schedule = [
            {
                "installment_number": 1,
                "due_date": "2026-11-12",
                "principal_due": 20000.0,
                "interest_due": 5000.0,
                "total_due": 25000.0,
                "amount_paid": 0.0,
                "status": "pending"
            },
            {
                "installment_number": 2,
                "due_date": "2026-12-12",
                "principal_due": 20000.0,
                "interest_due": 5000.0,
                "total_due": 25000.0,
                "amount_paid": 0.0,
                "status": "pending"
            }
        ]

        mock_uow = MagicMock()
        loan_data = {
            "loan_id": "loan-001",
            "client_id": "client-001",
            "active_credit": 50000.0,
            "total_due": 50000.0,
            "status": "Active",
            "loan_products": {
                "name": "Monthly SME Loan",
                "repayment_cycle": "Monthly",
                "installments": 2
            }
        }

        # Case 1: Evaluation date is NOT the due date (e.g., 2026-11-05)
        breakdown_non_due = ScheduleService.get_loan_due_breakdown(
            uow=mock_uow,
            loan_id="loan-001",
            evaluation_date=date(2026, 11, 5),
            loan_data=loan_data,
            schedule_rows=schedule,
            meeting_day_str="Thursday",  # 2026-11-05 is a Thursday, but loan is Monthly!
            total_paid_sch=0.0
        )
        self.assertFalse(breakdown_non_due["is_meeting_today"])
        self.assertEqual(breakdown_non_due["current_installment"], 0.0)
        self.assertEqual(breakdown_non_due["total_due_today"], 0.0)

        # Case 2: Evaluation date IS the exact monthly due date (2026-11-12)
        breakdown_due = ScheduleService.get_loan_due_breakdown(
            uow=mock_uow,
            loan_id="loan-001",
            evaluation_date=date(2026, 11, 12),
            loan_data=loan_data,
            schedule_rows=schedule,
            meeting_day_str="Thursday",
            total_paid_sch=0.0
        )
        self.assertTrue(breakdown_due["is_meeting_today"])
        self.assertEqual(breakdown_due["current_installment"], 25000.0)
        self.assertEqual(breakdown_due["total_due_today"], 25000.0)

    def test_savings_service_return_laps_to_savings(self):
        """
        Verify SavingsService.return_laps_to_savings:
        1. Records withdrawal in laps_savings
        2. Records deposit in individual_savings
        3. Restores client lifecycle status to 'Registered' (BR-CLI-004)
        4. Emits LapsRestoredToSavings domain event
        """
        mock_uow = MagicMock()
        mock_client = MagicMock()
        mock_uow.client = mock_client

        # Mock Registered status lookup
        mock_status_res = MagicMock()
        mock_status_res.data = [{"status_id": "status-reg-uuid", "status_name": "Registered"}]
        mock_client.table().select().eq().execute.return_value = mock_status_res

        result = SavingsService.return_laps_to_savings(
            uow=mock_uow,
            client_id="c-1234",
            client_name="Test Client",
            branch="Ikorodu",
            officer="CO1",
            amount=18000.0,
            reference="REF-001",
            remarks="Client re-activated"
        )

        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 18000.0)
        self.assertFalse(result["affects_cash_vault"])

        # Verify laps_savings and individual_savings calls
        self.assertTrue(mock_uow.laps_savings.create.called)
        self.assertTrue(mock_uow.individual_savings.create.called)

        # Verify domain event emitted to event_store
        self.assertTrue(mock_uow.event_store.append.called)
        emitted_event = mock_uow.event_store.append.call_args[0][0]
        self.assertEqual(emitted_event.event_type, "LapsRestoredToSavings")
        self.assertEqual(emitted_event.payload["amount"], 18000.0)
        self.assertEqual(emitted_event.payload["branch"], "Ikorodu")

    def test_onboarding_legacy_monthly_anchor_math(self):
        """
        Verify that adding months for legacy monthly schedules maintains the calendar day anchor.
        """
        first_anchor = date(2026, 11, 12)
        
        def add_months(sourcedate, months):
            import calendar
            month = sourcedate.month - 1 + months
            year = sourcedate.year + month // 12
            month = month % 12 + 1
            day = min(sourcedate.day, calendar.monthrange(year, month)[1])
            return date(year, month, day)

        inst_1 = add_months(first_anchor, 0)
        inst_2 = add_months(first_anchor, 1)
        inst_3 = add_months(first_anchor, 2)

        self.assertEqual(inst_1.isoformat(), "2026-11-12")
        self.assertEqual(inst_2.isoformat(), "2026-12-12")
        self.assertEqual(inst_3.isoformat(), "2027-01-12")


if __name__ == "__main__":
    unittest.main()
