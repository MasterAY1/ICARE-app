import toml
from supabase import create_client

def check_more():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    # Loans
    res_l = client.table("loans").select("loan_id, client_id, loan_amount, active_credit, total_due, loan_repay, status").execute()
    loans = res_l.data or []
    print(f"--- Loans ({len(loans)}) ---")
    for l in loans:
        print(f"Loan: {l.get('loan_id')} | Client: {l.get('client_id')} | Principal: {l.get('loan_amount')} | Active: {l.get('active_credit')} | Repay: {l.get('loan_repay')} | Status: {l.get('status')}")

    # Schedules
    res_s = client.table("loan_schedule").select("id, loan_id, installment_number, due_date, total_due, paid_amount, status").order("due_date").limit(15).execute()
    scheds = res_s.data or []
    print(f"\n--- Schedules ({len(scheds)}) ---")
    for s in scheds:
        print(f"Sched: {s.get('id')} | Loan: {s.get('loan_id')} | Inst: {s.get('installment_number')} | Due: {s.get('due_date')} | DueAmt: {s.get('total_due')} | Paid: {s.get('paid_amount')} | Status: {s.get('status')}")

    # Ledger entries
    res_led = client.table("financial_ledger_entries").select("*").order("created_at", desc=True).limit(15).execute()
    leds = res_led.data or []
    print(f"\n--- Ledger Entries ({len(leds)}) ---")
    for le in leds:
        print(f"Ledger: {le.get('entry_id')} | Acct: {le.get('account_code')} | Side: {le.get('side')} | Amt: {le.get('amount')} | Date: {le.get('created_at')}")

if __name__ == "__main__":
    check_more()
