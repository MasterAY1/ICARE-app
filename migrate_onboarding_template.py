import pandas as pd
from database.repositories.unit_of_work import SupabaseUnitOfWork
import datetime
import uuid
import holidays
import math
import time
import argparse

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

def run_migration(dry_run=False):
    file_path = "icare-group-member-onboarding-template.xlsx"
    mode_str = "[DRY-RUN AUDIT]" if dry_run else "[LIVE EXECUTION]"
    print(f"==================================================")
    print(f"Starting Onboarding Migration: {mode_str}")
    print(f"Reading Excel file '{file_path}'...")
    print(f"==================================================")
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

    def resolve_product(l_type_str):
        if not l_type_str or l_type_str in ('nan', 'None', ''):
            return None
        lt_lower = str(l_type_str).lower().strip()
        prod = product_map.get(lt_lower)
        if prod:
            return prod
        
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
        return prod

    # Fetch Closures & Holidays
    closures = []
    c_res = retry_call(lambda u: u.client.table("branch_closures").select("start_date, end_date").execute())
    if c_res.data:
        for c in c_res.data:
            closures.append((datetime.date.fromisoformat(c['start_date']), datetime.date.fromisoformat(c['end_date'])))

    base_date = datetime.date(2026, 9, 1)
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

    # Canonical status UUIDs
    REG_STATUS_ID = "11111111-1111-1111-1111-111111110001"
    ON_LOAN_STATUS_ID = "11111111-1111-1111-1111-111111110003"
    SAVINGS_ONLY_STATUS_ID = "11111111-1111-1111-1111-111111110006"

    # Pre-load all existing groups & clients in memory
    print("Pre-loading database state...")
    existing_groups_res = retry_call(lambda u: u.client.table("groups").select("*").execute())
    existing_groups_by_number = {
        (str(g.get("group_number")), str(g.get("branch_id"))): g 
        for g in (existing_groups_res.data or []) if g.get("group_number")
    }

    # Ghost Duplicate Client Cleanup
    # These 6 records were accidental duplicate inserts from previous runs with 0 loans, 0 savings, 0 repayments
    ghost_client_ids = [
        "dfa0a807-80b2-4bba-91af-1bc1733aacd3",  # Oyemade Keji duplicate holding OGI-47-021
        "91bcc033-dd6f-4556-9b6a-b41ee6638ac9",  # Simiat Ajani duplicate OGI-11-008
        "13f7d058-662b-4c50-9e3c-45a6e1bb13da",  # Simiat Ajani duplicate OGI-11-010
        "abdf0739-14d3-4b82-bd38-5f657a3ca470",  # Andrew Abah duplicate OGI-30-013
        "73662d10-d543-4d2a-92e6-1a2d17a417c0",  # Elaigwu Daniel duplicate OGI-30-014
        "0d3dfe70-b4a9-4f9f-a64c-154cb56786a4"   # Ogboru Ganiyat duplicate OGI-35-004
    ]
    if not dry_run:
        for g_cid in ghost_client_ids:
            try:
                retry_call(lambda u, g_cid=g_cid: u.client.table("client_memberships").delete().eq("client_id", g_cid).execute())
                retry_call(lambda u, g_cid=g_cid: u.client.table("clients").delete().eq("client_id", g_cid).execute())
            except Exception as e:
                print(f"Note: Could not purge ghost client {g_cid}: {e}")
    else:
        print(f"  [DRY-RUN] Would purge {len(ghost_client_ids)} ghost duplicate client records.")

    existing_clients_res = retry_call(lambda u: u.client.table("clients").select("*").execute())
    all_db_clients = [c for c in (existing_clients_res.data or []) if c['client_id'] not in ghost_client_ids]
    
    # Index DB clients by (name.lower().strip(), group_id)
    clients_by_name_and_group = {}
    for c in all_db_clients:
        if c.get("group_id") and c.get("name"):
            key = (c["name"].strip().lower(), str(c["group_id"]))
            if key not in clients_by_name_and_group:
                clients_by_name_and_group[key] = []
            clients_by_name_and_group[key].append(c)

    existing_clients_by_code = {
        c["client_code"].strip().upper(): c 
        for c in all_db_clients if c.get("client_code")
    }

    # Pre-load all loans, repayments, and savings
    all_loans_res = retry_call(lambda u: u.client.table("loans").select("*").execute())
    db_loans_by_client = {}
    for l in (all_loans_res.data or []):
        cid = l['client_id']
        if cid not in db_loans_by_client:
            db_loans_by_client[cid] = []
        db_loans_by_client[cid].append(l)

    reps_res = retry_call(lambda u: u.client.table("repayments").select("loan_id, client_id, amount_paid").execute())
    db_reps_by_loan = {}
    for r in (reps_res.data or []):
        lid = r.get('loan_id')
        if lid:
            db_reps_by_loan[lid] = db_reps_by_loan.get(lid, 0) + 1

    savings_res = retry_call(lambda u: u.client.table("individual_savings").select("*").eq("remarks", "Initial Onboarding Savings").execute())
    db_onboarding_savings = {s['client_id']: s for s in (savings_res.data or [])}

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
            if not dry_run:
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
            if not dry_run:
                retry_call(lambda u, new_g_data=new_g_data: u.client.table("groups").insert(new_g_data).execute())
            existing_groups_by_number[(str(gn), str(b_id))] = new_g_data
            print(f"Created new group: {g_name} (Group #{gn})")
            
        group_ref_to_info[g_ref] = {
            'group_id': g_id, 'branch_id': b_id, 'officer_id': o_id, 'branch_name': b_name, 'officer_name': o_name,
            'meeting_day': m_day, 'branch_code': b_code, 'group_number': gn, 'current_member_sequence': curr_seq
        }
        
        # Group Opening Savings (Upsert)
        if pd.notna(g_sav) and float(g_sav) > 0:
            gs_res = retry_call(lambda u, g_id=g_id: u.client.table("group_savings").select("id").eq("group_id", g_id).eq("remarks", "Initial Onboarding Group Savings").execute())
            if gs_res.data:
                gs_id = gs_res.data[0]['id']
                if not dry_run:
                    retry_call(lambda u, gs_id=gs_id, b_id=b_id, o_id=o_id, g_sav=g_sav: u.client.table("group_savings").update({
                        "deposit_amount": float(g_sav), "branch_id": b_id, "officer_id": o_id
                    }).eq("id", gs_id).execute())
                print(f"Updated Group Savings: NGN {float(g_sav):,.2f} for {g_name}")
            else:
                if not dry_run:
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

    # 3. MATCH MEMBERS & RESOLVE TARGET IDENTITIES
    print("\n--- MATCHING MEMBERS & RESOLVING TARGET CLIENT CODES ---")
    alias_map = {
        'olabanji kafayat taorid': 'olabanji kafayat',
        'adijat iyanda': 'adijat iyana'
    }

    group_max_seq = {}
    matched_members = [] # (row, existing_client_dict, target_code)
    new_members = []     # (row, target_code)

    for index, row in df_members.iterrows():
        g_ref = str(row.get('Group Reference*')).strip()
        if g_ref in ('nan', '', 'None'): continue
        
        f_name = str(row.get('Full Name*')).strip()
        m_num = row.get('Member Number')
        
        group_info = group_ref_to_info.get(g_ref)
        if not group_info:
            print(f"Skipping {f_name}, unknown group reference: {g_ref}")
            continue
            
        g_id = group_info['group_id']
        b_code = group_info['branch_code']
        gn = group_info['group_number']
        
        try:
            seq = int(float(str(m_num).strip()))
        except Exception:
            seq = index + 1
        group_max_seq[g_id] = max(group_max_seq.get(g_id, 0), seq)
        target_code = f"{b_code}-{str(gn).zfill(2)}-{str(seq).zfill(3)}"
        
        norm_name = f_name.lower()
        search_name = alias_map.get(norm_name, norm_name)
        candidates = clients_by_name_and_group.get((search_name, str(g_id)), [])

        if len(candidates) == 1:
            matched_members.append((row, candidates[0], target_code))
        elif len(candidates) > 1:
            # Disambiguate multiple accounts (e.g. Dasola Adedigba, Tiamiyu Kehinde, Oluwatoyin Adenuga)
            chosen = None
            for cand in candidates:
                if cand['client_code'].strip().upper() == target_code.strip().upper():
                    chosen = cand
                    break
            if not chosen:
                # Disambiguate by active_credit or product category
                row_prod = resolve_product(row.get('Loan Type (Product)*'))
                row_is_asset = "asset" in str(row.get('Loan Type (Product)*')).lower()
                for cand in candidates:
                    cand_loans = db_loans_by_client.get(cand['client_id'], [])
                    for cl in cand_loans:
                        cl_cat = cl.get('product_category') or ''
                        if (row_is_asset and cl_cat == 'Asset') or (not row_is_asset and cl_cat == 'Finance'):
                            chosen = cand
                            break
                    if chosen: break
            if not chosen:
                chosen = candidates[0]
            matched_members.append((row, chosen, target_code))
        else:
            new_members.append((row, target_code))

    print(f"Total Members in Template: {len(matched_members) + len(new_members)}")
    print(f"Matched Existing Clients: {len(matched_members)}")
    print(f"New Clients to Insert: {len(new_members)}")

    # 4. TWO-PHASE COLLISION-FREE CLIENT CODE REASSIGNMENT
    print("\n--- TWO-PHASE CLIENT CODE REASSIGNMENT ---")
    code_changes = []
    for row, cand, target_code in matched_members:
        if cand['client_code'].strip().upper() != target_code.strip().upper():
            code_changes.append((cand, target_code))

    print(f"Clients requiring code reassignment: {len(code_changes)}")
    for cand, target_code in code_changes:
        print(f"  {cand['name']:<25}: {cand['client_code']} -> {target_code}")

    # Phase A: Move conflicting clients to temporary code to free up target codes
    if code_changes:
        print("\nPhase A: Moving to temporary codes...")
        for cand, target_code in code_changes:
            temp_code = f"TMP-{cand['client_id'][:8]}-{uuid.uuid4().hex[:4]}".upper()
            if not dry_run:
                retry_call(lambda u, cid=cand['client_id'], temp_code=temp_code: u.client.table("clients").update({
                    "client_code": temp_code
                }).eq("client_id", cid).execute())
            cand['client_code'] = temp_code

    # Phase B: Assign canonical target code
    if code_changes:
        print("\nPhase B: Assigning canonical target codes...")
        for cand, target_code in code_changes:
            if not dry_run:
                retry_call(lambda u, cid=cand['client_id'], target_code=target_code: u.client.table("clients").update({
                    "client_code": target_code
                }).eq("client_id", cid).execute())
            cand['client_code'] = target_code

    # 5. PROCESS MEMBER DETAILS, SAVINGS, AND LOANS
    print("\n--- PROCESSING MEMBER DETAILS, SAVINGS, AND LOANS ---")
    loans_created = 0
    loans_updated = 0
    loans_removed = 0
    schedules_created = 0
    savings_updated = 0

    all_processed_items = []
    for row, cand, target_code in matched_members:
        all_processed_items.append((row, cand['client_id'], target_code, False))
    for row, target_code in new_members:
        new_cid = str(uuid.uuid4())
        all_processed_items.append((row, new_cid, target_code, True))

    for row, c_id, target_code, is_new in all_processed_items:
        g_ref = str(row.get('Group Reference*')).strip()
        group_info = group_ref_to_info[g_ref]
        g_id = group_info['group_id']
        b_id = group_info['branch_id']
        o_id = group_info['officer_id']
        
        f_name = str(row.get('Full Name*')).strip()
        phone = str(row.get('Phone Number*')).strip() if pd.notna(row.get('Phone Number*')) else ""
        address = str(row.get('Home Address*')).strip() if pd.notna(row.get('Home Address*')) else ""
        if phone == 'nan': phone = ""
        if address == 'nan': address = ""
        
        s_bal = row.get('Savings Balance*')
        l_type = str(row.get('Loan Type (Product)*')).strip()
        p_loan = row.get('Principal Loan*')
        a_cred = row.get('Active Credit (Disbursed)*')
        c_bal = row.get('Current Credit Balance*')
        
        has_active_loan = bool(pd.notna(a_cred) and float(a_cred) > 0)
        has_savings_only = bool(pd.notna(s_bal) and float(s_bal) > 0 and not has_active_loan)

        if has_active_loan:
            target_status_id = ON_LOAN_STATUS_ID
            target_status_str = "On Loan"
        elif has_savings_only:
            target_status_id = SAVINGS_ONLY_STATUS_ID
            target_status_str = "Inactive (Savings Only)"
        else:
            target_status_id = REG_STATUS_ID
            target_status_str = "Registered"

        # Update or Insert Client Record
        if is_new:
            new_c_data = {
                "client_id": c_id, "name": f_name, "phone": phone, "address": address,
                "status": target_status_str, "status_id": target_status_id,
                "client_code": target_code, "branch_id": b_id, "group_id": g_id, "officer_id": o_id
            }
            if not dry_run:
                retry_call(lambda u, new_c_data=new_c_data: u.client.table("clients").insert(new_c_data).execute())
            print(f"Created new client: {target_code} ({f_name})")
        else:
            if not dry_run:
                retry_call(lambda u, c_id=c_id, f_name=f_name, phone=phone, address=address, b_id=b_id, o_id=o_id, g_id=g_id, target_code=target_code, target_status_str=target_status_str, target_status_id=target_status_id: u.client.table("clients").update({
                    "name": f_name, "phone": phone, "address": address, "branch_id": b_id,
                    "officer_id": o_id, "group_id": g_id, "client_code": target_code,
                    "status": target_status_str, "status_id": target_status_id
                }).eq("client_id", c_id).execute())

        # Client Memberships Sync
        if not dry_run:
            if (c_id, g_id) not in existing_memberships_set:
                retry_call(lambda u, c_id=c_id: u.client.table("client_memberships").delete().eq("client_id", c_id).execute())
                retry_call(lambda u, c_id=c_id, g_id=g_id, b_id=b_id, o_id=o_id: u.client.table("client_memberships").insert({
                    "membership_id": str(uuid.uuid4()), "client_id": c_id, "group_id": g_id, "branch_id": b_id, "officer_id": o_id
                }).execute())
                existing_memberships_set.add((c_id, g_id))

        # Individual Opening Savings (Upsert)
        existing_sav = db_onboarding_savings.get(c_id)
        if pd.notna(s_bal) and float(s_bal) > 0:
            sav_val = float(s_bal)
            if existing_sav:
                if abs(float(existing_sav.get('deposit_amount', 0)) - sav_val) > 0.01:
                    if not dry_run:
                        retry_call(lambda u, sid=existing_sav['id'], sav_val=sav_val, b_id=b_id, o_id=o_id: u.client.table("individual_savings").update({
                            "deposit_amount": sav_val, "branch_id": b_id, "officer_id": o_id
                        }).eq("id", sid).execute())
                    print(f"Updated Savings: NGN {sav_val:,.2f} for {f_name} ({target_code})")
                    savings_updated += 1
            else:
                if not dry_run:
                    retry_call(lambda u, c_id=c_id, sav_val=sav_val, b_id=b_id, o_id=o_id: u.client.table("individual_savings").insert({
                        "id": str(uuid.uuid4()), "client_id": c_id, "posting_date": "1970-01-01",
                        "branch_id": b_id, "officer_id": o_id, "deposit_amount": sav_val,
                        "withdrawal_amount": 0.0, "reference": "ONBOARDING-MEMBER-OPENING",
                        "remarks": "Initial Onboarding Savings"
                    }).execute())
                print(f"Posted Savings: NGN {sav_val:,.2f} for {f_name} ({target_code})")
                savings_updated += 1
        elif existing_sav and (pd.isna(s_bal) or float(s_bal) == 0):
            # Corrected to 0
            if float(existing_sav.get('deposit_amount', 0)) > 0:
                if not dry_run:
                    retry_call(lambda u, sid=existing_sav['id']: u.client.table("individual_savings").update({
                        "deposit_amount": 0.0
                    }).eq("id", sid).execute())
                print(f"Zeroed Savings for {f_name} ({target_code})")
                savings_updated += 1

        # Loans & Schedule
        existing_client_loans = db_loans_by_client.get(c_id, [])
        active_legacy_loans = [l for l in existing_client_loans if l.get('status') == 'Active']

        if has_active_loan:
            prod = resolve_product(l_type)
            if not prod:
                print(f"  Warning: Loan Product '{l_type}' not found for {f_name}. Skipping loan!")
                continue

            duration = int(prod.get('installments') or 24)
            cycle = prod.get('repayment_cycle', 'Weekly')
            expected_inst = float(a_cred) / duration if duration > 0 else 0
            current_bal = float(c_bal) if pd.notna(c_bal) else float(a_cred)
            prod_cat = "Asset" if "asset" in prod.get('name', '').lower() else "Finance"

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
                "onboarded_at": "2026-08-19",
                "initial_active_credit": float(a_cred),
                "initial_balance": current_bal,
                "elapsed_cycles": elapsed_installments,
                "product_category": prod_cat
            }

            matched_loan = None
            if active_legacy_loans:
                # Prefer loan matching product category
                for l in active_legacy_loans:
                    if l.get('product_category') == prod_cat:
                        matched_loan = l
                        break
                if not matched_loan:
                    matched_loan = active_legacy_loans[0]

            if matched_loan:
                loan_id = matched_loan['loan_id']
                rep_count = db_reps_by_loan.get(loan_id, 0)
                
                # Check if product or values changed
                prod_changed = (matched_loan.get('product_id') != prod['product_id'])
                cred_changed = abs(float(matched_loan.get('active_credit') or 0) - float(a_cred)) > 0.01
                bal_changed = abs(float(matched_loan.get('total_due') or 0) - current_bal) > 0.01

                if prod_changed or cred_changed or bal_changed:
                    print(f"Updating Loan for {f_name} ({target_code}): Prod={prod['name']}, Active={a_cred}, Bal={current_bal}")
                    if not dry_run:
                        retry_call(lambda u, loan_id=loan_id, current_bal=current_bal, a_cred=a_cred, p_loan=p_loan, expected_inst=expected_inst, b_id=b_id, o_id=o_id, prod=prod, prod_cat=prod_cat, legacy_extra=legacy_extra: u.client.table("loans").update({
                            "total_due": current_bal, "active_credit": float(a_cred), "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred),
                            "loan_repay": round(expected_inst, 2), "branch_id": b_id, "officer_id": o_id,
                            "product_id": prod['product_id'], "product_category": prod_cat, "extra_fields": legacy_extra
                        }).eq("loan_id", loan_id).execute())
                    loans_updated += 1

                    # If no repayments were posted yet, regenerate schedule cleanly
                    if rep_count == 0:
                        if not dry_run:
                            retry_call(lambda u, loan_id=loan_id: u.client.table("loan_schedule").delete().eq("loan_id", loan_id).execute())
                        should_create_schedule = True
                    else:
                        should_create_schedule = False
                else:
                    should_create_schedule = False
            else:
                loan_id = str(uuid.uuid4())
                print(f"Creating New Loan for {f_name} ({target_code}): Prod={prod['name']}, Active={a_cred}, Bal={current_bal}")
                if not dry_run:
                    retry_call(lambda u, loan_id=loan_id, c_id=c_id, hist_date=hist_date, p_loan=p_loan, a_cred=a_cred, expected_inst=expected_inst, current_bal=current_bal, b_id=b_id, o_id=o_id, prod=prod, prod_cat=prod_cat, legacy_extra=legacy_extra: u.client.table("loans").insert({
                        "loan_id": loan_id, "client_id": c_id, "date": hist_date.isoformat(), "disbursement_date": hist_date.isoformat(), "start_date": hist_date.isoformat(),
                        "loan_amount": float(p_loan) if pd.notna(p_loan) else float(a_cred), "active_credit": float(a_cred),
                        "loan_repay": round(expected_inst, 2),
                        "total_due": current_bal, "status": "Active", "branch_id": b_id, "officer_id": o_id, "product_id": prod['product_id'],
                        "product_category": prod_cat,
                        "extra_fields": legacy_extra
                    }).execute())
                loans_created += 1
                should_create_schedule = True

            # Generate repayment schedule starting NEXT meeting/collection day (FP-008)
            if should_create_schedule and expected_inst > 0 and current_bal > 0:
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
                else:
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
                    if not dry_run:
                        retry_call(lambda u, schedule_rows=schedule_rows: u.client.table("loan_schedule").insert(schedule_rows).execute())
                    schedules_created += len(schedule_rows)
                    print(f"  Generated {len(schedule_rows)} schedule installments for {f_name} starting {schedule_rows[0]['due_date']}.")

        elif not has_active_loan and active_legacy_loans:
            # Loan was removed in template (e.g. Funmilayo sunday)
            for old_loan in active_legacy_loans:
                old_lid = old_loan['loan_id']
                old_reps = db_reps_by_loan.get(old_lid, 0)
                if old_reps == 0:
                    print(f"Removing unused legacy loan {old_lid} for {f_name} ({target_code})")
                    if not dry_run:
                        retry_call(lambda u, old_lid=old_lid: u.client.table("loan_schedule").delete().eq("loan_id", old_lid).execute())
                        retry_call(lambda u, old_lid=old_lid: u.client.table("loans").delete().eq("loan_id", old_lid).execute())
                    loans_removed += 1
                else:
                    print(f"  Warning: Loan {old_lid} for {f_name} has {old_reps} repayments; cannot delete!")

    # 6. UPDATE GROUP CURRENT MEMBER SEQUENCE
    print("\n--- UPDATING GROUP MEMBER SEQUENCES ---")
    for g_id, max_seq in group_max_seq.items():
        if not dry_run:
            retry_call(lambda u, g_id=g_id, max_seq=max_seq: u.client.table("groups").update({
                "current_member_sequence": max_seq
            }).eq("group_id", g_id).execute())

    # 7. PROCESS BRANCH POOLED SAVINGS (LAPS & Misc Fees)
    print("\n--- PROCESSING BRANCH POOLED SAVINGS (LAPS & MISC FEES) ---")
    try:
        df_bo_raw = pd.read_excel(file_path, sheet_name="Branch and Officer List", header=None)
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
                if branch_laps_val > 0:
                    ex_laps = retry_call(lambda u: u.client.table("laps_savings").select("id").eq("branch_id", b_id).eq("reference", "ONBOARDING_LEGACY").execute())
                    if not ex_laps.data:
                        if not dry_run:
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
                        print(f"  Ingested Branch LAPS Savings: NGN {branch_laps_val:,.2f} for branch '{target_branch_name}'.")
                    else:
                        print(f"  Branch LAPS Savings already onboarded for branch '{target_branch_name}' (NGN {branch_laps_val:,.2f}).")
                
                if misc_fees_val > 0:
                    from services.savings_service import SavingsService
                    uow_tmp = get_uow()
                    managing_id, managing_name = SavingsService.get_branch_misc_savings_officer(uow_tmp, target_branch_name)
                    ex_misc = retry_call(lambda u: u.client.table("internal_savings").select("id").eq("branch_id", b_id).eq("reference", "ONBOARDING_LEGACY").execute())
                    if not ex_misc.data:
                        if not dry_run:
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
                        print(f"  Ingested Misc Fees Savings: NGN {misc_fees_val:,.2f} for branch '{target_branch_name}' (Assigned to {managing_name}).")
                    else:
                        print(f"  Misc Fees Savings already onboarded for branch '{target_branch_name}' (NGN {misc_fees_val:,.2f}).")
    except Exception as bo_err:
        print(f"Note: Could not parse Branch and Officer List for pooled savings: {bo_err}")

    print("\n==================================================")
    print(f"ONBOARDING COMPLETE: {mode_str}")
    print(f"New Clients Inserted: {len(new_members)}")
    print(f"Client Codes Reassigned: {len(code_changes)}")
    print(f"Savings Records Updated: {savings_updated}")
    print(f"Loans Created: {loans_created}")
    print(f"Loans Updated: {loans_updated}")
    print(f"Loans Removed: {loans_removed}")
    print(f"Schedule Installments Created: {schedules_created}")
    print("==================================================")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Ingest onboarding template into Supabase.")
    parser.add_argument("--dry-run", action="store_true", help="Audit mode: print actions without writing to DB.")
    args = parser.parse_args()
    run_migration(dry_run=args.dry_run)
