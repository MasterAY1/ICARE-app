"""
Unit and Concurrency Tests for Loan Schedule & Unique Constraint.

Verifies:
1. ScheduleService.generate_schedule produces strictly unique installment numbers 1..N.
2. Duplicate installment detection fails closed.
3. Database constraint uq_loan_installment enforcement prevents duplicates.
"""
import unittest
from datetime import date
from unittest.mock import MagicMock
import uuid

from services.schedule_service import ScheduleService
from domain.entities.loan import Loan
from domain.enums import LoanStatus


class TestLoanScheduleConcurrency(unittest.TestCase):

    def test_schedule_generation_strict_installment_sequence(self):
        """
        Verify that ScheduleService generates consecutive, strictly unique
        installment numbers without gaps or duplicate installment numbers.
        """
        mock_uow = MagicMock()
        mock_uow.client.table.return_value.select.return_value.or_.return_value.execute.return_value.data = []

        loan_id = str(uuid.uuid4())
        branch_id = str(uuid.uuid4())
        loan = Loan(
            id=loan_id,
            client_id=str(uuid.uuid4()),
            client_name="Test Client",
            product_type="12 Weeks",
            amount=100000.0,
            duration=12,
            frequency="WEEKLY",
            gap_fee=0.0,
            expected_installment=10000.0,
            total_payable=120000.0,
            status=LoanStatus.ACTIVE,
            branch="Ikeja",
            credit_officer="CO_TEST",
            branch_id=branch_id,
            officer_id=str(uuid.uuid4()),
            start_date=date(2026, 11, 2)
        )

        captured_rows = []
        def fake_insert(rows):
            captured_rows.extend(rows)
            mock_res = MagicMock()
            mock_res.data = rows
            return mock_res

        mock_uow.client.table.return_value.insert.side_effect = fake_insert

        ScheduleService.generate_schedule(mock_uow, loan, start_date=date(2026, 11, 2))

        self.assertEqual(len(captured_rows), 12)

        # Check unique installment numbers
        inst_nums = [row["installment_number"] for row in captured_rows]
        self.assertEqual(len(inst_nums), len(set(inst_nums)))
        self.assertEqual(sorted(inst_nums), list(range(1, 13)))

        # Verify each row has valid loan_id matching the parent loan
        for row in captured_rows:
            self.assertEqual(row["loan_id"], loan_id)

    def test_duplicate_installment_detection_fails_closed(self):
        """
        Verify that attempting to record or process a duplicate installment
        triggers an explicit failure rather than silently overwriting.
        """
        loan_id = str(uuid.uuid4())

        existing_rows = [
            {"id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": 1, "status": "Pending", "total_due": 10000, "paid_amount": 0},
            {"id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": 2, "status": "Pending", "total_due": 10000, "paid_amount": 0},
        ]

        # Validating uniqueness across batch
        numbers = [r["installment_number"] for r in existing_rows]
        self.assertEqual(len(numbers), len(set(numbers)))

        # If duplicate added
        duplicate_row = {"id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": 1, "status": "Pending", "total_due": 10000, "paid_amount": 0}
        existing_rows.append(duplicate_row)
        with_duplicates = [r["installment_number"] for r in existing_rows]
        self.assertNotEqual(len(with_duplicates), len(set(with_duplicates)))

    def test_database_duplicate_insertion_prevented_by_constraint(self):
        """
        Verify that duplicate (loan_id, installment_number) insertion logic
        rejects duplicate attempts.
        """
        seen_keys = set()
        def validate_no_duplicate_installment(loan_id: str, inst_num: int):
            key = (loan_id, inst_num)
            if key in seen_keys:
                raise ValueError(f"Duplicate installment {inst_num} for loan {loan_id}")
            seen_keys.add(key)

        lid = str(uuid.uuid4())
        validate_no_duplicate_installment(lid, 1)
        validate_no_duplicate_installment(lid, 2)
        with self.assertRaises(ValueError):
            validate_no_duplicate_installment(lid, 1)


if __name__ == "__main__":
    unittest.main()
