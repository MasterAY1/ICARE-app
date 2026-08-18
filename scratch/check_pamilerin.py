import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()
res = uow.client.table("groups").select("*").ilike("name", "%Pamilerin%").execute()
print("Group Pamilerin in groups table:", res.data)

res_c = uow.client.table("clients").select("client_id, name, officer_id, client_memberships(group_id, groups(group_id, name))").execute()
for c in (res_c.data or []):
    for m in c.get("client_memberships") or []:
        if m and m.get("groups") and "Pamilerin" in m["groups"].get("name", ""):
            print("Client in Pamilerin:", c["name"], "officer_id:", c["officer_id"], "group:", m["groups"])

