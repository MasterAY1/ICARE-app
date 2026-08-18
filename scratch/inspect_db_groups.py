import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
import json

def inspect_officers_and_groups():
    uow = SupabaseUnitOfWork()
    
    # 1. App Users (Officers)
    users_res = uow.client.table("app_users").select("*").execute()
    print("=== APP USERS ===")
    for u in (users_res.data or []):
        print(f"ID: {u.get('id')} | Username: {u.get('username')} | Name: {u.get('full_name')} | Branch: {u.get('branch_id')}")
        
    # 2. Groups
    groups_res = uow.client.table("groups").select("*").execute()
    print("\n=== GROUPS IN DB ===")
    for g in (groups_res.data or []):
        print(f"Group ID: {g.get('group_id')} | Name: {g.get('name')} | Branch ID: {g.get('branch_id')} | Officer ID: {g.get('officer_id')}")
        
    # 3. Clients per officer and their groups
    clients_res = uow.client.table("clients").select("client_id, name, officer_id, branch_id, client_memberships(group_id, groups(group_id, name))").execute()
    print("\n=== CLIENTS & THEIR GROUPS ===")
    officer_groups_map = {}
    for c in (clients_res.data or []):
        off_id = c.get("officer_id")
        if off_id not in officer_groups_map:
            officer_groups_map[off_id] = set()
        m_list = c.get("client_memberships") or []
        if isinstance(m_list, dict):
            m_list = [m_list]
        for m in m_list:
            if m and m.get("groups") and m["groups"].get("name"):
                officer_groups_map[off_id].add(m["groups"]["name"])
                
    for off_id, grps in officer_groups_map.items():
        print(f"Officer ID: {off_id} -> Groups via active clients: {grps}")

if __name__ == "__main__":
    inspect_officers_and_groups()
