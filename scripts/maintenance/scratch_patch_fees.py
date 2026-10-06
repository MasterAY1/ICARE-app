with open('app.py', 'r', encoding='utf-8') as f:
    text = f.read()

import re

# 1. Update the member loop UI
member_loop_old = '''                                    st.markdown(f"**💵 Loan ({prod})** - Active Cr: ₦{info['act_cred']:,.0f}")
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
                                    }'''

member_loop_new = '''                                    st.markdown(f"**💵 Loan ({prod})** - Active Cr: ₦{info['act_cred']:,.0f}")
                                    d_rep = float(info['default_rep'])
                                    
                                    rep_col = st.number_input(f"Credit Repayment (Expected: ₦{d_rep:,.0f})", min_value=0.0, step=500.0, value=d_rep if d_rep > 0 else None, placeholder="0", key=f"rep_{cid}")
                                    
                                    rep_data[cid] = {
                                        "rep": rep_col, "app": 0, "pb": 0, "misc": 0,
                                        "asset_cr": 0, "cc": 0, "cfd": 0, "bonus": 0
                                    }'''

# 2. Update EOD form
eod_old = '''                out_1, out_2, out_3 = st.columns(3)
                global_expenses = out_1.number_input("Office Expenses", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_bank_dep = out_2.number_input("Bank Deposited", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_bank_wd = out_3.number_input("Bank Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                
                out_4, out_5 = st.columns(2)
                global_prod_wd = out_4.number_input("Product Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_laps_trans = out_5.number_input("Laps Transferred", min_value=0.0, step=500.0, value=None, placeholder="0")'''

eod_new = '''                out_1, out_2, out_3 = st.columns(3)
                global_expenses = out_1.number_input("Office Expenses", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_bank_dep = out_2.number_input("Bank Deposited", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_bank_wd = out_3.number_input("Bank Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                
                out_4, out_5 = st.columns(2)
                global_prod_wd = out_4.number_input("Product Withdrawal", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_laps_trans = out_5.number_input("Laps Transferred", min_value=0.0, step=500.0, value=None, placeholder="0")
                
                st.markdown("---")
                st.markdown("### Additional Global Collections")
                fee_1, fee_2, fee_3 = st.columns(3)
                global_app_fee = fee_1.number_input("Processing Fee", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_passbook = fee_2.number_input("Pass Book", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_misc_fee = fee_3.number_input("Misc Fee", min_value=0.0, step=500.0, value=None, placeholder="0")
                
                fee_4, fee_5, fee_6 = st.columns(3)
                global_asset_cr = fee_4.number_input("Asset Cr Sale", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_cc = fee_5.number_input("Cash & Carry", min_value=0.0, step=500.0, value=None, placeholder="0")
                global_cfd = fee_6.number_input("Cr Form Dmg", min_value=0.0, step=500.0, value=None, placeholder="0")
                
                global_bonus = st.number_input("Bonus", min_value=0.0, step=500.0, value=None, placeholder="0")'''

# 3. Update EOD saving logic
eod_save_old = '''                    global_expenses = float(global_expenses or 0)
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
                        }'''

eod_save_new = '''                    global_expenses = float(global_expenses or 0)
                    global_bank_dep = float(global_bank_dep or 0)
                    global_bank_wd = float(global_bank_wd or 0)
                    global_prod_wd = float(global_prod_wd or 0)
                    global_laps_trans = float(global_laps_trans or 0)
                    
                    global_app_fee = float(global_app_fee or 0)
                    global_passbook = float(global_passbook or 0)
                    global_misc_fee = float(global_misc_fee or 0)
                    global_asset_cr = float(global_asset_cr or 0)
                    global_cc = float(global_cc or 0)
                    global_cfd = float(global_cfd or 0)
                    global_bonus = float(global_bonus or 0)
                    
                    if any(x > 0 for x in [global_expenses, global_bank_dep, global_bank_wd, global_prod_wd, global_laps_trans, 
                                           global_app_fee, global_passbook, global_misc_fee, global_asset_cr, global_cc, global_cfd, global_bonus]):
                        g_out = {
                            "Date": date_str, "Client ID": f"GLOBAL-{target_co}", "Client Name": f"{target_co} End of Day",
                            "Officer": target_co, "Branch": BRANCH,
                            "Amount Paid": sum([global_app_fee, global_passbook, global_misc_fee, global_asset_cr, global_cc, global_cfd, global_bonus]),
                            "Transaction Type": "End of Day", "Note": "Branch/Officer Global Inputs",
                            "Savings Amount": 0, "Withdrawal Amount": 0, "Laps Reserved": 0,
                            "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
                            "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0,
                            "Bank Withdrawal": global_bank_wd, "Asset Sales": 0, "App Fee": global_app_fee, "Pass Book Bonus": global_passbook,
                            "Misc Fees": global_misc_fee, "Asset Credit Sales": global_asset_cr, "Cash and Carry": global_cc, "Credit Form": 0, "Credit Form Damage": global_cfd, "Bonus": global_bonus,
                            "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
                            "Product Withdrawal": global_prod_wd, "Expenses": global_expenses, "Bank Deposited": global_bank_dep, "Laps Transferred": global_laps_trans,
                            "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
                        }'''

if member_loop_old in text:
    print("Found member loop")
else:
    print("MEMBER LOOP NOT FOUND")

if eod_old in text:
    print("Found EOD old")
else:
    print("EOD OLD NOT FOUND")

if eod_save_old in text:
    print("Found EOD save old")
else:
    print("EOD SAVE OLD NOT FOUND")

text = text.replace(member_loop_old, member_loop_new)
text = text.replace(eod_old, eod_new)
text = text.replace(eod_save_old, eod_save_new)

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(text)
print('Replaced sections successfully')
