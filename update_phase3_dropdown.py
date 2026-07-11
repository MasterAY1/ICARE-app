import os
import re

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# For Daily Report
daily_report_section_search = r'(elif page == "📅 Daily Report":\n.*?)(?=elif page == "📖 WhatsApp Cashbook":)'
daily_match = re.search(daily_report_section_search, content, re.DOTALL)

if daily_match:
    daily_code = daily_match.group(1)
    
    # We need to inject the dropdown before we filter for daily_reps
    # Current:
    # daily_reps = repayments[repayments['DateStr'] == date_str]
    # if ROLE == "BM":
    #     daily_reps = daily_reps[daily_reps['Branch'] == BRANCH]
    # elif ROLE == "Officer":
    #     daily_reps = daily_reps[daily_reps['Officer'] == USER]
    
    dropdown_injection = """
        daily_reps = repayments[repayments['DateStr'] == date_str]
        
        # --- MANAGERIAL DROPDOWN ---
        if ROLE in ["BM", "AM"]:
            st.markdown("### 🏢 Managerial Controls")
            # Get unique officers for this branch today
            if ROLE == "BM":
                daily_reps = daily_reps[daily_reps['Branch'] == BRANCH]
            
            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if not unique_officers:
                st.info("No officers have records for today.")
                target_officer = "All Officers"
            else:
                target_officer = st.selectbox("Select Credit Officer", ["All Officers"] + unique_officers, key="daily_rep_co")
                
            if target_officer != "All Officers":
                daily_reps = daily_reps[daily_reps['Officer'] == target_officer]
                if not all_loans.empty:
                    daily_loans = daily_loans[daily_loans['Officer'] == target_officer]
        elif ROLE == "Officer":
            daily_reps = daily_reps[daily_reps['Officer'] == USER]
"""
    # Replace the old filtering logic with this
    daily_code = re.sub(r'        daily_reps = repayments\[repayments\[\'DateStr\'\] == date_str\].*?elif ROLE == "Officer":\n.*?daily_reps = daily_reps\[daily_reps\[\'Officer\'\] == USER\]', dropdown_injection, daily_code, flags=re.DOTALL)
    
    content = content.replace(daily_match.group(1), daily_code)


# For WhatsApp Cashbook
cashbook_section_search = r'(elif page == "📖 WhatsApp Cashbook":\n.*?)(?=elif page == "📒 Cash Book":)'
cash_match = re.search(cashbook_section_search, content, re.DOTALL)

if cash_match:
    cash_code = cash_match.group(1)
    
    dropdown_injection2 = """
        daily_reps = repayments[repayments['DateStr'] == date_str]
        
        # --- MANAGERIAL DROPDOWN ---
        if ROLE in ["BM", "AM"]:
            st.markdown("### 🏢 Managerial Controls")
            if ROLE == "BM":
                daily_reps = daily_reps[daily_reps['Branch'] == BRANCH]
                
            unique_officers = daily_reps['Officer'].dropna().unique().tolist()
            if not unique_officers:
                st.info("No officers have records for today.")
                target_officer = "All Officers"
            else:
                target_officer = st.selectbox("Select Credit Officer", ["All Officers"] + unique_officers, key="wa_cashbook_co")
                
            if target_officer != "All Officers":
                daily_reps = daily_reps[daily_reps['Officer'] == target_officer]
        elif ROLE == "Officer":
            daily_reps = daily_reps[daily_reps['Officer'] == USER]
"""
    cash_code = re.sub(r'        daily_reps = repayments\[repayments\[\'DateStr\'\] == date_str\].*?elif ROLE == "Officer":\n.*?daily_reps = daily_reps\[daily_reps\[\'Officer\'\] == USER\]', dropdown_injection2, cash_code, flags=re.DOTALL)
    
    content = content.replace(cash_match.group(1), cash_code)


with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Phase 3 Dropdowns added.")
