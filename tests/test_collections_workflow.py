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
        officer_am_id = "e6a77cdb-6012-4506-8240-7e46e81d954d"

        # Record initial balance and initial savings entry IDs before test operations
        savings_map_initial = load_client_savings_map()
        balance_before = savings_map_initial.get(client_code, 0.0)

        with SupabaseUnitOfWork() as uow:
            res_client = uow.client.table("clients").select("client_id").eq("client_code", client_code).execute()
            self.assertTrue(len(res_client.data) >= 1)
            c_uuid = res_client.data[0]["client_id"]
            init_res = uow.client.table("individual_savings").select("id").eq("client_id", c_uuid).execute()
            initial_entry_ids = set(r["id"] for r in init_res.data)

        try:
            # Step 1: Deposit Savings (₦3,000)
            dep_payload = {
                'Date': today_str,
                'Client ID': client_code,
                'Client Name': 'Alimi Fatimoh',
                'Officer': 'AM_Area_1',
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
            self.assertAlmostEqual(balance_after_dep - balance_before, 3000.0, msg="Portfolio savings map should reflect +3000 deposit")

            # Step 3: Withdraw Savings (₦1,000)
            wd_payload = {
                'Date': today_str,
                'Client ID': client_code,
                'Client Name': 'Alimi Fatimoh',
                'Officer': 'AM_Area_1',
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
            self.assertAlmostEqual(balance_after_wd - balance_after_dep, -1000.0, msg="Net savings balance change must equal -1000.0")

            # Step 5: Verify directly from individual_savings single source of truth table
            with SupabaseUnitOfWork() as uow:
                res_ind = uow.client.table("individual_savings").select("deposit_amount, withdrawal_amount").eq("client_id", c_uuid).execute()
                total_dep = sum(float(r["deposit_amount"] or 0) for r in res_ind.data)
                total_wd = sum(float(r["withdrawal_amount"] or 0) for r in res_ind.data)
                direct_db_net = total_dep - total_wd
                self.assertEqual(balance_after_wd, direct_db_net, "Portfolio balance and database individual_savings total MUST match exactly")
        finally:
            # Clean up all test artifacts created by this test run to prevent database contamination
            with SupabaseUnitOfWork() as uow:
                curr_res = uow.client.table("individual_savings").select("id").eq("client_id", c_uuid).execute()
                created_ids = [r["id"] for r in curr_res.data if r["id"] not in initial_entry_ids]
                if created_ids:
                    uow.client.table("financial_ledger_entries").delete().in_("aggregate_id", created_ids).execute()
                    uow.client.table("financial_transactions").delete().in_("reference", created_ids).execute()
                    uow.client.table("event_store").delete().in_("aggregate_id", created_ids).execute()
                    uow.client.table("individual_savings").delete().in_("id", created_ids).execute()
                # Remove any test cashbook projection generated for AM_Area_1
                uow.client.table("co_cashbooks").delete().eq("officer_id", officer_am_id).execute()

    def test_asset_loan_client_savings_deposit_collection(self):
        """Verify that a client on an asset loan can deposit savings during daily collection."""
        client_code = "OGI-08-007"
        today_str = date.today().isoformat()
        officer_am_id = "e6a77cdb-6012-4506-8240-7e46e81d954d"

        with SupabaseUnitOfWork() as uow:
            res_client = uow.client.table("clients").select("client_id, name").eq("client_code", client_code).execute()
            self.assertTrue(len(res_client.data) >= 1, f"Client {client_code} should exist in DB")
            c_uuid = res_client.data[0]["client_id"]
            c_name = res_client.data[0]["name"]
            
            init_res = uow.client.table("individual_savings").select("id, deposit_amount, withdrawal_amount").eq("client_id", c_uuid).execute()
            initial_entry_ids = set(r["id"] for r in init_res.data)
            init_sav = sum(float(r["deposit_amount"] or 0) - float(r["withdrawal_amount"] or 0) for r in init_res.data)

        try:
            # Submit collection with savings deposit (₦1,500) for asset client
            payload = {
                'Date': today_str,
                'Client ID': client_code,
                'Client Name': c_name,
                'Officer': 'AM_Area_1',
                'Branch': 'Ogijo',
                'Amount Paid': 0.0,
                'Savings Amount': 1500.0,
                'Withdrawal Amount': 0.0,
                'Loan Repayment Amount': 0.0,
                'Transaction Type': 'Collection'
            }
            save_repayment(payload)

            # Read back from database individual_savings
            with SupabaseUnitOfWork() as uow:
                post_res = uow.client.table("individual_savings").select("id, deposit_amount, withdrawal_amount").eq("client_id", c_uuid).execute()
                post_sav = sum(float(r["deposit_amount"] or 0) - float(r["withdrawal_amount"] or 0) for r in post_res.data)
                self.assertAlmostEqual(post_sav - init_sav, 1500.0, msg="Asset client savings must increase by exactly ₦1,500")

        finally:
            # Clean up test artifacts
            with SupabaseUnitOfWork() as uow:
                curr_res = uow.client.table("individual_savings").select("id").eq("client_id", c_uuid).execute()
                created_ids = [r["id"] for r in curr_res.data if r["id"] not in initial_entry_ids]
                if created_ids:
                    uow.client.table("financial_ledger_entries").delete().in_("aggregate_id", created_ids).execute()
                    uow.client.table("financial_transactions").delete().in_("reference", created_ids).execute()
                    uow.client.table("event_store").delete().in_("aggregate_id", created_ids).execute()
                    uow.client.table("individual_savings").delete().in_("id", created_ids).execute()
                uow.client.table("co_cashbooks").delete().eq("officer_id", officer_am_id).execute()

if __name__ == '__main__':
    unittest.main()
