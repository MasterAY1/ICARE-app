import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

whatsapp_page_code = """elif page == "📖 WhatsApp Cashbook":
    st.title("📖 WhatsApp Cashbook")
    st.caption("Daily Reconciliation Dashboard (Left vs Right)")
    
    view_date = st.date_input("Select Date", datetime.now().date(), key="wa_date")
    date_str = view_date.strftime("%Y-%m-%d")
    
    repayments = load_repayments()
    
    if not repayments.empty:
        repayments['DateStr'] = pd.to_datetime(repayments['Date'], errors='coerce').dt.date.astype(str)
        daily_reps = repayments[repayments['DateStr'] == date_str]
        
        if ROLE == "BM":
            daily_reps = daily_reps[daily_reps['Branch'] == BRANCH]
        elif ROLE == "Officer":
            daily_reps = daily_reps[daily_reps['Officer'] == USER]
            
        if daily_reps.empty:
            st.info(f"No transactions found for {date_str}.")
        else:
            # Calculate Inflows (Left)
            total_savings_dep = pd.to_numeric(daily_reps['Savings Amount'], errors='coerce').fillna(0).sum()
            total_loan_rep = pd.to_numeric(daily_reps['Loan Repayment Amount'], errors='coerce').fillna(0).sum()
            total_overdue = pd.to_numeric(daily_reps['Others Amount'], errors='coerce').fillna(0).sum()
            total_recoveries = pd.to_numeric(daily_reps['Recovery Amount'], errors='coerce').fillna(0).sum()
            total_excess = pd.to_numeric(daily_reps['excess_amount'], errors='coerce').fillna(0).sum()
            
            total_passbook = pd.to_numeric(daily_reps['Pass Book Paid'], errors='coerce').fillna(0).sum()
            total_proc_fees = pd.to_numeric(daily_reps['Processing Fee Paid'], errors='coerce').fillna(0).sum()
            total_mgt_fees = pd.to_numeric(daily_reps['Mgt Fee Paid'], errors='coerce').fillna(0).sum()
            total_init_pay = pd.to_numeric(daily_reps['initial_payment'], errors='coerce').fillna(0).sum()
            total_asset_sales = pd.to_numeric(daily_reps['asset_sales_paid'], errors='coerce').fillna(0).sum()
            total_contingency = pd.to_numeric(daily_reps['contingency_paid'], errors='coerce').fillna(0).sum()
            
            # Brought forward cash (Can be inputted)
            bf_cash = st.sidebar.number_input("Brought Forward Cash (₦)", value=0, step=500)
            cash_banked = st.sidebar.number_input("Cash Banked / Deposited (₦)", value=0, step=500)
            
            left_total = (bf_cash + total_savings_dep + total_loan_rep + total_overdue + total_recoveries + 
                          total_excess + total_passbook + total_proc_fees + total_mgt_fees + 
                          total_init_pay + total_asset_sales + total_contingency)
                          
            # Calculate Outflows (Right)
            total_withdrawal = pd.to_numeric(daily_reps['Withdrawal Amount'], errors='coerce').fillna(0).sum()
            total_cash_return = pd.to_numeric(daily_reps['Markup Paid'], errors='coerce').fillna(0).sum() # Cash Return
            
            # Parse adjustments from Note (since we didn't save it directly)
            # Example note: "Week 4 Group Collection | Adj:0"
            def get_adj(note):
                if isinstance(note, str) and "| Adj:" in note:
                    try:
                        return float(note.split("| Adj:")[1].strip())
                    except:
                        pass
                return 0.0
            
            daily_reps['parsed_adj'] = daily_reps['Note'].apply(get_adj)
            total_adjustments = daily_reps['parsed_adj'].sum()
            
            right_total = total_withdrawal + total_cash_return + total_adjustments + cash_banked
            
            st.markdown("---")
            left_col, right_col = st.columns(2)
            
            with left_col:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.subheader("🟢 LEFT (INFLOWS)")
                st.write(f"**Brought Forward:** ₦{bf_cash:,.0f}")
                st.write(f"**Savings Deposit:** ₦{total_savings_dep:,.0f}")
                st.write(f"**Installment Collection:** ₦{total_loan_rep:,.0f}")
                st.write(f"**Overdue Collected:** ₦{total_overdue:,.0f}")
                st.write(f"**Recoveries:** ₦{total_recoveries:,.0f}")
                st.write(f"**Excess:** ₦{total_excess:,.0f}")
                st.write(f"**Passbook Sales:** ₦{total_passbook:,.0f}")
                st.write(f"**Processing Fees:** ₦{total_proc_fees:,.0f}")
                st.write(f"**Mgt Fees:** ₦{total_mgt_fees:,.0f}")
                st.write(f"**Initial Payments:** ₦{total_init_pay:,.0f}")
                st.write(f"**Asset Sales:** ₦{total_asset_sales:,.0f}")
                st.write(f"**Contingency:** ₦{total_contingency:,.0f}")
                st.markdown("---")
                st.markdown(f"### Total Left: ₦{left_total:,.0f}")
                st.markdown("</div>", unsafe_allow_html=True)
                
            with right_col:
                st.markdown("<div class='card'>", unsafe_allow_html=True)
                st.subheader("🔴 RIGHT (OUTFLOWS)")
                st.write(f"**Savings Withdrawal:** ₦{total_withdrawal:,.0f}")
                st.write(f"**Cash Return:** ₦{total_cash_return:,.0f}")
                st.write(f"**Adjustments:** ₦{total_adjustments:,.0f}")
                st.write(f"**Cash Banked:** ₦{cash_banked:,.0f}")
                st.write(f"*(All active payouts today)*")
                st.markdown("---")
                st.markdown(f"### Total Right: ₦{right_total:,.0f}")
                st.markdown("</div>", unsafe_allow_html=True)
                
            st.markdown("---")
            st.markdown("## ⚖️ Golden Rule Validation")
            
            difference = left_total - right_total
            if difference == 0:
                st.success("## ✅ BALANCED")
                st.write("Your cashbook perfectly aligns! No shortage, no excess.")
            elif difference > 0:
                st.error(f"## 🚨 SHORTAGE / CASH AT HAND of ₦{difference:,.0f}")
                st.write("Your Inflows (Left) exceed your Outflows (Right). This means you should have this exact amount in physical cash right now, OR there is a shortage if you don't.")
            else:
                st.info(f"## 💎 EXCESS / OVERPAYMENT of ₦{abs(difference):,.0f}")
                st.write("Your Outflows (Right) exceed your Inflows (Left). This means you've banked or paid out more than recorded, OR there is an undocumented excess.")
                
    else:
        st.info("No records found.")

"""

lines = content.split('\n')
for i, line in enumerate(lines):
    if 'elif page == "📒 Cash Book":' in line:
        lines.insert(i, whatsapp_page_code)
        break

with open(file_path, "w", encoding="utf-8") as f:
    f.write('\n'.join(lines))

print("Phase 3 UI inserted")
