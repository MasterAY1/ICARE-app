"""
Unit tests verifying that when a client is marked NOT PAID:
1. The repayment record is still saved in 'repayments' with expected_amount > 0, amount_paid = 0.0, payment_status = 'NOT_PAID'.
2. The collection performance record is recorded in 'collection_performance' with status = 'NOT_PAID'.
3. Account 1000 physical vault cash is preserved (NO RepaymentReceived event emitted, NO Account 1000 debit).
4. Loan schedule is not advanced when amount_paid is 0.0.
5. Batch collection engine accurately reports 'Recorded (NOT PAID)'.
"""
import unittest
from unittest.mock import MagicMock, patch
from datetime import date
import uuid


class TestNotPaidCollectionFlow(unittest.TestCase):

    def setUp(self):
        self.mock_client = MagicMock()
        self.mock_uow = MagicMock()
        self.mock_uow.client = self.mock_client
        self.client_uuid = str(uuid.uuid4())
        self.loan_uuid = str(uuid.uuid4())
        self.officer_uuid = str(uuid.uuid4())
        self.branch_uuid = str(uuid.uuid4())

    @patch("services.schedule_service.ScheduleService.record_repayment")
    @patch("services.collection_performance_service.CollectionPerformanceService.record_meeting_collection")
    @patch("services.repayment_service.RepaymentService.post_repayment")
    def test_save_repayment_records_not_paid_loan(self, mock_post_rep, mock_record_cp, mock_sched_rep):
        from app import save_repayment

        # Mock loan fetch
        mock_loan_res = MagicMock()
        mock_loan_res.data = [{"loan_id": self.loan_uuid, "active_credit": 50000.0}]
        self.mock_client.table.return_value.select.return_value.eq.return_value.eq.return_value.execute.return_value = mock_loan_res

        data = {
            "tx_id": str(uuid.uuid4()),
            "Date": "2026-09-04",
            "Client ID": self.client_uuid,
            "Client Name": "Test Client",
            "Officer": "test_officer",
            "Branch": "Ogijo",
            "Amount Paid": 0.0,
            "Loan Repayment Amount": 0.0,
            "Savings Amount": 0.0,
            "Withdrawal Amount": 0.0,
            "Payment Status": "NOT_PAID",
            "Expected Amount": 2500.0,
            "Overdue Amount": 2500.0,
            "mark_not_paid": True,
            "Transaction Type": "Loan"
        }

        save_repayment(data, override_uow=self.mock_uow)

        # 1. Verify ScheduleService.record_repayment was NOT called for 0 repayment
        mock_sched_rep.assert_not_called()

        # 2. Verify RepaymentService.post_repayment WAS called with NOT_PAID domain entity
        mock_post_rep.assert_called_once()
        rep_arg = mock_post_rep.call_args[0][1]
        self.assertEqual(rep_arg.amount_paid, 0.0)
        self.assertEqual(rep_arg.loan_repayment_amount, 0.0)
        self.assertEqual(rep_arg.payment_status, "NOT_PAID")
        self.assertEqual(rep_arg.expected_amount, 2500.0)
        self.assertEqual(rep_arg.overdue_amount, 2500.0)

        # 3. Verify CollectionPerformanceService.record_meeting_collection WAS called with NOT_PAID
        mock_record_cp.assert_called_once()
        cp_kwargs = mock_record_cp.call_args[1]
        self.assertEqual(cp_kwargs["amount_paid"], 0.0)
        self.assertEqual(cp_kwargs["expected_amount"], 2500.0)
        self.assertEqual(cp_kwargs["client_id"], self.client_uuid)

    @patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Day open"))
    def test_repayment_service_no_account_1000_event_when_zero_paid(self, mock_biz_date):
        """FP-004 & BR-ACCT-002: Ensure RepaymentReceived is NOT emitted when loan_repayment_amount is 0.0"""
        from domain.entities.repayment import Repayment
        from services.repayment_service import RepaymentService

        mock_uow = MagicMock()
        mock_uow.client = MagicMock()
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
        mock_uow.repayments._prepare_db_data.return_value = {
            "id": str(uuid.uuid4()),
            "client_id": self.client_uuid,
            "loan_id": self.loan_uuid,
            "amount_paid": 0.0,
            "payment_status": "NOT_PAID",
            "expected_amount": 2500.0,
            "overdue_amount": 2500.0,
            "date": "2026-09-04"
        }

        rep = Repayment(
            id=str(uuid.uuid4()),
            loan_id=self.loan_uuid,
            client_id=self.client_uuid,
            amount_paid=0.0,
            savings_amount=0.0,
            loan_repayment_amount=0.0,
            withdrawal_amount=0.0,
            others_amount=0.0,
            recovery_amount=0.0,
            initial_payment=0.0,
            payment_date=date(2026, 9, 4),
            transaction_type="Loan",
            branch="Ogijo",
            credit_officer="test_officer",
            payment_status="NOT_PAID",
            expected_amount=2500.0,
            overdue_amount=2500.0
        )

        with patch("services.client_status_service.ClientStatusService.on_loan_repayment_check"):
            RepaymentService.post_repayment(mock_uow, rep)

        # Check the operations sent to atomic_execute_operations RPC
        rpc_call = mock_uow.client.rpc.call_args
        self.assertEqual(rpc_call[0][0], "atomic_execute_operations")
        ops = rpc_call[0][1]["p_operations"]

        # Operations must contain repayments insert and audit log, but NO event_store insert for RepaymentReceived
        tables_in_ops = [op["table"] for op in ops]
        self.assertIn("repayments", tables_in_ops)
        self.assertIn("audit_logs", tables_in_ops)
        self.assertNotIn("event_store", tables_in_ops)

    @patch("app.save_repayment")
    def test_save_repayments_batch_retains_not_paid_records(self, mock_save_rep):
        from app import save_repayments

        mock_uow = MagicMock()
        mock_uow.client = MagicMock()
        # Mock empty existing check
        mock_uow.client.table.return_value.select.return_value.in_.return_value.execute.return_value.data = []

        batch = [
            {
                "tx_id": str(uuid.uuid4()),
                "Client ID": self.client_uuid,
                "Client Name": "Defaulter Client",
                "Amount Paid": 0.0,
                "Loan Repayment Amount": 0.0,
                "Savings Amount": 0.0,
                "Payment Status": "NOT_PAID",
                "Expected Amount": 2500.0,
                "Overdue Amount": 2500.0,
                "mark_not_paid": True,
                "Transaction Type": "Loan"
            }
        ]

        with patch("database.repositories.unit_of_work.SupabaseUnitOfWork", return_value=mock_uow):
            receipt = save_repayments(batch)

        self.assertEqual(receipt["new_processed"], 1)
        self.assertEqual(receipt["total_repayment"], 0.0)
        self.assertEqual(receipt["total_cash"], 0.0)
        self.assertIn("Recorded (NOT PAID)", receipt["items"][0]["status"])
        mock_save_rep.assert_called_once()


if __name__ == "__main__":
    unittest.main()
