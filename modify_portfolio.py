import re

with open('services/portfolio_service.py', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Update signature
code = re.sub(
    r'(selected_officer:\s*Optional\[str\]\s*=\s*None,)',
    r'\1\n        selected_group: Optional[str] = None,',
    code
)

# 2. Add group and savings maps after fetching clients_raw
group_savings_fetch = '''        # Fetch group memberships
        group_map = {}
        try:
            client_ids = [c.get("client_id") or c.get("id") for c in clients_raw if (c.get("client_id") or c.get("id"))]
            if client_ids:
                g_query = uow.client.table("client_memberships").select("client_id, groups(name)").in_("client_id", client_ids).execute()
                for gm in (g_query.data or []):
                    grp = gm.get("groups") or {}
                    group_map[str(gm.get("client_id"))] = grp.get("name") or "Individual"
        except Exception:
            pass

        # Fetch individual savings
        savings_map = {}
        try:
            if client_ids:
                s_query = uow.client.table("individual_savings").select("client_id, balance").in_("client_id", client_ids).execute()
                for s in (s_query.data or []):
                    cid_str = str(s.get("client_id"))
                    savings_map[cid_str] = savings_map.get(cid_str, 0.0) + float(s.get("balance") or 0.0)
        except Exception:
            pass
'''
code = code.replace(
    '        # 2. Filter in memory by active dropdown selections (BM, AM, Admin)',
    group_savings_fetch + '\n        # 2. Filter in memory by active dropdown selections (BM, AM, Admin)'
)

# 3. Add group filter logic for loans/clients
group_filter = '''
        if selected_group and selected_group != "All":
            loans_raw = [l for l in loans_raw if group_map.get(str(l.get("client_id")), "Individual") == selected_group]
            clients_raw = [c for c in clients_raw if group_map.get(str(c.get("client_id") or c.get("id")), "Individual") == selected_group]
'''
code = code.replace(
    '        # 3. Query Repayments Today for Scope',
    group_filter + '\n        # 3. Query Repayments Today for Scope'
)

# 4. Add group filter for repayments
rep_filter = '''        if selected_group and selected_group != "All":
            repayments_today = [r for r in repayments_today if group_map.get(str(r.get("client_id")), "Individual") == selected_group]
'''
code = code.replace(
    '        # 4. Aggregations & Summary Calculations',
    rep_filter + '\n        # 4. Aggregations & Summary Calculations'
)

# 5. Modify client row logic
old_row_logic = '''                c_code = c_info.get("nickname") or cid or "N/A"
                bal = float(l.get("active_credit") or 0.0)
                repay_fixed = float(l.get("loan_repay") or 0.0)
                disbursed = float(l.get("loan_amount") or 0.0)
                
                prod_info = l.get("loan_products") or {}
                prod_name = prod_info.get("name") or "Unknown"'''

new_row_logic = '''                cid_str = str(cid) if cid else ""
                c_code = c_info.get("nickname") or "N/A"
                group_name = group_map.get(cid_str, "Individual")
                c_savings = savings_map.get(cid_str, 0.0)

                bal = float(l.get("active_credit") or 0.0)
                repay_fixed = float(l.get("loan_repay") or 0.0)
                disbursed = float(l.get("loan_amount") or 0.0)
                
                prod_info = l.get("loan_products") or {}
                prod_name = prod_info.get("name") or "Unknown"'''

code = code.replace(old_row_logic, new_row_logic)

old_append = '''                client_rows.append({
                    "Client Code": c_code,
                    "Client Name": c_name,
                    "Branch": (l.get("branches") or {}).get("name") or scope.branch_name,
                    "Officer": (l.get("app_users") or {}).get("username") or scope.username,
                    "Group": "Individual",
                    "Disbursed Amount": disbursed,
                    "Outstanding Balance": bal,
                    "Fixed Repayment": repay_fixed,
                    "Today Paid": paid_today,
                    "Status": "Overdue" if (paid_today == 0 and repay_fixed > 0) else ("Part Paid" if (paid_today > 0 and paid_today < repay_fixed) else "Normal")
                })'''

new_append = '''                client_rows.append({
                    "Client Code": c_code,
                    "Client Name": c_name,
                    "Group": group_name,
                    "Savings Balance": c_savings,
                    "Principal Loan": disbursed,
                    "Active Loan": bal,
                    "Outstanding Balance": bal,
                    "Fixed Repayment": repay_fixed,
                    "Total Paid": paid_today,
                    "Status": "Overdue" if (paid_today == 0 and repay_fixed > 0) else ("Part Paid" if (paid_today > 0 and paid_today < repay_fixed) else "Normal")
                })'''

code = code.replace(old_append, new_append)

old_df = 'pd.DataFrame(columns=["Client Code", "Client Name", "Branch", "Officer", "Group", "Disbursed Amount", "Outstanding Balance", "Fixed Repayment", "Today Paid", "Status"])'
new_df = 'pd.DataFrame(columns=["Client Code", "Client Name", "Group", "Savings Balance", "Principal Loan", "Active Loan", "Outstanding Balance", "Fixed Repayment", "Total Paid", "Status"])'
code = code.replace(old_df, new_df)

with open('services/portfolio_service.py', 'w', encoding='utf-8') as f:
    f.write(code)
print('portfolio_service.py updated')
