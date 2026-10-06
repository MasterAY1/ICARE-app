"""
Script: scripts/verification/verify_ogijo_september_parity.py
Automated 14-point audit asserting 100% mathematical parity across the paper summary,
Finance_book_automated.xlsx, and live Supabase database for Ogijo Branch (September 2026).
"""

import os
import sys
import pandas as pd
from datetime import date

# Add repository root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from database.connection import supabase
from interfaces.unit_of_work import UnitOfWork
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.rbac_scope_service import RBACScope
from services.portfolio_service import PortfolioService

OGIJO_BRANCH_ID = "997d504e-7f5c-4772-887d-fdd5a4c1183b"

OFFICER_TARGETS = {
    "573eca5f-958a-4ad4-950a-4108b0a798dc": {  # Dorcas (CO1)
        "name": "Dorcas (CO1)",
        "opening_credit": 7340750.0,
        "disbursed": 5846000.0,
        "initial_deposit": 98000.0,
        "net_disbursed": 5748000.0,
        "repayments": 5067250.0,
        "closing_credit": 8021500.0,
        "opening_savings": 2465530.0,
        "savings_dep": 1103800.0,
        "savings_wth": 1137650.0,
        "closing_savings": 2431680.0,
    },
    "c32125e1-c7e5-4a85-8948-12d05b40eaa9": {  # Ayomide (CO2)
        "name": "Ayomide (CO2)",
        "opening_credit": 5679750.0,
        "disbursed": 4453000.0,
        "initial_deposit": 130000.0,
        "net_disbursed": 4323000.0,
        "repayments": 3489375.0,
        "closing_credit": 6513375.0,
        "opening_savings": 1912200.0,
        "savings_dep": 811325.0,
        "savings_wth": 846800.0,
        "closing_savings": 1876725.0,
    },
    "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc": {  # Olajumoke (CO3)
        "name": "Olajumoke (CO3)",
        "opening_credit": 6483650.0,
        "disbursed": 5970000.0,
        "initial_deposit": 126000.0,
        "net_disbursed": 5844000.0,
        "repayments": 5208950.0,
        "closing_credit": 7118700.0,
        "opening_savings": 4381700.0,
        "savings_dep": 1533550.0,
        "savings_wth": 973700.0,
        "closing_savings": 4941550.0,
    },
    "0ad2a283-3ed1-42ea-ae7f-5b33b665389d": {  # Oluwaseun (CO4)
        "name": "Oluwaseun (CO4)",
        "opening_credit": 5388350.0,
        "disbursed": 3280000.0,
        "initial_deposit": 229000.0,
        "net_disbursed": 3051000.0,
        "repayments": 3700100.0,
        "closing_credit": 4739250.0,
        "opening_savings": 1931430.0,
        "savings_dep": 843550.0,
        "savings_wth": 539150.0,
        "closing_savings": 2235830.0,
    }
}

def fetch_all_paginated(table_name, select_cols, filter_fn=None):
    all_data = []
    page = 0
    step = 1000
    while True:
        q = supabase.table(table_name).select(select_cols)
        if filter_fn:
            q = filter_fn(q)
        res = q.range(page * step, (page + 1) * step - 1).execute()
        data = res.data or []
        all_data.extend(data)
        if len(data) < step:
            break
        page += 1
    return all_data

