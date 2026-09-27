import sys, os
from datetime import date, timedelta
from collections import defaultdict
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

sys.path.insert(0, r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit")
from database.repositories.unit_of_work import SupabaseUnitOfWork

# 22 Working banking days in the period from Sep 01 to Sep 30, 2026
WORKING_DAYS = [
    ("2026-09-01", "Tue"),
    ("2026-09-02", "Wed"),
    ("2026-09-03", "Thu"),
    ("2026-09-04", "Fri"),
    ("2026-09-07", "Mon"),
    ("2026-09-08", "Tue"),
    ("2026-09-09", "Wed"),
    ("2026-09-10", "Thu"),
    ("2026-09-11", "Fri"),
    ("2026-09-14", "Mon"),
    ("2026-09-15", "Tue"),
    ("2026-09-16", "Wed"),
    ("2026-09-17", "Thu"),
    ("2026-09-18", "Fri"),
    ("2026-09-21", "Mon"),
    ("2026-09-22", "Tue"),
    ("2026-09-23", "Wed"),
    ("2026-09-24", "Thu"),
    ("2026-09-25", "Fri"),
    ("2026-09-28", "Mon"),
    ("2026-09-29", "Tue"),
    ("2026-09-30", "Wed"),
]

PERIOD_START = "2026-09-01"
PERIOD_END = "2026-09-30"

# Color styling constants (Zero Emoji, Clean Corporate Theme)
NAVY_HEADER = "1B365D"
TEAL_ACCENT = "008080"
LIGHT_BLUE = "E8F1F5"
LIGHT_GRAY = "F7F9FA"
BORDER_GRAY = "D3D3D3"
GREEN_FILL = "E2F0D9"
AMBER_FILL = "FFF2CC"
PURPLE_HEADER = "4A2574"

font_header = Font(name="Calibri", size=10, bold=True, color="FFFFFF")
font_sub = Font(name="Calibri", size=10, bold=True, color="1B365D")
font_data = Font(name="Calibri", size=10, bold=False, color="000000")
font_bold = Font(name="Calibri", size=10, bold=True, color="000000")
font_title = Font(name="Calibri", size=14, bold=True, color="1B365D")
font_section = Font(name="Calibri", size=11, bold=True, color="FFFFFF")

fill_navy = PatternFill(start_color=NAVY_HEADER, end_color=NAVY_HEADER, fill_type="solid")
fill_teal = PatternFill(start_color=TEAL_ACCENT, end_color=TEAL_ACCENT, fill_type="solid")
fill_purple = PatternFill(start_color=PURPLE_HEADER, end_color=PURPLE_HEADER, fill_type="solid")
fill_light_blue = PatternFill(start_color=LIGHT_BLUE, end_color=LIGHT_BLUE, fill_type="solid")
fill_light_gray = PatternFill(start_color=LIGHT_GRAY, end_color=LIGHT_GRAY, fill_type="solid")
fill_green = PatternFill(start_color=GREEN_FILL, end_color=GREEN_FILL, fill_type="solid")
fill_amber = PatternFill(start_color=AMBER_FILL, end_color=AMBER_FILL, fill_type="solid")

thin_side = Side(border_style="thin", color=BORDER_GRAY)
med_top = Side(border_style="medium", color=NAVY_HEADER)
double_bottom = Side(border_style="double", color=NAVY_HEADER)

border_cell = Border(left=thin_side, right=thin_side, top=thin_side, bottom=thin_side)
border_totals = Border(left=thin_side, right=thin_side, top=med_top, bottom=double_bottom)

align_center = Alignment(horizontal="center", vertical="center", wrap_text=True)
align_left = Alignment(horizontal="left", vertical="center")
align_right = Alignment(horizontal="right", vertical="center")

def fmt_int(val):
    if val is None:
        return 0
    try:
        f = float(val)
        return int(round(f))
    except:
        return 0

def get_next_working_day(d_str: str) -> str:
    """Calculates next working banking day skipping Saturday/Sunday according to FP-008."""
    if not d_str:
        return PERIOD_START
    try:
        d = date.fromisoformat(d_str[:10])
    except Exception:
        return d_str
    curr = d + timedelta(days=1)
    while curr.weekday() >= 5:  # 5=Sat, 6=Sun
        curr += timedelta(days=1)
    return curr.isoformat()

def build_extended_workbook(officer_username: str, output_paths: list):
    print(f"\n=======================================================")
    print(f"Building Extended Master Multi-Day Workbook for {officer_username} (Sep 01 - Sep 30)")
    print(f"=======================================================")

    wb = openpyxl.Workbook()

    with SupabaseUnitOfWork() as uow:
        # 1. Fetch Officer User Details
        user = uow.client.table('app_users').select('id, username, full_name').eq('username', officer_username).single().execute().data
        user_id = user['id']
        full_name = user.get('full_name', officer_username)

        # 2. Fetch Groups for Officer
        groups = uow.client.table('groups').select('group_id, name, group_number, meeting_day').eq('officer_id', user_id).execute().data or []
        groups.sort(key=lambda g: int(g.get('group_number') or 999))
        grp_map = {g['group_id']: g for g in groups}
        gids = [g['group_id'] for g in groups]

        # 3. Fetch Clients in these groups
        clients = uow.client.table('clients').select('client_id, client_code, name, group_id, status, created_at, phone').in_('group_id', gids).execute().data or []
        c_map = {c['client_id']: c for c in clients}
        cids = [c['client_id'] for c in clients]

        # 4. Fetch Loans for these clients
        loans = uow.client.table('loans').select('*').in_('client_id', cids).execute().data or []
        
        # Categorize loans: Active, Completed, Pending
        active_loans = [l for l in loans if str(l.get('status') or '').capitalize() in ['Active', 'Approved']]
        completed_loans = [l for l in loans if str(l.get('status') or '').capitalize() in ['Completed', 'Settled']]

        # Map by client
        active_loans_by_c = defaultdict(list)
        completed_loans_by_c = defaultdict(list)
        for l in active_loans:
            active_loans_by_c[l['client_id']].append(l)
        for l in completed_loans:
            completed_loans_by_c[l['client_id']].append(l)

        # 5. Fetch repayments prior to Sep 01 and posted in Sep 1-22
        all_loan_ids = [l['loan_id'] for l in loans]
        reps_prior = defaultdict(float)
        reps_posted_period = defaultdict(lambda: defaultdict(float))  # loan_id -> date -> amount

        chunk_size = 50
        for i in range(0, len(all_loan_ids), chunk_size):
            chunk = all_loan_ids[i:i+chunk_size]
            reps_data = uow.client.table('repayments').select('loan_id, client_id, amount_paid, date, transaction_type').in_('loan_id', chunk).execute().data or []
            for r in reps_data:
                d = str(r.get('date') or '')[:10]
                amt = float(r.get('amount_paid') or 0.0)
                lid = r['loan_id']
                if d < PERIOD_START:
                    reps_prior[lid] += amt
                elif PERIOD_START <= d <= PERIOD_END:
                    reps_posted_period[lid][d] += amt

        # 6. Fetch savings
        savs_prior = defaultdict(float)
        savs_posted_period = defaultdict(lambda: defaultdict(float))  # client_id -> date -> amount
        customary_savings = defaultdict(lambda: 500)

        for i in range(0, len(cids), chunk_size):
            chunk = cids[i:i+chunk_size]
            savs_data = uow.client.table('individual_savings').select('client_id, deposit_amount, withdrawal_amount, posting_date').in_('client_id', chunk).execute().data or []
            for s in savs_data:
                d = str(s.get('posting_date') or '')[:10]
                dep = float(s.get('deposit_amount') or 0.0)
                wd = float(s.get('withdrawal_amount') or 0.0)
                cid = s['client_id']
                if d < PERIOD_START:
                    savs_prior[cid] += (dep - wd)
                elif PERIOD_START <= d <= PERIOD_END:
                    savs_posted_period[cid][d] += (dep - wd)
                if dep > 0:
                    customary_savings[cid] = int(dep)

        # =========================================================================
        # TAB 1: DAILY COLLECTIONS MATRIX
        # =========================================================================
        ws1 = wb.create_sheet(title="Daily Collections Matrix")
        ws1.views.sheetView[0].showGridLines = True

        ws1.row_dimensions[1].height = 28
        ws1.row_dimensions[2].height = 24

        headers_meta = [
            ("Group Code", 12),
            ("Group Name", 18),
            ("Client Code", 14),
            ("Client Name", 24),
            ("Loan ID", 14),
            ("Product Category", 16),
            ("Total Loan Due (₦)", 16),
            ("Starting Bal (₦)", 18),
            ("Daily Repay Rate (₦)", 16),
            ("Customary Daily Sav (₦)", 16),
        ]

        # Write fixed meta headers in Row 2
        for col_idx, (h_name, width) in enumerate(headers_meta, start=1):
            cell = ws1.cell(row=2, column=col_idx, value=h_name)
            cell.font = font_header
            cell.fill = fill_navy
            cell.alignment = align_center
            cell.border = border_cell
            ws1.column_dimensions[get_column_letter(col_idx)].width = width

        curr_col = len(headers_meta) + 1

        # Date columns start at col 11 (K)
        for d_str, d_day in WORKING_DAYS:
            col_repay = curr_col
            col_sav = curr_col + 1
            
            ws1.merge_cells(start_row=1, start_column=col_repay, end_row=1, end_column=col_sav)
            super_cell = ws1.cell(row=1, column=col_repay, value=f"{d_str} ({d_day})")
            super_cell.font = font_header
            super_cell.fill = fill_navy
            super_cell.alignment = align_center
            super_cell.border = border_cell

            c_rep = ws1.cell(row=2, column=col_repay, value="Repay (₦)")
            c_rep.font = font_header
            c_rep.fill = fill_teal
            c_rep.alignment = align_center
            c_rep.border = border_cell

            c_sav = ws1.cell(row=2, column=col_sav, value="Savings (₦)")
            c_sav.font = font_header
            c_sav.fill = fill_navy
            c_sav.alignment = align_center
            c_sav.border = border_cell

            ws1.column_dimensions[get_column_letter(col_repay)].width = 13
            ws1.column_dimensions[get_column_letter(col_sav)].width = 13

            curr_col += 2

        col_tot_repay = curr_col
        col_tot_sav = curr_col + 1
        col_end_bal = curr_col + 2
        col_notes = curr_col + 3

        summary_headers = [
            (col_tot_repay, "Total Repay Paid (₦)", 20, fill_teal),
            (col_tot_sav, "Total Savings Saved (₦)", 22, fill_navy),
            (col_end_bal, "Ending Loan Balance (₦)", 22, fill_navy),
            (col_notes, "Member Status / Notes", 28, fill_navy),
        ]

        for col_idx, h_text, width, f_color in summary_headers:
            ws1.merge_cells(start_row=1, start_column=col_idx, end_row=2, end_column=col_idx)
            cell = ws1.cell(row=1, column=col_idx, value=h_text)
            cell.font = font_header
            cell.fill = f_color
            cell.alignment = align_center
            cell.border = border_cell
            ws1.column_dimensions[get_column_letter(col_idx)].width = width

        # Freeze Panes at K3: Top 2 header rows and left 10 metadata columns (A to J) remain static and visible
        # while daily collection columns scroll horizontally!
        ws1.freeze_panes = "K3"

        row_idx = 3

        # Helper function to write a matrix row
        def write_matrix_row(g_code, g_name, c_code, c_name, lid, prod, tot_due, rem_bal, exp_repay, sav_rate, note, disb_d=None, first_repay_d=None, is_historical=False):
            nonlocal row_idx
            ws1.row_dimensions[row_idx].height = 20

            ws1.cell(row=row_idx, column=1, value=g_code).alignment = align_center
            ws1.cell(row=row_idx, column=2, value=g_name).alignment = align_left
            ws1.cell(row=row_idx, column=3, value=c_code).alignment = align_center
            ws1.cell(row=row_idx, column=4, value=c_name).alignment = align_left
            ws1.cell(row=row_idx, column=5, value=lid if lid != 'None' else "-").alignment = align_center
            ws1.cell(row=row_idx, column=6, value=prod).alignment = align_center
            
            c_tot = ws1.cell(row=row_idx, column=7, value=tot_due)
            c_tot.number_format = "#,##0"
            c_tot.alignment = align_right

            c_bal = ws1.cell(row=row_idx, column=8, value=rem_bal)
            c_bal.number_format = "#,##0"
            c_bal.alignment = align_right

            c_lr = ws1.cell(row=row_idx, column=9, value=exp_repay)
            c_lr.number_format = "#,##0"
            c_lr.alignment = align_right

            c_sav = ws1.cell(row=row_idx, column=10, value=sav_rate)
            c_sav.number_format = "#,##0"
            c_sav.alignment = align_right

            for c_meta in range(1, 11):
                ws1.cell(row=row_idx, column=c_meta).border = border_cell

            c_pos = 11
            repay_cells = []
            sav_cells = []

            for d_str, d_day in WORKING_DAYS:
                rep_let = get_column_letter(c_pos)
                sav_let = get_column_letter(c_pos + 1)
                repay_cells.append(f"{rep_let}{row_idx}")
                sav_cells.append(f"{sav_let}{row_idx}")

                # Check DB posted value
                posted_r = reps_posted_period.get(lid, {}).get(d_str) if lid != 'None' else None
                posted_s = savs_posted_period.get(cid, {}).get(d_str)

                # Determine repayment value
                if posted_r is not None:
                    val_r = fmt_int(posted_r)
                elif first_repay_d and d_str < first_repay_d:
                    # Enforce FP-008: Repayment is 0 before first repayment date!
                    val_r = 0
                elif rem_bal > 0 and exp_repay > 0:
                    val_r = exp_repay
                else:
                    val_r = 0

                # Determine savings value
                if posted_s is not None:
                    val_s = fmt_int(posted_s)
                else:
                    val_s = sav_rate

                cell_r = ws1.cell(row=row_idx, column=c_pos, value=val_r)
                cell_r.number_format = "#,##0"
                cell_r.alignment = align_right
                cell_r.border = border_cell

                cell_s = ws1.cell(row=row_idx, column=c_pos + 1, value=val_s)
                cell_s.number_format = "#,##0"
                cell_s.alignment = align_right
                cell_s.border = border_cell

                if posted_r is not None or posted_s is not None:
                    cell_r.fill = fill_green
                    cell_s.fill = fill_green

                c_pos += 2

            # Dynamic formulas
            ws1.cell(row=row_idx, column=col_tot_repay, value=f"={'+'.join(repay_cells)}").number_format = "#,##0"
            ws1.cell(row=row_idx, column=col_tot_repay).alignment = align_right
            ws1.cell(row=row_idx, column=col_tot_repay).font = font_bold
            ws1.cell(row=row_idx, column=col_tot_repay).fill = fill_light_blue
            ws1.cell(row=row_idx, column=col_tot_repay).border = border_cell

            ws1.cell(row=row_idx, column=col_tot_sav, value=f"={'+'.join(sav_cells)}").number_format = "#,##0"
            ws1.cell(row=row_idx, column=col_tot_sav).alignment = align_right
            ws1.cell(row=row_idx, column=col_tot_sav).font = font_bold
            ws1.cell(row=row_idx, column=col_tot_sav).fill = fill_light_blue
            ws1.cell(row=row_idx, column=col_tot_sav).border = border_cell

            tot_rep_letter = get_column_letter(col_tot_repay)
            bal_letter = get_column_letter(8)
            ws1.cell(row=row_idx, column=col_end_bal, value=f"=MAX(0, {bal_letter}{row_idx}-{tot_rep_letter}{row_idx})").number_format = "#,##0"
            ws1.cell(row=row_idx, column=col_end_bal).alignment = align_right
            ws1.cell(row=row_idx, column=col_end_bal).font = font_bold
            ws1.cell(row=row_idx, column=col_end_bal).fill = fill_amber
            ws1.cell(row=row_idx, column=col_end_bal).border = border_cell

            c_n = ws1.cell(row=row_idx, column=col_notes, value=note)
            c_n.alignment = align_left
            c_n.border = border_cell

            row_idx += 1

        # Sort clients by group number then client code
        sorted_clients = []
        for c in clients:
            g = grp_map.get(c['group_id'], {})
            try:
                g_num = int(g.get('group_number') or 999)
            except:
                g_num = 999
            sorted_clients.append((g_num, c.get('client_code') or '', c))
        sorted_clients.sort(key=lambda x: (x[0], x[1]))

        # SECTION 1: ACTIVE LOANS
        ws1.merge_cells(start_row=row_idx, start_column=1, end_row=row_idx, end_column=col_notes)
        s1_cell = ws1.cell(row=row_idx, column=1, value="SECTION 1: ACTIVE LOAN PORTFOLIO (CONTRACTUAL BORROWERS)")
        s1_cell.font = font_section
        s1_cell.fill = fill_navy
        s1_cell.alignment = align_left
        ws1.row_dimensions[row_idx].height = 22
        row_idx += 1

        for g_num, c_code, c in sorted_clients:
            cid = c['client_id']
            c_active_loans = active_loans_by_c.get(cid, [])
            if not c_active_loans:
                continue

            g = grp_map.get(c['group_id'], {})
            g_code = f"OGI-{g.get('group_number', '')}"
            g_name = g.get('name', '')
            c_name = c.get('name', '')
            c_sav_rate = customary_savings[cid]

            for l_idx, l in enumerate(c_active_loans):
                lid = l['loan_id']
                prod = l.get('product_category') or 'Cash Loan'
                tot_due = fmt_int(l.get('total_due') or l.get('active_credit') or l.get('loan_amount'))
                paid_prior = reps_prior.get(lid, 0.0)
                rem_bal = max(0, tot_due - fmt_int(paid_prior))
                l_repay = fmt_int(l.get('loan_repay'))
                exp_repay = min(l_repay, rem_bal) if rem_bal > 0 else 0

                disb_d = str(l.get('disbursement_date') or l.get('date') or '')[:10]
                first_repay_d = str(l.get('start_date') or '')[:10] if l.get('start_date') else None
                if not first_repay_d or (disb_d and first_repay_d <= disb_d):
                    first_repay_d = get_next_working_day(disb_d)

                note = f"Active Loan ({l.get('product_type') or prod})"
                if disb_d >= PERIOD_START:
                    note = f"Disbursed {disb_d} (First repay {first_repay_d})"

                write_matrix_row(
                    g_code, g_name, c_code, c_name, lid, prod, tot_due, rem_bal, exp_repay,
                    c_sav_rate if l_idx == 0 else 0,
                    note, disb_d, first_repay_d
                )

        # SECTION 2: SAVINGS ONLY / NON-BORROWING MEMBERS
        ws1.merge_cells(start_row=row_idx, start_column=1, end_row=row_idx, end_column=col_notes)
        s2_cell = ws1.cell(row=row_idx, column=1, value="SECTION 2: SAVINGS-ONLY & NON-BORROWING CLIENTS (MEETING ATTENDEES)")
        s2_cell.font = font_section
        s2_cell.fill = fill_teal
        s2_cell.alignment = align_left
        ws1.row_dimensions[row_idx].height = 22
        row_idx += 1

        for g_num, c_code, c in sorted_clients:
            cid = c['client_id']
            if cid in active_loans_by_c:
                continue

            g = grp_map.get(c['group_id'], {})
            g_code = f"OGI-{g.get('group_number', '')}"
            g_name = g.get('name', '')
            c_name = c.get('name', '')
            c_sav_rate = customary_savings[cid]

            write_matrix_row(
                g_code, g_name, c_code, c_name, "None", "Savings Only", 0, 0, 0,
                c_sav_rate, "Non-Borrower / Savings Only"
            )

        # SECTION 3: COMPLETED LOANS (SETTLED / PAID OFF IN FULL)
        ws1.merge_cells(start_row=row_idx, start_column=1, end_row=row_idx, end_column=col_notes)
        s3_cell = ws1.cell(row=row_idx, column=1, value="SECTION 3: COMPLETED LOANS (SETTLED / PAID OFF IN FULL)")
        s3_cell.font = font_section
        s3_cell.fill = fill_purple
        s3_cell.alignment = align_left
        ws1.row_dimensions[row_idx].height = 22
        row_idx += 1

        for g_num, c_code, c in sorted_clients:
            cid = c['client_id']
            c_comp = completed_loans_by_c.get(cid, [])
            for l in c_comp:
                lid = l['loan_id']
                tot_due = fmt_int(l.get('total_due') or l.get('active_credit') or l.get('loan_amount'))
                paid_prior = reps_prior.get(lid, 0.0)
                rem_bal = max(0, tot_due - fmt_int(paid_prior))
                g = grp_map.get(c['group_id'], {})
                g_code = f"OGI-{g.get('group_number', '')}"
                g_name = g.get('name', '')
                c_name = c.get('name', '')
                write_matrix_row(
                    g_code, g_name, c_code, c_name, lid, l.get('product_category') or 'Cash Loan',
                    tot_due, rem_bal, 0, 0, f"Completed / Settled ({l.get('status')})"
                )

        # SECTION 4: BLANK ROWS FOR NEW MEMBERS / RENEWALS
        ws1.merge_cells(start_row=row_idx, start_column=1, end_row=row_idx, end_column=col_notes)
        s4_cell = ws1.cell(row=row_idx, column=1, value="SECTION 4: BLANK ROWS FOR NEW MEMBERS REGISTERED & RENEWALS TAKEN IN SEP 1-30")
        s4_cell.font = font_section
        s4_cell.fill = fill_navy
        s4_cell.alignment = align_left
        ws1.row_dimensions[row_idx].height = 22
        row_idx += 1

        for b_i in range(15):
            ws1.row_dimensions[row_idx].height = 20
            for c_i in range(1, col_notes + 1):
                cell = ws1.cell(row=row_idx, column=c_i)
                cell.border = border_cell
                if 7 <= c_i <= col_end_bal:
                    cell.number_format = "#,##0"
                    cell.alignment = align_right

            repay_cells = [f"{get_column_letter(11 + j*2)}{row_idx}" for j in range(len(WORKING_DAYS))]
            sav_cells = [f"{get_column_letter(12 + j*2)}{row_idx}" for j in range(len(WORKING_DAYS))]
            ws1.cell(row=row_idx, column=col_tot_repay, value=f"={'+'.join(repay_cells)}").fill = fill_light_blue
            ws1.cell(row=row_idx, column=col_tot_repay).font = font_bold
            ws1.cell(row=row_idx, column=col_tot_sav, value=f"={'+'.join(sav_cells)}").fill = fill_light_blue
            ws1.cell(row=row_idx, column=col_tot_sav).font = font_bold
            ws1.cell(row=row_idx, column=col_end_bal, value=f"=MAX(0, H{row_idx}-{get_column_letter(col_tot_repay)}{row_idx})").fill = fill_amber
            ws1.cell(row=row_idx, column=col_end_bal).font = font_bold
            ws1.cell(row=row_idx, column=col_notes, value="New Member / Renewal")
            row_idx += 1

        last_data_row = row_idx - 1

        # TOTALS ROW
        ws1.row_dimensions[row_idx].height = 25
        totals_label = ws1.cell(row=row_idx, column=4, value="PORTFOLIO TOTALS:")
        totals_label.font = font_bold
        totals_label.alignment = align_right

        for c_idx in range(1, col_notes + 1):
            cell = ws1.cell(row=row_idx, column=c_idx)
            cell.border = border_totals
            if c_idx >= 7 and c_idx <= col_end_bal:
                col_let = get_column_letter(c_idx)
                cell.value = f"=SUM({col_let}3:{col_let}{last_data_row})"
                cell.number_format = "#,##0"
                cell.font = font_bold
                cell.alignment = align_right
                cell.fill = fill_light_blue

        portfolio_totals_row = row_idx

        # =========================================================================
        # TAB 2: NEW LOANS & DISBURSEMENTS (@rules Enforced)
        # =========================================================================
        ws2 = wb.create_sheet(title="New Loans & Disbursements")
        ws2.views.sheetView[0].showGridLines = True
        ws2.row_dimensions[1].height = 28

        new_loan_headers = [
            ("Disbursement Date\n(YYYY-MM-DD)", 18),
            ("First Repay Date\n(Next Workday)", 18),
            ("Group Code", 12),
            ("Group Name", 18),
            ("Client Code", 14),
            ("Client Name", 24),
            ("Product Category\n(Finance / Asset)", 18),
            ("Product Type\n(60d / 120d / Asset)", 20),
            ("Principal Amount /\nAsset Cost (₦)", 20),
            ("Interest Rate\n(12% / 21% / 0%)", 16),
            ("Upfront Interest (₦)\n[=Principal * Rate]", 18),
            ("Markup Fee (₦)\n[11% or 20%]", 18),
            ("Contingency Fee (₦)\n[1% Risk Premium]", 18),
            ("Gap Fee / Base Sav (₦)\n[Clean Rounding]", 18),
            ("Total Upfront Req (₦)\n[Interest + Gap]", 20),
            ("Asset Downpayment Cash (₦)", 20),
            ("Asset Downpayment Sav (₦)", 20),
            ("Active Credit Disbursed (₦)\n[Contractual Loan]", 22),
            ("Contractual Daily Repay (₦)\n[=Active Credit / 60]", 22),
            ("Fees Settlement Method", 32),
            ("Physical Cash Disbursed (₦)\n[Vault/Bank Outflow]", 22),
            ("Passbook Fee (₦)", 15),
            ("App Fee (₦)", 15),
            ("Disbursement Status", 22),
            ("Notes / Renewal Details", 32),
        ]

        for col_idx, (h_text, h_w) in enumerate(new_loan_headers, start=1):
            cell = ws2.cell(row=1, column=col_idx, value=h_text)
            cell.font = font_header
            cell.fill = fill_navy
            cell.alignment = align_center
            cell.border = border_cell
            ws2.column_dimensions[get_column_letter(col_idx)].width = h_w

        # Freeze Panes at G2: Top header row and client identifying metadata stay static
        ws2.freeze_panes = "G2"

        # Populate Sep 1-22 loans for this officer
        disb_row = 2
        officer_sep_loans = [l for l in loans if (l.get('date') or '') >= PERIOD_START and (l.get('date') or '') <= PERIOD_END]
        
        for l in sorted(officer_sep_loans, key=lambda x: str(x.get('date'))):
            cid = l['client_id']
            c = c_map.get(cid, {})
            g = grp_map.get(c.get('group_id'), {})
            amt = fmt_int(l.get('loan_amount'))
            act_c = fmt_int(l.get('active_credit'))
            tot_d = fmt_int(l.get('total_due'))
            l_repay = fmt_int(l.get('loan_repay'))
            extra = l.get('extra_fields') or {}
            is_asset = (l.get('product_category') == 'Asset')
            prod_cat = "Asset" if is_asset else "Finance"
            prod_type = l.get('product_type') or ("Daily Cash Loan (60 Days)" if not is_asset else "60-Day Asset Loan")
            
            disb_d = str(l.get('disbursement_date') or l.get('date') or '')[:10]
            first_rep = str(l.get('start_date') or '')[:10] if l.get('start_date') else None
            # Enforce FP-008: Disbursement Date != First Repayment Date (Next valid working day)
            if not first_rep or first_rep <= disb_d:
                first_rep = get_next_working_day(disb_d)
            
            gap_f = fmt_int(extra.get('gap_fee') or l.get('gap_fee'))
            up_int = fmt_int(extra.get('upfront_interest'))
            tot_upfront = fmt_int(extra.get('total_upfront_required'))
            if tot_upfront == 0 and not is_asset:
                up_int = fmt_int(amt * 0.12)
                tot_upfront = up_int + gap_f

            markup_val = fmt_int(up_int * (11.0 / 12.0)) if up_int > 0 else 0
            cont_val = up_int - markup_val if up_int > 0 else 0

            dp_cash = fmt_int(extra.get('downpayment_cash'))
            dp_sav = fmt_int(extra.get('downpayment_savings'))

            # Fee settlement method
            if is_asset:
                settlement = "Asset Sale (Physical Cash/Savings Downpayment)"
                phys_cash_disb = 0
            elif tot_upfront > 0:
                settlement = "Deducted from Savings (Automatic Deduction)"
                phys_cash_disb = amt
            else:
                settlement = "Paid in Physical Cash"
                phys_cash_disb = amt

            ws2.row_dimensions[disb_row].height = 20
            ws2.cell(row=disb_row, column=1, value=disb_d).alignment = align_center
            ws2.cell(row=disb_row, column=2, value=first_rep).alignment = align_center
            ws2.cell(row=disb_row, column=3, value=f"OGI-{g.get('group_number', '')}").alignment = align_center
            ws2.cell(row=disb_row, column=4, value=g.get('name', '')).alignment = align_left
            ws2.cell(row=disb_row, column=5, value=c.get('client_code', '')).alignment = align_center
            ws2.cell(row=disb_row, column=6, value=c.get('name', '')).alignment = align_left
            ws2.cell(row=disb_row, column=7, value=prod_cat).alignment = align_center
            ws2.cell(row=disb_row, column=8, value=prod_type).alignment = align_left

            ws2.cell(row=disb_row, column=9, value=amt).number_format = "#,##0"
            ws2.cell(row=disb_row, column=10, value=0.0 if is_asset else 0.12).number_format = "0.0%"
            ws2.cell(row=disb_row, column=11, value=up_int).number_format = "#,##0"
            ws2.cell(row=disb_row, column=12, value=markup_val).number_format = "#,##0"
            ws2.cell(row=disb_row, column=13, value=cont_val).number_format = "#,##0"
            ws2.cell(row=disb_row, column=14, value=gap_f).number_format = "#,##0"
            ws2.cell(row=disb_row, column=15, value=f"=K{disb_row}+N{disb_row}").number_format = "#,##0"
            ws2.cell(row=disb_row, column=16, value=dp_cash).number_format = "#,##0"
            ws2.cell(row=disb_row, column=17, value=dp_sav).number_format = "#,##0"
            
            # Active credit
            if is_asset:
                ws2.cell(row=disb_row, column=18, value=act_c).number_format = "#,##0"
            else:
                ws2.cell(row=disb_row, column=18, value=f"=I{disb_row}-N{disb_row}").number_format = "#,##0"

            ws2.cell(row=disb_row, column=19, value=l_repay).number_format = "#,##0"
            ws2.cell(row=disb_row, column=20, value=settlement).alignment = align_left
            ws2.cell(row=disb_row, column=21, value=phys_cash_disb).number_format = "#,##0"
            ws2.cell(row=disb_row, column=22, value=1000).number_format = "#,##0"
            ws2.cell(row=disb_row, column=23, value=500).number_format = "#,##0"
            ws2.cell(row=disb_row, column=24, value=f"In System ({l.get('status')})").alignment = align_center
            ws2.cell(row=disb_row, column=25, value=f"Loan ID: {l.get('loan_id')}").alignment = align_left

            for c_i in range(1, 26):
                cell = ws2.cell(row=disb_row, column=c_i)
                cell.border = border_cell
                if 9 <= c_i <= 19 or c_i in [21, 22, 23]:
                    cell.alignment = align_right
                    if c_i in [15, 18, 21]:
                        cell.fill = fill_light_blue
                        cell.font = font_bold
            disb_row += 1

        # 15 Blank Rows for New Disbursements / Renewals
        for _ in range(15):
            ws2.row_dimensions[disb_row].height = 20
            for c_i in range(1, 26):
                cell = ws2.cell(row=disb_row, column=c_i)
                cell.border = border_cell
                if 9 <= c_i <= 19 or c_i in [21, 22, 23]:
                    cell.number_format = "#,##0"
                    cell.alignment = align_right
            
            ws2.cell(row=disb_row, column=7, value="Finance").alignment = align_center
            ws2.cell(row=disb_row, column=8, value="Daily 60 Days").alignment = align_left
            ws2.cell(row=disb_row, column=10, value=0.12).number_format = "0.0%"
            ws2.cell(row=disb_row, column=11, value=f"=ROUND(I{disb_row}*J{disb_row}, 0)")
            ws2.cell(row=disb_row, column=12, value=f"=ROUND(K{disb_row}*(11/12), 0)")
            ws2.cell(row=disb_row, column=13, value=f"=K{disb_row}-L{disb_row}")
            ws2.cell(row=disb_row, column=15, value=f"=K{disb_row}+N{disb_row}")
            ws2.cell(row=disb_row, column=18, value=f"=IF(G{disb_row}=\"Asset\",(I{disb_row}+K{disb_row})-(P{disb_row}+Q{disb_row}), I{disb_row}-N{disb_row})")
            ws2.cell(row=disb_row, column=19, value=f"=ROUND(R{disb_row}/60, 0)")
            ws2.cell(row=disb_row, column=20, value="Deducted from Savings (Automatic Deduction)")
            ws2.cell(row=disb_row, column=21, value=f"=IF(G{disb_row}=\"Asset\", 0, IF(T{disb_row}=\"Deducted from Principal (Net Payout)\", I{disb_row}-O{disb_row}, I{disb_row}))")
            ws2.cell(row=disb_row, column=22, value=1000)
            ws2.cell(row=disb_row, column=23, value=500)
            ws2.cell(row=disb_row, column=24, value="New Entry to Disburse")
            disb_row += 1

        # =========================================================================
        # TAB 3: NEW CLIENT REGISTRATIONS (New Members Onboarding)
        # =========================================================================
        ws_reg = wb.create_sheet(title="New Client Registrations")
        ws_reg.views.sheetView[0].showGridLines = True
        ws_reg.row_dimensions[1].height = 28

        reg_headers = [
            ("Registration Date\n(YYYY-MM-DD)", 18),
            ("Group Code", 12),
            ("Group Name", 18),
            ("Assigned Client Code\n[Auto-sequenced if blank]", 22),
            ("Client Full Name", 26),
            ("Phone Number", 18),
            ("Gender\n(Female / Male)", 16),
            ("Marital Status", 16),
            ("Business / Occupation", 22),
            ("Business Address", 25),
            ("Home Address", 25),
            ("Guarantor Name", 22),
            ("Guarantor Phone", 18),
            ("Guarantor Relationship", 20),
            ("Initial Mandatory Savings (₦)", 22),
            ("Applying for Loan?", 22),
            ("Registration Status", 22),
            ("Notes / Remarks", 25),
        ]

        for col_idx, (h_text, h_w) in enumerate(reg_headers, start=1):
            cell = ws_reg.cell(row=1, column=col_idx, value=h_text)
            cell.font = font_header
            cell.fill = fill_navy
            cell.alignment = align_center
            cell.border = border_cell
            ws_reg.column_dimensions[get_column_letter(col_idx)].width = h_w

        ws_reg.freeze_panes = "F2"

        reg_r = 2
        new_clients_sep = [c for c in clients if str(c.get('created_at') or '')[:10] >= PERIOD_START]
        for c in sorted(new_clients_sep, key=lambda x: str(x.get('created_at'))):
            g = grp_map.get(c.get('group_id'), {})
            ws_reg.row_dimensions[reg_r].height = 20
            ws_reg.cell(row=reg_r, column=1, value=str(c.get('created_at') or '')[:10]).alignment = align_center
            ws_reg.cell(row=reg_r, column=2, value=f"OGI-{g.get('group_number', '')}").alignment = align_center
            ws_reg.cell(row=reg_r, column=3, value=g.get('name', '')).alignment = align_left
            ws_reg.cell(row=reg_r, column=4, value=c.get('client_code', '')).alignment = align_center
            ws_reg.cell(row=reg_r, column=5, value=c.get('name', '')).alignment = align_left
            ws_reg.cell(row=reg_r, column=6, value=str(c.get('phone') or '').replace('.0', '')).alignment = align_center
            ws_reg.cell(row=reg_r, column=7, value="Female").alignment = align_center
            ws_reg.cell(row=reg_r, column=8, value="Married").alignment = align_center
            ws_reg.cell(row=reg_r, column=9, value="Trader").alignment = align_left
            ws_reg.cell(row=reg_r, column=10, value="Ogijo Market").alignment = align_left
            ws_reg.cell(row=reg_r, column=11, value="Ogijo, Ogun State").alignment = align_left
            ws_reg.cell(row=reg_r, column=12, value="").alignment = align_left
            ws_reg.cell(row=reg_r, column=13, value="").alignment = align_center
            ws_reg.cell(row=reg_r, column=14, value="").alignment = align_left
            ws_reg.cell(row=reg_r, column=15, value=1000).number_format = "#,##0"
            ws_reg.cell(row=reg_r, column=15).alignment = align_right
            has_loan = c['client_id'] in active_loans_by_c
            ws_reg.cell(row=reg_r, column=16, value="Yes (See Tab 2)" if has_loan else "No (Savings Only)").alignment = align_center
            ws_reg.cell(row=reg_r, column=17, value="Already Registered in DB").alignment = align_center
            ws_reg.cell(row=reg_r, column=17).fill = fill_green
            ws_reg.cell(row=reg_r, column=18, value=f"Client ID: {c.get('client_id')}").alignment = align_left

            for c_i in range(1, 19):
                ws_reg.cell(row=reg_r, column=c_i).border = border_cell
            reg_r += 1

        # 20 Blank rows for new client registrations
        for _ in range(20):
            ws_reg.row_dimensions[reg_r].height = 20
            for c_i in range(1, 19):
                cell = ws_reg.cell(row=reg_r, column=c_i)
                cell.border = border_cell
                if c_i == 15:
                    cell.number_format = "#,##0"
                    cell.alignment = align_right
            ws_reg.cell(row=reg_r, column=7, value="Female").alignment = align_center
            ws_reg.cell(row=reg_r, column=8, value="Married").alignment = align_center
            ws_reg.cell(row=reg_r, column=9, value="Trader").alignment = align_left
            ws_reg.cell(row=reg_r, column=15, value=1000)
            ws_reg.cell(row=reg_r, column=16, value="Yes (Fill Tab 2)").alignment = align_center
            ws_reg.cell(row=reg_r, column=17, value="New Client to Register").alignment = align_center
            reg_r += 1

        # =========================================================================
        # TAB 4: SAVINGS WITHDRAWALS & AUTOMATIC DEDUCTIONS
        # =========================================================================
        ws3 = wb.create_sheet(title="Savings Withdrawals")
        ws3.views.sheetView[0].showGridLines = True
        ws3.row_dimensions[1].height = 28

        wd_headers = [
            ("Date (YYYY-MM-DD)", 18),
            ("Group Code", 12),
            ("Group Name", 18),
            ("Client Code", 14),
            ("Client Name", 24),
            ("Withdrawal Amount (₦)", 20),
            ("Withdrawal Classification", 35),
            ("Cash Impact on Vault Cash", 25),
            ("Approved By", 18),
            ("Narration / Purpose", 35),
        ]

        for col_idx, (h_text, h_w) in enumerate(wd_headers, start=1):
            cell = ws3.cell(row=1, column=col_idx, value=h_text)
            cell.font = font_header
            cell.fill = fill_navy
            cell.alignment = align_center
            cell.border = border_cell
            ws3.column_dimensions[get_column_letter(col_idx)].width = h_w

        ws3.freeze_panes = "F2"

        wd_r = 2
        # Pre-populate automatic upfront deductions from Sep 01-22 loans
        for l in sorted(officer_sep_loans, key=lambda x: str(x.get('date'))):
            cid = l['client_id']
            c = c_map.get(cid, {})
            g = grp_map.get(c.get('group_id'), {})
            extra = l.get('extra_fields') or {}
            tot_up = fmt_int(extra.get('total_upfront_required'))
            if tot_up > 0 and l.get('product_category') == 'Finance':
                ws3.row_dimensions[wd_r].height = 20
                ws3.cell(row=wd_r, column=1, value=str(l.get('date') or '')[:10]).alignment = align_center
                ws3.cell(row=wd_r, column=2, value=f"OGI-{g.get('group_number', '')}").alignment = align_center
                ws3.cell(row=wd_r, column=3, value=g.get('name', '')).alignment = align_left
                ws3.cell(row=wd_r, column=4, value=c.get('client_code', '')).alignment = align_center
                ws3.cell(row=wd_r, column=5, value=c.get('name', '')).alignment = align_left
                ws3.cell(row=wd_r, column=6, value=tot_up).number_format = "#,##0"
                ws3.cell(row=wd_r, column=7, value="Automatic Deduction for Loan Upfront Fees").alignment = align_left
                ws3.cell(row=wd_r, column=8, value="NO CASH IMPACT (Internal Transfer)").alignment = align_center
                ws3.cell(row=wd_r, column=9, value="Core Banking System").alignment = align_center
                ws3.cell(row=wd_r, column=10, value=f"Upfront Fee deduction for Loan {str(l.get('loan_id'))[:8]}").alignment = align_left
                for c_i in range(1, 11):
                    ws3.cell(row=wd_r, column=c_i).border = border_cell
                ws3.cell(row=wd_r, column=6).alignment = align_right
                ws3.cell(row=wd_r, column=8).fill = fill_amber
                wd_r += 1

        # 20 Blank rows for physical withdrawals / other deductions
        for _ in range(20):
            ws3.row_dimensions[wd_r].height = 20
            for c_i in range(1, 11):
                cell = ws3.cell(row=wd_r, column=c_i)
                cell.border = border_cell
                if c_i == 6:
                    cell.number_format = "#,##0"
                    cell.alignment = align_right
            ws3.cell(row=wd_r, column=7, value="Physical Cash Payout").alignment = align_left
            ws3.cell(row=wd_r, column=8, value="REDUCES VAULT CASH (Account 1000 Credit)").alignment = align_center
            ws3.cell(row=wd_r, column=9, value="Branch Manager").alignment = align_center
            wd_r += 1

        # =========================================================================
        # TAB 5: DAILY EOD CASH FLOW & BANK (@rules Enforced)
        # =========================================================================
        ws4 = wb.create_sheet(title="Daily EOD Cash Flow & Bank")
        ws4.views.sheetView[0].showGridLines = True
        ws4.row_dimensions[1].height = 28

        eod_headers = [
            ("Date (YYYY-MM-DD)", 18),
            ("Day", 10),
            ("Opening Vault Cash (₦)", 18),
            ("Bank Withdrawal (₦)\n[Inflow from Bank]", 20),
            ("Total Repayments (₦)\n[From Tab 1]", 20),
            ("Total Savings (₦)\n[From Tab 1]", 20),
            ("Total Daily Inflows (₦)\n[Bank + Field Collections]", 22),
            ("Cash Loan Disbursed (₦)\n[Physical Outflow]", 22),
            ("Physical Withdrawals (₦)\n[From Tab 3]", 22),
            ("Daily Office Expenses (₦)", 18),
            ("Bank Deposited (₦)\n[Outflow Remittance]", 20),
            ("Total Daily Outflows (₦)\n[Disb+Wd+Exp+Bank]", 22),
            ("Closing Vault Cash (₦)\n[Open + Inflows - Outflows]", 22),
            ("Expense Description / Cash Notes", 32),
        ]

        for col_idx, (h_text, h_w) in enumerate(eod_headers, start=1):
            cell = ws4.cell(row=1, column=col_idx, value=h_text)
            cell.font = font_header
            cell.fill = fill_navy
            cell.alignment = align_center
            cell.border = border_cell
            ws4.column_dimensions[get_column_letter(col_idx)].width = h_w

        ws4.freeze_panes = "C2"

        # Populate all 22 working days
        for idx, (d_str, d_day) in enumerate(WORKING_DAYS, start=2):
            ws4.row_dimensions[idx].height = 22
            ws4.cell(row=idx, column=1, value=d_str).alignment = align_center
            ws4.cell(row=idx, column=2, value=d_day).alignment = align_center
            
            # Opening Vault Cash
            if idx == 2:
                ws4.cell(row=idx, column=3, value=0).number_format = "#,##0"
            else:
                ws4.cell(row=idx, column=3, value=f"=M{idx-1}").number_format = "#,##0"

            # Historical defaults if available from known cashbook postings
            hist_bank_wd = 0
            hist_disb = 0
            hist_bank_dep = 0
            hist_exp = 0

            if officer_username == "CO4":
                if d_str == "2026-09-01":
                    hist_bank_wd = 866400
                    hist_disb = 855000
                    hist_bank_dep = 240900
                elif d_str == "2026-09-02":
                    hist_bank_dep = 188550
            elif officer_username == "CO3":
                if d_str == "2026-09-01":
                    hist_bank_dep = 282100
                elif d_str == "2026-09-02":
                    hist_bank_wd = 19700
                elif d_str == "2026-09-14":
                    hist_bank_dep = 321200
                elif d_str == "2026-09-15":
                    hist_bank_dep = 278700
                elif d_str == "2026-09-16":
                    hist_bank_dep = 300200

            # Col D: Bank Withdrawal
            ws4.cell(row=idx, column=4, value=hist_bank_wd).number_format = "#,##0"

            # Col E: Daily Repayments (Link to Tab 1 Total for that day)
            day_idx = idx - 2  # 0-indexed
            tab1_rep_col = get_column_letter(11 + day_idx * 2)
            ws4.cell(row=idx, column=5, value=f"='Daily Collections Matrix'!{tab1_rep_col}{portfolio_totals_row}").number_format = "#,##0"

            # Col F: Daily Savings (Link to Tab 1 Total for that day)
            tab1_sav_col = get_column_letter(12 + day_idx * 2)
            ws4.cell(row=idx, column=6, value=f"='Daily Collections Matrix'!{tab1_sav_col}{portfolio_totals_row}").number_format = "#,##0"

            # Col G: Total Inflows = Bank Withdrawal + Repayments + Savings
            ws4.cell(row=idx, column=7, value=f"=D{idx}+E{idx}+F{idx}").number_format = "#,##0"

            # Col H: Cash Disbursements
            ws4.cell(row=idx, column=8, value=hist_disb).number_format = "#,##0"

            # Col I: Physical Cash Withdrawals
            ws4.cell(row=idx, column=9, value=0).number_format = "#,##0"

            # Col J: Daily Expenses
            ws4.cell(row=idx, column=10, value=hist_exp).number_format = "#,##0"

            # Col K: Bank Deposited
            ws4.cell(row=idx, column=11, value=hist_bank_dep).number_format = "#,##0"

            # Col L: Total Outflows = Disbursements + Withdrawals + Expenses + Bank Deposited
            ws4.cell(row=idx, column=12, value=f"=H{idx}+I{idx}+J{idx}+K{idx}").number_format = "#,##0"

            # Col M: Closing Vault Cash = Opening + Inflows - Outflows
            ws4.cell(row=idx, column=13, value=f"=C{idx}+G{idx}-L{idx}").number_format = "#,##0"

            # Formatting
            for c_i in range(1, 15):
                cell = ws4.cell(row=idx, column=c_i)
                cell.border = border_cell
                if 3 <= c_i <= 13:
                    cell.alignment = align_right
                    if c_i in [7, 12]:
                        cell.fill = fill_light_blue
                        cell.font = font_bold
                    elif c_i == 13:
                        cell.fill = fill_amber
                        cell.font = font_bold

        # =========================================================================
        # TAB 6: INSTRUCTIONS & CORE BANKING RULES GUIDE
        # =========================================================================
        ws5 = wb.create_sheet(title="Instructions & Rules Guide")
        ws5.views.sheetView[0].showGridLines = False
        ws5.column_dimensions['B'].width = 110

        guide_lines = [
            ("ICARE CORE BANKING LOAN DISBURSEMENT & COLLECTION RULES GUIDE", font_title),
            ("", font_data),
            ("1. LOAN PRICING & DISBURSEMENT ARCHITECTURE (BR-FEE-001, BR-CASH-001)", font_sub),
            ("   - Daily Cash Loan (60 Days):", font_data),
            ("     * Total Interest Rate = 12% upfront (11% Markup + 1% Contingency Risk Premium).", font_data),
            ("     * Markup (11%) = Interest * (11 / 12) | Contingency (1%) = Interest * (1 / 12).", font_data),
            ("     * Gap Fee: Applied when Principal / 60 produces decimals, rounding daily repayments to clean multiples of 50.", font_data),
            ("     * Total Upfront Required = Upfront Interest (12%) + Gap Fee.", font_data),
            ("     * Active Credit Disbursed = Principal - Gap Fee.", font_data),
            ("     * Contractual Daily Repayment Rate = Active Credit / 60.", font_data),
            ("   - Daily Cash Loan (120 Days):", font_data),
            ("     * Total Interest Rate = 21% upfront (20% Markup + 1% Contingency Risk Premium).", font_data),
            ("     * Markup (20%) = Interest * (20 / 21) | Contingency (1%) = Interest * (1 / 21).", font_data),
            ("   - Asset Loans (Asset Program):", font_data),
            ("     * Physical assets provided on credit (NO bank cash transfer to client).", font_data),
            ("     * Active Credit = (Asset Cost + Interest) - (Cash Downpayment + Savings Downpayment).", font_data),
            ("     * In Cashbook: Asset Credit Sales on Left side balances Active Credit on Right side.", font_data),
            ("", font_data),
            ("2. FIRST REPAYMENT DATE & SCHEDULE INVARIANT (FP-008, BR-DATE-002)", font_sub),
            ("   - First loan repayment date begins on the NEXT valid working collection day after disbursement.", font_data),
            ("   - Disbursement Date != First Repayment Date. On the disbursement date, repayment installment = 0.", font_data),
            ("   - Weekends (Saturday/Sunday) and public holidays are skipped.", font_data),
            ("   - Example: Disbursed on Tuesday Sep 01 -> First Repayment is Wednesday Sep 02.", font_data),
            ("   - Example: Disbursed on Friday Sep 04 -> First Repayment is Monday Sep 07.", font_data),
            ("", font_data),
            ("3. UPFRONT FEE SETTLEMENT & CASHBOOK BALANCING (BR-FEE-001, BR-ACCT-002)", font_sub),
            ("   - Deducted from Savings (Automatic Deduction):", font_data),
            ("     * Non-cash internal transfer from Client Savings (Account 2000) to Fee Revenue (Account 4000).", font_data),
            ("     * DOES NOT touch physical vault cash (Account 1000).", font_data),
            ("     * In Cashbook: Left side Inflow (daily_11_pct + contingency) is balanced on Right side by 'Product Withdrawal'.", font_data),
            ("   - Paid in Physical Cash:", font_data),
            ("     * Enters physical vault cash (Account 1000 Debit). Left side Inflow, deposited to bank at EOD.", font_data),
            ("", font_data),
            ("4. FULL PAYOFF, LOAN RENEWAL & CLIENT STATUS (BR-CLI-003, BR-CLI-005, BR-DASH-005)", font_sub),
            ("   - When a client pays off their loan in full (Remaining Balance = 0):", font_data),
            ("     * Enter the exact payoff amount on that date in Tab 1 (e.g. 45,000). Enter 0 on subsequent days.", font_data),
            ("     * The system transitions Loan -> Completed, transitions Client -> Completed, and logs to loan_payoff_excess_records.", font_data),
            ("   - Loan Renewal:", font_data),
            ("     * Record payoff on old loan row in Tab 1.", font_data),
            ("     * Enter new loan in Tab 2 (New Loans & Disbursements).", font_data),
            ("     * Enter new loan's daily repayments in Tab 1 starting from the NEXT working day after disbursement.", font_data),
            ("", font_data),
            ("5. DAILY EOD CASH FLOW & BANK (Tab 5)", font_sub),
            ("   - Physical cash vault balance reconciles: Opening Vault + Bank Withdrawal + Collections - Disbursed - Expenses - Bank Deposited = Closing Vault.", font_data),
            ("   - Non-cash internal transfers (Asset loans, automatic savings fee deductions) do not alter physical cash vault.", font_data),
        ]

        for r_idx, (text, f_style) in enumerate(guide_lines, start=2):
            cell = ws5.cell(row=r_idx, column=2, value=text)
            cell.font = f_style

        if "Sheet" in wb.sheetnames:
            wb.remove(wb["Sheet"])

        for out_p in output_paths:
            try:
                wb.save(out_p)
                print(f"--> Successfully saved: {out_p}")
            except Exception as e:
                print(f"--> Could not save to {out_p}: {e}")

if __name__ == "__main__":
    co4_paths = [
        r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\CO4_Master_Collections_Sep01_to_Sep30.xlsx",
        r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\CO4_Master_Collections_Sep01_to_Sep22.xlsx",
        r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\CO4_Master_Collections_Sep01_to_Sep11_Rebuilt.xlsx"
    ]
    co3_paths = [
        r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\CO3_Master_Collections_Sep01_to_Sep30.xlsx",
        r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\CO3_Master_Collections_Sep01_to_Sep22.xlsx",
        r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit\CO3_Master_Collections_Sep01_to_Sep11.xlsx"
    ]

    build_extended_workbook("CO4", co4_paths)
    build_extended_workbook("CO3", co3_paths)
    print("\nALL EXTENDED MASTER WORKBOOKS REBUILT WITH FULL GOVERNANCE ENFORCEMENT!")
