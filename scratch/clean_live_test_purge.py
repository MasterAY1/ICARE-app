import os
import sys
from database.repositories.unit_of_work import SupabaseUnitOfWork

def purge_all_transactions():
    print("==========================================================")
    print("🧹 ICARE LIVE TEST DATABASE PURGE: TRANSACTIONS & AUDIT LOGS")
    print("Preserving: app_users, branches, groups, clients, memberships, loan_products, financial_accounts")
    print("==========================================================")

    dummy_uuid = "00000000-0000-0000-0000-000000000000"
    
    # List of tables to purge in dependency order (child tables first)
    tables_to_purge = [
        ("financial_ledger_entries", "entry_id"),
        ("financial_transactions", "transaction_id"),
        ("event_processing", "id"),
        ("event_store", "event_id"),
        ("audit_logs", "id"),
        ("correction_requests", "id"),
        ("withdrawal_requests", "id"),
        ("savings_withdrawals", "id"),
        ("laps_migrations", "id"),
        ("co_cashbooks", "id"),
        ("master_cashbooks", "id"),
        ("treasury_transactions", "id"),
        ("expenses", "id"),
        ("branch_closures", "id"),
        ("repayments", "id"),
        ("loan_schedule", "id"),
        ("loans", "loan_id"),
        ("individual_savings", "id"),
        ("group_savings", "id"),
        ("laps_savings", "id"),
        ("internal_savings", "id"),
        ("fees", "id"),
        ("collection_performances", "id"),
        ("eod_reports", "id"),
        ("reconciliations", "id"),
        ("vault_reconciliations", "id"),
        ("bank_reconciliations", "id"),
        ("cashbook_reconciliations", "id"),
        ("reconciliation_corrections", "id")
    ]

    with SupabaseUnitOfWork() as uow:
        for table_name, pkey in tables_to_purge:
            try:
                # Check row count before
                chk = uow.client.table(table_name).select(pkey, count="exact").execute()
                count_before = len(chk.data) if chk.data else 0
                
                if count_before > 0:
                    del_res = uow.client.table(table_name).delete().neq(pkey, dummy_uuid).execute()
                    print(f"✅ Purged {table_name}: {count_before} records deleted.")
                else:
                    print(f"⚪ {table_name}: already empty.")
            except Exception as e:
                # Table might not exist or had error
                err_msg = str(e)
                if "relation" in err_msg and "does not exist" in err_msg:
                    print(f"⚪ {table_name}: table does not exist in schema (skipped).")
                else:
                    print(f"⚠️ {table_name}: {err_msg}")

        print("\n----------------------------------------------------------")
        print("🔍 VERIFYING PRESERVED STRUCTURAL ENTITIES:")
        print("----------------------------------------------------------")
        preserved = ["app_users", "branches", "groups", "clients", "client_memberships", "loan_products", "financial_accounts"]
        for p_table in preserved:
            try:
                res = uow.client.table(p_table).select("*").execute()
                cnt = len(res.data) if res.data else 0
                print(f"  - {p_table}: {cnt} records preserved.")
            except Exception as ex:
                print(f"  - {p_table}: {ex}")

        print("----------------------------------------------------------")
        print("✨ PURGE COMPLETE: Database is clean and ready for live testing!")

if __name__ == "__main__":
    purge_all_transactions()
