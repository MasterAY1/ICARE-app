import pandas as pd

excel_path = r"C:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\icare-group-member-onboarding-template.xlsx"

for sheet in ["Groups", "Members"]:
    print(f"\n================ SHEET: {sheet} ================")
    df = pd.read_excel(excel_path, sheet_name=sheet, header=None)
    for i in range(min(5, len(df))):
        print(f"Row {i}: {df.iloc[i].tolist()}")
