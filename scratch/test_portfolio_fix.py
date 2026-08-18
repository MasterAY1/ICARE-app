import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.rbac_scope_service import RBACScopeService
from datetime import date

uow = SupabaseUnitOfWork()

# Test CO2 and BM
for username, role in [("CO2", "CO"), ("BM_Ogijo", "BM"), ("CO3", "CO")]:
    user_dict = {"username": username, "role": role, "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
    if role == "CO":
        user_dict["id"] = uow.loans._resolve_officer_id(username)
    else:
        user_dict["id"] = "f2656341-a85a-4e06-a1c8-d62cfef19b08"
    scope = RBACScopeService.resolve_scope(user_dict)
    
    start_date = date(2026, 8, 1)
    end_date = date(2026, 8, 31)
    
    # 1. Fetch clients
    c_q = uow.client.table("clients").select("*")
    if scope.scope_level == "OFFICER" and scope.user_id:
        c_q = c_q.eq("officer_id", scope.user_id)
    elif scope.scope_level == "BRANCH" and scope.branch_id:
        c_q = c_q.eq("branch_id", scope.branch_id)
    clients_raw = (c_q.execute()).data or []
    client_ids = [str(c.get("client_id") or c.get("id")) for c in clients_raw if (c.get("client_id") or c.get("id"))]
    
    # 2. Cumulative Individual Savings up to end_date
    savings_map = {}
    total_ind_dep = 0.0
    total_ind_wth = 0.0
    if client_ids:
        s_query = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount, posting_date").in_("client_id", client_ids).lte("posting_date", end_date.isoformat())
        s_res = s_query.execute()
        for s in (s_res.data or []):
            cid_str = str(s.get("client_id"))
            dep = float(s.get("deposit_amount") or 0.0)
            wth = float(s.get("withdrawal_amount") or 0.0)
            total_ind_dep += dep
            total_ind_wth += wth
            if cid_str not in savings_map:
                savings_map[cid_str] = {'dep': 0.0, 'wth': 0.0, 'bal': 0.0}
            savings_map[cid_str]['dep'] += dep
            savings_map[cid_str]['wth'] += wth
            savings_map[cid_str]['bal'] += (dep - wth)
            
    # 3. Group Savings up to end_date
    group_savings_bal_map = {}
    total_grp_dep = 0.0
    total_grp_wth = 0.0
    if client_ids:
        gm_query = uow.client.table("client_memberships").select("client_id, group_id, groups(name)").in_("client_id", client_ids).execute()
        g_id_name_map = {}
        for gm in (gm_query.data or []):
            gid = str(gm.get("group_id"))
            gname = (gm.get("groups") or {}).get("name") if isinstance(gm.get("groups"), dict) else None
            if gid and gname:
                g_id_name_map[gid] = gname
        all_gids = list(g_id_name_map.keys())
        if all_gids:
            gs_res = uow.client.table("group_savings").select("group_id, deposit_amount, withdrawal_amount, posting_date").in_("group_id", all_gids).lte("posting_date", end_date.isoformat()).execute()
            for gs in (gs_res.data or []):
                gid = str(gs.get("group_id"))
                gname = g_id_name_map.get(gid, "Individual")
                dep = float(gs.get("deposit_amount") or 0.0)
                wth = float(gs.get("withdrawal_amount") or 0.0)
                total_grp_dep += dep
                total_grp_wth += wth
                group_savings_bal_map[gname] = group_savings_bal_map.get(gname, 0.0) + (dep - wth)

    # 4. Misc Savings up to end_date
    total_misc_dep = 0.0
    total_misc_wth = 0.0
    from services.savings_service import SavingsService
    m_off_id, m_off_name = SavingsService.get_branch_misc_savings_officer(uow, "Ogijo")
    should_include_misc = (scope.scope_level == "BRANCH" or str(scope.user_id) == str(m_off_id) or "co3" in str(scope.username).lower())
    if should_include_misc:
        ms_res = uow.client.table("internal_savings").select("deposit_amount, withdrawal_amount, posting_date").lte("posting_date", end_date.isoformat()).execute()
        for ms in (ms_res.data or []):
            dep = float(ms.get("deposit_amount") or 0.0)
            wth = float(ms.get("withdrawal_amount") or 0.0)
            total_misc_dep += dep
            total_misc_wth += wth

    total_dep = total_ind_dep + total_grp_dep + total_misc_dep
    total_wth = total_ind_wth + total_grp_wth + total_misc_wth
    net_bal = total_dep - total_wth

    print(f"\n==========================================")
    print(f"TEST SCOPE: {username} ({role})")
    print(f"Total Deposits:    NGN {total_dep:,.2f}")
    print(f"Total Withdrawals: NGN {total_wth:,.2f}")
    print(f"Net Savings Bal:   NGN {net_bal:,.2f}")
    print(f"Clients with savings: {sum(1 for s in savings_map.values() if s['bal'] > 0)} / {len(client_ids)}")
    print(f"Sample client savings: {list(savings_map.items())[:3]}")

