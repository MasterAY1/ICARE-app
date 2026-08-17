import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def verify_monsurat_split():
    with SupabaseUnitOfWork() as uow:
        res = uow.client.table("clients").select("client_id, client_code, name, group_id, officer_id").execute()
        all_clients = [c for c in (res.data or []) if "monsurat" in str(c.get("name", "")).lower() and "oladeji" in str(c.get("name", "")).lower()]
        
        g_res = uow.client.table("groups").select("group_id, name").execute()
        g_map = {g['group_id']: g['name'] for g in (g_res.data or [])}
        
        o_res = uow.client.table("app_users").select("id, full_name").execute()
        o_map = {o['id']: o['full_name'] for o in (o_res.data or [])}
        
        print("=" * 80)
        print("MONSURAT OLADEJI DISAMBIGUATION VERIFICATION")
        print("=" * 80)
        
        for c in all_clients:
            c_id = c['client_id']
            c_code = c['client_code']
            c_name = c['name']
            g_name = g_map.get(c.get('group_id'), 'N/A')
            o_name = o_map.get(c.get('officer_id'), 'N/A')
            
            l_res = uow.client.table("loans").select("loan_id, active_credit, total_due").eq("client_id", c_id).execute()
            s_res = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", c_id).execute()
            
            loans_cnt = len(l_res.data or [])
            loan_str = f"Active Credit: NGN {l_res.data[0]['active_credit']}, Bal: NGN {l_res.data[0]['total_due']}" if loans_cnt > 0 else "No Active Loans"
            sav_amt = sum(float(s['deposit_amount'] or 0) for s in (s_res.data or []))
            
            print(f"Client Code:  {c_code}")
            print(f"Full Name:    {c_name}")
            print(f"Group:        {g_name}")
            print(f"Officer:      {o_name}")
            print(f"Savings:      NGN {sav_amt:,.2f}")
            print(f"Loan Status:  {loan_str}")
            print("-" * 80)

if __name__ == "__main__":
    verify_monsurat_split()
