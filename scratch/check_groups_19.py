import pandas as pd

def check_groups():
    file_path = "icare-group-member-onboarding-template.xlsx"
    df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
    print(df_groups[df_groups['Group Reference*'].isin(['GRP-12', 'GRP-18', 'GRP-19'])][['Group Reference*', 'Group Name*', 'Branch Name*', 'Credit Officer Name*', 'Meeting Day*']])

if __name__ == "__main__":
    check_groups()
