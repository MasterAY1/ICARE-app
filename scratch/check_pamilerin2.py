import sys
import os
import time
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

time.sleep(1)
uow = SupabaseUnitOfWork()
res = uow.client.table("groups").select("group_id, name, officer_id").execute()
for g in (res.data or []):
    if "pamilerin" in str(g.get("name", "")).lower():
        print("Pamilerin Group:", g)

