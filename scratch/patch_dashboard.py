import re

with open('app.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Let's see what metrics exist for savings
matches = re.findall(r'(\w+)\.metric\("Total Savings".*?\)', content)
print("Found Total Savings metrics:", len(matches))

# Let's just find where k1.metric("Total Savings", f"₦{total_savings:,.0f}") happens.
content = re.sub(
    r'([ \t]+)([a-zA-Z0-9_]+)\.metric\("Total Savings", f"₦\{total_savings:,\.0f\}"\)',
    r'''\1\2.metric("Total Savings", f"₦{total_savings:,.0f}")
\1\2.caption(f"Includes: Ind: ₦{ind_sav:,.0f} | Grp: ₦{grp_sav:,.0f} | Misc: ₦{misc_sav:,.0f}")
\1\2.caption(f"LAPS (Excluded): ₦{laps_sav:,.0f}")''',
    content
)

# Wait, `ind_sav`, `grp_sav`, `misc_sav` must be defined.
# I will find where `total_savings` is calculated and replace it.
dashboard_calc = """    # Calculate Branch Totals using SavingsService
    from database.repositories.unit_of_work import SupabaseUnitOfWork
    from services.savings_service import SavingsService
    try:
        with SupabaseUnitOfWork() as uow:
            sav_totals = SavingsService.get_branch_totals(uow, BRANCH)
            total_savings = sav_totals['total_active_savings']
            ind_sav = sav_totals['individual_savings']
            grp_sav = sav_totals['group_savings']
            misc_sav = sav_totals['misc_savings']
            laps_sav = sav_totals['laps_savings']
    except Exception as e:
        st.error(f"Error fetching savings from DB: {e}")
        total_savings, ind_sav, grp_sav, misc_sav, laps_sav = 0, 0, 0, 0, 0
"""

# I need to insert this right before the dashboard displays metrics.
# Usually it's around `st.markdown("### 📊 Performance Overview")` or `k1, k2, k3, k4 = st.columns(4)`

if 'k1, k2, k3, k4 = st.columns(4)' in content:
    content = content.replace('k1, k2, k3, k4 = st.columns(4)', dashboard_calc + '\n    k1, k2, k3, k4 = st.columns(4)')
    print("Injected dashboard_calc")
else:
    print("Could not find k1, k2, k3, k4")

with open('app.py', 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard patch done.")
