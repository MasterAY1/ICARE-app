import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.split('\n')
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if 'st.subheader("💸 Record Granular Collection")' in line:
        start_idx = i + 1
    if 'import time' in line and start_idx != -1:
        end_idx = i + 2
        break

if start_idx != -1 and end_idx != -1:
    new_form = """        with st.form("pay_form"):
            st.caption(f"Expected Fixed Repayment: **₦{fixed_repay:,.0f}**")
            
            st.markdown("**1. Core Collections**")
            c1, c2 = st.columns(2)
            loan_rep = c1.number_input("Installment Collection (₦)", value=int(auto_loan_rep), step=500)
            savings_dep = c2.number_input("Savings Deposit (₦)", value=int(auto_savings_dep), step=500)
            
            st.markdown("**2. Exceptions**")
            e1, e2, e3 = st.columns(3)
            overdue_coll = e1.number_input("Overdue Collected (₦)", value=0, step=500)
            recoveries = e2.number_input("Recoveries (₦)", value=0, step=500)
            excess = e3.number_input("Excess (₦)", value=0, step=500)
            
            st.markdown("**3. Fees & Sales**")
            f1, f2, f3 = st.columns(3)
            pass_book = f1.number_input("Passbook Sales (₦)", value=0, step=100)
            proc_fees = f2.number_input("Processing Fees (₦)", value=0, step=500)
            mgt_fees = f3.number_input("Mgt Fees (₦)", value=0, step=500)
            
            fs1, fs2, fs3 = st.columns(3)
            init_pay = fs1.number_input("Initial Payments (₦)", value=0, step=500)
            asset_sales = fs2.number_input("Asset Sales (₦)", value=0, step=500)
            contingency = fs3.number_input("Contingency (₦)", value=0, step=500)
            
            st.markdown("**4. Outflows (Deductions)**")
            o1, o2, o3 = st.columns(3)
            withdrawal = o1.number_input("Savings Withdrawal (₦)", value=0, step=500)
            cash_return = o2.number_input("Cash Return (₦)", value=0, step=500)
            adjustments = o3.number_input("Adjustments (₦)", value=0, step=500)
            
            note_col = st.text_input("Note", placeholder="e.g. Week 4 Group Collection")
            
            # Auto-calculate total cash layout for sanity check
            total_cash_in = (loan_rep + savings_dep + overdue_coll + recoveries + excess + 
                             pass_book + proc_fees + mgt_fees + init_pay + asset_sales + contingency)
            total_cash_out = withdrawal + cash_return + adjustments
            net_cash = total_cash_in - total_cash_out
            
            st.info(f"**Total Cash IN:** ₦{total_cash_in:,.0f} | **Total Cash OUT:** ₦{total_cash_out:,.0f} | **Net Cash Collected:** ₦{net_cash:,.0f}")
            
            if st.form_submit_button("🏦 AUTHORIZE CASH POSTING"):
                pay_data = {
                    "Date": datetime.now().strftime("%Y-%m-%d %H:%M"),
                    "Branch": BRANCH,
                    "Client ID": selected_id,
                    "Client Name": client_loan['Client Name'],
                    "Amount Paid": net_cash,
                    "Officer": USER,
                    "Note": note_col,
                    "Transaction Type": "Loan",
                    "Savings Amount": savings_dep,
                    "Loan Repayment Amount": loan_rep,
                    "Processing Fee Paid": proc_fees,
                    "Markup Paid": cash_return,
                    "Pass Book Paid": pass_book,
                    "Recovery Amount": recoveries,
                    "Withdrawal Amount": withdrawal,
                    "Mgt Fee Paid": mgt_fees,
                    "Others Amount": overdue_coll,
                    "asset_sales_paid": asset_sales,
                    "contingency_paid": contingency,
                    "excess_amount": excess,
                    "initial_payment": init_pay
                }
                # Since we changed columns, we map overdue_coll to Others Amount, cash_return to Markup Paid
                
                # Check if this exact payment pays them off!
                total_loan_contribution = loan_rep + overdue_coll + recoveries + init_pay
                if loan_balance_left - total_loan_contribution <= 0 and loan_balance_left > 0:
                    st.balloons()
                    
                save_repayment(pay_data)
                
                st.success("✅ Detailed Collection Recorded Globally!")
                
                import time
                time.sleep(1.5)
                st.rerun()"""

    lines[start_idx:end_idx] = new_form.split('\n')
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write('\n'.join(lines))
        
    print("Phase 1 UI updated.")
else:
    print("Could not find Phase 1 boundaries.")
