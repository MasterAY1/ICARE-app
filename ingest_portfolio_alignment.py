"""
ingest_portfolio_alignment.py
Aligns client portfolios (Active Loan, Outstanding Balance, Savings Balance)
with physical paper presentation records.

Guarantees:
- Account 1000 Physical Vault Cash is 100% UNTOUCHED (BR-CASH-001, SOT-001, BR-SAV-004).
- Baseline savings updated via onboarding savings records in individual_savings.
- Loan contracts (loans.active_credit, loans.total_due) and schedules (loan_schedule) realigned.
- Client lifecycle status transitioned automatically if loan balance reaches 0 (BR-CLI-001).
- Multi-loan separation (Finance vs Asset) preserved.
"""

import os
import sys
import uuid
import argparse
from datetime import date, datetime
import pandas as pd
from dotenv import load_dotenv

sys.path.insert(0, r"c:\Users\DELL\Desktop\Master_ AY Projects\trustmicro-credit")
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

from database.connection import get_supabase_client
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope


def clean_num(val):
    if pd.isna(val) or val is None or str(val).strip() in ['', '-', 'nan', 'None']:
        return 0.0
    s = str(val).replace('₦', '').replace(',', '').strip()
    try:
        return float(s)
    except Exception:
        return 0.0


def align_portfolio(file_path: str, dry_run: bool = True):
    print(f"==================================================")
    print(f" PORTFOLIO ALIGNMENT ENGINE")
    print(f" File: {file_path}")
    print(f" Mode: {'DRY RUN (No changes written)' if dry_run else 'LIVE APPLY (Writing to DB)'}")
    print(f"==================================================\n")

    if not os.path.exists(file_path):
        print(f"ERROR: File not found: {file_path}")
        return

    # Load file (CSV or Excel)
    if file_path.endswith('.xlsx') or file_path.endswith('.xls'):
        df = pd.read_excel(file_path)
    else:
        df = pd.read_csv(file_path)

    print(f"Loaded {len(df)} rows from file.")
    print(f"Columns present: {list(df.columns)}\n")

    # Column name resolution
    c_code_col = next((c for c in df.columns if 'client code' in c.lower()), None)
    c_id_col = next((c for c in df.columns if c.lower() in ['client id', 'id']), None)
    c_name_col = next((c for c in df.columns if 'name' in c.lower()), None)
    l_id_col = next((c for c in df.columns if 'loan id' in c.lower()), None)
    l_prod_col = next((c for c in df.columns if 'product' in c.lower()), None)
    
    act_col = next((c for c in df.columns if 'active' in c.lower() and ('loan' in c.lower() or 'credit' in c.lower())), None)
    bal_col = next((c for c in df.columns if 'outstanding' in c.lower() or ('balance' in c.lower() and 'saving' not in c.lower())), None)
    sav_col = next((c for c in df.columns if 'saving' in c.lower()), None)
    status_col = next((c for c in df.columns if 'status' in c.lower()), None)

    print(f"Column Mappings:")
    print(f"  Client Code:        {c_code_col}")
    print(f"  Client ID:          {c_id_col}")
    print(f"  Loan ID:            {l_id_col}")
    print(f"  Active Loan:        {act_col}")
    print(f"  Outstanding/Bal:    {bal_col}")
    print(f"  Savings Balance:    {sav_col}")
    print()

    client = get_supabase_client()
    uow = SupabaseUnitOfWork()

    # Pre-fetch lookup maps
    all_clients_res = client.table("clients").select("client_id, client_code, name, branch_id, status, status_id").execute()
    clients_by_code = {c["client_code"]: c for c in (all_clients_res.data or []) if c.get("client_code")}
    clients_by_id = {c["client_id"]: c for c in (all_clients_res.data or []) if c.get("client_id")}

    all_loans_res = client.table("loans").select("loan_id, client_id, product_id, active_credit, total_due, loan_repay, status, loan_products(name)").execute()
    loans_by_id = {l["loan_id"]: l for l in (all_loans_res.data or []) if l.get("loan_id")}
    loans_by_client = {}
    for l in (all_loans_res.data or []):
        loans_by_client.setdefault(l["client_id"], []).append(l)

    # Status ID map
    statuses_res = client.table("client_statuses").select("status_id, name").execute()
    status_id_map = {s["name"].lower(): s["status_id"] for s in (statuses_res.data or [])}

    # Batch pre-fetch savings and repayments to make ingestion instant
    print("Pre-fetching savings and loan repayments in batch...")
    target_cids = list(clients_by_id.keys())
    savings_by_client = {}
    if target_cids:
        # Fetch in chunks of 500
        for c_chunk in [target_cids[i:i+500] for i in range(0, len(target_cids), 500)]:
            s_res = client.table("individual_savings").select("id, client_id, deposit_amount, withdrawal_amount, remarks, posting_date").in_("client_id", c_chunk).execute()
            for s in (s_res.data or []):
                savings_by_client.setdefault(s["client_id"], []).append(s)

    all_lids = list(loans_by_id.keys())
    repayments_by_loan = {}
    if all_lids:
        for l_chunk in [all_lids[i:i+500] for i in range(0, len(all_lids), 500)]:
            r_res = client.table("repayments").select("loan_id, amount_paid").in_("loan_id", l_chunk).execute()
            for r in (r_res.data or []):
                repayments_by_loan.setdefault(r["loan_id"], []).append(r)

    # Tracking counters
    savings_updated = 0
    loans_updated = 0
    schedules_realigned = 0
    clients_completed = 0
    skipped_rows = 0

    plan_summary = []

    for idx, row in df.iterrows():
        raw_code = str(row.get(c_code_col) or '').strip()
        raw_cid = str(row.get(c_id_col) or '').strip()
        raw_lid = str(row.get(l_id_col) or '').strip()
        c_name = str(row.get(c_name_col) or '').strip()

        is_asset_row = raw_code.endswith('-ASSET') or 'asset' in str(row.get(l_prod_col) or '').lower()
        clean_code = raw_code.replace('-ASSET', '').strip()

        # Resolve client
        c_obj = None
        if raw_cid and raw_cid in clients_by_id:
            c_obj = clients_by_id[raw_cid]
        elif clean_code and clean_code in clients_by_code:
            c_obj = clients_by_code[clean_code]
        
        if not c_obj:
            skipped_rows += 1
            continue

        cid = c_obj["client_id"]
        c_branch_id = c_obj["branch_id"]

        # Parse target values
        target_act = clean_num(row.get(act_col)) if act_col else None
        target_bal = clean_num(row.get(bal_col)) if bal_col else None
        target_sav = clean_num(row.get(sav_col)) if sav_col else None

        # ----------------------------------------------------
        # 1. SAVINGS BALANCE ALIGNMENT (Attached to primary row only)
        # ----------------------------------------------------
        if not is_asset_row and target_sav is not None:
            # Query client savings entries from in-memory cache
            c_savs = savings_by_client.get(cid, [])
            
            # Separate onboarding baseline from live operations
            onb_rec = None
            live_net = 0.0
            for s in c_savs:
                rem = str(s.get("remarks") or "")
                p_dt = str(s.get("posting_date") or "")
                dep = float(s.get("deposit_amount") or 0.0)
                wd = float(s.get("withdrawal_amount") or 0.0)
                if "onboarding" in rem.lower() or p_dt in ["1970-01-01", "2026-08-31"]:
                    onb_rec = s
                else:
                    live_net += (dep - wd)

            req_baseline = max(0.0, target_sav - live_net)
            curr_sav_bal = sum(float(s.get("deposit_amount") or 0.0) - float(s.get("withdrawal_amount") or 0.0) for s in c_savs)

            if abs(curr_sav_bal - target_sav) > 0.01:
                savings_updated += 1
                plan_summary.append({
                    "Client Code": clean_code,
                    "Client Name": c_obj["name"],
                    "Action": "SAVINGS_ALIGNMENT",
                    "Current": curr_sav_bal,
                    "Target": target_sav,
                    "Required Baseline": req_baseline
                })
                if not dry_run:
                    if onb_rec:
                        client.table("individual_savings").update({
                            "deposit_amount": req_baseline,
                            "withdrawal_amount": 0.0
                        }).eq("id", onb_rec["id"]).execute()
                    else:
                        new_onb = {
                            "id": str(uuid.uuid4()),
                            "client_id": cid,
                            "branch_id": c_branch_id,
                            "posting_date": "1970-01-01",
                            "deposit_amount": req_baseline,
                            "withdrawal_amount": 0.0,
                            "remarks": "Initial Onboarding Savings",
                            "currency_code": "NGN",
                            "version": 1
                        }
                        client.table("individual_savings").insert(new_onb).execute()

        # ----------------------------------------------------
        # 2. LOAN & SCHEDULE ALIGNMENT
        # ----------------------------------------------------
        # Resolve target loan
        target_loan = None
        if raw_lid and raw_lid in loans_by_id:
            target_loan = loans_by_id[raw_lid]
        else:
            client_loans = loans_by_client.get(cid, [])
            active_client_loans = [l for l in client_loans if str(l.get("status")).upper() in ["ACTIVE", "APPROVED"]]
            if active_client_loans:
                if is_asset_row:
                    asset_loans = [l for l in active_client_loans if "asset" in str((l.get("loan_products") or {}).get("name") or "").lower()]
                    target_loan = asset_loans[0] if asset_loans else active_client_loans[0]
                else:
                    fin_loans = [l for l in active_client_loans if "asset" not in str((l.get("loan_products") or {}).get("name") or "").lower()]
                    target_loan = fin_loans[0] if fin_loans else active_client_loans[0]

        if target_loan and (target_act is not None or target_bal is not None):
            lid = target_loan["loan_id"]
            curr_act = float(target_loan.get("active_credit") or 0.0)
            curr_due = float(target_loan.get("total_due") if target_loan.get("total_due") is not None else curr_act)
            
            # Fetch lifetime repayments for this loan from in-memory cache
            reps_q = repayments_by_loan.get(lid, [])
            tot_repaid = sum(float(r.get("amount_paid") or 0.0) for r in reps_q)
            curr_out_bal = max(0.0, curr_due - tot_repaid)

            new_act = target_act if (target_act is not None and target_act > 0) else curr_act
            new_bal = target_bal if target_bal is not None else curr_out_bal
            new_due = new_bal + tot_repaid

            needs_loan_update = (abs(curr_act - new_act) > 0.01 or abs(curr_out_bal - new_bal) > 0.01)

            if needs_loan_update:
                loans_updated += 1
                plan_summary.append({
                    "Client Code": raw_code,
                    "Client Name": c_obj["name"],
                    "Action": "LOAN_BALANCE_ALIGNMENT",
                    "Loan ID": lid,
                    "Current ActCredit": curr_act,
                    "Target ActCredit": new_act,
                    "Current Balance": curr_out_bal,
                    "Target Balance": new_bal
                })

                if not dry_run:
                    loan_update = {
                        "active_credit": new_act,
                        "total_due": new_due
                    }
                    if new_bal <= 0.0:
                        loan_update["status"] = "Completed"
                    client.table("loans").update(loan_update).eq("loan_id", lid).execute()

                    # Rebalance loan_schedule unpaid installments
                    sched_rows = client.table("loan_schedule").select("*").eq("loan_id", lid).order("installment_number").execute().data or []
                    if sched_rows:
                        unpaid_sched = [s for s in sched_rows if float(s.get("paid_amount") or 0.0) < float(s.get("total_due") or 0.0)]
                        if unpaid_sched:
                            schedules_realigned += 1
                            if new_bal <= 0.0:
                                for s in unpaid_sched:
                                    client.table("loan_schedule").update({
                                        "paid_amount": s["total_due"],
                                        "status": "Paid"
                                    }).eq("id", s["id"]).execute()
                            else:
                                per_cycle = round(new_bal / len(unpaid_sched), 2)
                                remainder = round(new_bal - (per_cycle * len(unpaid_sched)), 2)
                                for s_idx, s in enumerate(unpaid_sched):
                                    adj_due = per_cycle + (remainder if s_idx == len(unpaid_sched) - 1 else 0.0)
                                    client.table("loan_schedule").update({
                                        "total_due": adj_due,
                                        "paid_amount": 0.0,
                                        "status": "Pending"
                                    }).eq("id", s["id"]).execute()

                    # Handle Client Status completion
                    if new_bal <= 0.0:
                        # Check other active loans
                        remaining_active = [
                            l for l in loans_by_client.get(cid, [])
                            if l["loan_id"] != lid and str(l.get("status")).upper() in ["ACTIVE", "APPROVED"]
                        ]
                        if not remaining_active:
                            clients_completed += 1
                            c_stat = "Completed"
                            stat_id = status_id_map.get("completed", "11111111-1111-1111-1111-111111110003")
                            client.table("clients").update({
                                "status": c_stat,
                                "status_id": stat_id,
                                "status_changed_at": datetime.now().isoformat()
                            }).eq("client_id", cid).execute()

    print("==================================================")
    print(" ALIGNMENT EXECUTION SUMMARY")
    print("==================================================")
    print(f" Savings Balances Aligned:   {savings_updated}")
    print(f" Loans Aligned:              {loans_updated}")
    print(f" Loan Schedules Realigned:   {schedules_realigned}")
    print(f" Clients Completed:          {clients_completed}")
    print(f" Skipped / Unmatched Rows:   {skipped_rows}")
    print("==================================================\n")

    if plan_summary:
        print("Sample Modifications (First 10):")
        for item in plan_summary[:10]:
            print(f"  - {item}")
        print()

    if dry_run:
        print(">> DRY RUN COMPLETE. No changes were applied to the database.")
        print(">> To write changes to the database, run with '--apply'.")
    else:
        print(">> LIVE APPLY COMPLETE. All changes successfully committed to database.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest and align portfolio balances from paper CSV/Excel")
    parser.add_argument("file", help="Path to portfolio CSV or Excel file")
    parser.add_argument("--apply", action="store_true", help="Apply changes to database (default is dry-run)")
    args = parser.parse_args()

    align_portfolio(args.file, dry_run=not args.apply)