def verify_all_parities():
    print("==================================================================")
    print("VERIFYING OGIJO BRANCH SEPTEMBER 2026 FINANCIAL PARITY")
    print("==================================================================")
    errors = []

    # 1. Verify September Loans Disbursed
    loans_sep = fetch_all_paginated("loans", "loan_amount, active_credit, officer_id", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID).gte("disbursement_date", "2026-09-01").lte("disbursement_date", "2026-09-30"))
    tot_loan_amt = sum(float(l["loan_amount"] or 0) for l in loans_sep)
    tot_act_cred = sum(float(l["active_credit"] or 0) for l in loans_sep)

    print(f"1. Total Disbursed Loans: {len(loans_sep)} loans")
    print(f"   - Principal: N{tot_loan_amt:,.2f} (Target: N19,549,000.00)")
    print(f"   - Active Credit: N{tot_act_cred:,.2f} (Target: N18,966,000.00)")
    if abs(tot_loan_amt - 19549000.0) > 0.01:
        errors.append(f"Disbursed principal mismatch: {tot_loan_amt} != 19549000.00")
    if abs(tot_act_cred - 18966000.0) > 0.01:
        errors.append(f"Disbursed active credit mismatch: {tot_act_cred} != 18966000.00")

    # 2. Verify September Repayments
    reps_sep = fetch_all_paginated("repayments", "amount_paid, officer_id", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID).gte("date", "2026-09-01T00:00:00").lte("date", "2026-09-30T23:59:59"))
    tot_rep = sum(float(r["amount_paid"] or 0) for r in reps_sep)
    print(f"\n2. Total Repayments: {len(reps_sep)} payments")
    print(f"   - Collections: N{tot_rep:,.2f} (Target: N17,465,675.00)")
    if abs(tot_rep - 17465675.0) > 0.01:
        errors.append(f"Repayments mismatch: {tot_rep} != 17465675.00")

    # 3. Verify September Savings Deposits & Withdrawals
    sav_sep = fetch_all_paginated("individual_savings", "deposit_amount, withdrawal_amount, officer_id, posting_date", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID).gte("posting_date", "2026-09-01").lte("posting_date", "2026-09-30"))
    tot_sav_dep = sum(float(s["deposit_amount"] or 0) for s in sav_sep)
    tot_sav_wth = sum(float(s["withdrawal_amount"] or 0) for s in sav_sep)
    print(f"\n3. September Savings Activity:")
    print(f"   - Deposits: N{tot_sav_dep:,.2f} (Target: N4,292,225.00)")
    print(f"   - Withdrawals: N{tot_sav_wth:,.2f} (Target: N3,497,300.00)")
    if abs(tot_sav_dep - 4292225.0) > 0.01:
        errors.append(f"Savings deposits mismatch: {tot_sav_dep} != 4292225.00")
    if abs(tot_sav_wth - 3497300.0) > 0.01:
        errors.append(f"Savings withdrawals mismatch: {tot_sav_wth} != 3497300.00")

    # 4. Verify Opening Savings B/F
    sav_open = fetch_all_paginated("individual_savings", "deposit_amount, officer_id", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID).eq("posting_date", "2026-08-31"))
    tot_sav_open = sum(float(s["deposit_amount"] or 0) for s in sav_open)
    print(f"\n4. Opening Savings B/F:")
    print(f"   - Savings B/F: N{tot_sav_open:,.2f} (Target: N10,690,860.00)")
    if abs(tot_sav_open - 10690860.0) > 0.01:
        errors.append(f"Opening savings mismatch: {tot_sav_open} != 10690860.00")

    # 5. Verify Closing Savings Balance
    closing_savings = tot_sav_open + tot_sav_dep - tot_sav_wth
    print(f"\n5. Closing Savings Balance:")
    print(f"   - Net Closing Savings: N{closing_savings:,.2f} (Target: N11,485,785.00)")
    if abs(closing_savings - 11485785.0) > 0.01:
        errors.append(f"Closing savings mismatch: {closing_savings} != 11485785.00")

    # 6. Verify Opening Loans Portfolio
    loans_open = fetch_all_paginated("loans", "active_credit, officer_id", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID).lt("disbursement_date", "2026-09-01"))
    tot_loan_open = sum(float(l["active_credit"] or 0) for l in loans_open)
    print(f"\n6. Opening Loans Portfolio:")
    print(f"   - Opening Credit: N{tot_loan_open:,.2f} (Target: N24,892,500.00)")
    if abs(tot_loan_open - 24892500.0) > 0.01:
        errors.append(f"Opening loan credit mismatch: {tot_loan_open} != 24892500.00")

    # 7. Verify Closing Loan Portfolio
    closing_credit = tot_loan_open + tot_act_cred - tot_rep
    print(f"\n7. Closing Loan Portfolio:")
    print(f"   - Net Closing Credit: N{closing_credit:,.2f} (Target: N26,392,825.00)")
    if abs(closing_credit - 26392825.0) > 0.01:
        errors.append(f"Closing credit mismatch: {closing_credit} != 26392825.00")

    # 8. Verify Bank Deposits from Ledger
    fle_bd = fetch_all_paginated("financial_ledger_entries", "amount", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID).eq("account_code", "1050"))
    tot_bd = sum(float(e["amount"] or 0) for e in fle_bd)
    print(f"\n8. Bank Deposits (Account 1050):")
    print(f"   - Total Bank Deposits: N{tot_bd:,.2f} (Target: N21,672,150.00)")
    if abs(tot_bd - 21672150.0) > 0.01:
        errors.append(f"Bank deposits mismatch: {tot_bd} != 21672150.00")

    # 9. Verify Office Expenses from Ledger
    fle_exp = fetch_all_paginated("financial_ledger_entries", "amount", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID).eq("account_code", "4000"))
    tot_exp = sum(float(e["amount"] or 0) for e in fle_exp)
    print(f"\n9. Office Expenses (Account 4000):")
    print(f"   - Total Expenses: N{tot_exp:,.2f} (Target: N207,600.00)")
    if abs(tot_exp - 207600.0) > 0.01:
        errors.append(f"Expenses mismatch: {tot_exp} != 207600.00")

    # 10. General Ledger Double-Entry Equality
    fle_all = fetch_all_paginated("financial_ledger_entries", "side, amount", lambda q: q.eq("branch_id", OGIJO_BRANCH_ID))
    debits = sum(float(e["amount"] or 0) for e in fle_all if e["side"] == "Debit")
    credits = sum(float(e["amount"] or 0) for e in fle_all if e["side"] == "Credit")
    diff_ledger = abs(debits - credits)
    print(f"\n10. General Ledger Balance:")
    print(f"   - Total Debits: N{debits:,.2f}")
    print(f"   - Total Credits: N{credits:,.2f}")
    print(f"   - Debits - Credits: N{diff_ledger:,.2f} (Target: N0.00)")
    if diff_ledger > 0.01:
        errors.append(f"Ledger unbalanced: Debits ({debits}) != Credits ({credits})")

    # 11. Per-Officer Granular Parity
    print(f"\n11. Officer-by-Officer Granular Parity:")
    for off_id, info in OFFICER_TARGETS.items():
        co_l = [l for l in loans_sep if l["officer_id"] == off_id]
        co_r = [r for r in reps_sep if r["officer_id"] == off_id]
        co_sd = [s for s in sav_sep if s["officer_id"] == off_id]

        c_disb = sum(float(l["loan_amount"] or 0) for l in co_l)
        c_rep = sum(float(r["amount_paid"] or 0) for r in co_r)
        c_sdep = sum(float(s["deposit_amount"] or 0) for s in co_sd)
        c_swth = sum(float(s["withdrawal_amount"] or 0) for s in co_sd)

        print(f"   {info['name']}:")
        print(f"     Disbursed: N{c_disb:,.2f} (Target: N{info['disbursed']:,.2f})")
        print(f"     Repayments: N{c_rep:,.2f} (Target: N{info['repayments']:,.2f})")
        print(f"     Savings Dep: N{c_sdep:,.2f} (Target: N{info['savings_dep']:,.2f})")
        print(f"     Savings Wth: N{c_swth:,.2f} (Target: N{info['savings_wth']:,.2f})")

        if abs(c_disb - info["disbursed"]) > 0.01:
            errors.append(f"{info['name']} disbursed mismatch: {c_disb} != {info['disbursed']}")
        if abs(c_rep - info["repayments"]) > 0.01:
            errors.append(f"{info['name']} repayment mismatch: {c_rep} != {info['repayments']}")
        if abs(c_sdep - info["savings_dep"]) > 0.01:
            errors.append(f"{info['name']} savings deposit mismatch: {c_sdep} != {info['savings_dep']}")
        if abs(c_swth - info["savings_wth"]) > 0.01:
            errors.append(f"{info['name']} savings withdrawal mismatch: {c_swth} != {info['savings_wth']}")

    print("\n==================================================================")
    if not errors:
        print("ALL 14 FINANCIAL AUDIT VERIFICATIONS PASSED WITH 100% PARITY!")
        print("==================================================================")
        return True
    else:
        print(f"FAILED WITH {len(errors)} DISCREPANCIES:")
        for err in errors:
            print(f" - {err}")
        print("==================================================================")
        return False

if __name__ == "__main__":
    success = verify_all_parities()
    sys.exit(0 if success else 1)
