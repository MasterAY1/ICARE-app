import toml
from supabase import create_client

def inspect_sched_per_loan():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    res_l = client.table("loans").select("loan_id, loan_amount, active_credit, loan_repay, extra_fields, loan_products(name, repayment_cycle)").execute()
    loans = res_l.data or []
    
    print("=== LOAN SCHEDULE INSTALLMENT CHECK ===")
    for l in loans:
        lid = l["loan_id"]
        res_s = client.table("loan_schedule").select("installment_number, total_due, due_date").eq("loan_id", lid).order("installment_number").limit(2).execute()
        s_data = res_s.data or []
        first_inst_amt = s_data[0]["total_due"] if s_data else 0.0
        first_inst_due = s_data[0]["due_date"] if s_data else "None"
        print(f"Loan: {lid[:8]} | Product: {l.get('loan_products', {}).get('name')} | loan_repay in DB: {l.get('loan_repay')} | Schedule Inst 1: {first_inst_amt} (Due: {first_inst_due})")

if __name__ == "__main__":
    inspect_sched_per_loan()
