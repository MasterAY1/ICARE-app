import tomllib
import math
from supabase import create_client, Client

print("Running database repair for loan products and repayments...")

try:
    with open(".streamlit/secrets.toml", "rb") as f:
        secrets = tomllib.load(f)
    url = secrets.get("SUPABASE_URL")
    key = secrets.get("SUPABASE_KEY")
except Exception as e:
    print(f"Could not load secrets.toml: {e}")
    exit()

supabase: Client = create_client(url, key)

response = supabase.table("loans").select("client_id, loan_product, meeting_day, active_credit, loan_repay").execute()
loans = response.data

updated_count = 0

for loan in loans:
    client_id = loan['client_id']
    old_product = str(loan.get('loan_product', '')).strip()
    meeting_day = str(loan.get('meeting_day', '')).strip()
    active_credit = float(loan.get('active_credit') or 0)
    
    updates = {}
    
    # Fix Product Category vs Loan Product mismatch
    if old_product in ["Finance", "Assets", "Assets "]:
        updates["product_category"] = "Asset" if "Asset" in old_product else "Finance"
        
        # Infer true loan product from meeting day
        if meeting_day == "Daily" or meeting_day == "N/A" or not meeting_day:
            updates["loan_product"] = "Daily Loan (60 Days)"
        else:
            # If it's a weekday
            updates["loan_product"] = "Weekly Loan (24 Weeks)" # Default fallback
    else:
        # It's already fixed or another type, we just leave it alone
        updates["loan_product"] = old_product
        
    # Calculate fixed repayment
    true_product = updates.get("loan_product", old_product)
    
    duration = 0
    if "Daily" in true_product:
        duration = 60
    elif "12 Weeks" in true_product:
        duration = 12
    elif "24 Weeks" in true_product:
        duration = 24
        
    if duration > 0 and active_credit > 0:
        raw_repay = active_credit / duration
        final_repay = math.ceil(raw_repay / 10) * 10
        updates["loan_repay"] = final_repay
        
    if updates:
        supabase.table("loans").update(updates).eq("client_id", client_id).execute()
        updated_count += 1
        print(f"Repaired {client_id} -> {updates}")

print(f"Done! Repaired {updated_count} accounts.")
