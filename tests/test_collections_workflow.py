import os
import sys
import unittest
from datetime import date

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from app import save_repayment, load_client_savings_map

class TestCollectionsWorkflow(unittest.TestCase):
    def test_full_collections_and_readback_workflow(self):
        client_code = "OGI-28-001"
        today_str = date.today().isoformat()

        # Step 1: Deposit Savings (₦3,000)
        dep_payload = {
            'Date': today_str,
            'Client ID': client_code,
            'Client Name': 'Alimi Fatimoh',
            'Officer': 'Olamide',
            'Branch': 'Ogijo',
            'Amount Paid': 3000.0,
            'Savings Amount': 3000.0,
            'Withdrawal Amount': 0.0,
            'Loan Repayment Amount': 0.0,
            'Transaction Type': 'Collection'
        }
        save_repayment(dep_payload)

        # Step 2: Read-back balance via Portfolio savings map
        savings_map = load_client_savings_map()
        balance_after_dep = savings_map.get(client_code, 0.0)
        self.assertTrue(balance_after_dep >= 3000.0, "Portfolio savings map should reflect deposit")

        # Step 3: Withdraw Savings (₦1,000)
        wd_payload = {
            'Date': today_str,
            'Client ID': client_code,
            'Client Name': 'Alimi Fatimoh',
            'Officer': 'Olamide',
            'Branch': 'Ogijo',
            'Amount Paid': 0.0,
            'Savings Amount': 0.0,
            'Withdrawal Amount': 1000.0,
            'Loan Repayment Amount': 0.0,
            'Transaction Type': 'Collection'
        }
        save_repayment(wd_payload)

        # Step 4: Verify single-source readback across Portfolio and Client Profile query source
        savings_map_updated = load_client_savings_map()
        balance_after_wd = savings_map_updated.get(client_code, 0.0)
        self.assertEqual(balance_after_wd, balance_after_dep - 1000.0, "Net savings balance must equal deposit minus withdrawal")

        # Step 5: Verify directly from individual_savings single source of truth table
        with SupabaseUnitOfWork() as uow:
            res_client = uow.client.table("clients").select("client_id").eq("client_code", client_code).execute()
            self.assertTrue(len(res_client.data) >= 1)
            c_uuid = res_client.data[0]["client_id"]

            res_ind = uow.client.table("individual_savings").select("deposit_amount, withdrawal_amount").eq("client_id", c_uuid).execute()
            total_dep = sum(float(r["deposit_amount"] or 0) for r in res_ind.data)
            total_wd = sum(float(r["withdrawal_amount"] or 0) for r in res_ind.data)
            direct_db_net = total_dep - total_wd

            self.assertEqual(balance_after_wd, direct_db_net, "Portfolio balance and database individual_savings total MUST match exactly")

if __name__ == '__main__':
    unittest.main()
