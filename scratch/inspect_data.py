import pandas as pd

excel_path = r"C:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\icare-group-member-onboarding-template.xlsx"

df_g = pd.read_excel(excel_path, sheet_name="Groups", header=1)
print("=== GROUPS COLUMNS ===")
print(df_g.columns.tolist())
# Filter rows where Group Name is not null
df_g_valid = df_g[df_g['Group Name*'].notna()]
print(f"Valid Groups: {len(df_g_valid)}")
print(df_g_valid.to_string())

df_m = pd.read_excel(excel_path, sheet_name="Members", header=1)
print("\n=== MEMBERS COLUMNS ===")
print(df_m.columns.tolist())
# Filter rows where First Name or Full Name is not null
name_col = [c for c in df_m.columns if 'name' in c.lower() or 'member' in c.lower()]
print("Name related cols:", name_col)
df_m_valid = df_m[df_m['First Name*'].notna()]
print(f"Valid Members: {len(df_m_valid)}")
print(df_m_valid.to_string())
