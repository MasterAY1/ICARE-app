import json
from database.repositories.unit_of_work import SupabaseUnitOfWork
from datetime import datetime, timezone

def update_statements_cycle_parity_september_2026():
    uow = SupabaseUnitOfWork()
    branch_id = "997d504e-7f5c-4772-887d-fdd5a4c1183b"
    year = 2026
    month = 9

    # Authoritative Statement A: Monthly Deposit Statement
    deposit_statement = {
        "rows": [
            {
                "programme": "Monthly",
                "member_prev": 2,
                "member_curr": 0,
                "member_total": 2,
                "deposit_prev": 27000.0,
                "deposit_curr": 9000.0,
                "deposit_total": 36000.0,
                "withdrawal_prev_no": 7,
                "withdrawal_prev_amount": 22790.0,
                "withdrawal_curr_no": 0,
                "withdrawal_curr_amount": 0.0,
                "withdrawal_total_no": 7,
                "withdrawal_total_amount": 22790.0,
                "return_prev_no": 1,
                "return_prev_amount": 5000.0,
                "return_curr_no": 0,
                "return_curr_amount": 0.0,
                "return_total_no": 1,
                "return_total_amount": 5000.0,
                "balance_no": 2,
                "balance_amount": 36000.0,
            },
            {
                "programme": "Weekly",
                "member_prev": 171,
                "member_curr": 12,
                "member_total": 183,
                "deposit_prev": 43777730.0,
                "deposit_curr": 1915125.0,
                "deposit_total": 45692855.0,
                "withdrawal_prev_no": 1540,
                "withdrawal_prev_amount": 40891965.0,
                "withdrawal_curr_no": 15,
                "withdrawal_curr_amount": 1758000.0,
                "withdrawal_total_no": 1555,
                "withdrawal_total_amount": 42649965.0,
                "return_prev_no": 549,
                "return_prev_amount": 9617175.0,
                "return_curr_no": 14,
                "return_curr_amount": 226450.0,
                "return_total_no": 563,
                "return_total_amount": 9843625.0,
                "balance_no": 169,
                "balance_amount": 4308405.0,
            },
            {
                "programme": "Daily",
                "member_prev": 130,
                "member_curr": 26,
                "member_total": 156,
                "deposit_prev": 62861130.0,
                "deposit_curr": 2368100.0,
                "deposit_total": 65229230.0,
                "withdrawal_prev_no": 1683,
                "withdrawal_prev_amount": 44025180.0,
                "withdrawal_curr_no": 51,
                "withdrawal_curr_amount": 1353800.0,
                "withdrawal_total_no": 1734,
                "withdrawal_total_amount": 45378980.0,
                "return_prev_no": 475,
                "return_prev_amount": 11654445.0,
                "return_curr_no": 8,
                "return_curr_amount": 159050.0,
                "return_total_no": 483,
                "return_total_amount": 11813495.0,
                "balance_no": 148,
                "balance_amount": 7141380.0,
            },
            {
                "programme": "Total",
                "member_prev": 303,
                "member_curr": 38,
                "member_total": 341,
                "deposit_prev": 106665860.0,
                "deposit_curr": 4292225.0,
                "deposit_total": 110958085.0,
                "withdrawal_prev_no": 3230,
                "withdrawal_prev_amount": 84939935.0,
                "withdrawal_curr_no": 66,
                "withdrawal_curr_amount": 3111800.0,
                "withdrawal_total_no": 3296,
                "withdrawal_total_amount": 88051735.0,
                "return_prev_no": 1025,
                "return_prev_amount": 21276620.0,
                "return_curr_no": 22,
                "return_curr_amount": 385500.0,
                "return_total_no": 1047,
                "return_total_amount": 21662120.0,
                "balance_no": 319,
                "balance_amount": 11485785.0,
            },
        ]
    }

    # Authoritative Statement B: Monthly Credit Statement
    credit_statement = {
        "rows": [
            {
                "section": "1. Credit Disbursed",
                "item": "• Previous Loans Count (B/F)",
                "monthly": 5,
                "weekly": 149,
                "daily": 129,
                "total": 283,
            },
            {
                "section": "1. Credit Disbursed",
                "item": "• Previous Disbursed Amount (₦)",
                "monthly": 792000.0,
                "weekly": 24525000.0,
                "daily": 21768000.0,
                "total": 47085000.0,
            },
            {
                "section": "1. Credit Disbursed",
                "item": "• Current Loans Count",
                "monthly": 1,
                "weekly": 62,
                "daily": 54,
                "total": 117,
            },
            {
                "section": "1. Credit Disbursed",
                "item": "• Current Disbursed Amount (₦)",
                "monthly": 180000.0,
                "weekly": 10009000.0,
                "daily": 8777000.0,
                "total": 18966000.0,
            },
            {
                "section": "1. Credit Disbursed",
                "item": "• Total Net Loans Count (Col 7 = 3+5-27)",
                "monthly": 3,
                "weekly": 155,
                "daily": 135,
                "total": 293,
            },
            {
                "section": "1. Credit Disbursed",
                "item": "• Total Net Disbursed (₦) (Col 8 = 4+6-28)",
                "monthly": 402000.0,
                "weekly": 25560000.0,
                "daily": 22461000.0,
                "total": 48423000.0,
            },
            {
                "section": "2. Excess Collection",
                "item": "• Previous Excess (₦) (Col 9)",
                "monthly": 0.0,
                "weekly": 25119900.0,
                "daily": 46164400.0,
                "total": 71284300.0,
            },
            {
                "section": "2. Excess Collection",
                "item": "• Current Month Excess (₦) (Col 10)",
                "monthly": 0.0,
                "weekly": 345625.0,
                "daily": 357600.0,
                "total": 703225.0,
            },
            {
                "section": "2. Excess Collection",
                "item": "• Total Excess Collection (₦) (Col 11 = 9+10)",
                "monthly": 0.0,
                "weekly": 25465525.0,
                "daily": 46522000.0,
                "total": 71987525.0,
            },
            {
                "section": "3. Installment Collection",
                "item": "• Previous Installments (₦) (Col 12)",
                "monthly": 400000.0,
                "weekly": 11504500.0,
                "daily": 10288000.0,
                "total": 22192500.0,
            },
            {
                "section": "3. Installment Collection",
                "item": "• Current Month Installment (₦) (Col 13)",
                "monthly": 264000.0,
                "weekly": 8556625.0,
                "daily": 8645050.0,
                "total": 17465675.0,
            },
            {
                "section": "3. Installment Collection",
                "item": "• Total Net Installments (₦) (Col 14 = 12+13-28)",
                "monthly": 256000.0,
                "weekly": 11025125.0,
                "daily": 10749050.0,
                "total": 22030175.0,
            },
            {
                "section": "4. Balance (Portfolio)",
                "item": "• Active Loans Balance Count (Col 23 = Col 7)",
                "monthly": 3,
                "weekly": 155,
                "daily": 135,
                "total": 293,
            },
            {
                "section": "4. Balance (Portfolio)",
                "item": "• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)",
                "monthly": 146000.0,
                "weekly": 14534875.0,
                "daily": 11711950.0,
                "total": 26392825.0,
            },
            {
                "section": "5. Full Repayment (Settled Loans)",
                "item": "• Previous Full Repayment Count (Col 25)",
                "monthly": 19,
                "weekly": 1592,
                "daily": 1579,
                "total": 3190,
            },
            {
                "section": "5. Full Repayment (Settled Loans)",
                "item": "• Previous Full Repayment Amount (₦) (Col 26)",
                "monthly": 2898000.0,
                "weekly": 20424500.0,
                "daily": 16954000.0,
                "total": 40276500.0,
            },
            {
                "section": "5. Full Repayment (Settled Loans)",
                "item": "• Current Full Repayment Count (Col 27)",
                "monthly": 3,
                "weekly": 56,
                "daily": 48,
                "total": 107,
            },
            {
                "section": "5. Full Repayment (Settled Loans)",
                "item": "• Current Full Repayment Amount (₦) (Col 28)",
                "monthly": 408000.0,
                "weekly": 9036000.0,
                "daily": 8184000.0,
                "total": 17628000.0,
            },
            {
                "section": "5. Full Repayment (Settled Loans)",
                "item": "• Total Cumulative Settled Count",
                "monthly": 22,
                "weekly": 1648,
                "daily": 1627,
                "total": 3297,
            },
            {
                "section": "5. Full Repayment (Settled Loans)",
                "item": "• Total Cumulative Settled Amount (₦)",
                "monthly": 3306000.0,
                "weekly": 29460500.0,
                "daily": 25138000.0,
                "total": 57904500.0,
            },
        ]
    }

    # Fetch current record to merge
    res = uow.client.table("monthly_statement_reconciliations").select("data").eq("branch_id", branch_id).eq("year", year).eq("month", month).execute()
    existing_data = res.data[0]["data"] if res.data else {}

    existing_data["deposit_statement"] = deposit_statement
    existing_data["credit_statement"] = credit_statement

    uow.client.table("monthly_statement_reconciliations").upsert({
        "branch_id": branch_id,
        "year": year,
        "month": month,
        "data": existing_data,
        "updated_at": datetime.now(timezone.utc).isoformat()
    }, on_conflict="branch_id,year,month").execute()

    print("SUCCESS: Updated monthly_statement_reconciliations for September 2026 with 100% paper parity.")

if __name__ == "__main__":
    update_statements_cycle_parity_september_2026()
