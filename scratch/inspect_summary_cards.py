import toml
import json
from datetime import date
from supabase import create_client

def inspect_summary_cards():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    # 1. Check all loans
    res_l = client.table("loans").select("*, loan_products(name, repayment_cycle), clients(name, client_code)").execute()
    loans = res_l.data or []
    print(f"=== LOANS ({len(loans)}) ===")
    for l in loans:
        print(f"Loan ID: {l.get('loan_id')} | Client: {l.get('clients', {}).get('name')} | Prod: {l.get('loan_products', {}).get('name')} | Principal: {l.get('loan_amount')} | Active: {l.get('active_credit')} | loan_repay: {l.get('loan_repay')} | extra_fields: {json.dumps(l.get('extra_fields'))}")

    # 2. Check schedules for these loans
    res_s = client.table("loan_schedule").select("loan_id, installment_number, due_date, total_due, paid_amount, status").order("due_date").execute()
    scheds = res_s.data or []
    print(f"\n=== SCHEDULES ({len(scheds)}) ===")
    due_dates = set(s.get("due_date") for s in scheds)
    print(f"Schedule due dates: {sorted(list(due_dates))}")
    for d in sorted(list(due_dates)):
        due_scheds = [s for s in scheds if s.get("due_date") == d]
        total_due = sum(float(s.get("total_due") or 0) for s in due_scheds)
        total_paid = sum(float(s.get("paid_amount") or 0) for s in due_scheds)
        print(f"  Date: {d} | Count: {len(due_scheds)} | Total Due: {total_due} | Total Paid: {total_paid}")

    # 3. Check group meeting days
    res_grp = client.table("groups").select("*").execute()
    print(f"\n=== GROUPS ({len(res_grp.data or [])}) ===")
    for g in (res_grp.data or []):
        print(f"Group: {g.get('name')} | Meeting Day: {g.get('meeting_day')}")

    # 4. Check client memberships
    res_mem = client.table("client_memberships").select("client_id, group_id, groups(name, meeting_day)").execute()
    print(f"\n=== CLIENT MEMBERSHIPS ({len(res_mem.data or [])}) ===")
    for m in (res_mem.data or []):
        print(f"Client: {m.get('client_id')} | Group: {m.get('groups', {}).get('name')} | Meeting Day: {m.get('groups', {}).get('meeting_day')}")

if __name__ == "__main__":
    inspect_summary_cards()
