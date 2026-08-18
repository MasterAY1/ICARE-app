import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope, RBACScopeService

def investigate_monsurat():
    with SupabaseUnitOfWork() as uow:
        print("=" * 80)
        print("1. DATABASE QUERY: CLIENTS TABLE")
        print("=" * 80)
        c_res = uow.client.table("clients").select("*").execute()
        m_clients = [c for c in (c_res.data or []) if "monsurat" in str(c.get("name", "")).lower() and "oladeji" in str(c.get("name", "")).lower()]
        
        g_res = uow.client.table("groups").select("*").execute()
        g_map = {g['group_id']: g for g in (g_res.data or [])}
        
        u_res = uow.client.table("app_users").select("*").execute()
        u_map = {u['id']: u for u in (u_res.data or [])}
        
        for c in m_clients:
            c_id = c['client_id']
            g_info = g_map.get(c.get('group_id'), {})
            u_info = u_map.get(c.get('officer_id'), {})
            print(f"Client ID:   {c_id}")
            print(f"Client Code: {c.get('client_code')}")
            print(f"Name:        {c.get('name')}")
            print(f"Group ID:    {c.get('group_id')} ({g_info.get('name', 'N/A')}) [Group Officer: {u_map.get(g_info.get('officer_id'), {}).get('full_name')}]")
            print(f"Officer ID:  {c.get('officer_id')} ({u_info.get('full_name', 'N/A')})")
            print(f"Branch ID:   {c.get('branch_id')}")
            
            # Check loans
            l_res = uow.client.table("loans").select("*").eq("client_id", c_id).execute()
            print(f"Loans in DB: {len(l_res.data or [])}")
            for l in (l_res.data or []):
                print(f"  -> Loan ID: {l.get('loan_id')}, Active Credit: {l.get('active_credit')}, Total Due: {l.get('total_due')}, Repay: {l.get('loan_repay')}, Status: {l.get('status')}")
            
            # Check savings
            s_res = uow.client.table("individual_savings").select("*").eq("client_id", c_id).execute()
            print(f"Savings in DB: {len(s_res.data or [])}")
            for s in (s_res.data or []):
                print(f"  -> Savings ID: {s.get('id')}, Dep: {s.get('deposit_amount')}, Ref: {s.get('reference')}, Remarks: {s.get('remarks')}")
            
            # Check client_memberships
            m_res = uow.client.table("client_memberships").select("*").eq("client_id", c_id).execute()
            print(f"Memberships in DB: {len(m_res.data or [])}")
            for m in (m_res.data or []):
                mg_info = g_map.get(m.get('group_id'), {})
                print(f"  -> Group ID: {m.get('group_id')} ({mg_info.get('name')})")
            print("-" * 80)

        print("\n" + "=" * 80)
        print("2. GROUPS TABLE QUERY (Olorunsogo, Oluwapelumi, Feresisemi)")
        print("=" * 80)
        for g in (g_res.data or []):
            g_name_l = str(g.get("name", "")).lower()
            if any(k in g_name_l for k in ["olorun", "oluwapelumi", "feresi"]):
                o_info = u_map.get(g.get('officer_id'), {})
                print(f"Group: {g.get('name'):<15} | Group #{g.get('group_number')} | ID: {g.get('group_id')} | Officer: {o_info.get('full_name')} ({o_info.get('username')}) | Day: {g.get('meeting_day')}")

        print("\n" + "=" * 80)
        print("3. PORTFOLIO SERVICE FOR CO AYOMIDE (CO2)")
        print("=" * 80)
        # Find Ayomide user
        user_ayo = next((u for u in (u_res.data or []) if "ayomide" in str(u.get("full_name", "")).lower() or "co2" in str(u.get("username", "")).lower()), None)
        if user_ayo:
            scope_co = RBACScopeService.resolve_scope(user_ayo)
            p_co = PortfolioService.get_portfolio_data_for_scope(uow, scope_co)
            df_co = p_co["client_table"]
            print("CO Portfolio Client Table:")
            print(df_co.to_string())
            
        print("\n" + "=" * 80)
        print("4. PORTFOLIO SERVICE FOR ADMIN (ALL GROUPS)")
        print("=" * 80)
        scope_admin = RBACScope(role="Admin", scope_level="ALL", branch_id=None, branch_name=None, assigned_branch_ids=[])
        p_admin = PortfolioService.get_portfolio_data_for_scope(uow, scope_admin)
        df_admin = p_admin["client_table"]
        print("Admin Portfolio Group Table:")
        print(df_admin.to_string())

if __name__ == "__main__":
    investigate_monsurat()
