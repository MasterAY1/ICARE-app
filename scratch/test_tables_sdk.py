import toml
import json
from supabase import create_client

secrets = toml.load('.streamlit/secrets.toml')
url = secrets["SUPABASE_URL"]
key = secrets["SUPABASE_KEY"]
supabase = create_client(url, key)

print("--- TESTING CANDIDATE TABLES DIRECTLY VIA SUPABASE SDK ---")

candidate_tables = [
    # Core
    "branches", "app_users", "clients", "groups", "loans", "repayments", "client_memberships",
    # Savings
    "individual_savings", "group_savings", "laps_savings", "internal_savings",
    # Financial Ledger & Event Store
    "financial_transactions", "financial_ledger_entries", "posting_rules", "event_store", "event_processing", "chart_of_accounts",
    # Cashbooks
    "co_cashbooks", "master_cashbook",
    # Treasury
    "treasury_transactions", "bank_deposits", "bank_withdrawals", "fund_transfers", "office_expenses",
    # Fee Ledgers
    "fees", "processing_fees", "passbook_fees", "credit_form_fees", "contingency", "markup_11", "markup_20", "misc_fees", "bonus", "credit_form_damage",
    # Loan Pricing
    "loan_products", "loan_schedule",
    # Audit & Other
    "audit_logs", "user_audit_logs", "login_history", "branch_closures", "guarantors", "loan_guarantors", "roles", "permissions", "user_roles", "role_permissions", "zones", "regions"
]

results = {}

for table in candidate_tables:
    try:
        res = supabase.table(table).select("*").limit(1).execute()
        row_count = 0
        try:
            res_count = supabase.table(table).select("count", count="exact").limit(1).execute()
            row_count = res_count.count if res_count.count is not None else len(res.data or [])
        except Exception:
            row_count = len(res.data or [])

        sample = res.data[0] if res.data else {}
        results[table] = {
            "exists": True,
            "row_count": row_count,
            "columns": list(sample.keys()) if sample else "Table empty (exists)"
        }
        print(f"[EXISTS] Table '{table}' Rows: {row_count}")
    except Exception as e:
        results[table] = {
            "exists": False,
            "error": str(e)
        }
        print(f"[NOT FOUND] Table '{table}' (Error: {e})")

with open("scratch/live_db_table_test.json", "w") as f:
    json.dump(results, f, indent=2)

print("\nSaved test output to scratch/live_db_table_test.json")
