import pandas as pd
df_groups = pd.read_excel("icare-group-member-onboarding-template.xlsx", sheet_name='Groups')
print("Groups rows:")
print(df_groups.head(10).to_string())

df_members = pd.read_excel("icare-group-member-onboarding-template.xlsx", sheet_name='Members')
print("\nMembers rows:")
print(df_members.head(10).to_string())
