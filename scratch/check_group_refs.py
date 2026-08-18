import pandas as pd

def check_group_refs():
    file_path = "icare-group-member-onboarding-template.xlsx"
    df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
    valid_groups = df_groups[df_groups['Group Reference*'].notna() & (df_groups['Group Reference*'] != '')].copy()
    
    print(f"Total valid groups: {len(valid_groups)}")
    for idx, row in valid_groups.iterrows():
        g_ref = str(row['Group Reference*']).strip()
        g_name = str(row['Group Name*']).strip()
        print(f"  {g_ref} -> {g_name}")

if __name__ == "__main__":
    check_group_refs()
