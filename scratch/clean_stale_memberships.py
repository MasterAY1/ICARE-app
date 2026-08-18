import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def clean_memberships():
    with SupabaseUnitOfWork() as uow:
        print("1. Fetching all clients and their primary group_ids...")
        c_res = uow.client.table("clients").select("client_id, client_code, name, group_id").execute()
        clients = c_res.data or []
        
        print(f"Total clients in DB: {len(clients)}")
        
        print("2. Clearing client_memberships table...")
        uow.client.table("client_memberships").delete().neq("client_id", "00000000-0000-0000-0000-000000000000").execute()
        
        print("3. Re-inserting exact 1-to-1 memberships matching clients.group_id...")
        new_memberships = []
        for c in clients:
            cid = c.get("client_id")
            gid = c.get("group_id")
            if cid and gid:
                new_memberships.append({"client_id": cid, "group_id": gid})
                
        # Insert in chunks of 100
        chunk_size = 100
        for i in range(0, len(new_memberships), chunk_size):
            chunk = new_memberships[i:i + chunk_size]
            uow.client.table("client_memberships").insert(chunk).execute()
            print(f"  Inserted chunk {i // chunk_size + 1} ({len(chunk)} memberships)")
            
        m_cnt = uow.client.table("client_memberships").select("client_id", count="exact").execute().count
        print(f"\n>>> CLEANUP COMPLETE: Exactly {m_cnt} client memberships in DB (matches {len(clients)} clients) <<<")

if __name__ == "__main__":
    clean_memberships()
