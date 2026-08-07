import pandas as pd
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.savings_service import SavingsService
import datetime
import uuid

def run_migration():
    file_path = "icare-group-member-onboarding-template.xlsx"
    print("Reading Excel file...")
    try:
        df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
        df_members = pd.read_excel(file_path, sheet_name="Members", header=2)
    except Exception as e:
        print(f"Error reading excel file: {e}")
        return

    with SupabaseUnitOfWork() as uow:
        # Load maps
        print("Loading branches, officers, and products...")
        b_res = uow.client.table("branches").select("branch_id, name").execute()
        branch_map = {b['name'].strip().lower(): b['branch_id'] for b in b_res.data} if b_res.data else {}
        
        o_res = uow.client.table("app_users").select("id, full_name").execute()
        officer_map = {o['full_name'].strip().lower(): o['id'] for o in o_res.data} if o_res.data else {}
        
        p_res = uow.client.table("loan_products").select("product_id, name").execute()
        product_map = {p['name'].strip().lower(): p['product_id'] for p in p_res.data} if p_res.data else {}
        
        # 1. PROCESS GROUPS
        print("\n--- PROCESSING GROUPS ---")
        group_ref_to_id = {}
        for index, row in df_groups.iterrows():
            g_ref = str(row.get('Group Reference*')).strip()
            if g_ref == 'nan' or not g_ref: continue
            
            b_name = str(row.get('Branch Name*')).strip()
            g_name = str(row.get('Group Name*')).strip()
            leader = str(row.get('Group Leader Name*'))
            m_day = str(row.get('Meeting Day*')).strip()
            o_name = str(row.get('Credit Officer Name*')).strip()
            g_sav = row.get('Group Savings')
            
            b_id = branch_map.get(b_name.lower())
            o_id = officer_map.get(o_name.lower())
            if leader == 'nan': leader = None
            if m_day == 'nan' or not m_day: m_day = 'Weekly' # fallback
            
            g_res = uow.client.table("groups").select("*").eq("name", g_name).execute()
            if g_res.data:
                g_id = g_res.data[0]['group_id']
                # Update existing
                try:
                    uow.client.table("groups").update({
                        "meeting_day": m_day,
                        "branch_id": b_id,
                        "officer_id": o_id,
                        "leader_name": leader
                    }).eq("group_id", g_id).execute()
                    print(f"Updated group: {g_name}")
                except Exception as e:
                    print(f"Failed to update group {g_name}: {e}")
            else:
                # Insert new
                g_id = str(uuid.uuid4())
                try:
                    uow.client.table("groups").insert({
                        "group_id": g_id,
                        "name": g_name,
                        "meeting_day": m_day,
                        "branch_id": b_id,
                        "officer_id": o_id,
                        "leader_name": leader,
                        "status": "Active"
                    }).execute()
                    print(f"Created new group: {g_name}")
                except Exception as e:
                    print(f"Failed to create group {g_name}: {e}")
                
            group_ref_to_id[g_ref] = {
                'group_id': g_id,
                'branch_id': b_id,
                'officer_id': o_id,
                'branch_name': b_name,
                'officer_name': o_name
            }
            
            # Post Group Savings Idempotently
            if pd.notna(g_sav) and float(g_sav) > 0:
                gs_res = uow.client.table("group_savings").select("id").eq("group_id", g_id).eq("remarks", "Initial Onboarding Group Savings").execute()
                if not gs_res.data:
                    print(f"Posting Group Savings: {g_sav} for {g_name}")
                    try:
                        SavingsService.post_group_savings(uow, g_name, b_name, o_name, float(g_sav), remarks="Initial Onboarding Group Savings")
                    except Exception as e:
                        print(f"  Error posting group savings: {e}")

        # 2. PROCESS MEMBERS
        print("\n--- PROCESSING MEMBERS ---")
        for index, row in df_members.iterrows():
            m_ref = str(row.get('Member Reference*')).strip()
            g_ref = str(row.get('Group Reference*')).strip()
            if m_ref == 'nan' or not m_ref: continue
            if g_ref == 'nan' or not g_ref: continue
            
            f_name = str(row.get('Full Name*')).strip()
            phone = str(row.get('Phone Number*')).strip()
            address = str(row.get('Home Address*')).strip()
            s_bal = row.get('Savings Balance*')
            l_type = str(row.get('Loan Type (Product)*')).strip()
            p_loan = row.get('Principal Loan*')
            a_cred = row.get('Active Credit (Disbursed)*')
            c_bal = row.get('Current Credit Balance*')
            
            if phone == 'nan': phone = ""
            if address == 'nan': address = ""
            
            group_info = group_ref_to_id.get(g_ref)
            if not group_info:
                print(f"Skipping {f_name}, unknown group reference: {g_ref}")
                continue
                
            g_id = group_info['group_id']
            b_id = group_info['branch_id']
            o_id = group_info['officer_id']
            b_name = group_info['branch_name']
            o_name = group_info['officer_name']
                
            # Upsert client
            c_res = uow.client.table("clients").select("*").eq("name", f_name).execute()
            if c_res.data:
                c_id = c_res.data[0]['client_id']
                uow.client.table("clients").update({
                    "phone": phone,
                    "address": address
                }).eq("client_id", c_id).execute()
                print(f"Updated client: {f_name}")
            else:
                c_id = str(uuid.uuid4())
                uow.client.table("clients").insert({
                    "client_id": c_id,
                    "name": f_name,
                    "phone": phone,
                    "address": address,
                    "status": "Active"
                }).execute()
                print(f"Created new client: {f_name}")
                
            # Ensure client membership
            m_res = uow.client.table("client_memberships").select("*").eq("client_id", c_id).eq("group_id", g_id).execute()
            if not m_res.data:
                uow.client.table("client_memberships").insert({
                    "client_id": c_id,
                    "group_id": g_id
                }).execute()
                
            # Post Individual Savings Idempotently
            if pd.notna(s_bal) and float(s_bal) > 0:
                is_res = uow.client.table("individual_savings").select("id").eq("client_id", c_id).eq("remarks", "Initial Onboarding Savings").execute()
                if not is_res.data:
                    print(f"Posting Savings: {s_bal} for {f_name}")
                    try:
                        SavingsService.post_individual_savings(uow, c_id, f_name, b_name, o_name, float(s_bal), remarks="Initial Onboarding Savings")
                    except Exception as e:
                        print(f"  Error posting savings: {e}")
            
            # Upsert Loan if applicable
            if pd.notna(a_cred) and float(a_cred) > 0:
                print(f"Setting up Loan for {f_name}: {a_cred}")
                
                prod_id = None
                if l_type and l_type != 'nan':
                    prod_id = product_map.get(l_type.lower())
                    
                if pd.notna(c_bal):
                    l_res = uow.client.table("loans").select("*").eq("client_id", c_id).eq("status", "Active").execute()
                    if l_res.data:
                        uow.client.table("loans").update({
                            "total_due": float(c_bal),
                            "active_credit": float(a_cred),
                            "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred),
                            "branch_id": b_id,
                            "officer_id": o_id,
                            "product_id": prod_id
                        }).eq("loan_id", l_res.data[0]['loan_id']).execute()
                    else:
                        uow.client.table("loans").insert({
                            "client_id": c_id,
                            "date": datetime.datetime.now().strftime('%Y-%m-%d'),
                            "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred),
                            "active_credit": float(a_cred),
                            "total_due": float(c_bal),
                            "status": "Active",
                            "branch_id": b_id,
                            "officer_id": o_id,
                            "product_id": prod_id
                        }).execute()

    print("\nMigration Complete!")

if __name__ == '__main__':
    run_migration()
