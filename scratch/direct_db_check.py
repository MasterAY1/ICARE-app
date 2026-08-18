import os
import sys
import toml
from supabase import create_client

def main():
    secrets = toml.load(".streamlit/secrets.toml")
    url = secrets.get("SUPABASE_URL")
    key = secrets.get("SUPABASE_KEY")
    client = create_client(url, key)

    print("Connected to Supabase successfully!")
    
    # Check repayments table
    res_reps = client.table("repayments").select("*").order("created_at", desc=True).limit(20).execute()
    reps = res_reps.data or []
    print(f"\n--- Recent Repayments ({len(reps)}) ---")
    for r in reps:
        print(f"Date: {r.get('date')} | Amount: {r.get('amount_paid')} | Savings: {r.get('savings_amount')} | Client: {r.get('client_id')} | Loan: {r.get('loan_id')} | Note: {r.get('note')} | Type: {r.get('transaction_type')}")

    # Check individual savings table
    res_sav = client.table("individual_savings").select("*").order("created_at", desc=True).limit(20).execute()
    sav = res_sav.data or []
    print(f"\n--- Recent Individual Savings ({len(sav)}) ---")
    for s in sav:
        print(f"Date: {s.get('posting_date')} | Deposit: {s.get('deposit_amount')} | Withdrawal: {s.get('withdrawal_amount')} | Client: {s.get('client_id')} | Remarks: {s.get('remarks')}")

    # Check group savings table
    res_grp = client.table("group_savings").select("*").order("created_at", desc=True).limit(20).execute()
    grp = res_grp.data or []
    print(f"\n--- Recent Group Savings ({len(grp)}) ---")
    for g in grp:
        print(f"Date: {g.get('posting_date')} | Deposit: {g.get('deposit_amount')} | Withdrawal: {g.get('withdrawal_amount')} | Group: {g.get('group_id')} | Remarks: {g.get('remarks')}")

    # Check co_cashbooks table
    res_cb = client.table("co_cashbooks").select("*").order("date", desc=True).limit(10).execute()
    cbs = res_cb.data or []
    print(f"\n--- Recent CO Cashbooks ({len(cbs)}) ---")
    for c in cbs:
        print(f"Date: {c.get('date')} | Officer: {c.get('officer_id')} | Inflows: {c.get('total_inflows')} | Outflows: {c.get('total_outflows')} | Close: {c.get('closing_balance')} | Rep12W: {c.get('rep_12_weeks')} | Rep24W: {c.get('rep_24_weeks')} | RepDaily: {c.get('rep_daily')} | SavDep: {c.get('savings_deposit')}")

if __name__ == "__main__":
    main()
