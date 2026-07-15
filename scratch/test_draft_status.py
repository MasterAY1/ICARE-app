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

# Try inserting a loan with status 'Draft'
test_loan = {
    "client_id": "00000000-0000-0000-0000-000000000000",
    "product_id": "11111111-1111-1111-1111-111111111111",
    "branch_id": "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d",
    "officer_id": "00000000-0000-0000-0000-000000000000",
    "date": "2026-07-14",
    "loan_amount": 10000,
    "active_credit": 10000,
    "loan_repay": 1000,
    "total_due": 11000,
    "status": "Draft",
    "product_category": "Finance"
}

try:
    res = supabase.table("loans").insert(test_loan).execute()
    print("SUCCESS! Draft status is accepted.")
    # Delete the test row
    if res.data:
        supabase.table("loans").delete().eq("loan_id", res.data[0]["loan_id"]).execute()
except Exception as e:
    print(f"FAILED: {e}")
