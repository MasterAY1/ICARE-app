import os
import re

file_path = "app.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

robust_excel_code = """
                # Read without headers to manually find them
                raw_groups = pd.read_excel(uploaded_file, sheet_name='Groups', header=None)
                raw_members = pd.read_excel(uploaded_file, sheet_name='Members', header=None)
                
                def extract_table(df, key_col1, key_col2):
                    # Search for the header row
                    header_idx = -1
                    for i, row in df.iterrows():
                        row_str = row.astype(str).str.replace('*', '', regex=False).str.strip().str.lower()
                        if key_col1.lower() in row_str.values and key_col2.lower() in row_str.values:
                            header_idx = i
                            break
                            
                    if header_idx != -1:
                        # Set headers and slice
                        df.columns = df.iloc[header_idx].astype(str).str.replace('*', '', regex=False).str.strip()
                        df = df.iloc[header_idx + 1:].reset_index(drop=True)
                        return df
                    return pd.DataFrame() # Return empty if headers not found

                df_groups = extract_table(raw_groups, 'Group Reference', 'Group Name')
                df_members = extract_table(raw_members, 'Member Reference', 'Full Name')
                
                # Filter empty rows and example/dummy rows
                if not df_groups.empty and 'Group Name' in df_groups.columns:
                    df_groups = df_groups.dropna(subset=['Group Reference', 'Group Name'])
                    df_groups = df_groups[~df_groups['Group Name'].astype(str).str.contains('Example', case=False, na=False)]
                    
                if not df_members.empty and 'Full Name' in df_members.columns:
                    df_members = df_members.dropna(subset=['Member Reference', 'Full Name'])
                    df_members = df_members[~df_members['Full Name'].astype(str).str.contains('Example', case=False, na=False)]
"""

content = re.sub(r'                df_groups = pd\.read_excel\(uploaded_file, sheet_name=\'Groups\', skiprows=2\).*?df_members\[~df_members\[\'Full Name\'\]\.astype\(str\)\.str\.contains\(\'Full Name\', case=False, na=False\)\]', robust_excel_code.strip('\n'), content, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Excel parsing engine upgraded.")
