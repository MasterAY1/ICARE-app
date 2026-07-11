import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Let's replace the UI section around line 1076 to 1120.
# We'll use re.sub but it's safer to read lines and replace a slice.
lines = content.split('\n')
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if 'st.subheader("4. Financial Request (Applied Credit)")' in line:
        start_idx = i - 1  # include the card div
    if 'total_cash_to_collect = savings_shortfall + other_fees + extra_savings' in line:
        end_idx = i + 1
        break

if start_idx != -1 and end_idx != -1:
    new_ui = """            st.markdown("<div class='card'>", unsafe_allow_html=True)
            st.subheader("4. Financial Request (Applied Credit / Asset)")
        
            cat_col, prod_col, amt_col = st.columns(3)
            product_category = cat_col.selectbox("Product Category", ["Finance", "Asset"])
            
            if product_category == "Asset":
                product = prod_col.selectbox("Proposed Scheme", ["Cash and Carry", "60-Day Installment", "120-Day Installment"])
                amount_label = "Base Price (Asset Value ₦)"
            else:
                product = prod_col.selectbox("Proposed Scheme", ["Daily Loan (60 Days)", "Weekly Loan (12 Weeks)", "Weekly Loan (24 Weeks)"])
                amount_label = "Applied Credit Amount (Principal ₦)"
                
            amount = amt_col.number_input(amount_label, value=100000, step=5000, min_value=10000)
        
            setup = calculate_loan_setup(amount, product, product_category)
        
            st.markdown("---")
            col_gap, col_int = st.columns(2)
            
            if product_category == "Asset":
                # For Assets, the manual_gap acts as the 'Upfront Payment' which determines remaining balance
                manual_gap = col_gap.number_input("Upfront Payment (Deducted from Total Price ₦)", value=int(amount * 0.2), step=500)
            else:
                manual_gap = col_gap.number_input("Savings Balance (Gap/Deposit)", value=int(setup['initial_payment']), step=500)
                
            col_int.metric("Interest (Fixed)", f"₦{setup['interest']:,.0f}")
            
            if product_category == "Asset" and "Cash and Carry" not in product:
                total_price = amount + setup['interest']
                remaining_balance = total_price - manual_gap
                actual_repayment = remaining_balance / setup['duration']
                st.info(f"💡 **Asset Math:** Total Price (₦{total_price:,.0f}) - Upfront (₦{manual_gap:,.0f}) = Remaining ₦{remaining_balance:,.0f}. Expected {setup['freq']} Payment: **₦{actual_repayment:,.0f}**")
            elif product_category == "Asset" and "Cash and Carry" in product:
                actual_repayment = 0
                st.info(f"💡 **Asset Math:** Cash and Carry requires full upfront payment. Expected Payment: **₦0**")
        
            st.markdown("#### Origination Fees & Upfront Savings")
        
            # Base automated fees
            auto_proc = 500
            auto_group = 1000
            auto_branch = 1000
            auto_passbook = 0
        
            f1, f2, f3 = st.columns(3)
            processing_fee = f1.number_input("Processing Fee", value=auto_proc, step=50)
            group_savings = f2.number_input("Group Savings", value=auto_group, step=500)
            branch_contingency = f3.number_input("Branch Contingency", value=auto_branch, step=500)
        
            s1, s2 = st.columns(2)
            pass_book_fee = s1.number_input("Pass Book Fee (If exhausted)", value=auto_passbook, step=500)
            extra_savings = s2.number_input("Extra Personal Savings Deposit", value=2500 if not prev_client_id else 0, step=500)
        
            if product_category == "Asset":
                required_deduction = manual_gap
            else:
                required_deduction = setup['interest'] + manual_gap
                
            other_fees = processing_fee + group_savings + branch_contingency + pass_book_fee
        
            savings_available = prev_savings if prev_client_id else 0
            savings_shortfall = max(0, required_deduction - savings_available)
        
            total_cash_to_collect = savings_shortfall + other_fees + extra_savings"""
    
    lines[start_idx:end_idx] = new_ui.split('\n')
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write('\n'.join(lines))
        
    print("UI updated successfully.")
else:
    print("Could not find boundaries.")
