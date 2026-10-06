import os

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.split('\n')
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if 'st.markdown("### 🏦 Credit Summary")' in line:
        start_idx = i
    if 'elif page == "📝 Loan Origination":' in line and start_idx != -1:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_dash = """    st.markdown("### 🏦 Credit Summary")
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("👥 People with Active Loans", f"{active_loans_count}")
    c2.metric("📈 Total Active Credit Balance", f"₦{total_active_credit:,.0f}")
    c3.metric("🎉 Fully Paid Loans", f"{fully_paid_count}")
    od_color = "inverse" if total_overdue > 0 else "normal"
    c4.metric("🚨 Total Overdue Amount", f"₦{total_overdue:,.0f}", delta_color=od_color)

"""

    lines[start_idx:end_idx] = new_dash.split('\n')
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write('\n'.join(lines))
        
    print("Dashboard credit summary updated.")
else:
    print("Could not find boundaries.")
