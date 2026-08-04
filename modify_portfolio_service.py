import re

with open('services/portfolio_service.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Update signature
new_signature = '''    def get_portfolio_data_for_scope(
        uow: UnitOfWork,
        scope: RBACScope,
        selected_am: Optional[str] = None,
        selected_branch: Optional[str] = None,
        selected_officer: Optional[str] = None,
        selected_group: Optional[str] = None,
        selected_product: Optional[str] = None,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None
    ) -> Dict[str, Any]:
        """
        Calculates hierarchical portfolio intelligence for CO, BM, AM, Admin, and Director views.
        """
        if not start_date:
            start_date = date.today()
        if not end_date:
            end_date = date.today()
'''

content = re.sub(
    r'    def get_portfolio_data_for_scope.*?date_str = target_date.isoformat\(\)',
    new_signature,
    content,
    flags=re.DOTALL
)

# Update savings fetching to handle dates and track deposit/withdrawal totals
savings_fetching_old = '''        # Fetch individual savings
        savings_map = {}
        try:
            if client_ids:
                s_query = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").in_("client_id", client_ids).execute()
                for s in (s_query.data or []):
                    cid_str = str(s.get("client_id"))
                    dep = float(s.get("deposit_amount") or 0.0)
                    wth = float(s.get("withdrawal_amount") or 0.0)
                    savings_map[cid_str] = savings_map.get(cid_str, 0.0) + (dep - wth)
        except Exception:
            pass'''

savings_fetching_new = '''        # Fetch individual savings within date range
        savings_map = {}
        total_savings_deposit = 0.0
        total_savings_withdrawal = 0.0
        try:
            if client_ids:
                s_query = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount, posting_date").in_("client_id", client_ids)
                s_query = s_query.gte("posting_date", start_date.isoformat()).lte("posting_date", end_date.isoformat())
                s_res = s_query.execute()
                for s in (s_res.data or []):
                    cid_str = str(s.get("client_id"))
                    dep = float(s.get("deposit_amount") or 0.0)
                    wth = float(s.get("withdrawal_amount") or 0.0)
                    
                    total_savings_deposit += dep
                    total_savings_withdrawal += wth
                    
                    if cid_str not in savings_map:
                        savings_map[cid_str] = {'dep': 0.0, 'wth': 0.0, 'bal': 0.0}
                    savings_map[cid_str]['dep'] += dep
                    savings_map[cid_str]['wth'] += wth
                    savings_map[cid_str]['bal'] += (dep - wth)
        except Exception:
            pass'''

content = content.replace(savings_fetching_old, savings_fetching_new)

# Update loans and clients mapping inside `2. Filter in memory by active dropdown selections`
# We also need to add product filtering and repayments date filtering

repayments_fetching_old = '''        # 3. Query Repayments Today for Scope
        try:
            r_query = uow.client.table("repayments").select("*").eq("date", date_str)
            if scope.scope_level == "OFFICER":
                if scope.user_id:
                    r_query = r_query.eq("officer_id", scope.user_id)
            elif scope.scope_level == "BRANCH":
                if scope.branch_id:
                    r_query = r_query.eq("branch_id", scope.branch_id)
            elif scope.scope_level == "REGION":
                if scope.assigned_branch_ids:
                    r_query = r_query.in_("branch_id", scope.assigned_branch_ids)

            r_res = r_query.execute()
            repayments_today = r_res.data or []
            
            if selected_branch and selected_branch != "All":
                b_id = None
                try: b_id = uow.loans._resolve_branch_id(selected_branch)
                except: pass
                repayments_today = [r for r in repayments_today if str(r.get("branch_id")).lower() == str(b_id).lower() or str(r.get("branch") or "").lower() == selected_branch.lower()]
            
            if selected_officer and selected_officer != "All":
                o_id = None
                try: o_id = uow.loans._resolve_officer_id(selected_officer)
                except: pass
                repayments_today = [r for r in repayments_today if str(r.get("officer_id")).lower() == str(o_id).lower() or str(r.get("officer") or "").lower() == selected_officer.lower()]
        except Exception:
            repayments_today = []'''

repayments_fetching_new = '''        # 2.5 Filter by Loan Product
        if selected_product and selected_product != "All":
            # Filter loans by product name
            filtered_loans = []
            valid_client_ids = set()
            for l in loans_raw:
                p_name = (l.get("loan_products") or {}).get("name")
                if p_name == selected_product:
                    filtered_loans.append(l)
                    valid_client_ids.add(str(l.get("client_id")))
            
            loans_raw = filtered_loans
            # Filter clients to only those who have this product
            clients_raw = [c for c in clients_raw if str(c.get("client_id") or c.get("id")) in valid_client_ids]
            
            # Adjust global savings totals to only sum clients with this product
            total_savings_deposit = sum(s['dep'] for cid, s in savings_map.items() if cid in valid_client_ids)
            total_savings_withdrawal = sum(s['wth'] for cid, s in savings_map.items() if cid in valid_client_ids)

        # 3. Query Repayments in Date Range for Scope
        try:
            r_query = uow.client.table("repayments").select("*").gte("date", start_date.isoformat()).lte("date", end_date.isoformat())
            if scope.scope_level == "OFFICER":
                if scope.user_id:
                    r_query = r_query.eq("officer_id", scope.user_id)
            elif scope.scope_level == "BRANCH":
                if scope.branch_id:
                    r_query = r_query.eq("branch_id", scope.branch_id)
            elif scope.scope_level == "REGION":
                if scope.assigned_branch_ids:
                    r_query = r_query.in_("branch_id", scope.assigned_branch_ids)

            r_res = r_query.execute()
            repayments_today = r_res.data or []
            
            if selected_branch and selected_branch != "All":
                b_id = None
                try: b_id = uow.loans._resolve_branch_id(selected_branch)
                except: pass
                repayments_today = [r for r in repayments_today if str(r.get("branch_id")).lower() == str(b_id).lower() or str(r.get("branch") or "").lower() == selected_branch.lower()]
            
            if selected_officer and selected_officer != "All":
                o_id = None
                try: o_id = uow.loans._resolve_officer_id(selected_officer)
                except: pass
                repayments_today = [r for r in repayments_today if str(r.get("officer_id")).lower() == str(o_id).lower() or str(r.get("officer") or "").lower() == selected_officer.lower()]
                
            if selected_product and selected_product != "All":
                repayments_today = [r for r in repayments_today if str(r.get("client_id")) in valid_client_ids]
                
        except Exception:
            repayments_today = []'''

content = content.replace(repayments_fetching_old, repayments_fetching_new)

# Update Aggregations & Summary Calculations
aggs_old = '''        total_active_credit = sum(float(l.get("disbursed_amount") or l.get("principal") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_outstanding_balance = sum(float(l.get("active_credit") or l.get("balance") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])

        from services.savings_service import SavingsService
        total_savings = 0.0
        try:
            if scope.scope_level == "BRANCH":
                total_savings = SavingsService.get_branch_totals(uow, selected_branch or scope.branch_name).get("total_active_savings", 0.0)
            elif scope.scope_level == "OFFICER":
                total_savings = SavingsService.get_officer_totals(uow, scope.user_id).get("total_active_savings", 0.0)
            else:
                pass # Use global total if needed
        except Exception:
            pass'''

aggs_new = '''        total_active_credit = sum(float(l.get("disbursed_amount") or l.get("principal") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_outstanding_balance = sum(float(l.get("active_credit") or l.get("balance") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_expected_repayment = sum(float(l.get("loan_repay") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])

        total_savings_balance = total_savings_deposit - total_savings_withdrawal'''

content = content.replace(aggs_old, aggs_new)

# Make sure we don't return `total_savings` incorrectly, replace in dict
return_old = '''            "summary": {
                "total_registered_clients": total_registered_clients,
                "active_clients": active_clients_count,
                "closed_clients": closed_clients_count,
                "dormant_clients": dormant_clients_count,
                "total_active_credit": total_active_credit,
                "total_outstanding_balance": total_outstanding_balance,
                "total_savings": total_savings,
                "today_collection": today_collection,
                "this_week_collection": this_week_collection,
                "this_month_collection": this_month_collection,
                "full_payments": {"count": full_payments_count, "amount": full_payments_amt},
                "excess_payments": {"count": excess_payments_count, "amount": excess_payments_amt},
                "part_payments": {"count": part_payments_count, "amount": part_payments_amt},
                "overdue": {"count": overdue_count, "amount": overdue_amt},
                "par": f"{par_pct}%",
                "product_summary": product_summary
            }'''

return_new = '''            "summary": {
                "total_registered_clients": total_registered_clients,
                "active_clients": active_clients_count,
                "closed_clients": closed_clients_count,
                "dormant_clients": dormant_clients_count,
                "total_active_credit": total_active_credit,
                "total_expected_repayment": total_expected_repayment,
                "total_outstanding_balance": total_outstanding_balance,
                "total_savings_deposit": total_savings_deposit,
                "total_savings_withdrawal": total_savings_withdrawal,
                "total_savings_balance": total_savings_balance,
                "today_collection": today_collection,
                "this_week_collection": this_week_collection,
                "this_month_collection": this_month_collection,
                "full_payments": {"count": full_payments_count, "amount": full_payments_amt},
                "excess_payments": {"count": excess_payments_count, "amount": excess_payments_amt},
                "part_payments": {"count": part_payments_count, "amount": part_payments_amt},
                "overdue": {"count": overdue_count, "amount": overdue_amt},
                "par": f"{par_pct}%",
                "product_summary": product_summary
            }'''

content = content.replace(return_old, return_new)

# Update individual client mapping `c_savings = savings_map.get(cid_str, 0.0)`
c_savings_old = 'c_savings = savings_map.get(cid_str, 0.0)'
c_savings_new = "c_savings = savings_map.get(cid_str, {}).get('bal', 0.0)"
content = content.replace(c_savings_old, c_savings_new)

# Inject Group Summary dataframe logic inside `client_df = ...`
client_df_old = '''        client_df = pd.DataFrame(client_rows) if client_rows else pd.DataFrame(columns=["Client Code", "Client Name", "Group", "Savings Balance", "Principal Loan", "Active Loan", "Outstanding Balance", "Fixed Repayment", "Total Paid", "Status"])'''

client_df_new = '''        client_df = pd.DataFrame(client_rows) if client_rows else pd.DataFrame(columns=["Client Code", "Client Name", "Group", "Savings Balance", "Principal Loan", "Active Loan", "Outstanding Balance", "Fixed Repayment", "Total Paid", "Status"])
        
        if selected_group == "All" and not client_df.empty:
            group_df = client_df.groupby("Group").agg(
                Clients=("Client Code", "count"),
                Savings_Balance=("Savings Balance", "sum"),
                Active_Loan=("Active Loan", "sum"),
                Outstanding_Balance=("Outstanding Balance", "sum"),
                Fixed_Repayment=("Fixed Repayment", "sum"),
                Total_Paid=("Total Paid", "sum")
            ).reset_index()
            group_df.columns = ["Group Name", "Total Clients", "Total Savings Balance", "Total Active Loan", "Total Outstanding Balance", "Total Fixed Repayment", "Total Paid"]
            client_df = group_df'''

content = content.replace(client_df_old, client_df_new)

with open('services/portfolio_service.py', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated portfolio_service.py successfully")
