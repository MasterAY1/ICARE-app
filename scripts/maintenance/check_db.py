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

try:
    res_loans = supabase.table("loans").select("count", count="exact").execute()
    loans_count = res_loans.count
    
    res_repayments = supabase.table("repayments").select("count", count="exact").execute()
    repayments_count = res_repayments.count
    
    print(f"Database Check:")
    print(f"Loans Table Count: {loans_count}")
    print(f"Repayments Table Count: {repayments_count}")
    
except Exception as e:
    print(f"Error checking database: {e}")
