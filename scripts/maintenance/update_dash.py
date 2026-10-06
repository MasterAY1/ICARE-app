import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.split('\n')
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if 'if page == "📊 Dashboard":' in line:
        start_idx = i
    if 'elif page == "📝 Loan Origination":' in line and start_idx != -1:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_dash = """if page == "📊 Dashboard":
    st.title("📊 Performance & Risk Dashboard")
    
    all_loans = load_loans()
    all_repayments = load_repayments()
    my_loans = get_clients_for_user(all_loans, ROLE, USER, BRANCH)
    
    total_people_with_savings = 0
    total_savings = 0
    active_loans_count = 0
    total_active_credit = 0
    fully_paid_count = 0
    total_overdue = 0
    
    for _, loan in my_loans.iterrows():
        cid = loan.get('Client ID')
        c_payments = all_repayments[all_repayments['Client ID'] == cid]
        s_amt, l_amt = calculate_client_savings(c_payments, loan.get('Loan Repay', 0))
        
        loan_bal = loan.get('Active Credit', 0) - l_amt
        
        if s_amt > 0:
            total_people_with_savings += 1
            total_savings += s_amt
            
        if loan_bal > 0:
            active_loans_count += 1
            total_active_credit += loan_bal
            
            # calculate overdue
            start_date_str = loan.get('Date', '')
            product = loan.get('Loan Product', '')
            fixed_repay = loan.get('Loan Repay', 0)
            if start_date_str and product:
                exp_paid, overdue_amt = calculate_overdue(start_date_str, product, fixed_repay, l_amt)
                total_overdue += overdue_amt
        else:
            fully_paid_count += 1
            
    st.markdown("### 💰 Savings Summary")
    s1, s2 = st.columns(2)
    s1.metric("👥 People with Savings", f"{total_people_with_savings}")
    s2.metric("🐷 Total Savings Balance", f"₦{total_savings:,.0f}")
    
    st.divider()
    
    st.markdown("### 🏦 Credit Summary")
    c1, c2, c3 = st.columns(3)
    c1.metric("📈 Active Loans (Count)", f"{active_loans_count}")
    c2.metric("🎉 Fully Paid Loans", f"{fully_paid_count}")
    od_color = "inverse" if total_overdue > 0 else "normal"
    c3.metric("🚨 Total Overdue Amount", f"₦{total_overdue:,.0f}", delta_color=od_color)

"""

    lines[start_idx:end_idx] = new_dash.split('\n')
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write('\n'.join(lines))
        
    print("Dashboard updated.")
else:
    print("Could not find boundaries.")
