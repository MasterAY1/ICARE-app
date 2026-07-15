import os
import sys
import tomllib
from supabase import create_client, Client

try:
    with open(".streamlit/secrets.toml", "rb") as f:
        secrets = tomllib.load(f)
    url = secrets.get("SUPABASE_URL")
    key = secrets.get("SUPABASE_KEY")
except Exception as e:
    print(f"Could not load secrets.toml: {e}")
    sys.exit(1)

supabase: Client = create_client(url, key)

tables = ["regions", "zones", "branches", "app_users", "clients", "groups", "client_memberships", "loan_products", "loans", "loan_schedule", "repayments", "individual_savings", "group_savings", "internal_savings", "laps_savings", "fees", "treasury_transactions", "master_cashbook", "event_store"]

print("Tables verification in Supabase:")
for table in tables:
    try:
        res = supabase.table(table).select("*").limit(1).execute()
        print(f"Table '{table}' exists. Columns: {list(res.data[0].keys()) if res.data else 'Empty table'}")
    except Exception as e:
        print(f"Table '{table}' does NOT exist or failed: {e}")
