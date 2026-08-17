import pandas as pd

def check_excel():
    file_path = "icare-group-member-onboarding-template.xlsx"
    df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
    df_members = pd.read_excel(file_path, sheet_name="Members", header=2)
    
    print(f"Total rows in Groups sheet: {len(df_groups)}")
    valid_groups = df_groups[df_groups['Group Reference*'].notna() & (df_groups['Group Reference*'] != '')]
    print(f"Valid groups: {len(valid_groups)}")
    
    print(f"Total rows in Members sheet: {len(df_members)}")
    valid_members = df_members[df_members['Group Reference*'].notna() & (df_members['Group Reference*'] != '') & df_members['Full Name*'].notna()]
    print(f"Valid members: {len(valid_members)}")
    
    loans_in_excel = valid_members[valid_members['Active Credit (Disbursed)*'].notna() & (valid_members['Active Credit (Disbursed)*'] > 0)]
    print(f"Loans with Active Credit > 0: {len(loans_in_excel)}")
    for idx, row in loans_in_excel.iterrows():
        print(f"  - {row['Full Name*']} | Product: {row['Loan Type (Product)*']} | Credit: {row['Active Credit (Disbursed)*']} | Bal: {row['Current Credit Balance*']}")
        
    sav_in_excel = valid_members[valid_members['Savings Balance*'].notna() & (valid_members['Savings Balance*'] > 0)]
    print(f"Members with Savings Balance > 0: {len(sav_in_excel)}")
    
    grp_sav = valid_groups[valid_groups['Group Savings'].notna() & (valid_groups['Group Savings'] > 0)]
    print(f"Groups with Group Savings > 0: {len(grp_sav)}")

if __name__ == "__main__":
    check_excel()
