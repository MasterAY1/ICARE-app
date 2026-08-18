import pandas as pd

def check_monsurat():
    file_path = "icare-group-member-onboarding-template.xlsx"
    df_members = pd.read_excel(file_path, sheet_name="Members", header=2)
    df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
    
    print("--- GROUPS MATCHING OLORUNSHOGO / OLUWAPELUMI ---")
    print(df_groups[df_groups['Group Name*'].str.contains('olorun|oluwapelumi', case=False, na=False)][['Group Reference*', 'Group Name*', 'Branch Name*', 'Credit Officer Name*']])
    
    print("\n--- MEMBERS MATCHING MONSURAT OLADEJI ---")
    matches = df_members[df_members['Full Name*'].str.contains('monsurat oladeji', case=False, na=False)]
    for idx, row in matches.iterrows():
        print(f"Row {idx}: Name={row['Full Name*']}, MemberNum={row['Member Number']}, GroupRef={row['Group Reference*']}, Savings={row['Savings Balance*']}, Loan={row['Active Credit (Disbursed)*']}, Bal={row['Current Credit Balance*']}")

if __name__ == "__main__":
    check_monsurat()
