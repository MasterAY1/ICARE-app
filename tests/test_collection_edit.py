import os
import sys
import unittest
from datetime import date

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from app import save_repayment
from mappers.base_mappers import RepaymentMapper
from domain.entities.repayment import Repayment

class TestCollectionEdit(unittest.TestCase):
    def test_repayment_edit_idempotency(self):
        client_code = "OGI-28-001"
        today_str = date.today().isoformat()
        
        # 1. Initial repayment insertion
        initial_payload = {
            'Date': today_str,
            'Client ID': client_code,
            'Client Name': 'Alimi Fatimoh',
            'Officer': 'Olamide',
            'Branch': 'Ogijo',
            'Amount Paid': 2000.0,
            'Savings Amount': 2000.0,
            'Withdrawal Amount': 0.0,
            'Loan Repayment Amount': 0.0,
            'Transaction Type': 'Collection'
        }
        
        save_repayment(initial_payload)

        with SupabaseUnitOfWork() as uow:
            res1 = uow.client.table("repayments").select("*").eq("amount_paid", 2000.0).order("created_at", desc=True).limit(1).execute()
            self.assertTrue(len(res1.data) >= 1, "Initial repayment must exist")
            rep_id = res1.data[0]["id"]
            count_before = len(uow.client.table("repayments").select("id").eq("date", today_str).execute().data)

            # 2. Perform Edit on existing repayment ID
            updated_payload = {
                'id': rep_id,
                'Date': today_str,
                'Client ID': client_code,
                'Client Name': 'Alimi Fatimoh',
                'Officer': 'Olamide',
                'Branch': 'Ogijo',
                'Amount Paid': 2500.0,
                'Savings Amount': 2500.0,
                'Withdrawal Amount': 0.0,
                'Loan Repayment Amount': 0.0,
                'Transaction Type': 'Collection'
            }

            # Update repayment in-place
            db_data = {
                'id': rep_id,
                'date': today_str,
                'client_id': res1.data[0]["client_id"],
                'amount_paid': 2500.0,
                'savings_amount': 2500.0,
                'loan_repayment_amount': 0.0,
                'withdrawal_amount': 0.0,
                'others_amount': 0.0,
                'recovery_amount': 0.0,
                'transaction_type': 'Collection',
                'branch': 'Ogijo',
                'officer': 'Olamide'
            }
            rep_obj = RepaymentMapper.to_domain(db_data)
            uow.repayments.update(rep_obj)

            # 3. Assertions
            res_after = uow.client.table("repayments").select("*").eq("id", rep_id).execute()
            self.assertEqual(len(res_after.data), 1, "Repayment must still exist as single record")
            self.assertEqual(float(res_after.data[0]["amount_paid"]), 2500.0, "Repayment amount must be updated to 2500.0")

            count_after = len(uow.client.table("repayments").select("id").eq("date", today_str).execute().data)
            self.assertEqual(count_after, count_before, "No extra repayment row should be added during edit")

if __name__ == '__main__':
    unittest.main()
