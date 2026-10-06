import re

with open('app.py', 'r', encoding='utf-8') as f:
    code = f.read()

group_filter = '''
        # Group Filter
        all_grp = ["All"]
        try:
            g_q = uow_p.client.table("groups").select("name")
            if sel_branch and sel_branch != "All":
                b_res = uow_p.client.table("branches").select("branch_id").eq("name", sel_branch).execute()
                if b_res.data:
                    g_q = g_q.eq("branch_id", b_res.data[0]["branch_id"])
            elif p_scope.scope_level == "BRANCH" and p_scope.branch_id:
                g_q = g_q.eq("branch_id", p_scope.branch_id)
            elif p_scope.scope_level == "OFFICER" and p_scope.user_id:
                g_q = g_q.eq("officer_id", p_scope.user_id)
            
            g_res = g_q.execute()
            all_grp += sorted(list(set(g["name"] for g in (g_res.data or []) if g.get("name"))))
        except Exception:
            pass
        
        sel_group = st.selectbox("Filter Group", all_grp, key="port_grp_sel")

        # Load Scoped Data
'''
code = code.replace('        # Load Scoped Data', group_filter)

load_call_old = '''        p_data = PortfolioService.get_portfolio_data_for_scope(
            uow_p, p_scope, selected_branch=sel_branch, selected_officer=sel_officer
        )'''
load_call_new = '''        p_data = PortfolioService.get_portfolio_data_for_scope(
            uow_p, p_scope, selected_branch=sel_branch, selected_officer=sel_officer, selected_group=sel_group
        )'''
code = code.replace(load_call_old, load_call_new)

code = code.replace('st.markdown("### Authorized Client Portfolio Table")', 'st.markdown("### Client Portfolio")')

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(code)
print('app.py updated')
