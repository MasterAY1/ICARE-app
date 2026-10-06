import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
import math

def run_fix():
    print("Starting deep fix...")
    with SupabaseUnitOfWork() as uow:
        # 1. Fix missing branch_id, officer_id in client_memberships
        print("Fixing client memberships...")
        m_res = uow.client.table("client_memberships").select("membership_id, group_id").is_("branch_id", "null").execute()
        for m in m_res.data:
            g_res = uow.client.table("groups").select("branch_id, officer_id").eq("group_id", m['group_id']).execute()
            if g_res.data:
                b_id = g_res.data[0]['branch_id']
                o_id = g_res.data[0]['officer_id']
                uow.client.table("client_memberships").update({"branch_id": b_id, "officer_id": o_id}).eq("membership_id", m['membership_id']).execute()
                print(f"Fixed membership {m['membership_id']}")
                
        # 2. Fix clients table (pull from memberships now that it's fixed)
        print("Fixing clients table...")
        b_res = uow.client.table("branches").select("branch_id, name").execute()
        b_map = {b['branch_id']: b['name'] for b in b_res.data}
        
        c_res = uow.client.table("clients").select("client_id, client_code, branch_id").execute()
        branch_counts = {}
        for c in c_res.data:
            c_id = c['client_id']
            needs_update = False
            updates = {}
            
            if not c.get('branch_id'):
                mem_res = uow.client.table("client_memberships").select("group_id, branch_id, officer_id").eq("client_id", c_id).execute()
                if mem_res.data:
                    updates['group_id'] = mem_res.data[0]['group_id']
                    updates['branch_id'] = mem_res.data[0]['branch_id']
                    updates['officer_id'] = mem_res.data[0]['officer_id']
                    c['branch_id'] = mem_res.data[0]['branch_id']
                    needs_update = True
                    
            if not c.get('client_code') or c.get('client_code') == "":
                b_id = c.get('branch_id') or updates.get('branch_id')
                if b_id:
                    if b_id not in branch_counts:
                        count_res = uow.client.table("clients").select("client_id", count="exact").eq("branch_id", b_id).neq("client_code", None).execute()
                        branch_counts[b_id] = count_res.count or 0
                        
                    branch_counts[b_id] += 1
                    b_name = b_map.get(b_id, "UNK")
                    prefix = b_name[:3].upper()
                    new_code = f"{prefix}-MIG-{branch_counts[b_id]:03d}"
                    updates['client_code'] = new_code
                    needs_update = True
                    
            if needs_update:
                uow.client.table("clients").update(updates).eq("client_id", c_id).execute()
                print(f"Fixed client {c_id}")
                
        # 3. Fix savings officer_ids
        print("Fixing savings officer_ids...")
        is_res = uow.client.table("individual_savings").select("id, client_id").eq("officer_id", "00000000-0000-0000-0000-000000000000").execute()
        for s in is_res.data:
            mem_res = uow.client.table("client_memberships").select("officer_id").eq("client_id", s['client_id']).execute()
            if mem_res.data and mem_res.data[0]['officer_id']:
                uow.client.table("individual_savings").update({"officer_id": mem_res.data[0]['officer_id']}).eq("id", s['id']).execute()
                print(f"Fixed individual savings {s['id']}")

        gs_res = uow.client.table("group_savings").select("id, group_id").eq("officer_id", "00000000-0000-0000-0000-000000000000").execute()
        for g in gs_res.data:
            gr_res = uow.client.table("groups").select("officer_id").eq("group_id", g['group_id']).execute()
            if gr_res.data and gr_res.data[0]['officer_id']:
                uow.client.table("group_savings").update({"officer_id": gr_res.data[0]['officer_id']}).eq("id", g['id']).execute()
                print(f"Fixed group savings {g['id']}")
                
    print("All fixed!")

if __name__ == '__main__':
    run_fix()
