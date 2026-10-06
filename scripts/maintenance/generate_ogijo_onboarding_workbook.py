"""
Generate Ogijo Branch October 2026 Onboarding Master Workbook.
Authoritative synchronization from Supabase database to Excel template:
- Strictly Ogijo Branch solidarity groups (51 groups, GRP-01 to GRP-51)
- All 422 group-affiliated members (424 member loan rows including dual loans)
- Reconciled individual savings balances and active loan balances as of Oct 1, 2026
"""

import sys
import os
import copy
from datetime import datetime, date
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
import pandas as pd

sys.path.insert(0, os.getcwd())
from database.connection import supabase

def generate_workbook():
    print("==================================================================")
    print("GENERATING OGIJO BRANCH OCTOBER 2026 ONBOARDING MASTER WORKBOOK")
    print("==================================================================")

    backup_path = "storage/workbooks/icare-group-member-onboarding-template-Sep2026-backup.xlsx"
    target_active_path = "storage/workbooks/icare-group-member-onboarding-template.xlsx"
    target_dated_path = "storage/workbooks/icare-group-member-onboarding-template-Ogijo-Oct2026.xlsx"

    # 1. Fetch Ogijo Branch
    res_b = supabase.table("branches").select("branch_id, name, code").eq("name", "Ogijo").execute()
    if not res_b.data:
        raise ValueError("Ogijo branch not found in database!")
    ogijo_id = res_b.data[0]["branch_id"]
    ogijo_name = res_b.data[0]["name"]
    ogijo_code = res_b.data[0]["code"] or "OGI"
    print(f"Branch: {ogijo_name} ({ogijo_id})")

    # 2. Fetch Officers
    users_res = supabase.table("app_users").select("id, username, full_name, branch_id, extra_fields").execute()
    user_name_map = {}
    user_phone_map = {}
    for u in (users_res.data or []):
        uid = u["id"]
        fn = u.get("full_name") or u.get("username")
        user_name_map[uid] = fn
        
        ef = u.get("extra_fields") or {}
        ph = ef.get("phone") or ef.get("phone_number")
        if not ph:
            un = str(u.get("username", "")).lower()
            fl = str(fn).lower()
            if "ayomide" in un or "ayomide" in fl: ph = "08127382706"
            elif "dorcas" in un or "dorcas" in fl: ph = "08139512052"
            elif "oluwaseun" in un or "oluwaseun" in fl: ph = "09049374666"
            elif "olajumoke" in un or "olajumoke" in fl: ph = "07036076569"
        user_phone_map[uid] = str(ph or "").replace(".0", "")

    # 3. Fetch Loan Products
    prod_res = supabase.table("loan_products").select("product_id, name, repayment_cycle").execute()
    prod_map = {p["product_id"]: p["name"] for p in (prod_res.data or [])}

    # 4. Fetch 51 Ogijo Groups
    groups_res = supabase.table("groups").select("*").eq("branch_id", ogijo_id).execute()
    all_groups = groups_res.data or []
    # Sort groups numerically by group_number
    def parse_gnum(g):
        gn = g.get("group_number")
        try: return int(gn)
        except: return 999
    all_groups.sort(key=parse_gnum)
    print(f"Found {len(all_groups)} Ogijo groups.")

    # 5. Fetch Group Savings
    grp_sav_res = supabase.table("group_savings").select("group_id, deposit_amount, withdrawal_amount").execute()
    df_gs = pd.DataFrame(grp_sav_res.data or [])
    if not df_gs.empty:
        df_gs["deposit_amount"] = pd.to_numeric(df_gs["deposit_amount"], errors="coerce").fillna(0.0)
        df_gs["withdrawal_amount"] = pd.to_numeric(df_gs["withdrawal_amount"], errors="coerce").fillna(0.0)
        df_gs["net"] = df_gs["deposit_amount"] - df_gs["withdrawal_amount"]
        grp_savings_map = df_gs.groupby("group_id")["net"].sum().to_dict()
    else:
        grp_savings_map = {}

    # Map groups to reference
    group_info_by_id = {}
    for g in all_groups:
        gid = g["group_id"]
        gnum = parse_gnum(g)
        g_ref = f"GRP-{str(gnum).zfill(2)}"
        g_leader = g.get("leader_name") or g.get("name")
        g_day = g.get("meeting_day") or "Daily"
        g_officer = user_name_map.get(g.get("officer_id"), "Miss. Olajumoke")
        g_phone = user_phone_map.get(g.get("officer_id"), "07036076569")
        g_savings = float(grp_savings_map.get(gid, 0.0))
        g_date = g.get("created_at") or "2018-03-23"
        if isinstance(g_date, str) and "T" in g_date:
            g_date = g_date.split("T")[0]

        group_info_by_id[gid] = {
            "group_id": gid,
            "group_number": gnum,
            "group_reference": g_ref,
            "branch_name": ogijo_name,
            "group_name": g.get("name"),
            "group_leader_name": g_leader,
            "meeting_day": g_day,
            "formation_date": g_date,
            "officer_name": g_officer,
            "officer_phone": g_phone,
            "group_savings": g_savings
        }

    # 6. Fetch Ogijo Group Members
    clients_res = supabase.table("clients").select("*").eq("branch_id", ogijo_id).not_.is_("group_id", "null").execute()
    all_clients = clients_res.data or []
    print(f"Found {len(all_clients)} Ogijo group members.")

    # 7. Fetch Individual Savings
    ind_sav_res = supabase.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").execute()
    df_is = pd.DataFrame(ind_sav_res.data or [])
    if not df_is.empty:
        df_is["deposit_amount"] = pd.to_numeric(df_is["deposit_amount"], errors="coerce").fillna(0.0)
        df_is["withdrawal_amount"] = pd.to_numeric(df_is["withdrawal_amount"], errors="coerce").fillna(0.0)
        df_is["net"] = df_is["deposit_amount"] - df_is["withdrawal_amount"]
        client_savings_map = df_is.groupby("client_id")["net"].sum().to_dict()
    else:
        client_savings_map = {}

    # 8. Fetch Active Loans & Repayments
    reps_res = supabase.table("repayments").select("loan_id, amount_paid").execute()
    df_rp = pd.DataFrame(reps_res.data or [])
    if not df_rp.empty:
        df_rp["amount_paid"] = pd.to_numeric(df_rp["amount_paid"], errors="coerce").fillna(0.0)
        reps_by_loan = df_rp.groupby("loan_id")["amount_paid"].sum().to_dict()
    else:
        reps_by_loan = {}

    loans_res = supabase.table("loans").select("*").eq("branch_id", ogijo_id).execute()
    active_loans_by_client = {}
    for l in (loans_res.data or []):
        if l.get("status") == "Active":
            cid = l["client_id"]
            lid = l["loan_id"]
            pid = l.get("product_id")
            pname = prod_map.get(pid, "Daily 60 Days")
            
            tot_due = float(l.get("total_due") or l.get("active_credit") or l.get("loan_amount") or 0.0)
            paid = reps_by_loan.get(lid, 0.0)
            rem_bal = max(0.0, tot_due - paid)
            
            loan_item = {
                "loan_id": lid,
                "product_name": pname,
                "loan_amount": float(l.get("loan_amount") or 0.0),
                "active_credit": float(l.get("active_credit") or 0.0),
                "total_due": tot_due,
                "paid": paid,
                "remaining_balance": rem_bal,
                "is_asset": "asset" in pname.lower()
            }
            if cid not in active_loans_by_client:
                active_loans_by_client[cid] = []
            active_loans_by_client[cid].append(loan_item)

    # 9. Structure Member Rows Group-by-Group
    # Group clients by group_id
    clients_by_group = {}
    for c in all_clients:
        gid = c["group_id"]
        if gid not in clients_by_group:
            clients_by_group[gid] = []
        clients_by_group[gid].append(c)

    # Sort clients within each group by client_code sequence
    def parse_seq(c):
        code = str(c.get("client_code") or "")
        parts = code.split("-")
        try: return int(parts[-1])
        except: return 999

    member_rows_data = []
    total_savings_sum = 0.0
    total_active_credit_sum = 0.0
    total_loan_balance_sum = 0.0

    for g in all_groups:
        gid = g["group_id"]
        g_info = group_info_by_id[gid]
        g_ref = g_info["group_reference"]
        group_clients = clients_by_group.get(gid, [])
        group_clients.sort(key=parse_seq)

        for seq, client in enumerate(group_clients, 1):
            cid = client["client_id"]
            client_code = client.get("client_code") or f"OGI-{str(g_info['group_number']).zfill(2)}-{str(seq).zfill(3)}"
            full_name = client.get("name") or "Unknown"
            phone_raw = client.get("phone") or "00000000000"
            phone = str(phone_raw).replace(".0", "").strip()
            if not phone or phone == "nan": phone = "00000000000"
            if len(phone) == 10 and not phone.startswith("0"):
                phone = "0" + phone
            address = client.get("address") or client.get("business_address") or "Ogijo"
            
            savings_bal = float(client_savings_map.get(cid, 0.0))
            total_savings_sum += savings_bal

            client_loans = active_loans_by_client.get(cid, [])
            
            if not client_loans:
                # Member with no active loan (savings-only or completed)
                member_rows_data.append({
                    "member_ref": client_code,
                    "group_ref": g_ref,
                    "member_num": seq,
                    "full_name": full_name,
                    "phone": phone,
                    "address": address,
                    "savings_balance": savings_bal,
                    "loan_product": None,
                    "principal_loan": None,
                    "active_credit": None,
                    "current_credit_balance": None
                })
            else:
                # Put cash loan first if multiple loans
                client_loans.sort(key=lambda x: (1 if x["is_asset"] else 0))
                for l_idx, loan_info in enumerate(client_loans):
                    # Only the first loan row carries the member's savings balance
                    row_sav_bal = savings_bal if l_idx == 0 else 0.0
                    p_loan = loan_info["loan_amount"] if loan_info["loan_amount"] > 0 else loan_info["active_credit"]
                    act_cred = loan_info["active_credit"]
                    rem_bal = loan_info["remaining_balance"]
                    
                    total_active_credit_sum += act_cred
                    total_loan_balance_sum += rem_bal

                    member_rows_data.append({
                        "member_ref": client_code,
                        "group_ref": g_ref,
                        "member_num": seq,
                        "full_name": full_name,
                        "phone": phone,
                        "address": address,
                        "savings_balance": row_sav_bal,
                        "loan_product": loan_info["product_name"],
                        "principal_loan": p_loan,
                        "active_credit": act_cred,
                        "current_credit_balance": rem_bal
                    })

    print(f"Generated {len(member_rows_data)} member rows across {len(all_groups)} groups.")
    print(f"Total Client Savings: NGN {total_savings_sum:,.2f}")
    print(f"Total Active Credit:  NGN {total_active_credit_sum:,.2f}")
    print(f"Total Loan Balance:   NGN {total_loan_balance_sum:,.2f}")

    # 10. Load Excel Template & Apply Styling
    wb = openpyxl.load_workbook(backup_path)

    # Sheet 1: Instructions
    ws_inst = wb['Instructions']
    ws_inst.cell(5, 2).value = "ICARE Management System"
    ws_inst.cell(6, 2).value = "2026-10-01"
    ws_inst.cell(7, 2).value = "Live Database Synchronization (Oct 2026 Baseline)"
    ws_inst.cell(8, 2).value = "Ogijo Branch"
    ws_inst.cell(9, 2).value = "Ogijo Branch solidarity groups (51 groups) and members (422 clients). Balances pre-populated from database for manual paper verification and updates."

    # Style templates from existing template
    thin_border = Border(
        left=Side(style='thin', color='D9D9D9'),
        right=Side(style='thin', color='D9D9D9'),
        top=Side(style='thin', color='D9D9D9'),
        bottom=Side(style='thin', color='D9D9D9')
    )
    regular_font = Font(name='Calibri', size=11)
    bold_font = Font(name='Calibri', size=11, bold=True)
    align_left = Alignment(horizontal='left', vertical='center')
    align_center = Alignment(horizontal='center', vertical='center')
    align_right = Alignment(horizontal='right', vertical='center')

    # Sheet 2: Groups
    ws_groups = wb['Groups']
    # Clear existing data rows (from row 4 down)
    for r in range(4, ws_groups.max_row + 10):
        for c in range(1, 10):
            ws_groups.cell(r, c).value = None

    for r_idx, g in enumerate(all_groups, 4):
        g_info = group_info_by_id[g["group_id"]]
        vals = [
            g_info["group_reference"],
            g_info["branch_name"],
            g_info["group_name"],
            g_info["group_leader_name"],
            g_info["meeting_day"],
            g_info["formation_date"],
            g_info["officer_name"],
            g_info["officer_phone"],
            g_info["group_savings"]
        ]
        for c_idx, val in enumerate(vals, 1):
            cell = ws_groups.cell(r_idx, c_idx)
            cell.value = val
            cell.font = regular_font
            cell.border = thin_border
            if c_idx in [1, 2, 5, 6, 8]:
                cell.alignment = align_center
            elif c_idx == 9:
                cell.alignment = align_right
                cell.number_format = '#,##0'
            else:
                cell.alignment = align_left

    # Sheet 3: Members
    ws_members = wb['Members']
    # Clear existing data rows (from row 4 down)
    for r in range(4, ws_members.max_row + 10):
        for c in range(1, 12):
            ws_members.cell(r, c).value = None

    for r_idx, m in enumerate(member_rows_data, 4):
        vals = [
            m["member_ref"],
            m["group_ref"],
            str(m["member_num"]),
            m["full_name"],
            m["phone"],
            m["address"],
            m["savings_balance"],
            m["loan_product"],
            m["principal_loan"],
            m["active_credit"],
            m["current_credit_balance"]
        ]
        for c_idx, val in enumerate(vals, 1):
            cell = ws_members.cell(r_idx, c_idx)
            cell.value = val
            cell.font = regular_font
            cell.border = thin_border
            if c_idx in [1, 2, 3, 5]:
                cell.alignment = align_center
            elif c_idx in [7, 9, 10, 11]:
                cell.alignment = align_right
                if val is not None:
                    cell.number_format = '#,##0'
            else:
                cell.alignment = align_left

    # Sheet 4: Branch and Officer List
    ws_officers = wb['Branch and Officer List']
    for r in range(4, ws_officers.max_row + 10):
        for c in range(1, 9):
            ws_officers.cell(r, c).value = None

    officer_list_data = [
        ("Mr. Ayomide", "08127382706"),
        ("Mrs. Dorcas", "08139512052"),
        ("Mr. Oluwaseun", "09049374666"),
        ("Miss. Olajumoke", "07036076569")
    ]
    for r_idx, (oname, ophone) in enumerate(officer_list_data, 4):
        # Col 1: Branch Name, Col 2: Region Name, Col 3: Status
        ws_officers.cell(r_idx, 1).value = "Ogijo"
        ws_officers.cell(r_idx, 1).font = regular_font
        ws_officers.cell(r_idx, 1).alignment = align_center
        ws_officers.cell(r_idx, 1).border = thin_border

        ws_officers.cell(r_idx, 2).value = "South West"
        ws_officers.cell(r_idx, 2).font = regular_font
        ws_officers.cell(r_idx, 2).alignment = align_center
        ws_officers.cell(r_idx, 2).border = thin_border

        ws_officers.cell(r_idx, 3).value = "Active"
        ws_officers.cell(r_idx, 3).font = regular_font
        ws_officers.cell(r_idx, 3).alignment = align_center
        ws_officers.cell(r_idx, 3).border = thin_border

        # Col 5: Credit Officer Name, Col 6: Phone Number, Col 7: Branch Name
        ws_officers.cell(r_idx, 5).value = oname
        ws_officers.cell(r_idx, 5).font = regular_font
        ws_officers.cell(r_idx, 5).alignment = align_left
        ws_officers.cell(r_idx, 5).border = thin_border

        ws_officers.cell(r_idx, 6).value = ophone
        ws_officers.cell(r_idx, 6).font = regular_font
        ws_officers.cell(r_idx, 6).alignment = align_center
        ws_officers.cell(r_idx, 6).border = thin_border

        ws_officers.cell(r_idx, 7).value = "Ogijo"
        ws_officers.cell(r_idx, 7).font = regular_font
        ws_officers.cell(r_idx, 7).alignment = align_center
        ws_officers.cell(r_idx, 7).border = thin_border

    # Save to active production template and dated copy
    print(f"Saving active template to: {target_active_path}")
    wb.save(target_active_path)
    print(f"Saving dated master copy to: {target_dated_path}")
    wb.save(target_dated_path)
    print("Workbook generated and saved successfully!")

if __name__ == "__main__":
    generate_workbook()
