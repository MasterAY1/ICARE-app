import os
import sys
import unittest
from datetime import date

# Ensure root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from app import save_repayment

class TestGroupSavingsRepayment(unittest.TestCase):
    def test_group_savings_repayment_and_posting(self):
        group_code = "GROUP-Owoyemi"
        payload = {
            'Date': date.today().isoformat(),
            'Client ID': group_code,
            'Client Name': 'Owoyemi Meeting',
            'Officer': 'AM_Area_1',
            'Branch': 'Ogijo',
            'Amount Paid': 5000.0,
            'Savings Amount': 5000.0,
            'Withdrawal Amount': 0.0,
            'Loan Repayment Amount': 0.0,
            'Transaction Type': 'Group Meeting',
            'Group Savings Deposit': 5000.0,
            'Group Savings Withdrawal': 0.0
        }

        # Process collection
        save_repayment(payload)

        with SupabaseUnitOfWork() as uow:
            # 1. Operational group_savings row
            res_gs = uow.client.table("group_savings").select("*").eq("deposit_amount", 5000.0).order("created_at", desc=True).limit(1).execute()
            self.assertTrue(len(res_gs.data) >= 1, "Expected group_savings record to be created")
            gs_id = res_gs.data[0]["id"]

            # 2. Event Store record
            res_evt = uow.client.table("event_store").select("*").eq("event_type", "SavingsDeposited").order("created_at", desc=True).limit(10).execute()
            matched_evts = [e for e in res_evt.data if gs_id in str(e.get("payload", ""))]
            self.assertTrue(len(matched_evts) >= 1, "Expected event_store record for group savings")
            evt_id = matched_evts[0]["event_id"]

            # 3. Financial transaction & ledger double entry
            res_tx = uow.client.table("financial_transactions").select("*").eq("event_id", evt_id).execute()
            self.assertTrue(len(res_tx.data) >= 1, "Expected financial_transaction record for event")
            tx_id = res_tx.data[0]["transaction_id"]

            res_led = uow.client.table("financial_ledger_entries").select("*").eq("transaction_id", tx_id).execute()
            self.assertEqual(len(res_led.data), 2, "Expected exactly 2 ledger entries (Debit and Credit)")

            # 4. Repayment row check
            res_rep = uow.client.table("repayments").select("*").eq("transaction_type", group_code).order("created_at", desc=True).limit(1).execute()
            self.assertEqual(len(res_rep.data), 0, "Group savings should not create a dummy repayment row")

if __name__ == '__main__':
    unittest.main()
