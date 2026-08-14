import pandas as pd

excel_path = r"C:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\icare-group-member-onboarding-template.xlsx"

# Groups sheet
df_g = pd.read_excel(excel_path, sheet_name="Groups", skiprows=1)
print("=== GROUPS HEADERS ===")
print(df_g.columns.tolist())
print(f"Non-empty groups count: {len(df_g.dropna(subset=[df_g.columns[0]]))}")
print(df_g.dropna(subset=[df_g.columns[0]]).head(10))

# Members sheet
df_m = pd.read_excel(excel_path, sheet_name="Members", skiprows=1)
print("\n=== MEMBERS HEADERS ===")
print(df_m.columns.tolist())
print(f"Non-empty members count: {len(df_m.dropna(subset=[df_m.columns[0]]))}")
print(df_m.dropna(subset=[df_m.columns[0]]).head(10))
