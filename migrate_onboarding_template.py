import pandas as pd
from database.repositories.unit_of_work import SupabaseUnitOfWork
import datetime
import uuid
import holidays
import math
import time

uow_holder = [None]

def get_uow():
    if uow_holder[0] is None:
        uow_holder[0] = SupabaseUnitOfWork()
    return uow_holder[0]

def retry_call(fn, max_retries=7, delay=2):
    for attempt in range(max_retries):
        try:
            uow = get_uow()
            return fn(uow)
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            print(f"Connection glitch, reconnecting ({attempt + 1}/{max_retries})... {e}")
            time.sleep(delay)
            try:
                uow_holder[0] = SupabaseUnitOfWork()
            except Exception:
                pass

def run_migration():
    file_path = "icare-group-member-onboarding-template.xlsx"
    print(f"Reading Excel file '{file_path}'...")
    try:
        df_groups = pd.read_excel(file_path, sheet_name="Groups", header=2)
        df_members = pd.read_excel(file_path, sheet_name="Members", header=2)
    except Exception as e:
        print(f"Error reading excel file: {e}")
        return

    # 1. Load Reference Maps
    print("Loading branches, officers, products, and closures...")
    b_res = retry_call(lambda u: u.client.table("branches").select("branch_id, name, code").execute())
    branch_map = {b['name'].strip().lower(): b for b in (b_res.data or [])}
    
    o_res = retry_call(lambda u: u.client.table("app_users").select("id, full_name, username").execute())
    officer_map = {o['full_name'].strip().lower(): o['id'] for o in (o_res.data or []) if o.get('full_name')}
    for o in (o_res.data or []):
        if o.get('username'):
            officer_map[o['username'].strip().lower()] = o['id']
    
    p_res = retry_call(lambda u: u.client.table("loan_products").select("product_id, name, installments, repayment_cycle").execute())
    product_map = {p['name'].strip().lower(): p for p in (p_res.data or [])}

    # Fetch Closures & Holidays
    closures = []
    c_res = retry_call(lambda u: u.client.table("branch_closures").select("start_date, end_date").execute())
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

    def get_next_working_day(d: datetime.date) -> datetime.date:
        while not is_working_day(d):
            d += datetime.timedelta(days=1)
        return d

    def add_months(d: datetime.date, num_months: int) -> datetime.date:
        import calendar
        m = d.month - 1 + num_months
        y = d.year + m // 12
        m = m % 12 + 1
        day = min(d.day, calendar.monthrange(y, m)[1])
        return datetime.date(y, m, day)

    # Pre-load all existing groups & clients in memory
    existing_groups_res = retry_call(lambda u: u.client.table("groups").select("*").execute())
    existing_groups_by_number = {
        (str(g.get("group_number")), str(g.get("branch_id"))): g 
        for g in (existing_groups_res.data or []) if g.get("group_number")
    }

    existing_clients_res = retry_call(lambda u: u.client.table("clients").select("*").execute())
    existing_clients_by_name_and_group = {
        (c["name"].strip().lower(), str(c.get("group_id"))): c 
        for c in (existing_clients_res.data or []) if c.get("group_id") and c.get("name")
    }
    existing_clients_by_code = {
        c["client_code"].strip().upper(): c 
        for c in (existing_clients_res.data or []) if c.get("client_code")
    }

    existing_memberships_res = retry_call(lambda u: u.client.table("client_memberships").select("client_id, group_id").execute())
    existing_memberships_set = {(m["client_id"], m["group_id"]) for m in (existing_memberships_res.data or [])}

    day_map = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6}

    # 2. PROCESS GROUPS
    print("\n--- PROCESSING GROUPS ---")
    group_ref_to_info = {}
    for index, row in df_groups.iterrows():
        g_ref = str(row.get('Group Reference*')).strip()
        if g_ref in ('nan', '', 'None'): continue
        
        b_name = str(row.get('Branch Name*')).strip()
        g_name = str(row.get('Group Name*')).strip()
        leader = str(row.get('Group Leader Name*')).strip() if pd.notna(row.get('Group Leader Name*')) else None
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
        
        if leader in ('nan', 'None', ''): leader = None
        if m_day in ('nan', 'None', ''): m_day = 'Weekly'
        
        try:
            gn = int(g_ref.upper().replace("GRP-", "").strip())
        except Exception:
            gn = index + 1
        
        existing_g = existing_groups_by_number.get((str(gn), str(b_id)))
        if existing_g:
            g_id = existing_g['group_id']
            curr_seq = existing_g.get('current_member_sequence') or 0
            retry_call(lambda u, g_id=g_id, m_day=m_day, b_id=b_id, o_id=o_id, leader=leader, gn=gn, g_name=g_name: u.client.table("groups").update({
                "name": g_name, "meeting_day": m_day, "branch_id": b_id, "officer_id": o_id, "leader_name": leader,
                "group_number": str(gn)
            }).eq("group_id", g_id).execute())
        else:
            g_id = str(uuid.uuid4())
            curr_seq = 0
            new_g_data = {
                "group_id": g_id, "name": g_name, "meeting_day": m_day, "branch_id": b_id, 
                "officer_id": o_id, "leader_name": leader, "status": "Active",
                "group_number": str(gn), "current_member_sequence": curr_seq
            }
            retry_call(lambda u, new_g_data=new_g_data: u.client.table("groups").insert(new_g_data).execute())
            existing_groups_by_number[(str(gn), str(b_id))] = new_g_data
            print(f"Created new group: {g_name} (Group #{gn})")
            
        group_ref_to_info[g_ref] = {
            'group_id': g_id, 'branch_id': b_id, 'officer_id': o_id, 'branch_name': b_name, 'officer_name': o_name,
            'meeting_day': m_day, 'branch_code': b_code, 'group_number': gn, 'current_member_sequence': curr_seq
        }
        
        # Insert or Update Group Opening Savings (Upsert)
        if pd.notna(g_sav) and float(g_sav) > 0:
            gs_res = retry_call(lambda u, g_id=g_id: u.client.table("group_savings").select("id").eq("group_id", g_id).eq("remarks", "Initial Onboarding Group Savings").execute())
            if gs_res.data:
                gs_id = gs_res.data[0]['id']
                retry_call(lambda u, gs_id=gs_id, b_id=b_id, o_id=o_id, g_sav=g_sav: u.client.table("group_savings").update({
                    "deposit_amount": float(g_sav), "branch_id": b_id, "officer_id": o_id
                }).eq("id", gs_id).execute())
                print(f"Updated Group Savings: NGN {float(g_sav):,.2f} for {g_name}")
            else:
                retry_call(lambda u, g_id=g_id, b_id=b_id, o_id=o_id, g_sav=g_sav: u.client.table("group_savings").insert({
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
            
        # Canonical status UUIDs
        REG_STATUS_ID = "11111111-1111-1111-1111-111111110001"
        ON_LOAN_STATUS_ID = "11111111-1111-1111-1111-111111110003"
        SAVINGS_ONLY_STATUS_ID = "11111111-1111-1111-1111-111111110006"

        has_active_loan = bool(pd.notna(a_cred) and float(a_cred) > 0)
        has_savings_only = bool(pd.notna(s_bal) and float(s_bal) > 0 and not has_active_loan)

        if has_active_loan:
            initial_status = ON_LOAN_STATUS_ID
        elif has_savings_only:
            initial_status = SAVINGS_ONLY_STATUS_ID
        else:
            initial_status = REG_STATUS_ID

        # Match existing client by exact code (in-memory or live DB check)
        existing_c = existing_clients_by_code.get(expected_code)
        if not existing_c:
            chk_db = retry_call(lambda u, expected_code=expected_code: u.client.table("clients").select("client_id, name, client_code").eq("client_code", expected_code).execute())
            if chk_db.data:
                existing_c = chk_db.data[0]
                existing_clients_by_code[expected_code] = existing_c
        
        if existing_c:
            c_id = existing_c['client_id']
            retry_call(lambda u, f_name=f_name, phone=phone, address=address, b_id=b_id, o_id=o_id, g_id=g_id, expected_code=expected_code, initial_status=initial_status, c_id=c_id: u.client.table("clients").update({
                "name": f_name, "phone": phone, "address": address, "branch_id": b_id, 
                "officer_id": o_id, "group_id": g_id, "client_code": expected_code,
                "status": initial_status, "status_id": initial_status
            }).eq("client_id", c_id).execute())
        else:
            c_id = str(uuid.uuid4())
            new_c_data = {
                "client_id": c_id, "name": f_name, "phone": phone, "address": address,
                "status": initial_status, "status_id": initial_status,
                "client_code": expected_code, "branch_id": b_id, "group_id": g_id, "officer_id": o_id
            }
            try:
                retry_call(lambda u, new_c_data=new_c_data: u.client.table("clients").insert(new_c_data).execute())
            except Exception as ins_err:
                if "duplicate key" in str(ins_err) or "23505" in str(ins_err):
                    chk_db2 = retry_call(lambda u, expected_code=expected_code: u.client.table("clients").select("client_id").eq("client_code", expected_code).execute())
                    if chk_db2.data:
                        c_id = chk_db2.data[0]["client_id"]
                        new_c_data["client_id"] = c_id
                else:
                    raise ins_err
            existing_clients_by_code[expected_code] = new_c_data
            print(f"Created new client: {expected_code} ({f_name}) in Group #{gn}")
            
        # Client Memberships (Guarantee exact 1-to-1 sync with primary group)
        chk_mem = retry_call(lambda u, c_id=c_id, g_id=g_id: u.client.table("client_memberships").select("membership_id").eq("client_id", c_id).eq("group_id", g_id).execute())
        if not chk_mem.data:
            retry_call(lambda u, c_id=c_id: u.client.table("client_memberships").delete().eq("client_id", c_id).execute())
            retry_call(lambda u, c_id=c_id, g_id=g_id, b_id=b_id, o_id=o_id: u.client.table("client_memberships").insert({
                "membership_id": str(uuid.uuid4()), "client_id": c_id, "group_id": g_id, "branch_id": b_id, "officer_id": o_id
            }).execute())
            existing_memberships_set.add((c_id, g_id))
            
        # Member Opening Savings (Upsert)
        if pd.notna(s_bal) and float(s_bal) > 0:
            is_res = retry_call(lambda u, c_id=c_id: u.client.table("individual_savings").select("id").eq("client_id", c_id).eq("remarks", "Initial Onboarding Savings").execute())
            if is_res.data:
                is_id = is_res.data[0]['id']
                retry_call(lambda u, is_id=is_id, b_id=b_id, o_id=o_id, s_bal=s_bal: u.client.table("individual_savings").update({
                    "deposit_amount": float(s_bal), "branch_id": b_id, "officer_id": o_id
                }).eq("id", is_id).execute())
            else:
                retry_call(lambda u, c_id=c_id, b_id=b_id, o_id=o_id, s_bal=s_bal: u.client.table("individual_savings").insert({
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
                lt_lower = l_type.lower().strip()
                prod = product_map.get(lt_lower)
                if not prod:
                    is_asset_type = "asset" in lt_lower
                    if "12" in lt_lower and "24" not in lt_lower and ("week" in lt_lower or "w" in lt_lower or "wk" in lt_lower):
                        prod = product_map.get("weekly 12w asset") if is_asset_type else product_map.get("weekly 12w")
                    elif "24" in lt_lower and ("week" in lt_lower or "w" in lt_lower or "wk" in lt_lower):
                        prod = product_map.get("weekly 24w asset") if is_asset_type else product_map.get("weekly 24w")
                    elif "60" in lt_lower and ("day" in lt_lower or "d" in lt_lower):
                        prod = product_map.get("60-day asset") if is_asset_type else product_map.get("daily 60 days")
                    elif "120" in lt_lower and ("day" in lt_lower or "d" in lt_lower):
                        prod = product_map.get("120-day asset") if is_asset_type else product_map.get("daily 120 days")
                    elif "3" in lt_lower and ("m" in lt_lower or "month" in lt_lower):
                        prod = product_map.get("monthly 3m asset") if is_asset_type else product_map.get("monthly 3m")
                    elif "6" in lt_lower and ("m" in lt_lower or "month" in lt_lower):
                        prod = product_map.get("monthly 6m asset") if is_asset_type else product_map.get("monthly 6m")
                    elif "cash" in lt_lower or "carry" in lt_lower:
                        prod = product_map.get("cash and carry")
                    elif is_asset_type:
                        prod = product_map.get("weekly 12w asset")
                    else:
                        if "daily" in lt_lower:
                            prod = product_map.get("daily 60 days")
                        elif "monthly" in lt_lower:
                            prod = product_map.get("monthly 3m")
                        elif "weekly" in lt_lower:
                            prod = product_map.get("weekly 12w")
            if not prod:
                print(f"  Warning: Loan Product '{l_type}' not found for {f_name}. Skipping loan!")
                continue
            
            duration = int(prod.get('installments') or 24)
            cycle = prod.get('repayment_cycle', 'Weekly')
            expected_inst = float(a_cred) / duration if duration > 0 else 0
            current_bal = float(c_bal) if pd.notna(c_bal) else float(a_cred)
            prod_cat = "Asset" if "asset" in prod.get('name', '').lower() else "Finance"
            
            # Calculate historical origination date from elapsed cycle periods
            rem_installments = math.ceil(current_bal / expected_inst) if expected_inst > 0 else duration
            elapsed_installments = max(1, duration - rem_installments)
            if cycle == "Weekly":
                hist_date = base_date - datetime.timedelta(weeks=elapsed_installments)
            elif cycle == "Daily":
                hist_date = base_date - datetime.timedelta(days=elapsed_installments)
            else:
                hist_date = base_date - datetime.timedelta(days=30 * elapsed_installments)
            
            legacy_extra = {
                "is_legacy": True,
                "onboarded_at": base_date.isoformat(),
                "initial_active_credit": float(a_cred),
                "initial_balance": current_bal,
                "elapsed_cycles": elapsed_installments,
                "product_category": prod_cat
            }

            print(f"Setting up Loan for {f_name} ({expected_code}): Product={prod.get('name')}, Active Credit={a_cred}, Bal={current_bal}, Duration={duration}, Disbursed={hist_date.isoformat()}")
            
            p_id = prod['product_id']
            l_res = retry_call(lambda u, c_id=c_id, p_id=p_id: u.client.table("loans").select("*").eq("client_id", c_id).eq("product_id", p_id).eq("status", "Active").execute())
            if l_res.data:
                loan_id = l_res.data[0]['loan_id']
                retry_call(lambda u, current_bal=current_bal, a_cred=a_cred, p_loan=p_loan, expected_inst=expected_inst, b_id=b_id, o_id=o_id, prod=prod, prod_cat=prod_cat, loan_id=loan_id, hist_date=hist_date, legacy_extra=legacy_extra: u.client.table("loans").update({
                    "total_due": current_bal, "active_credit": float(a_cred), "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred),
                    "loan_repay": round(expected_inst, 2), "date": hist_date.isoformat(), "disbursement_date": hist_date.isoformat(), "start_date": hist_date.isoformat(),
                    "branch_id": b_id, "officer_id": o_id, "product_id": prod['product_id'], "product_category": prod_cat, "extra_fields": legacy_extra
                }).eq("loan_id", loan_id).execute())
            else:
                loan_id = str(uuid.uuid4())
                retry_call(lambda u, loan_id=loan_id, c_id=c_id, hist_date=hist_date, p_loan=p_loan, a_cred=a_cred, expected_inst=expected_inst, current_bal=current_bal, b_id=b_id, o_id=o_id, prod=prod, prod_cat=prod_cat, legacy_extra=legacy_extra: u.client.table("loans").insert({
                    "loan_id": loan_id, "client_id": c_id, "date": hist_date.isoformat(), "disbursement_date": hist_date.isoformat(), "start_date": hist_date.isoformat(),
                    "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred), "active_credit": float(a_cred),
                    "loan_repay": round(expected_inst, 2),
                    "total_due": current_bal, "status": "Active", "branch_id": b_id, "officer_id": o_id, "product_id": prod['product_id'],
                    "product_category": prod_cat,
                    "extra_fields": legacy_extra
                }).execute())
                loans_created += 1
            
            # Generate repayment schedule starting NEXT meeting/collection day (FP-008)
            sch_res = retry_call(lambda u, loan_id=loan_id: u.client.table("loan_schedule").select("id").eq("loan_id", loan_id).execute())
            if not sch_res.data and expected_inst > 0 and current_bal > 0:
                remaining_count = math.ceil(current_bal / expected_inst)
                target_weekday = day_map.get(group_info['meeting_day'])
                schedule_rows = []
                rem_bal = current_bal

                if cycle == "Weekly" and target_weekday is not None:
                    days_ahead = target_weekday - base_date.weekday()
                    if days_ahead <= 0:
                        days_ahead += 7
                    first_meeting = base_date + datetime.timedelta(days=days_ahead)
                    current_anchor = first_meeting - datetime.timedelta(weeks=1)
                elif cycle == "Daily":
                    current_anchor = base_date
                else: # Monthly / Other
                    current_anchor = base_date

                for i in range(1, remaining_count + 1):
                    if cycle == "Daily":
                        current_anchor += datetime.timedelta(days=1)
                        current_anchor = get_next_working_day(current_anchor)
                        current_due_date = current_anchor
                    elif cycle == "Weekly":
                        current_anchor += datetime.timedelta(weeks=1)
                        while not is_working_day(current_anchor):
                            current_anchor += datetime.timedelta(weeks=1)
                        current_due_date = current_anchor
                    elif cycle == "Monthly":
                        m_target = add_months(base_date, i)
                        current_due_date = get_next_working_day(m_target)
                    else:
                        current_due_date = get_next_working_day(base_date + datetime.timedelta(days=i * 30))
                    
                    inst_amount = min(expected_inst, rem_bal)
                    rem_bal -= inst_amount
                    
                    schedule_rows.append({
                        "id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": i,
                        "due_date": current_due_date.isoformat(), "principal": inst_amount,
                        "interest": 0.0, "fees": 0.0, "total_due": inst_amount, "status": "Pending",
                        "paid_amount": 0.0, "paid_date": None
                    })
                    if rem_bal <= 0: break
                    
                if schedule_rows:
                    retry_call(lambda u, schedule_rows=schedule_rows: u.client.table("loan_schedule").insert(schedule_rows).execute())
                    schedules_created += len(schedule_rows)
                    print(f"  Generated {len(schedule_rows)} remaining schedule installments starting {schedule_rows[0]['due_date']}.")

    # 4. PROCESS BRANCH POOLED SAVINGS (Branch LAPS & Misc Fees Savings from Sheet 4)
    print("\n--- PROCESSING BRANCH POOLED SAVINGS (LAPS & MISC FEES) ---")
    try:
        df_bo_raw = pd.read_excel(file_path, sheet_name="Branch and Officer List", header=None)
        
        # Determine branch name
        target_branch_name = None
        if not df_groups.empty and 'Branch Name*' in df_groups.columns:
            target_branch_name = str(df_groups['Branch Name*'].dropna().iloc[0]).strip()
        
        branch_laps_val = 0.0
        misc_fees_val = 0.0

        for r_idx in range(len(df_bo_raw)):
            for c_idx in range(len(df_bo_raw.columns)):
                cell_val = str(df_bo_raw.iloc[r_idx, c_idx]).strip()
                if 'laps savings' in cell_val.lower():
                    if r_idx + 1 < len(df_bo_raw):
                        val_below = df_bo_raw.iloc[r_idx + 1, c_idx]
                        try:
                            if pd.notna(val_below) and float(str(val_below).replace(',', '')) > 0:
                                branch_laps_val = float(str(val_below).replace(',', ''))
                        except (ValueError, TypeError):
                            pass
                    if c_idx + 1 < len(df_bo_raw.columns) and branch_laps_val == 0.0:
                        val_right = df_bo_raw.iloc[r_idx, c_idx + 1]
                        try:
                            if pd.notna(val_right) and float(str(val_right).replace(',', '')) > 0:
                                branch_laps_val = float(str(val_right).replace(',', ''))
                        except (ValueError, TypeError):
                            pass
                elif 'misc fees' in cell_val.lower() or 'misc savings' in cell_val.lower():
                    if r_idx + 1 < len(df_bo_raw):
                        val_below = df_bo_raw.iloc[r_idx + 1, c_idx]
                        try:
                            if pd.notna(val_below) and float(str(val_below).replace(',', '')) > 0:
                                misc_fees_val = float(str(val_below).replace(',', ''))
                        except (ValueError, TypeError):
                            pass
                    if c_idx + 1 < len(df_bo_raw.columns) and misc_fees_val == 0.0:
                        val_right = df_bo_raw.iloc[r_idx, c_idx + 1]
                        try:
                            if pd.notna(val_right) and float(str(val_right).replace(',', '')) > 0:
                                misc_fees_val = float(str(val_right).replace(',', ''))
                        except (ValueError, TypeError):
                            pass

        if target_branch_name:
            b_info = branch_map.get(target_branch_name.lower())
            if b_info:
                b_id = b_info['branch_id']
                # Ingest Branch Laps Savings (if > 0)
                if branch_laps_val > 0:
                    ex_laps = retry_call(lambda u: u.client.table("laps_savings").select("id").eq("branch_id", b_id).eq("reference", "ONBOARDING_LEGACY").execute())
                    if not ex_laps.data:
                        laps_payload = {
                            "id": str(uuid.uuid4()),
                            "branch_id": b_id,
                            "deposit_amount": branch_laps_val,
                            "withdrawal_amount": 0.0,
                            "reference": "ONBOARDING_LEGACY",
                            "remarks": "Legacy Branch LAPS Savings Onboarded",
                            "posting_date": base_date.isoformat()
                        }
                        retry_call(lambda u: u.client.table("laps_savings").insert(laps_payload).execute())
                        print(f"  Ingested Branch LAPS Savings: ₦{branch_laps_val:,.2f} for branch '{target_branch_name}'.")
                    else:
                        print(f"  Branch LAPS Savings already onboarded for branch '{target_branch_name}' (₦{branch_laps_val:,.2f}).")
                
                # Ingest Misc Fees / Internal Savings (if > 0)
                if misc_fees_val > 0:
                    from services.savings_service import SavingsService
                    uow_tmp = get_uow()
                    managing_id, managing_name = SavingsService.get_branch_misc_savings_officer(uow_tmp, target_branch_name)
                    ex_misc = retry_call(lambda u: u.client.table("internal_savings").select("id").eq("branch_id", b_id).eq("reference", "ONBOARDING_LEGACY").execute())
                    if not ex_misc.data:
                        misc_payload = {
                            "id": str(uuid.uuid4()),
                            "branch_id": b_id,
                            "officer_id": managing_id,
                            "deposit_amount": misc_fees_val,
                            "withdrawal_amount": 0.0,
                            "reference": "ONBOARDING_LEGACY",
                            "remarks": f"Legacy Misc/Internal Savings Onboarded (Managed by {managing_name})",
                            "posting_date": "1970-01-01"
                        }
                        retry_call(lambda u: u.client.table("internal_savings").insert(misc_payload).execute())
                        print(f"  Ingested Misc Fees Savings: ₦{misc_fees_val:,.2f} for branch '{target_branch_name}' (Assigned to {managing_name}).")
                    else:
                        print(f"  Misc Fees Savings already onboarded for branch '{target_branch_name}' (₦{misc_fees_val:,.2f}).")
    except Exception as bo_err:
        print(f"Note: Could not parse Branch and Officer List for pooled savings: {bo_err}")

    print("\n==================================================")
    print(f"ONBOARDING COMPLETE!")
    print(f"Loans Created: {loans_created}, Schedule Installments Created: {schedules_created}")
    print("==================================================")

if __name__ == '__main__':
    run_migration()

