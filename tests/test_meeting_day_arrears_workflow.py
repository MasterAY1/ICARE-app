"""
Unit tests for Meeting-Day Frequency Rules, Arrears Accumulation,
Zero-UI Repayment Classification, and Field Collection Reconciliation Tally.
All database calls are mocked to ensure ZERO live database contamination.
"""
import unittest
from unittest.mock import MagicMock, patch
from datetime import date, datetime
import uuid

from services.schedule_service import ScheduleService
from services.repayment_service import RepaymentService
from services.financial_reconciliation_service import FinancialReconciliationService


class TestMeetingDayArrearsWorkflow(unittest.TestCase):

    def setUp(self):
        self.mock_client = MagicMock()
        self.mock_uow = MagicMock()
        self.mock_uow.client = self.mock_client
        self.loan_id = str(uuid.uuid4())
        self.client_id = str(uuid.uuid4())
        self.branch_id = str(uuid.uuid4())
        self.officer_id = str(uuid.uuid4())

    def test_meeting_day_gating_weekly_loan(self):
        """
        Weekly Loan frequency gating:
        - Evaluated on Monday (2026-09-07): is_meeting_today should be False, total_due_today = 0.0.
        - Evaluated on Friday (2026-09-11): is_meeting_today should be True, total_due_today = 2500.0.
        """
        # Friday group setup
        loan_record = {
            "loan_id": self.loan_id,
            "client_id": self.client_id,
            "active_credit": 30000.0,
            "duration": 12,
            "status": "Active",
            "amount": 30000.0,
            "extra_fields": {},
            "loan_products": {"name": "Weekly 12 Weeks", "repayment_cycle": "Weekly", "installments": 12}
        }
        group_record = [{"groups": {"meeting_day": "Friday"}}]

        # 1. Test Monday Evaluation (2026-09-07 is a Monday)
        eval_monday = date(2026, 9, 7)
        self.assertEqual(eval_monday.strftime("%A"), "Monday")

        # Mock Supabase responses
        mock_l = MagicMock()
        mock_l.data = [loan_record]
        mock_g = MagicMock()
        mock_g.data = group_record
        mock_s = MagicMock()
        mock_s.data = [
            {"installment_number": 1, "due_date": "2026-09-11", "total_due": 2500.0, "paid_amount": 0.0}
        ]

        def mock_table(table_name):
            chain = MagicMock()
            if table_name == "loans":
                chain.select.return_value.eq.return_value.execute.return_value = mock_l
            elif table_name == "client_memberships":
                chain.select.return_value.eq.return_value.execute.return_value = mock_g
            elif table_name == "loan_schedule":
                chain.select.return_value.eq.return_value.order.return_value.execute.return_value = mock_s
            return chain

        self.mock_client.table.side_effect = mock_table

        with patch("services.schedule_service.ScheduleService.get_total_paid", return_value=(0.0, True)):
            res_monday = ScheduleService.get_loan_due_breakdown(
                self.mock_uow, self.loan_id, evaluation_date=eval_monday, client_id=self.client_id
            )

        self.assertFalse(res_monday["is_meeting_today"])
        self.assertEqual(res_monday["total_due_today"], 0.0)
        self.assertEqual(res_monday["meeting_day"], "Friday")

        # 2. Test Friday Evaluation (2026-09-11 is a Friday)
        eval_friday = date(2026, 9, 11)
        self.assertEqual(eval_friday.strftime("%A"), "Friday")

        with patch("services.schedule_service.ScheduleService.get_total_paid", return_value=(0.0, True)):
            res_friday = ScheduleService.get_loan_due_breakdown(
                self.mock_uow, self.loan_id, evaluation_date=eval_friday, client_id=self.client_id
            )

        self.assertTrue(res_friday["is_meeting_today"])
        self.assertEqual(res_friday["current_installment"], 2500.0)
        self.assertEqual(res_friday["overdue_arrears"], 0.0)
        self.assertEqual(res_friday["total_due_today"], 2500.0)
        self.assertFalse(res_friday["has_overdue"])

    def test_arrears_accumulation_on_next_meeting_day(self):
        """
        Weekly client who missed Friday 1 (2026-09-04):
        On Friday 2 (2026-09-11), total_due_today MUST be:
        2500.0 (overdue arrears from week 1) + 2500.0 (current installment for week 2) = 5000.0.
        """
        loan_record = {
            "loan_id": self.loan_id,
            "client_id": self.client_id,
            "active_credit": 30000.0,
            "duration": 12,
            "status": "Active",
            "amount": 30000.0,
            "extra_fields": {},
            "loan_products": {"name": "Weekly 12 Weeks", "repayment_cycle": "Weekly", "installments": 12}
        }
        group_record = [{"groups": {"meeting_day": "Friday"}}]

        # Two installments: Week 1 overdue, Week 2 due today
        schedule_rows = [
            {"installment_number": 1, "due_date": "2026-09-04", "total_due": 2500.0, "paid_amount": 0.0},
            {"installment_number": 2, "due_date": "2026-09-11", "total_due": 2500.0, "paid_amount": 0.0},
            {"installment_number": 3, "due_date": "2026-09-18", "total_due": 2500.0, "paid_amount": 0.0}
        ]

        mock_l = MagicMock()
        mock_l.data = [loan_record]
        mock_g = MagicMock()
        mock_g.data = group_record
        mock_s = MagicMock()
        mock_s.data = schedule_rows

        def mock_table(table_name):
            chain = MagicMock()
            if table_name == "loans":
                chain.select.return_value.eq.return_value.execute.return_value = mock_l
            elif table_name == "client_memberships":
                chain.select.return_value.eq.return_value.execute.return_value = mock_g
            elif table_name == "loan_schedule":
                chain.select.return_value.eq.return_value.order.return_value.execute.return_value = mock_s
            return chain

        self.mock_client.table.side_effect = mock_table

        eval_friday_2 = date(2026, 9, 11)
        with patch("services.schedule_service.ScheduleService.get_total_paid", return_value=(0.0, True)):
            breakdown = ScheduleService.get_loan_due_breakdown(
                self.mock_uow, self.loan_id, evaluation_date=eval_friday_2, client_id=self.client_id
            )

        self.assertTrue(breakdown["is_meeting_today"])
        self.assertTrue(breakdown["has_overdue"])
        self.assertEqual(breakdown["overdue_arrears"], 2500.0)
        self.assertEqual(breakdown["current_installment"], 2500.0)
        self.assertEqual(breakdown["total_due_today"], 5000.0)
        self.assertEqual(breakdown["missed_installments_count"], 1)

    def test_zero_ui_repayment_classification(self):
        """
        Zero-UI RepaymentService.classify_repayment invariants (BR-DASH-007):
        - Paying cumulative debt of 5000 when 5000 is due (2500 arrears + 2500 current):
          MUST be 'PAID (ARREARS CLEARED)', NOT 'EXCESS'!
        - Paying 6000 when 5000 is due:
          MUST be 'EXCESS' with true_excess = 1000.0.
        - Paying 2500 when 5000 is due:
          MUST be 'PART_PAID' with overdue_shortfall = 2500.0.
        - Paying 0 when 5000 is due:
          MUST be 'NOT_PAID' with overdue_shortfall = 5000.0.
        """
        # Case 1: Paying exactly cumulative debt (Arrears cleared)
        c1 = RepaymentService.classify_repayment(
            amount_paid=5000.0,
            total_due_today=5000.0,
            current_installment=2500.0,
            has_overdue=True
        )
        self.assertEqual(c1["status"], "PAID")
        self.assertIn("ARREARS CLEARED", c1["status_badge"])
        self.assertEqual(c1["true_excess"], 0.0)
        self.assertEqual(c1["overdue_shortfall"], 0.0)
        self.assertTrue(c1["is_arrears_cleared"])
        self.assertEqual(c1["arrears_recovered"], 2500.0)

        # Case 2: Paying surplus above cumulative debt
        c2 = RepaymentService.classify_repayment(
            amount_paid=6000.0,
            total_due_today=5000.0,
            current_installment=2500.0,
            has_overdue=True
        )
        self.assertEqual(c2["status"], "EXCESS")
        self.assertEqual(c2["true_excess"], 1000.0)
        self.assertEqual(c2["overdue_shortfall"], 0.0)

        # Case 3: Partial payment of cumulative debt
        c3 = RepaymentService.classify_repayment(
            amount_paid=2500.0,
            total_due_today=5000.0,
            current_installment=2500.0,
            has_overdue=True
        )
        self.assertEqual(c3["status"], "PART_PAID")
        self.assertEqual(c3["overdue_shortfall"], 2500.0)
        self.assertEqual(c3["true_excess"], 0.0)
        self.assertFalse(c3["is_arrears_cleared"])

        # Case 4: Marked NOT PAID (0 payment)
        c4 = RepaymentService.classify_repayment(
            amount_paid=0.0,
            total_due_today=5000.0,
            current_installment=2500.0,
            has_overdue=True
        )
        self.assertEqual(c4["status"], "NOT_PAID")
        self.assertEqual(c4["overdue_shortfall"], 5000.0)
        self.assertEqual(c4["true_excess"], 0.0)

    def test_daily_collection_arrears_reconciliation_tally(self):
        """
        FinancialReconciliationService.get_daily_collection_arrears_tally:
        Verifies correct paper reconciliation bridge:
        - Scheduled expected: 10,000
        - Red-pen not paid: 2,500
        - Excess banked: 1,000
        - Actual cash collected: 8,500 repayments + 2,000 savings = 10,500
        - Bank deposit: 10,500
        - Closing balance: 0.0 (Balanced)
        """
        posting_date = date(2026, 9, 11)

        # Mock repayments data
        reps_data = [
            # Client A: Paid full due (5,000)
            {
                "id": str(uuid.uuid4()), "client_id": "c1", "amount_paid": 5000.0, "expected_amount": 5000.0,
                "overdue_amount": 0.0, "payment_status": "PAID", "note": "On schedule",
                "clients": {"name": "Client A", "client_code": "CLI-001"}
            },
            # Client B: Marked NOT PAID (0 collected, 2,500 expected)
            {
                "id": str(uuid.uuid4()), "client_id": "c2", "amount_paid": 0.0, "expected_amount": 2500.0,
                "overdue_amount": 2500.0, "payment_status": "NOT_PAID", "note": "Marked NOT PAID",
                "clients": {"name": "Client B", "client_code": "CLI-002"}
            },
            # Client C: Paid excess (3,500 collected, 2,500 expected -> 1,000 excess)
            {
                "id": str(uuid.uuid4()), "client_id": "c3", "amount_paid": 3500.0, "expected_amount": 2500.0,
                "overdue_amount": 0.0, "payment_status": "EXCESS", "note": "Extra paid",
                "clients": {"name": "Client C", "client_code": "CLI-003"}
            }
        ]

        # Mock savings data
        sav_data = [
            {"deposit_amount": 2000.0}
        ]

        # Mock cashbook
        cb_data = [
            {"bank_deposit": 10500.0, "closing_balance": 0.0}
        ]

        def mock_table(table_name):
            chain = MagicMock()
            if table_name == "repayments":
                chain.select.return_value.eq.return_value.gte.return_value.lte.return_value.execute.return_value = MagicMock(data=reps_data)
                chain.select.return_value.eq.return_value.gte.return_value.lte.return_value.eq.return_value.execute.return_value = MagicMock(data=reps_data)
            elif table_name == "individual_savings":
                chain.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=sav_data)
                chain.select.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=sav_data)
            elif table_name in ["co_cashbooks", "master_cashbook"]:
                chain.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=cb_data)
                chain.select.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=cb_data)
            return chain

        self.mock_client.table.side_effect = mock_table

        tally = FinancialReconciliationService.get_daily_collection_arrears_tally(
            uow=self.mock_uow,
            branch_id=self.branch_id,
            posting_date=posting_date
        )

        self.assertEqual(tally["scheduled_expected"], 10000.0)
        self.assertEqual(tally["not_paid_amount"], 2500.0)
        self.assertEqual(tally["not_paid_count"], 1)
        self.assertEqual(tally["excess_amount"], 1000.0)
        self.assertEqual(tally["excess_count"], 1)
        self.assertEqual(tally["actual_repayments"], 8500.0)
        self.assertEqual(tally["actual_savings"], 2000.0)
        self.assertEqual(tally["actual_cash_collected"], 10500.0)
        self.assertEqual(tally["bank_deposited"], 10500.0)
        self.assertEqual(tally["closing_cash_balance"], 0.0)
        self.assertTrue(tally["is_cash_balanced"])
        self.assertEqual(len(tally["not_paid_clients"]), 1)
        self.assertEqual(tally["not_paid_clients"][0]["name"], "Client B")


if __name__ == "__main__":
    unittest.main()
