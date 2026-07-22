import toml
import json
from supabase import create_client

secrets = toml.load('.streamlit/secrets.toml')
url = secrets["SUPABASE_URL"]
key = secrets["SUPABASE_KEY"]
supabase = create_client(url, key)

print("--- INSPECTING COLUMN STRUCTURES OF ALL EXISTING TABLES ---")

existing_tables = [
    "branches", "app_users", "clients", "groups", "loans", "repayments", "client_memberships",
    "individual_savings", "group_savings", "laps_savings", "internal_savings",
    "financial_transactions", "financial_ledger_entries", "posting_rules", "event_store", "event_processing", "chart_of_accounts",
    "co_cashbooks", "master_cashbook", "treasury_transactions", "fees",
    "loan_products", "loan_schedule", "audit_logs", "user_audit_logs", "login_history", "branch_closures", "guarantors", "loan_guarantors", "roles", "user_roles", "zones", "regions"
]

schema_map = {}

for t in existing_tables:
    try:
        res = supabase.table(t).select("*").limit(1).execute()
        if res.data:
            schema_map[t] = list(res.data[0].keys())
        else:
            schema_map[t] = "Table empty"
    except Exception as e:
        schema_map[t] = f"Error: {e}"

with open("scratch/live_schema_columns.json", "w") as f:
    json.dump(schema_map, f, indent=2)

print("Saved column maps to scratch/live_schema_columns.json")
