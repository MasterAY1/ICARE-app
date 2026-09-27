import openpyxl
import sys
from openpyxl.utils import get_column_letter

sys.stdout.reconfigure(encoding='utf-8')

for fname in [
    "CO3_Master_Collections_Sep01_to_Sep30.xlsx", 
    "CO4_Master_Collections_Sep01_to_Sep30.xlsx",
    "CO3_Master_Collections_Sep01_to_Sep22.xlsx",
    "CO4_Master_Collections_Sep01_to_Sep22.xlsx"
]:
    print(f"\n==================== VERIFYING {fname} ====================")
    wb = openpyxl.load_workbook(fname, data_only=False)
    
    # 1. Check sheets
    print("Sheets:", wb.sheetnames)
    assert len(wb.sheetnames) == 6, f"Expected 6 sheets, got {len(wb.sheetnames)}"
    
    # 2. Check Tab 1 headers
    ws1 = wb["Daily Collections Matrix"]
    print(f"Tab 1 dimensions: max_row={ws1.max_row}, max_col={ws1.max_column}")
    
    # Check date headers in row 1
    dates = []
    for c in range(11, ws1.max_column - 3, 2):
        d_val = ws1.cell(row=1, column=c).value
        dates.append((c, d_val))
    print(f"Total date columns: {len(dates)}")
    print(f"First 3 dates: {dates[:3]}")
    print(f"Last 3 dates: {dates[-3:]}")
    assert len(dates) == 22, f"Expected 22 working days, got {len(dates)}"
    assert "2026-09-30" in dates[-1][1], f"Last date should be 2026-09-30, got {dates[-1][1]}"
    
    # Check summary column headers
    col_tot_rep = ws1.max_column - 3
    col_tot_sav = ws1.max_column - 2
    col_end_bal = ws1.max_column - 1
    col_notes = ws1.max_column
    
    print(f"Col {col_tot_rep} ({get_column_letter(col_tot_rep)}) header:", ws1.cell(row=1, column=col_tot_rep).value)
    print(f"Col {col_tot_sav} ({get_column_letter(col_tot_sav)}) header:", ws1.cell(row=1, column=col_tot_sav).value)
    print(f"Col {col_end_bal} ({get_column_letter(col_end_bal)}) header:", ws1.cell(row=1, column=col_end_bal).value)
    print(f"Col {col_notes} ({get_column_letter(col_notes)}) header:", ws1.cell(row=1, column=col_notes).value)
    
    # Check sample row formulas
    print(f"Row 4 Tot Repay formula: {ws1.cell(row=4, column=col_tot_rep).value[:40]}...")
    print(f"Row 4 Tot Sav formula: {ws1.cell(row=4, column=col_tot_sav).value[:40]}...")
    print(f"Row 4 End Bal formula: {ws1.cell(row=4, column=col_end_bal).value}")
    
    # Check totals row
    totals_r = ws1.max_row
    print(f"Totals row ({totals_r}): {ws1.cell(row=totals_r, column=4).value}")
    print(f"Totals formula for Col 11 (Day 1 Repay): {ws1.cell(row=totals_r, column=11).value}")
    last_rep_col = 11 + (22 - 1) * 2
    print(f"Totals formula for Col {last_rep_col} (Day 22 Repay): {ws1.cell(row=totals_r, column=last_rep_col).value}")
    
    # 3. Check Tab 2 (New Loans)
    ws2 = wb["New Loans & Disbursements"]
    print(f"\nTab 2 rows: {ws2.max_row}")
    disb_loans = []
    for r in range(2, ws2.max_row + 1):
        c_name = ws2.cell(row=r, column=6).value
        d_date = ws2.cell(row=r, column=1).value
        p_amt = ws2.cell(row=r, column=9).value
        stat = ws2.cell(row=r, column=24).value
        if c_name and d_date:
            disb_loans.append((d_date, c_name, p_amt, stat))
    print(f"Disbursed loans found: {len(disb_loans)}")
    for dl in disb_loans:
        print(f"  {dl[0]} | {dl[1]} | ₦{dl[2]:,} | {dl[3]}")
        
    # 4. Check Tab 5 (EOD Cash Flow & Bank)
    ws4 = wb["Daily EOD Cash Flow & Bank"]
    eod_days = ws4.max_row - 1
    print(f"\nTab 5 EOD days: {eod_days}")
    assert eod_days == 22, f"Expected 22 EOD rows, got {eod_days}"
    
    first_dt = ws4.cell(row=2, column=1).value
    last_dt = ws4.cell(row=ws4.max_row, column=1).value
    print(f"  First EOD row: {first_dt} | Last EOD row: {last_dt}")
    assert first_dt == "2026-09-01", f"First date must be 2026-09-01, got {first_dt}"
    assert last_dt == "2026-09-30", f"Last date must be 2026-09-30, got {last_dt}"
    
    # Check link formula for Day 22
    rep_f = ws4.cell(row=ws4.max_row, column=5).value
    sav_f = ws4.cell(row=ws4.max_row, column=6).value
    close_f = ws4.cell(row=ws4.max_row, column=13).value
    print(f"  Day 22 (Sep 30) Repay link: {rep_f} | Sav link: {sav_f} | Close formula: {close_f}")

print("\n>>> ALL 4 WORKBOOKS PASSED RIGOROUS 22-DAY AUDIT! <<<")
