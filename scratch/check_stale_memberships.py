import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def check_memberships():
    with SupabaseUnitOfWork() as uow:
        c_res = uow.client.table("clients").select("client_id, client_code, name, group_id").execute()
        clients = c_res.data or []
        
        g_res = uow.client.table("groups").select("group_id, name").execute()
        g_map = {g['group_id']: g['name'] for g in (g_res.data or [])}
        
        m_res = uow.client.table("client_memberships").select("client_id, group_id").execute()
        memberships = m_res.data or []
        
        print(f"Total clients: {len(clients)}")
        print(f"Total membership rows: {len(memberships)}")
        
        from collections import defaultdict
        m_by_client = defaultdict(list)
        for m in memberships:
            m_by_client[m['client_id']].append(m['group_id'])
            
        multi_m = {cid: gids for cid, gids in m_by_client.items() if len(gids) > 1}
        print(f"Clients with multiple memberships: {len(multi_m)}")
        
        c_dict = {c['client_id']: c for c in clients}
        for cid, gids in multi_m.items():
            c = c_dict.get(cid, {})
            c_name = c.get('name')
            c_code = c.get('client_code')
            c_gid = c.get('group_id')
            gnames = [g_map.get(gid, gid) for gid in gids]
            primary_gname = g_map.get(c_gid, c_gid)
            print(f"  * Client: {c_code} ({c_name}) | Primary Group: {primary_gname} | Memberships: {gnames}")

if __name__ == "__main__":
    check_memberships()
