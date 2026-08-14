import pandas as pd

excel_path = r"C:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\icare-group-member-onboarding-template.xlsx"

df_g = pd.read_excel(excel_path, sheet_name="Groups", header=2)
df_m = pd.read_excel(excel_path, sheet_name="Members", header=2)

print("=== GROUPS WITH DATA ===")
valid_g = df_g[df_g['Group Name*'].notna()]
print(f"Total Groups: {len(valid_g)}")
for idx, row in valid_g.iterrows():
    print(f"Ref: {row['Group Reference*']} | Group: {row['Group Name*']} | Leader: {row.get('Group Leader Name*')} | Officer: {row.get('Credit Officer Name*')} | Meeting: {row.get('Meeting Day*')} | Savings: {row.get('Group Savings')}")

print("\n=== MEMBERS WITH DATA (SAMPLE) ===")
valid_m = df_m[df_m['Full Name*'].notna()]
print(f"Total Members: {len(valid_m)}")
# Check how many have savings, loans, addresses, phones
has_sav = valid_m[valid_m['Savings Balance*'].notna()]
has_loan = valid_m[valid_m['Active Credit (Disbursed)*'].notna()]
print(f"Members with Savings: {len(has_sav)}")
print(f"Members with Loans: {len(has_loan)}")
print("\nSample members with savings/loans:")
print(valid_m[valid_m['Savings Balance*'].notna() | valid_m['Active Credit (Disbursed)*'].notna()].head(20).to_string())
