import pandas as pd
from supabase import create_client, Client
import uuid
import os
from dotenv import load_dotenv

# Load your database credentials
load_dotenv()
url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(url, key)

print("🚀 Starting Smart Bulk Upload directly from clients.xlsx...")

# 1. Read the Excel file directly
try:
    df = pd.read_excel("clients.xlsx", sheet_name="clients")
except Exception as e:
    print(f"❌ Error reading Excel file: {e}")
    exit()

success_count = 0

# 2. Clean the data
df['status'] = df['status'].astype(str).str.strip().replace('nan', 'Internal Account')
df['loan_product'] = df['loan_product'].astype(str).str.strip().replace('nan', 'N/A')
df['client_name'] = df['client_name'].fillna('Unnamed Account')

df.fillna({
    'loan_amount': 0, 
    'active_credit': 0, 
    'loan_balance': 0, 
    'total_savings': 0,
    'group_name': '',
    'business_type': 'Other',
    'phone': '',
    'address': '',
    'date': '2026-05-01',
    'meeting_day': 'Daily',
    'branch': 'Main',
    'officer': 'Admin',
    'product_category': 'Finance',
    'group_savings': 0,
    'branch_contingency': 0,
    'branch_contingency_2': 0
}, inplace=True)

# 3. Loop through every client row
for index, row in df.iterrows():
    try:
        client_id = str(uuid.uuid4())
        
        loan_amount = float(row['loan_amount'])
        active_credit = float(row['active_credit'])
        loan_balance = float(row['loan_balance'])
        
        # Calculate historical balances
        if loan_amount > 0:
            upfront_payment = loan_amount - active_credit
            installments_paid = active_credit - loan_balance
        else:
            upfront_payment = 0
            installments_paid = 0
            
        # --- A. Insert the Client Profile ---
        client_data = {
            "client_id": client_id,
            "date": str(row['date'])[:10],
            "branch": row['branch'],
            "officer": row['officer'],
            "client_name": row['client_name'],
            "phone": str(row['phone']),
            "address": row['address'],
            "business_type": row['business_type'],
            "group_name": row['group_name'],
            "meeting_day": row['meeting_day'],
            "loan_product": row['loan_product'],
            "product_category": row.get('product_category', 'Finance'),
            "loan_amount": loan_amount,
            "active_credit": active_credit,
            "total_due": active_credit,
            "status": row['status']
        }
        supabase.table("loans").insert(client_data).execute()
        
        # --- B. Log the Upfront Payment ---
        if upfront_payment > 0:
            upfront_data = {
                "client_id": client_id,
                "client_name": row['client_name'],
                "date": str(row['date'])[:10] + " 08:00:00",
                "amount_paid": upfront_payment,
                "transaction_type": "Loan",
                "officer": "Admin Migration",
                "note": "Historical Initial Upfront Payment.",
                "branch": row['branch']
            }
            supabase.table("repayments").insert(upfront_data).execute()

        # --- C. Log the Historical Installments ---
        if installments_paid > 0:
            installment_data = {
                "client_id": client_id,
                "client_name": row['client_name'],
                "date": str(row['date'])[:10] + " 12:00:00",
                "amount_paid": installments_paid,
                "transaction_type": "Loan",
                "officer": "Admin Migration",
                "note": "Historical accumulated installments.",
                "branch": row['branch'],
                "loan_repayment_amount": installments_paid
            }
            supabase.table("repayments").insert(installment_data).execute()
            
        # --- D. Log the Historical Savings ---
        savings = float(row['total_savings'])
        if savings > 0:
            savings_data = {
                "client_id": client_id,
                "client_name": row['client_name'],
                "date": str(row['date'])[:10] + " 16:00:00",
                "amount_paid": savings,
                "transaction_type": "Savings",
                "officer": "Admin Migration",
                "note": "Historical savings balance migrated.",
                "branch": row['branch'],
                "savings_amount": savings
            }
            supabase.table("repayments").insert(savings_data).execute()
            
        print(f"✅ Successfully uploaded: {row['client_name']} ({row['status']})")
        success_count += 1
        
    except Exception as e:
        print(f"❌ Failed to upload {row['client_name']}: {e}")

print(f"\n🎉 Upload Complete! Successfully migrated {success_count} accounts.")
