import toml
from supabase import create_client

def patch_db_loans():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    res_l = client.table("loans").select("loan_id, loan_amount, active_credit, loan_repay").execute()
    loans = res_l.data or []
    patched = 0
    for l in loans:
        lid = l["loan_id"]
        res_s = client.table("loan_schedule").select("total_due").eq("loan_id", lid).order("installment_number").limit(1).execute()
        if res_s.data:
            inst = float(res_s.data[0]["total_due"] or 0)
            if inst > 0:
                client.table("loans").update({"loan_repay": inst}).eq("loan_id", lid).execute()
                print(f"Patched Loan {lid[:8]}: loan_repay = {inst}")
                patched += 1
    print(f"Successfully patched {patched} loans with active repayment amounts.")

if __name__ == "__main__":
    patch_db_loans()
