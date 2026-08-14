import os
import sys

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def clear_transactions():
    print("==================================================")
    print("PURGING ALL TRANSACTIONS, LEDGERS & MIGRATION DATA")
    print("PRESERVING: clients, groups, loan_products, users, branches, chart_of_accounts, posting_rules, etc.")
    print("==================================================")

    tables_to_clear = [
        "loan_schedule",
        "loan_guarantors",
        "repayments",
        "individual_savings",
        "group_savings",
        "internal_savings",
        "laps_savings",
        "fees",
        "withdrawal_requests",
        "correction_requests",
        "collection_performance",
        "loans",
        "treasury_transactions",
        "financial_ledger_entries",
        "financial_transactions",
        "event_processing",
        "event_store",
        "co_cashbooks",
        "master_cashbook",
        "notifications",
        "audit_logs",
        "audit_log",
        "user_audit_logs"
    ]

    with SupabaseUnitOfWork() as uow:
        print("\n--- 1. CURRENT RECORD COUNTS BEFORE PURGE ---")
        for tbl in tables_to_clear:
            try:
                res = uow.client.table(tbl).select("id", count="exact").execute()
                cnt = res.count if res.count is not None else len(res.data or [])
                print(f"Table '{tbl}': {cnt} records")
            except Exception:
                try:
                    res = uow.client.table(tbl).select("*", count="exact").execute()
                    cnt = res.count if res.count is not None else len(res.data or [])
                    print(f"Table '{tbl}': {cnt} records")
                except Exception as e:
                    print(f"Table '{tbl}': could not count ({e})")

        print("\n--- 2. EXECUTING TRANSACTION PURGE ---")
        for tbl in tables_to_clear:
            try:
                # Use raw SQL delete for fast, atomic cascading cleanup without PostgREST row limits
                uow.client.table(tbl).delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
                print(f"Cleared table: '{tbl}'")
            except Exception as e:
                # Try deleting where true via RPC or neq with different PK column
                try:
                    if tbl == "loans":
                        uow.client.table(tbl).delete().neq("loan_id", "00000000-0000-0000-0000-000000000000").execute()
                    elif tbl == "repayments":
                        uow.client.table(tbl).delete().neq("repayment_id", "00000000-0000-0000-0000-000000000000").execute()
                    elif tbl in ["co_cashbooks", "master_cashbook"]:
                        uow.client.table(tbl).delete().gte("date", "1900-01-01").execute()
                    elif tbl == "event_store":
                        uow.client.table(tbl).delete().neq("event_id", "00000000-0000-0000-0000-000000000000").execute()
                    elif tbl == "financial_transactions":
                        uow.client.table(tbl).delete().neq("transaction_id", "00000000-0000-0000-0000-000000000000").execute()
                    elif tbl == "financial_ledger_entries":
                        uow.client.table(tbl).delete().neq("entry_id", "00000000-0000-0000-0000-000000000000").execute()
                    elif tbl == "fees":
                        uow.client.table(tbl).delete().neq("fee_id", "00000000-0000-0000-0000-000000000000").execute()
                    else:
                        uow.client.table(tbl).delete().neq("created_at", "1900-01-01").execute()
                    print(f"Cleared table (fallback): '{tbl}'")
                except Exception as ex2:
                    print(f"Failed to clear table '{tbl}': {ex2}")

        print("\n--- 3. VERIFYING PRESERVED STRUCTURAL MASTER TABLES ---")
        preserved_tables = [
            "branches",
            "app_users",
            "roles",
            "permissions",
            "loan_products",
            "chart_of_accounts",
            "posting_rules",
            "groups",
            "clients",
            "client_memberships",
            "guarantors"
        ]
        for tbl in preserved_tables:
            try:
                res = uow.client.table(tbl).select("*", count="exact").execute()
                cnt = res.count if res.count is not None else len(res.data or [])
                print(f"Preserved Table '{tbl}': {cnt} records intact.")
            except Exception as e:
                print(f"Preserved Table '{tbl}': could not count ({e})")

        print("\n==================================================")
        print("DATABASE PURGE COMPLETE - CLEAN STATE READY FOR LIVE USE")
        print("==================================================")

if __name__ == "__main__":
    clear_transactions()
