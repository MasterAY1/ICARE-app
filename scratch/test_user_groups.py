import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

users = ["CO1", "CO2", "CO3", "CO4", "BM_Ogijo", "AM_Area_1", "admin", "Master"]

for u in users:
    print(f"\n================ USER: {u} ================")
    # 1. Resolve officer ID
    try:
        off_id = uow.loans._resolve_officer_id(u)
        print(f"Resolved officer ID: {off_id}")
    except Exception as e:
        off_id = None
        print(f"Could not resolve officer_id: {e}")
        
    # Let's check what groups query returns for this user in app.py:
    # 1. Direct groups where groups.officer_id == target_officer_id
    BRANCH_ID = '997d504e-7f5c-4772-887d-fdd5a4c1183b'
    res_g_direct = uow.client.table("groups").select("group_id, name").eq("branch_id", BRANCH_ID).eq("officer_id", off_id).execute()
    direct_grps = [g["name"] for g in (res_g_direct.data or []) if g and g.get("name")]
    print(f"Direct groups (groups.officer_id == {off_id}): {direct_grps}")
    
    # 2. Groups where officer has active clients via memberships
    res_c_groups = uow.client.table("clients").select("client_memberships(group_id, groups(group_id, name))").eq("officer_id", off_id).eq("status", "Active").execute()
    membership_grps = []
    for c in (res_c_groups.data or []):
        m_list = c.get("client_memberships") or []
        if isinstance(m_list, dict):
            m_list = [m_list]
        for m in m_list:
            if m and m.get("groups") and m["groups"].get("name"):
                membership_grps.append(m["groups"]["name"])
    membership_grps = list(set(membership_grps))
    print(f"Membership groups (clients.officer_id == {off_id}): {membership_grps}")
    
    combined = sorted(list(set(direct_grps + membership_grps)))
    print(f"TOTAL COMBINED GROUPS FOR {u}: {combined}")
