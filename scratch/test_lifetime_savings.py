import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.rbac_scope_service import RBACScopeService

uow = SupabaseUnitOfWork()

# Check savings for all officers and entire branch
officers = ["CO1", "CO2", "CO3", "CO4", "BM_Ogijo"]

for off_name in officers:
    user_dict = {"username": off_name, "role": "BM" if "BM" in off_name else "CO", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
    if off_name != "BM_Ogijo":
        user_dict["id"] = uow.loans._resolve_officer_id(off_name)
    else:
        user_dict["id"] = "f2656341-a85a-4e06-a1c8-d62cfef19b08"
    scope = RBACScopeService.resolve_scope(user_dict)
    
    # 1. Clients in scope
    c_q = uow.client.table("clients").select("client_id, name")
    if scope.scope_level == "OFFICER":
        c_q = c_q.eq("officer_id", scope.user_id)
    elif scope.scope_level == "BRANCH":
        c_q = c_q.eq("branch_id", scope.branch_id)
    c_res = c_q.execute()
    client_ids = [c["client_id"] for c in (c_res.data or []) if c.get("client_id")]
    
    # 2. Individual savings (Lifetime)
    ind_dep = 0.0
    ind_wth = 0.0
    if client_ids:
        s_res = uow.client.table("individual_savings").select("deposit_amount, withdrawal_amount").in_("client_id", client_ids).execute()
        ind_dep = sum(float(s.get("deposit_amount") or 0) for s in (s_res.data or []))
        ind_wth = sum(float(s.get("withdrawal_amount") or 0) for s in (s_res.data or []))
        
    # 3. Group savings (Lifetime)
    grp_dep = 0.0
    grp_wth = 0.0
    g_q = uow.client.table("groups").select("group_id")
    if scope.scope_level == "OFFICER":
        g_q = g_q.eq("officer_id", scope.user_id)
    elif scope.scope_level == "BRANCH":
        g_q = g_q.eq("branch_id", scope.branch_id)
    g_res = g_q.execute()
    g_ids = [g["group_id"] for g in (g_res.data or []) if g.get("group_id")]
    if g_ids:
        gs_res = uow.client.table("group_savings").select("deposit_amount, withdrawal_amount").in_("group_id", g_ids).execute()
        grp_dep = sum(float(s.get("deposit_amount") or 0) for s in (gs_res.data or []))
        grp_wth = sum(float(s.get("withdrawal_amount") or 0) for s in (gs_res.data or []))
        
    # 4. Misc savings
    misc_dep = 0.0
    misc_wth = 0.0
    if off_name == "CO3" or off_name == "BM_Ogijo":
        ms_res = uow.client.table("internal_savings").select("deposit_amount, withdrawal_amount").execute()
        misc_dep = sum(float(s.get("deposit_amount") or 0) for s in (ms_res.data or []))
        misc_wth = sum(float(s.get("withdrawal_amount") or 0) for s in (ms_res.data or []))
        
    tot_dep = ind_dep + grp_dep + misc_dep
    tot_wth = ind_wth + grp_wth + misc_wth
    net_bal = tot_dep - tot_wth
    
    print(f"\n=== SCOPE: {off_name} ({len(client_ids)} clients, {len(g_ids)} groups) ===")
    print(f"Individual: Dep=NGN {ind_dep:,.2f}, Wth=NGN {ind_wth:,.2f}, Bal=NGN {ind_dep-ind_wth:,.2f}")
    print(f"Group:      Dep=NGN {grp_dep:,.2f}, Wth=NGN {grp_wth:,.2f}, Bal=NGN {grp_dep-grp_wth:,.2f}")
    print(f"Misc:       Dep=NGN {misc_dep:,.2f}, Wth=NGN {misc_wth:,.2f}, Bal=NGN {misc_dep-misc_wth:,.2f}")
    print(f"TOTAL:      Total Deposits=NGN {tot_dep:,.2f}, Total Withdrawals=NGN {tot_wth:,.2f}, Net Balance=NGN {net_bal:,.2f}")
