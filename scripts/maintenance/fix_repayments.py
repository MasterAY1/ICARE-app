import tomllib
import math
from supabase import create_client, Client

print("Running database backfill for missing loan_repay...")

try:
    with open(".streamlit/secrets.toml", "rb") as f:
        secrets = tomllib.load(f)
    url = secrets.get("SUPABASE_URL")
    key = secrets.get("SUPABASE_KEY")
except Exception as e:
    print(f"Could not load secrets.toml: {e}")
    exit()

supabase: Client = create_client(url, key)

response = supabase.table("loans").select("client_id, loan_product, active_credit, loan_repay").execute()
loans = response.data

updated_count = 0

for loan in loans:
    current_repay = float(loan.get('loan_repay') or 0)
    
    # We only overwrite if it's 0 or None
    if current_repay <= 0:
        product = str(loan.get('loan_product', ''))
        active_credit = float(loan.get('active_credit') or 0)
        
        duration = 0
        if "Daily" in product:
            duration = 60
        elif "12 Weeks" in product:
            duration = 12
        elif "24 Weeks" in product:
            duration = 24
            
        if duration > 0 and active_credit > 0:
            raw_repay = active_credit / duration
            final_repay = math.ceil(raw_repay / 10) * 10
            
            # Update the database
            supabase.table("loans").update({"loan_repay": final_repay}).eq("client_id", loan['client_id']).execute()
            updated_count += 1
            print(f"Updated {loan['client_id']} -> Repayment: {final_repay}")

print(f"Done! Backfilled loan_repay for {updated_count} accounts.")
