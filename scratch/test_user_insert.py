import sys
import os

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scratch.verify_phase3 import load_secrets
from supabase import create_client

secrets = load_secrets()
client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

# Try to insert a user and print results
print("Inserting user...")
try:
    res_ins = client.table("app_users").insert({
        "username": "dbg_user",
        "full_name": "Debug User",
        "password_hash": "dbg_hash",
        "branch_id": None
    }).execute()
    print("Insert response data:", res_ins.data)
except Exception as e:
    print("Insert failed:", e)

# Try to select
print("Selecting user...")
try:
    res_sel = client.table("app_users").select("*").eq("username", "dbg_user").execute()
    print("Select response data:", res_sel.data)
except Exception as e:
    print("Select failed:", e)

# Clean up
client.table("app_users").delete().eq("username", "dbg_user").execute()
