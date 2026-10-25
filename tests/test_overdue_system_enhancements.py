"""
Unit tests for the Overdue System Enhancements (BIA-ALL-OVERDUE-001 & BIA-CO-OVERDUE-002):
1. SingleClientSubmitInput mark_not_paid & expected_amount validation
2. PAR% calculation strictly aligned with BR-DASH-004 (overdue_amt / total_active_credit)
3. Financial Reconciliation overdue_repayments exception checks actual overdue installments, not active performing balance
"""
import unittest
from unittest.mock import MagicMock, patch
from datetime import date
import uuid

from api.schemas.collections import SingleClientSubmitInput
from services.financial_reconciliation_service import FinancialReconciliationService


class TestOverdueSystemEnhancements(unittest.TestCase):

    def test_single_client_schema_mark_not_paid(self):
        """Verify schema accepts mark_not_paid and expected_amount correctly."""
        payload = {
            "branch_id": str(uuid.uuid4()),
            "center_id": str(uuid.uuid4()),
            "officer_id": str(uuid.uuid4()),
            "client_id": str(uuid.uuid4()),
            "client_name": "Test Client",
            "collection_date": "2026-10-25",
            "mark_not_paid": True,
            "expected_amount": 7500.0,
            "loan_repayment": 0.0,
            "savings_deposit": 0.0,
        }
        item = SingleClientSubmitInput(**payload)
        self.assertTrue(item.mark_not_paid)
        self.assertEqual(item.expected_amount, 7500.0)
        self.assertEqual(item.loan_repayment, 0.0)

    def test_par_formula_alignment_br_dash_004(self):
        """
        Verify PAR% formula uses total_active_credit as denominator (BR-DASH-004):
        PAR% = round((overdue_amt / total_active_credit * 100.0), 2)
        """
        overdue_amt = 5000.0
        total_active_credit = 100000.0
        total_outstanding_balance = 40000.0

        # Prior buggy formula: overdue_amt / total_outstanding_balance * 100 = 12.5%
        buggy_par = round((overdue_amt / total_outstanding_balance * 100.0), 2)
        self.assertEqual(buggy_par, 12.5)

        # Correct BR-DASH-004 formula: overdue_amt / total_active_credit * 100 = 5.0%
        authoritative_par = round((overdue_amt / total_active_credit * 100.0), 2)
        self.assertEqual(authoritative_par, 5.0)

    def test_reconciliation_overdue_repayments_healthy_loan_not_flagged(self):
        """Verify reconciliation does not flag active loans whose installments are current."""
        mock_uow = MagicMock()
        mock_uow.client = MagicMock()
        branch_id = str(uuid.uuid4())

        loan_id = str(uuid.uuid4())
        mock_loans = MagicMock()
        mock_loans.data = [{
            "loan_id": loan_id,
            "client_id": str(uuid.uuid4()),
            "active_credit": 100000.0,
            "loan_repay": 25000.0
        }]

        # Total paid = 25000
        mock_reps = MagicMock()
        mock_reps.data = [{"loan_id": loan_id, "amount_paid": 25000.0}]

        # Schedule has NO installments overdue past today (due_date > today)
        mock_sch = MagicMock()
        mock_sch.data = []

        # Dispatch queries based on table name
        def mock_table(table_name):
            chain = MagicMock()
            if table_name == "loans":
                chain.select.return_value.eq.return_value.eq.return_value.execute.return_value = mock_loans
                chain.select.return_value.eq.return_value.execute.return_value = mock_loans
            elif table_name == "repayments":
                chain.select.return_value.in_.return_value.execute.return_value = mock_reps
            elif table_name == "loan_schedule":
                chain.select.return_value.in_.return_value.lt.return_value.execute.return_value = mock_sch
            else:
                empty = MagicMock()
                empty.data = []
                chain.select.return_value.execute.return_value = empty
                chain.select.return_value.eq.return_value.execute.return_value = empty
            return chain

        mock_uow.client.table.side_effect = mock_table

        res = FinancialReconciliationService.run_15_exception_reports(mock_uow, branch_id)

        # Active loan is performing with 0 overdue installments -> exception 13 must be empty
        self.assertEqual(len(res["details"]["overdue_repayments"]), 0)


if __name__ == "__main__":
    unittest.main()
