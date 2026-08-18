import pandas as pd

def check_all_duplicates():
    file_path = "icare-group-member-onboarding-template.xlsx"
    df_members = pd.read_excel(file_path, sheet_name="Members", header=2)
    df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
    
    group_map = dict(zip(df_groups['Group Reference*'], df_groups['Group Name*']))
    co_map = dict(zip(df_groups['Group Reference*'], df_groups['Credit Officer Name*']))
    
    valid_members = df_members[df_members['Group Reference*'].notna() & df_members['Full Name*'].notna()].copy()
    valid_members['CleanName'] = valid_members['Full Name*'].astype(str).str.strip().str.lower()
    
    name_counts = valid_members['CleanName'].value_counts()
    dup_names = name_counts[name_counts > 1].index.tolist()
    
    print(f"Total duplicate names in Members sheet: {len(dup_names)}")
    for name in dup_names:
        sub = valid_members[valid_members['CleanName'] == name]
        print(f"\n--- Name: '{name}' (Appears {len(sub)} times) ---")
        for idx, row in sub.iterrows():
            g_ref = row['Group Reference*']
            g_name = group_map.get(g_ref, 'Unknown')
            co_name = co_map.get(g_ref, 'Unknown')
            print(f"  Row {idx}: Name='{row['Full Name*']}', MemberNum={row['Member Number']}, GroupRef={g_ref} ({g_name}), CO={co_name}, Savings={row['Savings Balance*']}, Loan={row['Active Credit (Disbursed)*']}")

if __name__ == "__main__":
    check_all_duplicates()
