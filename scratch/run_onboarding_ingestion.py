import os
import sys
import uuid
import math
from datetime import datetime, date, timedelta
import pandas as pd
from database.repositories.unit_of_work import SupabaseUnitOfWork

def run_onboarding():
    excel_path = r"C:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\icare-group-member-onboarding-template.xlsx"
    print("==========================================================")
    print("🚀 RUNNING ONBOARDING INGESTION FROM EXCEL")
    print(f"File: {excel_path}")
    print("==========================================================")

    uow = SupabaseUnitOfWork()

    # 1. Load Officer and Branch Reference Maps
    user_res = uow.client.table("app_users").select("id, username, full_name, branch_id").execute()
    officer_map = {}
    for u in (user_res.data or []):
        if u.get("username"):
            officer_map[str(u["username"]).strip().lower()] = u["id"]
        if u.get("full_name"):
            officer_map[str(u["full_name"]).strip().lower()] = u["id"]
    
    # Explicit aliases
    officer_map["miss. olajumoke"] = "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc"
    officer_map["mr. oluwaseun"] = "0ad2a283-3ed1-42ea-ae7f-5b33b665389d"
    officer_map["mr. oluwaseun "] = "0ad2a283-3ed1-42ea-ae7f-5b33b665389d"
    officer_map["mr. ayomide"] = "c32125e1-c7e5-4a85-8948-12d05b40eaa9"
    officer_map["mrs. dorcas"] = "573eca5f-958a-4ad4-950a-4108b0a798dc"

    branch_res = uow.client.table("branches").select("branch_id, name").execute()
    branch_map = {str(b["name"]).strip().lower(): b["branch_id"] for b in (branch_res.data or [])}
    default_branch_id = branch_map.get("ogijo", "997d504e-7f5c-4772-887d-fdd5a4c1183b")

    prod_res = uow.client.table("loan_products").select("product_id, name, repayment_cycle, installments").execute()
    prod_map = {}
    for p in (prod_res.data or []):
        p_name = str(p["name"]).strip().lower()
        prod_map[p_name] = p
        if "12w" in p_name:
            prod_map["weekly 12w"] = p
            prod_map["12w"] = p
        if "24w" in p_name:
            prod_map["weekly 24w"] = p
            prod_map["24w"] = p
        if "60" in p_name:
            prod_map["daily 60 days"] = p
            prod_map["60 days"] = p
        if "120" in p_name:
            prod_map["daily 120 days"] = p
            prod_map["120 days"] = p

    # 2. Read Groups Sheet (header row at index 2)
    df_groups = pd.read_excel(excel_path, sheet_name="Groups", header=2)
    valid_groups = df_groups[df_groups['Group Name*'].notna()]
    print(f"Found {len(valid_groups)} groups to process...")

    group_ref_to_id = {}
    group_ref_to_info = {}

    day_name_to_weekday = {
        "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6
    }

    base_date = date.today()

    for _, row in valid_groups.iterrows():
        g_ref = str(row['Group Reference*']).strip()
        g_name = str(row['Group Name*']).strip()
        b_name = str(row.get('Branch Name*') or 'Ogijo').strip().lower()
        b_id = branch_map.get(b_name, default_branch_id)
        
        co_name = str(row.get('Credit Officer Name*') or '').strip().lower()
        o_id = officer_map.get(co_name, "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc")
        
        m_day = str(row.get('Meeting Day*') or 'Daily').strip()
        l_name = str(row.get('Group Leader Name*')).strip() if pd.notna(row.get('Group Leader Name*')) else None
        
        g_savings = float(row.get('Group Savings')) if pd.notna(row.get('Group Savings')) else 0.0

        # Check existing group in DB
        g_res = uow.client.table("groups").select("*").ilike("name", g_name).execute()
        if g_res.data:
            g_id = g_res.data[0]['group_id']
            u_dict = {"meeting_day": m_day, "branch_id": b_id, "officer_id": o_id}
            if l_name: u_dict["leader_name"] = l_name
            uow.client.table("groups").update(u_dict).eq("group_id", g_id).execute()
            print(f"  [Group Updated] {g_name} (ID: {g_id}) | Leader: {l_name}")
        else:
            g_id = str(uuid.uuid4())
            ins_dict = {
                "group_id": g_id, "name": g_name, "meeting_day": m_day,
                "branch_id": b_id, "officer_id": o_id, "status": "Active"
            }
            if l_name: ins_dict["leader_name"] = l_name
            uow.client.table("groups").insert(ins_dict).execute()
            print(f"  [Group Created] {g_name} (ID: {g_id}) | Leader: {l_name}")

        group_ref_to_id[g_ref] = g_id
        group_ref_to_info[g_ref] = {
            "group_id": g_id, "name": g_name, "meeting_day": m_day,
            "branch_id": b_id, "officer_id": o_id, "leader_name": l_name
        }

        # Post Group Savings if present
        if g_savings > 0:
            gs_chk = uow.client.table("group_savings").select("id").eq("group_id", g_id).execute()
            if not gs_chk.data:
                uow.client.table("group_savings").insert({
                    "id": str(uuid.uuid4()), "group_id": g_id, "branch_id": b_id, "officer_id": o_id,
                    "deposit_amount": g_savings, "withdrawal_amount": 0.0,
                    "posting_date": base_date.isoformat(), "remarks": "Initial Onboarding Group Savings"
                }).execute()
                print(f"    Posted Group Savings: ₦{g_savings:,.2f} for group {g_name}")

    # 3. Read Members Sheet (header row at index 2)
    df_members = pd.read_excel(excel_path, sheet_name="Members", header=2)
    valid_members = df_members[df_members['Full Name*'].notna()]
    print(f"\nFound {len(valid_members)} members to process...")

    for _, row in valid_members.iterrows():
        m_ref = str(row['Member Reference*']).strip()
        g_ref = str(row.get('Group Reference*') or '').strip()
        m_num = str(row.get('Member Number') or '').strip()
        f_name = str(row['Full Name*']).strip()
        
        # Phone
        raw_phone = row.get('Phone Number*')
        if pd.notna(raw_phone):
            try:
                phone_str = f"0{int(float(raw_phone))}"
            except:
                phone_str = str(raw_phone).strip()
        else:
            phone_str = ""

        # Address
        raw_addr = row.get('Home Address*')
        addr_str = str(raw_addr).strip() if pd.notna(raw_addr) else "Ogijo, Ogun State"

        # Savings
        s_bal = float(row.get('Savings Balance*')) if pd.notna(row.get('Savings Balance*')) else 0.0

        # Loan details
        l_type = str(row.get('Loan Type (Product)*') or '').strip()
        p_loan = float(row.get('Principal Loan*')) if pd.notna(row.get('Principal Loan*')) else None
        a_cred = float(row.get('Active Credit (Disbursed)*')) if pd.notna(row.get('Active Credit (Disbursed)*')) else None
        c_bal = float(row.get('Current Credit Balance*')) if pd.notna(row.get('Current Credit Balance*')) else None

        g_info = group_ref_to_info.get(g_ref, {})
        g_id = g_info.get("group_id")
        b_id = g_info.get("branch_id", default_branch_id)
        o_id = g_info.get("officer_id", "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc")
        m_day = g_info.get("meeting_day", "Daily")

        # Generate standard client code
        g_num_part = g_ref.replace("GRP-", "").replace("GRP", "").zfill(2)
        m_num_part = m_num.zfill(3) if m_num and m_num.isdigit() else m_ref.replace("MEM-", "").replace("MEM", "").zfill(3)
        client_code = f"OGI-{g_num_part}-{m_num_part}"

        # Check / create client
        c_res = uow.client.table("clients").select("*").or_(f"name.eq.{f_name},client_code.eq.{client_code}").execute()
        if c_res.data:
            c_id = c_res.data[0]['client_id']
            u_client = {"phone": phone_str, "address": addr_str, "branch_id": b_id, "group_id": g_id, "officer_id": o_id, "status": "Active"}
            uow.client.table("clients").update(u_client).eq("client_id", c_id).execute()
        else:
            c_id = str(uuid.uuid4())
            ins_client = {
                "client_id": c_id, "name": f_name, "client_code": client_code,
                "phone": phone_str, "address": addr_str, "branch_id": b_id,
                "group_id": g_id, "officer_id": o_id, "status": "Active"
            }
            uow.client.table("clients").insert(ins_client).execute()

        # Link Client Membership
        if g_id:
            cm_res = uow.client.table("client_memberships").select("membership_id").eq("client_id", c_id).eq("group_id", g_id).execute()
            if not cm_res.data:
                uow.client.table("client_memberships").insert({
                    "membership_id": str(uuid.uuid4()), "client_id": c_id, "group_id": g_id,
                    "branch_id": b_id, "officer_id": o_id, "start_date": base_date.isoformat()
                }).execute()

        # Post Individual Savings
        if s_bal > 0:
            is_res = uow.client.table("individual_savings").select("id").eq("client_id", c_id).execute()
            if not is_res.data:
                uow.client.table("individual_savings").insert({
                    "id": str(uuid.uuid4()), "client_id": c_id, "branch_id": b_id, "officer_id": o_id,
                    "deposit_amount": s_bal, "withdrawal_amount": 0.0,
                    "posting_date": base_date.isoformat(), "remarks": "Initial Onboarding Savings"
                }).execute()
                print(f"    Posted Savings: ₦{s_bal:,.2f} for {f_name} ({client_code})")

        # Post Loans & Schedules
        if a_cred and a_cred > 0:
            prod = prod_map.get(l_type.lower()) if l_type else None
            if not prod:
                # Default to Weekly 12W if not resolved
                prod = prod_map.get("weekly 12w") or list(prod_map.values())[0]

            duration = int(prod.get("installments") or 12)
            cycle = prod.get("repayment_cycle", "Weekly")
            expected_inst = round(a_cred / duration, 2) if duration > 0 else 0.0
            current_bal = c_bal if (c_bal is not None and c_bal >= 0) else a_cred
            loan_amt = p_loan if (p_loan is not None and p_loan > 0) else a_cred

            l_chk = uow.client.table("loans").select("*").eq("client_id", c_id).eq("status", "Active").execute()
            if l_chk.data:
                loan_id = l_chk.data[0]['loan_id']
                uow.client.table("loans").update({
                    "loan_amount": loan_amt, "active_credit": a_cred, "total_due": current_bal,
                    "loan_repay": expected_inst, "branch_id": b_id, "officer_id": o_id, "product_id": prod['product_id']
                }).eq("loan_id", loan_id).execute()
            else:
                loan_id = str(uuid.uuid4())
                uow.client.table("loans").insert({
                    "loan_id": loan_id, "client_id": c_id, "date": base_date.isoformat(),
                    "loan_amount": loan_amt, "active_credit": a_cred, "total_due": current_bal,
                    "loan_repay": expected_inst, "status": "Active", "branch_id": b_id, "officer_id": o_id,
                    "product_id": prod['product_id']
                }).execute()

            # Schedule Generation
            sch_chk = uow.client.table("loan_schedule").select("id").eq("loan_id", loan_id).execute()
            if not sch_chk.data and expected_inst > 0 and current_bal > 0:
                remaining_count = math.ceil(current_bal / expected_inst)
                
                # Next meeting day calculation
                t_weekday = day_name_to_weekday.get(m_day.lower(), 0)
                anchor = base_date
                if cycle == "Weekly":
                    days_ahead = t_weekday - anchor.weekday()
                    if days_ahead <= 0: days_ahead += 7
                    anchor = anchor + timedelta(days=days_ahead)
                elif cycle == "Daily":
                    anchor = anchor + timedelta(days=1)

                schedule_rows = []
                past_paid = round(a_cred - current_bal, 2)
                
                # BR-DASH-006: Insert historical paid installment 0
                if past_paid > 0.01:
                    schedule_rows.append({
                        "id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": 0,
                        "due_date": "1970-01-01", "principal": past_paid, "interest": 0.0,
                        "fees": 0.0, "total_due": past_paid, "status": "Paid",
                        "paid_amount": past_paid, "paid_date": "1970-01-01"
                    })
                    
                    rep_chk = uow.client.table("repayments").select("id").eq("loan_id", loan_id).execute()
                    if not rep_chk.data:
                        uow.client.table("repayments").insert({
                            "id": str(uuid.uuid4()), "loan_id": loan_id, "client_id": c_id,
                            "branch_id": b_id, "officer_id": o_id, "amount_paid": past_paid,
                            "transaction_type": "ONBOARDING_LEGACY", "payment_status": "Completed",
                            "date": "1970-01-01", "note": "Legacy Repayments Onboarded"
                        }).execute()

                rem_bal_track = current_bal
                for inst_idx in range(1, remaining_count + 1):
                    if inst_idx > 1:
                        if cycle == "Weekly":
                            anchor += timedelta(weeks=1)
                        elif cycle == "Daily":
                            anchor += timedelta(days=1)
                    
                    # Skip weekends
                    while anchor.weekday() >= 5:
                        anchor += timedelta(days=1)
                        
                    inst_amt = min(expected_inst, rem_bal_track)
                    rem_bal_track -= inst_amt
                    
                    schedule_rows.append({
                        "id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": inst_idx,
                        "due_date": anchor.isoformat(), "principal": inst_amt, "interest": 0.0,
                        "fees": 0.0, "total_due": inst_amt, "status": "Pending",
                        "paid_amount": 0.0, "paid_date": None
                    })
                    if rem_bal_track <= 0: break

                if schedule_rows:
                    uow.client.table("loan_schedule").insert(schedule_rows).execute()
                    print(f"    Generated Loan & {len(schedule_rows)} installments for {f_name}: Active=₦{a_cred:,.2f}, Bal=₦{current_bal:,.2f}, Repay=₦{expected_inst:,.2f}")

    print("\n==========================================================")
    print("✨ ONBOARDING INGESTION COMPLETED SUCCESSFULLY!")
    print("==========================================================")

if __name__ == "__main__":
    run_onboarding()
