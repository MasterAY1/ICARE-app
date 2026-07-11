import pandas as pd

file_path = 'icare-group-member-onboarding-template.xlsx'
df_groups = pd.read_excel(file_path, sheet_name='Groups', header=None)
print("Groups rows:")
print(df_groups.head(5).to_string())
