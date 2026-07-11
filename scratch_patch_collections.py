import sys

with open('app.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1
for i, line in enumerate(lines):
    if line.startswith('elif page == "Collections":'):
        start_idx = i
    if start_idx != -1 and line.startswith('elif page == "Daily Report":'):
        end_idx = i
        break

new_block = """elif page == "Collections":
    st.title("👥 Daily Collections & Outflows")
    st.caption("Record daily repayments, savings, and end of day outflows.")
    
    view_date = st.date_input("Select Date", datetime.now().date(), key="col_date")
    date_str = view_date.strftime("%Y-%m-%d")
    
    all_loans = load_loans()
    repayments = load_repayments()
    
    if all_loans.empty:
        st.warning("No active loans found.")
    else:
        # Filter active loans for this officer (unless BM/AM looking at all)
        if ROLE in ["BM", "AM"]:
            branch_loans = all_loans[all_loans['Branch'] == BRANCH] if ROLE == "BM" else all_loans
            unique_officers = branch_loans['Officer'].dropna().unique().tolist()
            if unique_officers:
                display_options = [CO_DISPLAY_MAP.get(o, o) for o in unique_officers]
                selected_display = st.selectbox("Select Credit Officer", display_options, key="col_co")
                target_co = CO_NAME_MAP.get(selected_display, selected_display)
            else:
                target_co = USER
        else:
            target_co = USER
            
        # Top-level tabs for Collections page
        col_tab, eod_tab = st.tabs(["👥 Member Collections", "📤 End of Day / Global Outflows"])
        
        with col_tab:
            # Show all clients that are not strictly closed, so completed clients can still deposit savings
            co_loans = all_loans[(all_loans['Officer'] == target_co) & (all_loans['Status'] != 'Closed')]
            
            if co_loans.empty:
                st.info("No active or pending members for this officer.")
            else:
                groups = ["Ungrouped"] + sorted(co_loans[co_loans['Group Name'].notna()]['Group Name'].unique().tolist())
                selected_group = st.selectbox("Select Group", groups)
                
                if selected_group == "Ungrouped":
                    group_loans = co_loans[co_loans['Group Name'].isna() | (co_loans['Group Name'] == "")]
                else:
                    group_loans = co_loans[co_loans['Group Name'] == selected_group]
                    
                if group_loans.empty:
                    st.info("No active or pending members in this group.")
                else:
                    st.markdown(f"### Members in {selected_group}")
                    
                    # Fetch history for today to prefill/check
                    today_reps = repayments[(repayments['Date'] == date_str) & (repayments['Officer'] == target_co)] if not repayments.empty else pd.DataFrame()
                    
                    # Pre-compute member data
                    member_info = {}
                    for _, member in group_loans.iterrows():
                        cid = member['Client ID']
                        mem_reps = repayments[repayments['Client ID'] == cid] if not repayments.empty else pd.DataFrame()
                        acc_sav = mem_reps['Savings Amount'].astype(float).sum() if not mem_reps.empty else 0
                        acc_wd = mem_reps['Withdrawal Amount'].astype(float).sum() if 'Withdrawal Amount' in mem_reps.columns and not mem_reps.empty else 0
                        sav_bal = acc_sav - acc_wd
                        total_paid = mem_reps['Loan Repayment Amount'].astype(float).sum() if not mem_reps.empty else 0
                        act_cred = float(member.get('Active Credit', 0))
                        rem_bal = act_cred - total_paid
                        exp_rep = float(member.get('Loan Repayment', 0))
                        today_paid = today_reps[today_reps['Client ID'] == cid] if not today_reps.empty else pd.DataFrame()
                        default_rep = exp_rep if today_paid.empty else 0.0
                        member_info[cid] = {
                            "member": member,
                            "sav_bal": sav_bal,
                            "rem_bal": rem_bal,
                            "act_cred": act_cred,
                            "default_rep": default_rep,
                            "start_date": str(member.get('Start Date', ''))
                        }
                    
                    if st.session_state.get('pending_collections') and st.session_state.get('collections_group') == selected_group and st.session_state.get('collections_date') == date_str:
                        st.markdown("### 🔍 Review Group Collections")
                        to_insert = st.session_state['pending_collections']
                        
                        total_in = sum(float(tx.get('Amount Paid', 0)) + float(tx.get('Bank Withdrawal', 0)) for tx in to_insert)
                        total_out = sum(float(tx.get('Withdrawal Amount', 0)) + float(tx.get('Expenses', 0)) + float(tx.get('Bank Deposited', 0)) + float(tx.get('Product Withdrawal', 0)) + float(tx.get('Laps Transferred', 0)) for tx in to_insert)
                        net_cash = total_in - total_out
                        
                        st.info(f"**Total Money Collected (Cash In):** ₦{total_in:,.0f}")
                        st.warning(f"**Total Money Given Out (Cash Out):** ₦{total_out:,.0f}")
                        st.success(f"**NET CASH EXPECTED FROM GROUP:** ₦{net_cash:,.0f}")
                        
                        c1, c2 = st.columns(2)
                        if c1.button("🔙 Edit / Go Back"):
                            del st.session_state['pending_collections']
                            st.rerun()
                        
                        if c2.button("✅ Confirm & Save to Database", type="primary", use_container_width=True):
                            db_payload = []
                            for tx in to_insert:
                                db_payload.append({UI_TO_DB_REP[k]: v for k, v in tx.items() if k in UI_TO_DB_REP})
                            try:
                                supabase.table('repayments').insert(db_payload).execute()
                                st.success("Group Collections Submitted Successfully!")
                                del st.session_state['pending_collections']
                                import time
                                time.sleep(2)
                                st.rerun()
                            except Exception as e:
                                st.error(f"Error saving: {e}")
                    else:
                        with st.form("collections_form"):
                            sav_data = {}
                            rep_data = {}
                            
                            # ---- GROUP-LEVEL SAVINGS ----
                            st.markdown("### 🏛️ Group-Level Savings")
                            st.caption("Input communal group savings and withdrawal amounts.")
                            gsc1, gsc2, gsc3 = st.columns(3)
                            global_group_savings = gsc1.number_input("Group Savings Deposit", min_value=0.0, step=500.0, value=None, placeholder="0")
                            global_group_wd = gsc2.number_input("Group Savings Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                            global_laps_reserved = gsc3.number_input("Laps Reserved", min_value=0.0, step=500.0, value=None, placeholder="0")
                            st.markdown("---")
                            
                            # ---- PER-CLIENT COLLECTIONS ----
                            st.markdown("### 📋 Client Collections (Savings & Repayments)")
                            for cid, info in member_info.items():
                                m = info['member']
                                prod = str(m['Loan Product'])
                                is_asset = str(cid).endswith("-ASSET")
                                
                                if is_asset:
                                    title = f"📋 {m['Client Name']} (ASSET) - Rem: ₦{info['rem_bal']:,.0f}"
                                else:
                                    title = f"👤 {m['Client Name']} ({cid}) - Rem: ₦{info['rem_bal']:,.0f} | Sav: ₦{info['sav_bal']:,.0f}"
                                    
                                with st.expander(title):
                                    s_date_str = info.get("start_date", "")
                                    s_date = pd.to_datetime(s_date_str, errors='coerce') if s_date_str and str(s_date_str).strip() not in ['None', 'nan', ''] else pd.NaT
                                    view_dt = pd.to_datetime(date_str)
                                    
                                    if pd.notna(s_date) and s_date > view_dt:
                                        st.warning(f"⚠️ **Next Repayment Due On:** {s_date.strftime('%Y-%m-%d')}")
                                        st.caption("*Collection is locked until the start date.*")
                                        continue
                                    
                                    if not is_asset:
                                        st.markdown("**🏦 Savings**")
                                        sc1, sc2 = st.columns(2)
                                        s_dep = sc1.number_input("Savings Deposit", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"sdep_{cid}")
                                        s_wd = sc2.number_input("Savings Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"swd_{cid}")
                                        sav_data[cid] = {"dep": s_dep, "wd": s_wd}
                                        st.markdown("---")
                                    
                                    st.markdown(f"**💵 Loan ({prod})** - Active Cr: ₦{info['act_cred']:,.0f}")
                                    d_rep = float(info['default_rep'])
                                    
                                    r1, r2 = st.columns(2)
                                    rep_col = r1.number_input("Credit Repayment", min_value=0.0, step=500.0, value=d_rep if d_rep > 0 else None, placeholder="0", key=f"rep_{cid}")
                                    app_col = r2.number_input("Processing Fee", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"app_{cid}")
                                    
                                    r3, r4 = st.columns(2)
                                    pb_col = r3.number_input("Pass Book", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"pb_{cid}")
                                    misc_col = r4.number_input("Misc Fee", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"misc_{cid}")
                                    
                                    a1, a2 = st.columns(2)
                                    asset_cr_col = a1.number_input("Asset Cr Sale", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"acr_{cid}")
                                    cc_col = a2.number_input("Cash & Carry", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"cc_{cid}")
                                    
                                    a3, a4 = st.columns(2)
                                    cfd_col = a3.number_input("Cr Form Dmg", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"cfd_{cid}")
                                    bonus_col = a4.number_input("Bonus", min_value=0.0, step=500.0, value=None, placeholder="0", key=f"bon_{cid}")
                                    
                                    rep_data[cid] = {
                                        "rep": rep_col, "app": app_col, "pb": pb_col, "misc": misc_col,
                                        "asset_cr": asset_cr_col, "cc": cc_col, "cfd": cfd_col, "bonus": bonus_col
                                    }
                            
                            st.markdown("---")
                            submit_btn = st.form_submit_button("Calculate Totals & Review Members", type="primary", use_container_width=True)
                            
                            if submit_btn:
                                to_insert = []
                                
                                # Process per-client data
                                for cid, info in member_info.items():
                                    m = info['member']
                                    s = sav_data.get(cid, {"dep": 0, "wd": 0})
                                    r = rep_data.get(cid, {"rep": 0, "app": 0, "pb": 0, "misc": 0, "asset_cr": 0, "cc": 0, "cfd": 0, "bonus": 0})
                                    
                                    sav = float(s['dep'] or 0)
                                    sav_wd = float(s['wd'] or 0)
                                    rep = float(r['rep'] or 0)
                                    app = float(r['app'] or 0)
                                    pb = float(r['pb'] or 0)
                                    misc = float(r['misc'] or 0)
                                    asset_cr = float(r['asset_cr'] or 0)
                                    cc = float(r['cc'] or 0)
                                    cfd = float(r['cfd'] or 0)
                                    bon = float(r['bonus'] or 0)
                                    
                                    if sav == 0 and sav_wd == 0 and rep == 0 and app == 0 and pb == 0 and misc == 0 and asset_cr == 0 and cc == 0 and cfd == 0 and bon == 0:
                                        continue
                                    
                                    prod_low = str(m['Loan Product']).lower()
                                    rep_12w = rep_24w = rep_60d = rep_120d = rep_mth = 0
                                    
                                    if "12 week" in prod_low or "12wk" in prod_low or "12w" in prod_low: rep_12w = rep
                                    elif "24 week" in prod_low or "24wk" in prod_low or "24w" in prod_low: rep_24w = rep
                                    elif "60 day" in prod_low or ("daily" in prod_low and "120" not in prod_low) or "60-day" in prod_low: rep_60d = rep
                                    elif "120 day" in prod_low or "120-day" in prod_low: rep_120d = rep
                                    elif "month" in prod_low: rep_mth = rep
                                    else: rep_60d = rep
                                    
                                    tx_data = {
                                        "Date": date_str,
                                        "Client ID": cid,
                                        "Client Name": m['Client Name'],
                                        "Officer": target_co,
                                        "Branch": m['Branch'],
                                        "Amount Paid": sav + rep + app + pb + misc + asset_cr + cc + cfd + bon,
                                        "Transaction Type": "Loan",
                                        "Note": "Daily Collection",
                                        "Savings Amount": sav,
                                        "Withdrawal Amount": sav_wd,
                                        "Loan Repayment Amount": rep,
                                        "Repayment 12 Weeks": rep_12w,
                                        "Repayment 24 Weeks": rep_24w,
                                        "Repayment 60 Days": rep_60d,
                                        "Repayment 120 Days": rep_120d,
                                        "Monthly": rep_mth,
                                        "Bank Withdrawal": 0,
                                        "Asset Sales": 0,
                                        "App Fee": app,
                                        "Pass Book Bonus": pb,
                                        "Misc Fees": misc,
                                        "Asset Credit Sales": asset_cr,
                                        "Cash and Carry": cc,
                                        "Credit Form": 0,
                                        "Credit Form Damage": cfd,
                                        "Bonus": bon,
                                        "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0,
                                        "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                        "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0,
                                        "Laps Reserved": 0, "Laps Transferred": 0,
                                        "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                                    }
                                    to_insert.append(tx_data)
                                
                                # Process Group-Level Inflows
                                global_group_savings = float(global_group_savings or 0)
                                global_group_wd = float(global_group_wd or 0)
                                global_laps_reserved = float(global_laps_reserved or 0)
                                
                                if global_group_savings > 0 or global_group_wd > 0 or global_laps_reserved > 0:
                                    g_data = {
                                        "Date": date_str, "Client ID": f"GROUP-{selected_group}", "Client Name": f"{selected_group} Meeting",
                                        "Officer": target_co, "Branch": BRANCH,
                                        "Amount Paid": global_group_savings + global_laps_reserved,
                                        "Transaction Type": "Group Meeting", "Note": "Group Level Inputs",
                                        "Savings Amount": global_group_savings, "Withdrawal Amount": global_group_wd,
                                        "Laps Reserved": global_laps_reserved,
                                        "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                                        "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0, "Bank Withdrawal": 0,
                                        "Asset Sales": 0, "App Fee": 0, "Pass Book Bonus": 0, "Misc Fees": 0, "Asset Credit Sales": 0,
                                        "Cash and Carry": 0, "Credit Form": 0, "Credit Form Damage": 0, "Bonus": 0,
                                        "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                                        "Product Withdrawal": 0, "Expenses": 0, "Bank Deposited": 0, "Laps Transferred": 0,
                                        "Group Savings Deposit": global_group_savings, "Group Savings Withdrawal": global_group_wd
                                    }
                                    to_insert.append(g_data)
                                    
                                if to_insert:
                                    st.session_state['pending_collections'] = to_insert
                                    st.session_state['collections_group'] = selected_group
                                    st.session_state['collections_date'] = date_str
                                    st.rerun()
                                else:
                                    st.warning("No data entered to save.")
                                    
        with eod_tab:
            st.markdown("### 📤 End of Day / Global Outflows")
            st.caption("Log your daily branch expenses, bank deposits, and withdrawals here.")
            
            with st.form("eod_form"):
                out_1, out_2, out_3 = st.columns(3)
                global_expenses = out_1.number_input("Office Expenses", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_bank_dep = out_2.number_input("Bank Deposited", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_bank_wd = out_3.number_input("Bank Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                
                out_4, out_5 = st.columns(2)
                global_prod_wd = out_4.number_input("Product Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_laps_trans = out_5.number_input("Laps Transferred", min_value=0.0, step=500.0, value=None, placeholder="0")
                
                st.markdown("---")
                submit_eod = st.form_submit_button("Save End of Day", type="primary", use_container_width=True)
                
                if submit_eod:
                    global_expenses = float(global_expenses or 0)
                    global_bank_dep = float(global_bank_dep or 0)
                    global_bank_wd = float(global_bank_wd or 0)
                    global_prod_wd = float(global_prod_wd or 0)
                    global_laps_trans = float(global_laps_trans or 0)
                    
                    if global_expenses > 0 or global_bank_dep > 0 or global_bank_wd > 0 or global_prod_wd > 0 or global_laps_trans > 0:
                        g_out = {
                            "Date": date_str, "Client ID": f"GLOBAL-{target_co}", "Client Name": f"{target_co} End of Day",
                            "Officer": target_co, "Branch": BRANCH,
                            "Amount Paid": 0, "Transaction Type": "End of Day", "Note": "Branch/Officer Global Inputs",
                            "Savings Amount": 0, "Withdrawal Amount": 0, "Laps Reserved": 0,
                            "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                            "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0,
                            "Bank Withdrawal": global_bank_wd, "Asset Sales": 0, "App Fee": 0, "Pass Book Bonus": 0,
                            "Misc Fees": 0, "Asset Credit Sales": 0, "Cash and Carry": 0, "Credit Form": 0, "Credit Form Damage": 0, "Bonus": 0,
                            "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                            "Product Withdrawal": global_prod_wd, "Expenses": global_expenses, "Bank Deposited": global_bank_dep, "Laps Transferred": global_laps_trans,
                            "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                        }
                        
                        db_payload = {UI_TO_DB_REP[k]: v for k, v in g_out.items() if k in UI_TO_DB_REP}
                        try:
                            supabase.table('repayments').insert([db_payload]).execute()
                            st.success("End of Day Outflows Submitted Successfully!")
                        except Exception as e:
                            st.error(f"Error saving: {e}")
                    else:
                        st.warning("No data entered to save.")
\n"""

lines[start_idx:end_idx] = [new_block]
with open('app.py', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('Successfully refactored Collections page')
