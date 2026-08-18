import pandas as pd
import io

def test_manifest_csv_unit():
    print("=== RUNNING UNIT TEST: MANIFEST CSV GENERATION & PARSING ===")

    # 1. Mock member info dictionary (same structure as computed in app.py)
    member_info = {
        "OGI-28-007": {
            "member": pd.Series({
                "Client Name": "Koleosho Sheriffat",
                "Client ID": "OGI-28-007",
                "Branch": "Ogijo",
                "Loan Product": "Weekly 24W"
            }),
            "sav_bal": 25000.0,
            "rem_bal": 246000.0,
            "act_cred": 246000.0,
            "expected_rep_schedule": 10250.0,
            "prev_dep": 0.0,
            "prev_wd": 0.0,
            "prev_rep": 10250.0,
            "start_date": "2026-08-07"
        },
        "OGI-28-008": {
            "member": pd.Series({
                "Client Name": "Femi Kayode",
                "Client ID": "OGI-28-008",
                "Branch": "Ogijo",
                "Loan Product": "Weekly 24W"
            }),
            "sav_bal": 18000.0,
            "rem_bal": 246000.0,
            "act_cred": 246000.0,
            "expected_rep_schedule": 10250.0,
            "prev_dep": 0.0,
            "prev_wd": 0.0,
            "prev_rep": 10250.0,
            "start_date": "2026-08-07"
        },
        "OGI-28-002": {
            "member": pd.Series({
                "Client Name": "Orumo Fatimoh",
                "Client ID": "OGI-28-002",
                "Branch": "Ogijo",
                "Loan Product": "Weekly 12W"
            }),
            "sav_bal": 35000.0,
            "rem_bal": 198000.0,
            "act_cred": 198000.0,
            "expected_rep_schedule": 16500.0,
            "prev_dep": 0.0,
            "prev_wd": 0.0,
            "prev_rep": 16500.0,
            "start_date": "2026-08-07"
        }
    }

    # 2. Test CSV Export generation with Group Savings
    selected_group = "Favour"
    group_savings_balance = 75000.0
    manifest_rows = []
    if selected_group != "Ungrouped":
        manifest_rows.append({
            "Client ID": f"GROUP-{selected_group}",
            "Client Name": f"{selected_group} Communal Savings",
            "Savings Balance": round(float(group_savings_balance), 2),
            "Remaining Balance": 0.0,
            "Expected Repayment": 0.0,
            "Amount Collected": 0.0,
            "Savings Deposit": 0.0
        })
    for cid, info in member_info.items():
        m = info['member']
        manifest_rows.append({
            "Client ID": cid,
            "Client Name": m['Client Name'],
            "Savings Balance": round(float(info['sav_bal']), 2),
            "Remaining Balance": round(float(info['rem_bal']), 2),
            "Expected Repayment": round(float(info['expected_rep_schedule']), 2),
            "Amount Collected": 0.0,
            "Savings Deposit": 0.0
        })

    df_export = pd.DataFrame(manifest_rows)
    print("Generated CSV Header & Sample Rows (including Group Savings):")
    print(df_export.to_string(index=False))

    # Assert expected columns and group row
    expected_cols = ["Client ID", "Client Name", "Savings Balance", "Remaining Balance", "Expected Repayment", "Amount Collected", "Savings Deposit"]
    assert list(df_export.columns) == expected_cols, f"Columns mismatch: {df_export.columns}"
    assert "Signature" not in df_export.columns, "Signature must be excluded!"
    assert df_export.iloc[0]["Client ID"] == "GROUP-Favour"
    assert df_export.iloc[0]["Savings Balance"] == 75000.0

    # 3. Simulate Field Officer editing the CSV including Group Savings:
    # Officer enters Group Savings = 5000
    edited_csv = """Client ID,Client Name,Savings Balance,Remaining Balance,Expected Repayment,Amount Collected,Savings Deposit
GROUP-Favour,Favour Communal Savings,75000.0,0.0,0.0,0.0,5000.0
OGI-28-007,Koleosho Sheriffat,25000.0,246000.0,10250.0,10250.0,1000.0
OGI-28-008,Femi Kayode,18000.0,246000.0,10250.0,5000.0,500.0
OGI-28-002,Orumo Fatimoh,35000.0,198000.0,16500.0,0.0,0.0
"""

    # 4. Simulate Upload Parsing Logic (mirroring app.py parser)
    df_up = pd.read_csv(io.StringIO(edited_csv))
    df_up.columns = [str(c).strip() for c in df_up.columns]

    id_col = next((c for c in df_up.columns if c.lower() in ["client id", "id", "client_id", "code"]), None)
    rep_col_name = next((c for c in df_up.columns if c.lower() in ["amount collected", "loan repayment amount", "repayment", "amount_collected", "amount paid"]), None)
    sav_col_name = next((c for c in df_up.columns if c.lower() in ["savings deposit", "savings amount", "savings", "savings_deposit"]), None)

    assert id_col == "Client ID"
    assert rep_col_name == "Amount Collected"
    assert sav_col_name == "Savings Deposit"

    csv_entries = []
    target_co = "CO2"
    BRANCH = "Ogijo"
    date_str = "2026-08-16"

    for _, u_row in df_up.iterrows():
        raw_cid = str(u_row.get(id_col, '')).strip()
        if not raw_cid or raw_cid == 'nan': continue

        is_group_row = (
            raw_cid.startswith("GROUP-") or
            "group" in str(u_row.get("Client Name", "")).lower() or
            "communal" in str(u_row.get("Client Name", "")).lower() or
            raw_cid.lower() == selected_group.lower()
        )
        if is_group_row:
            grp_sav = 0.0
            if sav_col_name and pd.notna(u_row.get(sav_col_name)):
                try: grp_sav = float(str(u_row.get(sav_col_name)).replace(',', '').strip() or 0.0)
                except Exception: grp_sav = 0.0
            if grp_sav == 0.0 and rep_col_name and pd.notna(u_row.get(rep_col_name)):
                try: grp_sav = float(str(u_row.get(rep_col_name)).replace(',', '').strip() or 0.0)
                except Exception: grp_sav = 0.0
                
            if grp_sav > 0:
                g_data = {
                    "Date": date_str,
                    "Client ID": f"GROUP-{selected_group}",
                    "Client Name": f"{selected_group} Meeting",
                    "Officer": target_co,
                    "Branch": BRANCH,
                    "Amount Paid": grp_sav,
                    "Transaction Type": "Group Meeting",
                    "Note": "Daily Collection (CSV Upload)",
                    "Savings Amount": grp_sav,
                    "Withdrawal Amount": 0.0,
                    "Group Savings Deposit": grp_sav
                }
                csv_entries.append(g_data)
            continue

        info = member_info.get(raw_cid)
        assert info is not None, f"Client {raw_cid} not found in member_info!"

        m = info['member']
        rep_val = float(str(u_row.get(rep_col_name)).replace(',', '').strip() or 0.0)
        sav_val = float(str(u_row.get(sav_col_name)).replace(',', '').strip() or 0.0)
        exp_rep = float(info['expected_rep_schedule'] or 0.0)

        p_status = "PAID" if rep_val >= exp_rep and exp_rep > 0 else ("PART_PAID" if rep_val > 0 else "NOT_PAID")

        tx_data = {
            "Date": date_str,
            "Client ID": raw_cid,
            "Client Name": m['Client Name'],
            "Officer": target_co,
            "Branch": BRANCH,
            "Amount Paid": rep_val,
            "Transaction Type": "Loan",
            "Note": "Daily Collection (CSV Upload)",
            "Savings Amount": sav_val,
            "Withdrawal Amount": 0.0,
            "Loan Repayment Amount": rep_val,
            "Payment Status": p_status,
            "Expected Amount": exp_rep,
            "Overdue Amount": max(0.0, exp_rep - rep_val)
        }
        csv_entries.append(tx_data)

    print(f"\nParsed {len(csv_entries)} Transaction Records (including Group Savings):")
    for tx in csv_entries:
        print(f"  Client: {tx['Client ID']} ({tx['Client Name']}) | Repay: NGN {tx.get('Loan Repayment Amount', 0):,.2f} | Savings: NGN {tx['Savings Amount']:,.2f}")

    # Assertions
    assert csv_entries[0]["Client ID"] == "GROUP-Favour"
    assert csv_entries[0]["Savings Amount"] == 5000.0
    assert csv_entries[0]["Group Savings Deposit"] == 5000.0

    assert csv_entries[1]["Loan Repayment Amount"] == 10250.0
    assert csv_entries[1]["Savings Amount"] == 1000.0
    assert csv_entries[1]["Payment Status"] == "PAID"

    assert csv_entries[2]["Loan Repayment Amount"] == 5000.0
    assert csv_entries[2]["Savings Amount"] == 500.0
    assert csv_entries[2]["Payment Status"] == "PART_PAID"

    print("\n>>> ALL UNIT TEST ASSERTIONS PASSED! <<<")

if __name__ == "__main__":
    test_manifest_csv_unit()
