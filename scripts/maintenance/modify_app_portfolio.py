import re

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the old Group filter since we want to structure it better
old_filters = '''        # Group Filter
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
        
        sel_group = st.selectbox("Filter Group", all_grp, key="port_grp_sel")'''

new_filters = '''        # Date and Product Filters
        import calendar
        from datetime import date, timedelta
        
        tf1, tf2, tf3, tf4 = st.columns(4)
        
        with tf1:
            time_period = st.selectbox("Time Period", ["Current Month", "Last Month", "Custom Date Range"], key="port_time_period")
        
        today = date.today()
        start_date = today
        end_date = today
        
        if time_period == "Current Month":
            start_date = today.replace(day=1)
            end_date = today.replace(day=calendar.monthrange(today.year, today.month)[1])
        elif time_period == "Last Month":
            first = today.replace(day=1)
            last_month = first - timedelta(days=1)
            start_date = last_month.replace(day=1)
            end_date = last_month
            
        with tf2:
            if time_period == "Custom Date Range":
                date_range = st.date_input("Date Range", [start_date, end_date], key="port_date_range")
                if isinstance(date_range, tuple) and len(date_range) == 2:
                    start_date = date_range[0]
                    end_date = date_range[1]
                elif isinstance(date_range, tuple) and len(date_range) == 1:
                    start_date = date_range[0]
                    end_date = date_range[0]
            else:
                st.date_input("Date Range", [start_date, end_date], disabled=True, key="port_date_range_disabled")
                
        all_prods = ["All"]
        try:
            p_res = uow_p.client.table("loan_products").select("name").execute()
            all_prods += sorted(list(set(p["name"] for p in (p_res.data or []) if p.get("name"))))
        except Exception:
            pass
            
        with tf3:
            sel_product = st.selectbox("Filter Loan Product", all_prods, key="port_prod_sel")

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
        
        with tf4:
            sel_group = st.selectbox("Filter Group", all_grp, key="port_grp_sel")'''

content = content.replace(old_filters, new_filters)

# Update portfolio method call
old_call = '''        p_data = PortfolioService.get_portfolio_data_for_scope(
            uow_p, p_scope, selected_branch=sel_branch, selected_officer=sel_officer, selected_group=sel_group
        )'''
new_call = '''        p_data = PortfolioService.get_portfolio_data_for_scope(
            uow_p, p_scope, selected_branch=sel_branch, selected_officer=sel_officer, selected_group=sel_group,
            selected_product=sel_product, start_date=start_date, end_date=end_date
        )'''
content = content.replace(old_call, new_call)

# Update UI metrics layout
old_metrics = '''        st.divider()
        st.markdown("### Portfolio Summary & Metrics")

        m1, m2, m3, m4, m5 = st.columns(5)
        m1.metric("Registered Clients", f"{p_sum['total_registered_clients']:,}")
        m2.metric("Active Clients", f"{p_sum['active_clients']:,}")
        m3.metric("Closed Clients", f"{p_sum['closed_clients']:,}")
        m4.metric("Dormant Clients", f"{p_sum['dormant_clients']:,}")
        m5.metric("Portfolio PAR", p_sum['par'])

        f1, f2, f3, f4 = st.columns(4)
        f1.metric("Active Credit", f"₦{p_sum['total_active_credit']:,.0f}")
        f2.metric("Outstanding Balance", f"₦{p_sum['total_outstanding_balance']:,.0f}")
        f3.metric("Total Savings", f"₦{p_sum['total_savings']:,.0f}")
        f4.metric("Today's Collection", f"₦{p_sum['today_collection']:,.0f}")

        c1, c2, c3, c4 = st.columns(4)
        c1.metric("Full Payments", f"{p_sum['full_payments']['count']} (₦{p_sum['full_payments']['amount']:,.0f})")
        c2.metric("Excess Payments", f"{p_sum['excess_payments']['count']} (₦{p_sum['excess_payments']['amount']:,.0f})")
        c3.metric("Part Payments", f"{p_sum['part_payments']['count']} (₦{p_sum['part_payments']['amount']:,.0f})")
        c4.metric("Overdue Clients", f"{p_sum['overdue']['count']} (₦{p_sum['overdue']['amount']:,.0f})")'''

new_metrics = '''        st.divider()
        st.markdown("### Portfolio Summary & Metrics")

        st.caption("Row 1: Savings Summary")
        s1, s2, s3 = st.columns(3)
        s1.metric("Total Deposits", f"₦{p_sum.get('total_savings_deposit', 0.0):,.0f}")
        s2.metric("Total Withdrawals", f"₦{p_sum.get('total_savings_withdrawal', 0.0):,.0f}")
        s3.metric("Net Savings Balance", f"₦{p_sum.get('total_savings_balance', 0.0):,.0f}")

        st.caption("Row 2: Loan Summary")
        l1, l2, l3 = st.columns(3)
        l1.metric("Total Active Credit", f"₦{p_sum.get('total_active_credit', 0.0):,.0f}")
        l2.metric("Total Expected Repayment", f"₦{p_sum.get('total_expected_repayment', 0.0):,.0f}")
        l3.metric("Total Outstanding Balance", f"₦{p_sum.get('total_outstanding_balance', 0.0):,.0f}")

        st.caption("Row 3: Repayment Status")
        r1, r2, r3, r4 = st.columns(4)
        r1.metric("Excess Payments", f"{p_sum.get('excess_payments', {}).get('count', 0)} (₦{p_sum.get('excess_payments', {}).get('amount', 0.0):,.0f})")
        r2.metric("Full Payments", f"{p_sum.get('full_payments', {}).get('count', 0)} (₦{p_sum.get('full_payments', {}).get('amount', 0.0):,.0f})")
        r3.metric("Overdue Clients", f"{p_sum.get('overdue', {}).get('count', 0)} (₦{p_sum.get('overdue', {}).get('amount', 0.0):,.0f})")
        r4.metric("Portfolio PAR", p_sum.get('par', '0.00%'))'''

content = content.replace(old_metrics, new_metrics)

# Table headers to show if it is Group Summary or Client Detail
old_table_header = 'st.markdown("### Client Portfolio")'
new_table_header = '''if sel_group == "All":
            st.markdown("### Group Portfolio Summary")
            st.caption("Showing aggregate totals per group. Select a specific group above to drill down to individual clients.")
        else:
            st.markdown(f"### Client Portfolio ({sel_group})")'''
            
content = content.replace(old_table_header, new_table_header)

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated app.py successfully")
