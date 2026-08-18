import sys
import os

# Add root directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork

def clear_transactional_data():
    print("========================================")
    print("🧹 CLEARING TRANSACTIONAL DATA FOR TESTING")
    print("Preserving: Users, Branches, Groups, Products, Client Records")
    print("Clearing: CO/Master Cashbooks, Loans, Savings, Repayments, Schedules, Ledger, Events, Audit Logs")
    print("========================================")

    try:
        with SupabaseUnitOfWork() as uow:
            dummy_uuid = "00000000-0000-0000-0000-000000000000"
            
            print("[1] Deleting Financial Ledger Entries & Transactions...")
            uow.client.table("financial_ledger_entries").delete().neq("entry_id", dummy_uuid).execute()
            uow.client.table("financial_transactions").delete().neq("transaction_id", dummy_uuid).execute()
            
            print("[2] Deleting Event Store & Event Processing...")
            try:
                uow.client.table("event_processing").delete().neq("id", dummy_uuid).execute()
            except Exception:
                pass
            uow.client.table("event_store").delete().neq("event_id", dummy_uuid).execute()
            
            print("[3] Deleting CO Cashbooks & Master Cashbook Projections...")
            uow.client.table("co_cashbooks").delete().neq("id", dummy_uuid).execute()
            uow.client.table("master_cashbook").delete().neq("id", dummy_uuid).execute()
            
            print("[4] Deleting Treasury Transactions...")
            uow.client.table("treasury_transactions").delete().neq("id", dummy_uuid).execute()

            print("[5] Deleting Correction & Withdrawal Requests...")
            try:
                uow.client.table("correction_requests").delete().neq("id", dummy_uuid).execute()
            except Exception:
                pass
            try:
                uow.client.table("withdrawal_requests").delete().neq("id", dummy_uuid).execute()
            except Exception:
                pass

            print("[6] Deleting Repayments & Collections...")
            uow.client.table("repayments").delete().neq("id", dummy_uuid).execute()

            print("[7] Deleting Loan Schedules & Loans...")
            try:
                uow.client.table("loan_schedule").delete().neq("id", dummy_uuid).execute()
            except Exception:
                pass
            uow.client.table("loans").delete().neq("loan_id", dummy_uuid).execute()

            print("[8] Deleting Savings (Individual, Group, LAPS, Internal)...")
            uow.client.table("individual_savings").delete().neq("id", dummy_uuid).execute()
            uow.client.table("group_savings").delete().neq("id", dummy_uuid).execute()
            uow.client.table("laps_savings").delete().neq("id", dummy_uuid).execute()
            uow.client.table("internal_savings").delete().neq("id", dummy_uuid).execute()

            print("[9] Deleting Fees...")
            uow.client.table("fees").delete().neq("id", dummy_uuid).execute()

            print("[10] Resetting Client Lifecycle Statuses to 'Registered'...")
            reg_id = "11111111-1111-1111-1111-111111110001"
            uow.client.table("clients").update({"status": reg_id}).neq("client_id", dummy_uuid).execute()

            print("\n🎉 Database successfully reset for fresh testing!")
            print("All transactional history cleared. System ready for Day 1 testing.")

    except Exception as e:
        print(f"\n❌ Error during database reset: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    clear_transactional_data()
