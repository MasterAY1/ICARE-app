import os
import sys
import unittest
from datetime import date

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from app import save_repayment
from mappers.base_mappers import RepaymentMapper
from domain.entities.repayment import Repayment

@unittest.skipUnless(os.environ.get("RUN_LIVE_INTEGRATION_TESTS") == "1", "Requires RUN_LIVE_INTEGRATION_TESTS=1 to prevent live database mutation")
class TestCollectionEdit(unittest.TestCase):
    def test_repayment_edit_idempotency(self):
        client_code = "OGI-28-001"
        today_str = date.today().isoformat()
        
        # 1. Initial repayment insertion
        initial_payload = {
            'Date': today_str,
            'Client ID': client_code,
            'Client Name': 'Alimi Fatimoh',
            'Officer': 'CO1',
            'Branch': 'Ogijo',
            'Amount Paid': 2000.0,
            'Savings Amount': 0.0,
            'Withdrawal Amount': 0.0,
            'Loan Repayment Amount': 2000.0,
            'Transaction Type': 'Collection'
        }
        
        save_repayment(initial_payload)

        rep_id = None
        try:
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
                    'Officer': 'CO1',
                    'Branch': 'Ogijo',
                    'Amount Paid': 2500.0,
                    'Savings Amount': 0.0,
                    'Withdrawal Amount': 0.0,
                    'Loan Repayment Amount': 2500.0,
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
                    'officer': 'CO1'
                }
                rep_obj = RepaymentMapper.to_domain(db_data)
                uow.repayments.update(rep_obj)

                # 3. Assertions
                res_after = uow.client.table("repayments").select("*").eq("id", rep_id).execute()
                self.assertEqual(len(res_after.data), 1, "Repayment must still exist as single record")
                self.assertEqual(float(res_after.data[0]["amount_paid"]), 2500.0, "Repayment amount must be updated to 2500.0")

                count_after = len(uow.client.table("repayments").select("id").eq("date", today_str).execute().data)
                self.assertEqual(count_after, count_before, "No extra repayment row should be added during edit")
        finally:
            if rep_id:
                with SupabaseUnitOfWork() as uow:
                    # Clean up FT, FLE, CP, event_processing, event_store, and repayment
                    ft_res = uow.client.table("financial_transactions").select("transaction_id, event_id").eq("reference", rep_id).execute()
                    for f in (ft_res.data or []):
                        if f.get("event_id"):
                            uow.client.table("event_processing").delete().eq("event_id", f["event_id"]).execute()
                        uow.client.table("financial_ledger_entries").delete().eq("transaction_id", f["transaction_id"]).execute()
                        uow.client.table("financial_transactions").delete().eq("transaction_id", f["transaction_id"]).execute()
                        if f.get("event_id"):
                            uow.client.table("event_store").delete().eq("event_id", f["event_id"]).execute()
                    uow.client.table("collection_performance").delete().eq("id", rep_id).execute()
                    uow.client.table("repayments").delete().eq("id", rep_id).execute()

if __name__ == '__main__':
    unittest.main()
