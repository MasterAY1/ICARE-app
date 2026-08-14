import os
import re

APP_PY = 'C:/Users/DELL/Desktop/Master_ AY Projects/trustmicro-credit/app.py'
PORTFOLIO_SVC = 'C:/Users/DELL/Desktop/Master_ AY Projects/trustmicro-credit/services/portfolio_service.py'

def fix_portfolio_service():
    with open(PORTFOLIO_SVC, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix Dashboard metrics for Total Outstanding Balance
    old_aggs = '''        total_active_credit = sum(float(l.get("disbursed_amount") or l.get("principal") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_outstanding_balance = sum(float(l.get("active_credit") or l.get("balance") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])
        total_expected_repayment = sum(float(l.get("loan_repay") or 0.0) for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"])'''

    new_aggs = '''        active_loans_list = [l for l in loans_raw if str(l.get("status") or "").upper() in ["ACTIVE", "APPROVED"]]
        active_loan_ids = {l.get("loan_id") for l in active_loans_list if l.get("loan_id")}
        
        total_active_credit = sum(float(l.get("active_credit") or l.get("principal") or 0.0) for l in active_loans_list)
        total_paid_on_active = sum(float(r.get("amount_paid") or 0.0) for r in repayments_raw if r.get("loan_id") in active_loan_ids and str(r.get("payment_status") or "").upper() != "FAILED")
        
        total_outstanding_balance = max(0.0, total_active_credit - total_paid_on_active)
        total_expected_repayment = sum(float(l.get("loan_repay") or 0.0) for l in active_loans_list)'''

    if old_aggs in content:
        content = content.replace(old_aggs, new_aggs)
        print("Replaced aggs in portfolio_service.py")
    else:
        print("Could not find old_aggs in portfolio_service.py")

    with open(PORTFOLIO_SVC, 'w', encoding='utf-8') as f:
        f.write(content)

def fix_app_py():
    with open(APP_PY, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Collection Page: member_dict.update
    old_update = '''                        member_dict.update({
                            "Active Credit": rem_bal,
                            "Loan Repay": expected_rep_schedule,
                            "Loan Product": loan_prod_val,
                            "Start Date": start_date_val
                        })'''
    new_update = '''                        member_dict.update({
                            "Active Credit": act_cred,
                            "Remaining Balance": rem_bal,
                            "Expected Repayment": expected_rep_schedule,
                            "Loan Product": loan_prod_val,
                            "Start Date": start_date_val
                        })'''
    if old_update in content:
        content = content.replace(old_update, new_update)
        print("Fixed member_dict.update in Collection page")
    else:
        print("Could not find old_update")

    # 2. Collection Page: display_cols
    old_disp = "display_cols = [c for c in ['Date', 'Client ID', 'Client Name', 'Officer', 'Branch', 'Loan Product', 'Loan Amount', 'Active Credit', 'Loan Repay', 'Status'] if c in filtered.columns]"
    new_disp = "display_cols = [c for c in ['Date', 'Client ID', 'Client Name', 'Officer', 'Branch', 'Loan Product', 'Loan Amount', 'Active Credit', 'Remaining Balance', 'Expected Repayment', 'Status'] if c in filtered.columns]"
    
    if old_disp in content:
        content = content.replace(old_disp, new_disp)
        print("Fixed display_cols in Collection page")
    else:
        print("Could not find display_cols")
        
    # 3. Collection Page: replace 'Loan Repay' with 'Expected Repayment' in formatting loop
    old_for_loop = "for col in ['Loan Amount', 'Active Credit', 'Loan Repay']:"
    new_for_loop = "for col in ['Loan Amount', 'Active Credit', 'Remaining Balance', 'Expected Repayment']:"
    if old_for_loop in content:
        content = content.replace(old_for_loop, new_for_loop)
        print("Fixed formatting loop")
        
    # 4. Collection Page: column_config
    old_col_config = '''                column_config={
                    "Loan Amount": st.column_config.NumberColumn(format="₦%d"),
                    "Active Credit": st.column_config.NumberColumn(format="₦%d"),
                    "Loan Repay": st.column_config.NumberColumn(format="₦%d")
                }'''
    new_col_config = '''                column_config={
                    "Loan Amount": st.column_config.NumberColumn(format="₦%d"),
                    "Active Credit": st.column_config.NumberColumn(format="₦%d"),
                    "Remaining Balance": st.column_config.NumberColumn(format="₦%d"),
                    "Expected Repayment": st.column_config.NumberColumn(format="₦%d")
                }'''
    if old_col_config in content:
        content = content.replace(old_col_config, new_col_config)
        print("Fixed column_config")

    # 5. Portfolio Page: Loan History
    old_df_l = '''                            df_l = df_l.rename(columns={
                                "loan_amount": "Loan Amount",
                                "active_credit": "Active Credit",
                                "total_due": "Total Due",
                                "status": "Status",
                                "product_category": "Product Category",
                                "date": "Date"
                            })
                            cols = ["Client ID", "Name", "Date", "Loan Amount", "Active Credit", "Total Due", "Status", "Product Category", "Product"]
                            st.dataframe(df_l[[c for c in cols if c in df_l.columns]], use_container_width=True)'''

    new_df_l = '''                            
                            df_l = df_l.rename(columns={
                                "loan_amount": "Loan Amount",
                                "active_credit": "Active Credit",
                                "loan_repay": "Expected Repayment",
                                "status": "Status",
                                "product_category": "Product Category",
                                "date": "Date"
                            })
                            
                            # Calculate Remaining Balance dynamically
                            rep_df = dd["repayment_history"]
                            if not rep_df.empty and "loan_id" in rep_df.columns:
                                paid_map = rep_df.groupby("loan_id")["amount_paid"].sum().to_dict()
                                df_l["Remaining Balance"] = df_l.apply(lambda r: max(0.0, float(r.get("Active Credit", 0.0)) - float(paid_map.get(r.get("loan_id"), 0.0))), axis=1)
                            else:
                                df_l["Remaining Balance"] = df_l["Active Credit"]
                            
                            cols = ["Client ID", "Name", "Date", "Loan Amount", "Active Credit", "Expected Repayment", "Remaining Balance", "Status", "Product Category", "Product"]
                            st.dataframe(df_l[[c for c in cols if c in df_l.columns]], use_container_width=True)'''
                            
    if old_df_l in content:
        content = content.replace(old_df_l, new_df_l)
        print("Fixed Portfolio page UI columns")
    else:
        print("Could not find old_df_l")

    # 6. Outstanding Balance row in Group Summary in Portfolio page
    old_group_disp = '''                            cols = ["Client Code", "Client Name", "Group", "Savings Balance", "Principal Loan", "Active Loan", "Outstanding Balance", "Fixed Repayment", "Total Paid", "Status"]
                            st.dataframe(df_filtered[[c for c in cols if c in df_filtered.columns]], use_container_width=True)'''
    new_group_disp = '''                            cols = ["Client Code", "Client Name", "Group", "Savings Balance", "Principal Loan", "Active Loan", "Outstanding Balance", "Fixed Repayment", "Total Paid", "Status"]
                            st.dataframe(df_filtered[[c for c in cols if c in df_filtered.columns]], use_container_width=True, hide_index=True)'''
    # Actually wait, Outstanding Balance in Group summary is derived from Active Loan? 
    # Let's check how modify_portfolio.py did it. Actually, I don't need to change it if it's fine.
    
    with open(APP_PY, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    fix_portfolio_service()
    fix_app_py()
    print("Done")
