import toml
import json
from supabase import create_client

def check_10_loans():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    res_l = client.table("loans").select("loan_id, client_id, loan_amount, active_credit, loan_repay, total_due, status, branch_id, officer_id, extra_fields, loan_products(name, repayment_cycle), clients(name, client_code)").execute()
    loans = res_l.data or []
    print(f"=== 10 LOANS DETAILS ===")
    for l in loans:
        c = l.get("clients") or {}
        lp = l.get("loan_products") or {}
        print(f"Client: {c.get('name')} ({c.get('client_code')}) | LoanID: {l.get('loan_id')[:8]} | Prod: {lp.get('name')} | Cycle: {lp.get('repayment_cycle')} | Amt: {l.get('loan_amount')} | ActiveCr: {l.get('active_credit')} | loan_repay: {l.get('loan_repay')} | Status: {l.get('status')}")

if __name__ == "__main__":
    check_10_loans()
