import openpyxl
import pandas as pd
import glob
import os

excel_files = glob.glob("*.xlsx")
print(f"Found Excel files: {excel_files}")

for filename in excel_files:
    if filename.startswith("~$"):
        continue
    print(f"\n==================================================")
    print(f"FILE: {filename}")
    print(f"==================================================")
    try:
        wb = openpyxl.load_workbook(filename, read_only=True)
        sheetnames = wb.sheetnames
        print(f"Sheets: {sheetnames}")
        
        for sheet in sheetnames[:3]:  # print first 3 sheets to avoid too much noise
            print(f"\n--- Sheet: {sheet} ---")
            df = pd.read_excel(filename, sheet_name=sheet)
            print(f"Shape: {df.shape}")
            print(f"Columns: {df.columns.tolist()[:10]}")
            print("First 2 rows:")
            print(df.head(2).to_string())
    except Exception as e:
        print(f"Error reading {filename}: {e}")
