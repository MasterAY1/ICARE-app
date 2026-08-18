import os
import sys
import time

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from database.connection import get_supabase_client

for i in range(3):
    try:
        client = get_supabase_client()
        res = client.table("branches").select("branch_id, name").execute()
        print("Success:", res.data)
        break
    except Exception as e:
        print(f"Attempt {i+1} failed: {e}")
        time.sleep(2)
