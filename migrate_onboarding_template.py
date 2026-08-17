import pandas as pd
from database.repositories.unit_of_work import SupabaseUnitOfWork
import datetime
import uuid
import holidays
import math
import time

def retry_call(fn, max_retries=5, delay=2):
    for attempt in range(max_retries):
        try:
            return fn()
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            print(f"Network glitch, retrying ({attempt + 1}/{max_retries})... {e}")
            time.sleep(delay)

def run_migration():
    file_path = "icare-group-member-onboarding-template.xlsx"
    print(f"Reading Excel file '{file_path}'...")
    try:
        df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
        df_members = pd.read_excel(file_path, sheet_name="Members", header=2)
    except Exception as e:
        print(f"Error reading excel file: {e}")
        return

    with SupabaseUnitOfWork() as uow:
        # 1. Load Reference Maps
        print("Loading branches, officers, products, and closures...")
        b_res = retry_call(lambda: uow.client.table("branches").select("branch_id, name, code").execute())
        branch_map = {b['name'].strip().lower(): b for b in (b_res.data or [])}
        
        o_res = retry_call(lambda: uow.client.table("app_users").select("id, full_name").execute())
        officer_map = {o['full_name'].strip().lower(): o['id'] for o in (o_res.data or [])}
        
        p_res = retry_call(lambda: uow.client.table("loan_products").select("product_id, name, installments, repayment_cycle").execute())
        product_map = {p['name'].strip().lower(): p for p in (p_res.data or [])}

        # Fetch Closures & Holidays
        closures = []
        c_res = retry_call(lambda: uow.client.table("branch_closures").select("start_date, end_date").execute())
        if c_res.data:
            for c in c_res.data:
                closures.append((datetime.date.fromisoformat(c['start_date']), datetime.date.fromisoformat(c['end_date'])))

        base_date = datetime.date.today()
        ng_holidays = holidays.NG(years=[base_date.year, base_date.year + 1, base_date.year + 2])

        def is_working_day(d: datetime.date) -> bool:
            if d.weekday() >= 5: return False
            if d in ng_holidays: return False
            for c_start, c_end in closures:
                if c_start <= d <= c_end: return False
            return True

        # Pre-load all existing groups & clients in memory
        existing_groups_res = retry_call(lambda: uow.client.table("groups").select("*").execute())
        existing_groups_by_name = {g["name"].strip().lower(): g for g in (existing_groups_res.data or [])}

        existing_clients_res = retry_call(lambda: uow.client.table("clients").select("*").execute())
        existing_clients_by_name_and_group = {
            (c["name"].strip().lower(), str(c.get("group_id"))): c 
            for c in (existing_clients_res.data or []) if c.get("group_id") and c.get("name")
        }
        existing_clients_by_code = {
            c["client_code"].strip().upper(): c 
            for c in (existing_clients_res.data or []) if c.get("client_code")
        }

        existing_memberships_res = retry_call(lambda: uow.client.table("client_memberships").select("client_id, group_id").execute())
        existing_memberships_set = {(m["client_id"], m["group_id"]) for m in (existing_memberships_res.data or [])}

        day_map = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6}

        # 2. PROCESS GROUPS
        print("\n--- PROCESSING GROUPS ---")
        group_ref_to_info = {}
        for index, row in df_groups.iterrows():
            g_ref = str(row.get('Group Reference*')).strip()
            if g_ref == 'nan' or not g_ref: continue
            
            b_name = str(row.get('Branch Name*')).strip()
            g_name = str(row.get('Group Name*')).strip()
            leader = str(row.get('Group Leader Name*'))
            m_day = str(row.get('Meeting Day*')).strip()
            o_name = str(row.get('Credit Officer Name*')).strip()
            g_sav = row.get('Group Savings')
            
            b_info = branch_map.get(b_name.lower())
            if not b_info:
                print(f"Branch '{b_name}' not found. Skipping group {g_name}.")
                continue
                
            b_id = b_info['branch_id']
            b_code = b_info.get('code', b_name[:3].upper())
            o_id = officer_map.get(o_name.lower())
            
            if leader == 'nan': leader = None
            if m_day == 'nan' or not m_day: m_day = 'Weekly'
            
            try:
                gn = int(g_ref.upper().replace("GRP-", "").strip())
            except Exception:
                gn = index + 1
            
            existing_g = existing_groups_by_name.get(g_name.lower())
            if existing_g:
                g_id = existing_g['group_id']
                curr_seq = existing_g.get('current_member_sequence') or 0
                retry_call(lambda: uow.client.table("groups").update({
                    "meeting_day": m_day, "branch_id": b_id, "officer_id": o_id, "leader_name": leader,
                    "group_number": gn
                }).eq("group_id", g_id).execute())
            else:
                g_id = str(uuid.uuid4())
                curr_seq = 0
                new_g_data = {
                    "group_id": g_id, "name": g_name, "meeting_day": m_day, "branch_id": b_id, 
                    "officer_id": o_id, "leader_name": leader, "status": "Active",
                    "group_number": gn, "current_member_sequence": curr_seq
                }
                retry_call(lambda: uow.client.table("groups").insert(new_g_data).execute())
                existing_groups_by_name[g_name.lower()] = new_g_data
                print(f"Created new group: {g_name} (Group #{gn})")
                
            group_ref_to_info[g_ref] = {
                'group_id': g_id, 'branch_id': b_id, 'officer_id': o_id, 'branch_name': b_name, 'officer_name': o_name,
                'meeting_day': m_day, 'branch_code': b_code, 'group_number': gn, 'current_member_sequence': curr_seq
            }
            
            # Insert Group Opening Savings
            if pd.notna(g_sav) and float(g_sav) > 0:
                gs_res = retry_call(lambda: uow.client.table("group_savings").select("id").eq("group_id", g_id).eq("remarks", "Initial Onboarding Group Savings").execute())
                if not gs_res.data:
                    retry_call(lambda: uow.client.table("group_savings").insert({
                        "id": str(uuid.uuid4()),
                        "group_id": g_id,
                        "posting_date": "1970-01-01",
                        "branch_id": b_id,
                        "officer_id": o_id,
                        "deposit_amount": float(g_sav),
                        "withdrawal_amount": 0.0,
                        "reference": "ONBOARDING-GROUP-OPENING",
                        "remarks": "Initial Onboarding Group Savings"
                    }).execute())
                    print(f"Posted Group Savings: NGN {float(g_sav):,.2f} for {g_name}")

        # 3. PROCESS MEMBERS
        print("\n--- PROCESSING MEMBERS ---")
        db_group_seq = {}
        loans_created = 0
        schedules_created = 0
        
        for index, row in df_members.iterrows():
            m_ref = row.get('Member Number')
            g_ref = str(row.get('Group Reference*')).strip()
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
            
            group_info = group_ref_to_info.get(g_ref)
            if not group_info:
                print(f"Skipping {f_name}, unknown group reference: {g_ref}")
                continue
                
            g_id = group_info['group_id']
            b_id = group_info['branch_id']
            o_id = group_info['officer_id']
            b_code = group_info['branch_code']
            gn = group_info['group_number']
            
            if pd.notna(m_ref) and str(m_ref).strip() != '' and str(m_ref).strip() != 'nan':
                try:
                    seq = int(float(str(m_ref).strip()))
                except Exception:
                    db_group_seq[g_id] = db_group_seq.get(g_id, group_info['current_member_sequence']) + 1
                    seq = db_group_seq[g_id]
            else:
                db_group_seq[g_id] = db_group_seq.get(g_id, group_info['current_member_sequence']) + 1
                seq = db_group_seq[g_id]
                
            expected_code = f"{b_code}-{str(gn).zfill(2)}-{str(seq).zfill(3)}"
                
            # Match existing client by exact code OR by (name, group_id)
            existing_c = existing_clients_by_code.get(expected_code) or existing_clients_by_name_and_group.get((f_name.lower(), str(g_id)))
            
            if existing_c:
                c_id = existing_c['client_id']
                retry_call(lambda: uow.client.table("clients").update({
                    "name": f_name, "phone": phone, "address": address, "branch_id": b_id, 
                    "officer_id": o_id, "group_id": g_id, "client_code": expected_code, "status": "Active"
                }).eq("client_id", c_id).execute())
            else:
                c_id = str(uuid.uuid4())
                new_c_data = {
                    "client_id": c_id, "name": f_name, "phone": phone, "address": address, "status": "Active",
                    "client_code": expected_code, "branch_id": b_id, "group_id": g_id, "officer_id": o_id
                }
                retry_call(lambda: uow.client.table("clients").insert(new_c_data).execute())
                existing_clients_by_code[expected_code] = new_c_data
                existing_clients_by_name_and_group[(f_name.lower(), str(g_id))] = new_c_data
                print(f"Created new client: {expected_code} ({f_name}) in Group #{gn}")
                
            # Client Memberships
            if (c_id, g_id) not in existing_memberships_set:
                retry_call(lambda: uow.client.table("client_memberships").insert({"client_id": c_id, "group_id": g_id}).execute())
                existing_memberships_set.add((c_id, g_id))
                
            # Member Opening Savings
            if pd.notna(s_bal) and float(s_bal) > 0:
                is_res = retry_call(lambda: uow.client.table("individual_savings").select("id").eq("client_id", c_id).eq("remarks", "Initial Onboarding Savings").execute())
                if not is_res.data:
                    retry_call(lambda: uow.client.table("individual_savings").insert({
                        "id": str(uuid.uuid4()),
                        "client_id": c_id,
                        "posting_date": "1970-01-01",
                        "branch_id": b_id,
                        "officer_id": o_id,
                        "deposit_amount": float(s_bal),
                        "withdrawal_amount": 0.0,
                        "reference": "ONBOARDING-MEMBER-OPENING",
                        "remarks": "Initial Onboarding Savings"
                    }).execute())
                    print(f"Posted Individual Savings: NGN {float(s_bal):,.2f} for {f_name} ({expected_code})")
            
            # Loans & Schedule
            if pd.notna(a_cred) and float(a_cred) > 0:
                prod = None
                if l_type and l_type != 'nan':
                    lt_lower = l_type.lower()
                    prod = product_map.get(lt_lower)
                    if not prod:
                        if "12" in lt_lower and "asset" not in lt_lower:
                            prod = product_map.get("weekly 12w")
                        elif "24" in lt_lower and "asset" not in lt_lower:
                            prod = product_map.get("weekly 24w")
                        elif "60" in lt_lower and "asset" not in lt_lower:
                            prod = product_map.get("daily 60 days")
                        elif "120" in lt_lower and "asset" not in lt_lower:
                            prod = product_map.get("daily 120 days")
                if not prod:
                    print(f"  Warning: Loan Product '{l_type}' not found for {f_name}. Skipping loan!")
                    continue
                
                duration = int(prod.get('installments') or 24)
                cycle = prod.get('repayment_cycle', 'Weekly')
                expected_inst = float(a_cred) / duration if duration > 0 else 0
                current_bal = float(c_bal) if pd.notna(c_bal) else float(a_cred)
                
                print(f"Setting up Loan for {f_name} ({expected_code}): Product={prod.get('name')}, Active Credit={a_cred}, Bal={current_bal}, Duration={duration}")
                
                l_res = retry_call(lambda: uow.client.table("loans").select("*").eq("client_id", c_id).eq("status", "Active").execute())
                if l_res.data:
                    loan_id = l_res.data[0]['loan_id']
                    retry_call(lambda: uow.client.table("loans").update({
                        "total_due": current_bal, "active_credit": float(a_cred), "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred),
                        "loan_repay": round(expected_inst, 2),
                        "branch_id": b_id, "officer_id": o_id, "product_id": prod['product_id']
                    }).eq("loan_id", loan_id).execute())
                else:
                    loan_id = str(uuid.uuid4())
                    retry_call(lambda: uow.client.table("loans").insert({
                        "loan_id": loan_id, "client_id": c_id, "date": base_date.isoformat(),
                        "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred), "active_credit": float(a_cred),
                        "loan_repay": round(expected_inst, 2),
                        "total_due": current_bal, "status": "Active", "branch_id": b_id, "officer_id": o_id, "product_id": prod['product_id']
                    }).execute())
                    loans_created += 1
                
                # Generate repayment schedule starting NEXT meeting day (FP-008)
                sch_res = retry_call(lambda: uow.client.table("loan_schedule").select("id").eq("loan_id", loan_id).execute())
                if not sch_res.data and expected_inst > 0 and current_bal > 0:
                    remaining_count = math.ceil(current_bal / expected_inst)
                    
                    target_weekday = day_map.get(group_info['meeting_day'])
                    current_anchor = base_date
                    if cycle == "Weekly" and target_weekday is not None:
                        days_ahead = target_weekday - current_anchor.weekday()
                        if days_ahead < 0:
                            days_ahead += 7
                        current_anchor = current_anchor + datetime.timedelta(days=days_ahead)
                    
                    schedule_rows = []
                    rem_bal = current_bal
                    for i in range(1, remaining_count + 1):
                        if i > 1:
                            if cycle == "Weekly":
                                current_anchor += datetime.timedelta(weeks=1)
                                while not is_working_day(current_anchor):
                                    current_anchor += datetime.timedelta(weeks=1)
                            elif cycle == "Daily":
                                current_anchor += datetime.timedelta(days=1)
                                while not is_working_day(current_anchor):
                                    current_anchor += datetime.timedelta(days=1)
                        else:
                            if cycle == "Weekly":
                                while not is_working_day(current_anchor):
                                    current_anchor += datetime.timedelta(weeks=1)
                        
                        inst_amount = min(expected_inst, rem_bal)
                        rem_bal -= inst_amount
                        
                        schedule_rows.append({
                            "id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": i,
                            "due_date": current_anchor.isoformat(), "principal": inst_amount,
                            "interest": 0.0, "fees": 0.0, "total_due": inst_amount, "status": "Pending",
                            "paid_amount": 0.0, "paid_date": None
                        })
                        if rem_bal <= 0: break
                        
                    if schedule_rows:
                        retry_call(lambda: uow.client.table("loan_schedule").insert(schedule_rows).execute())
                        schedules_created += len(schedule_rows)
                        print(f"  Generated {len(schedule_rows)} remaining schedule installments starting {schedule_rows[0]['due_date']}.")

        print("\n==================================================")
        print(f"ONBOARDING COMPLETE!")
        print(f"Loans Created: {loans_created}, Schedule Installments Created: {schedules_created}")
        print("==================================================")

if __name__ == '__main__':
    run_migration()
