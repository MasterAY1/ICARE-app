import os
import sys
import uuid
import pandas as pd
from datetime import datetime

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def patch_group_savings(excel_path):
    print("Patching Group Savings...")
    df = pd.read_excel(excel_path, sheet_name="Groups", header=2)
    
    with SupabaseUnitOfWork() as uow:
        for idx, row in df.iterrows():
            g_ref = str(row.get('Group Reference*')).strip()
            if g_ref == 'nan': continue
            
            g_name = str(row.get('Group Name*')).strip()
            g_sav = row.get('Group Savings')
            leader = str(row.get('Group Leader Name*')).strip()
            
            if leader == 'nan': leader = None
            
            # Fetch Group ID
            g_res = uow.client.table("groups").select("group_id, branch_id, officer_id, leader_name").eq("name", g_name).execute()
            if g_res.data:
                g_info = g_res.data[0]
                g_id = g_info['group_id']
                b_id = g_info['branch_id']
                o_id = g_info['officer_id']
                
                print(f"Group: {g_name} | Leader: {leader or 'None'}")
                
                # Check Savings
                if pd.notna(g_sav) and float(g_sav) > 0:
                    # Check if already exists
                    gs_res = uow.client.table("group_savings").select("id").eq("group_id", g_id).eq("remarks", "Initial Onboarding Group Savings").execute()
                    if not gs_res.data:
                        uow.client.table("group_savings").insert({
                            "id": str(uuid.uuid4()),
                            "group_id": g_id, "branch_id": b_id, "officer_id": o_id, 
                            "posting_date": datetime.now().date().isoformat(), "deposit_amount": float(g_sav),
                            "remarks": "Initial Onboarding Group Savings"
                        }).execute()
                        print(f" -> Posted Group Savings: {g_sav}")
                    else:
                        print(f" -> Group Savings {g_sav} already posted.")
                        
if __name__ == "__main__":
    patch_group_savings("icare-group-member-onboarding-template.xlsx")
