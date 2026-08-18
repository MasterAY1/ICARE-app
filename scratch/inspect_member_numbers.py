import pandas as pd

def inspect_member_numbers():
    file_path = "icare-group-member-onboarding-template.xlsx"
    df_members = pd.read_excel(file_path, sheet_name="Members", header=2)
    valid_members = df_members[df_members['Group Reference*'].notna() & df_members['Full Name*'].notna()].copy()
    
    has_num = valid_members['Member Number'].notna()
    print(f"Total valid members: {len(valid_members)}")
    print(f"Members with Member Number: {has_num.sum()}")
    print(f"Members without Member Number: {(~has_num).sum()}")
    
    print("\nSample with Member Number:")
    print(valid_members[['Full Name*', 'Group Reference*', 'Member Number']].head(10))

if __name__ == "__main__":
    inspect_member_numbers()
