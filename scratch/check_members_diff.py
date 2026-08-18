import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
import pandas as pd
from database.repositories.unit_of_work import SupabaseUnitOfWork

df_m = pd.read_excel('icare-group-member-onboarding-template.xlsx', sheet_name='Members', header=2)

with SupabaseUnitOfWork() as uow:
    db_c = uow.client.table('clients').select('name, client_code').execute().data
    db_codes = {c['client_code']: c['name'] for c in db_c}

print(f"Total Rows in Excel: {len(df_m)}")
print(f"Total Clients in DB: {len(db_c)}")

seen_codes = {}
for idx, r in df_m.iterrows():
    g_ref = str(r['Group Reference*']).strip()
    m_num = r['Member Number']
    f_name = str(r['Full Name*']).strip()
    
    gn = int(g_ref.replace('GRP-', ''))
    seq = int(float(str(m_num).strip())) if pd.notna(m_num) else (idx + 1)
    code = f"OGI-{str(gn).zfill(2)}-{str(seq).zfill(3)}"
    
    if code in seen_codes:
        print(f"DUPLICATE CODE IN EXCEL: {code} -> Row {seen_codes[code]} ({seen_codes[code+'_name']}) vs Row {idx} ({f_name})")
    seen_codes[code] = idx
    seen_codes[code + '_name'] = f_name
    
    if code not in db_codes:
        print(f"NOT IN DB: {code} - {f_name} (Group {g_ref})")
