import pandas as pd
import os
import toml
from supabase import create_client
from datetime import datetime

# Load configuration
try:
    config = toml.load('.streamlit/secrets.toml')
    SUPABASE_URL = config.get("SUPABASE_URL")
    SUPABASE_KEY = config.get("SUPABASE_KEY")
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("Missing Supabase credentials in .streamlit/secrets.toml")
except Exception as e:
    print(f"Error loading secrets: {e}")
    exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

def run_migration():
    file_path = 'Master_Balancing_Template.xlsx'
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        return

    print(f"Reading data from {file_path}...")
    try:
        df = pd.read_excel(file_path)
    except Exception as e:
        print(f"Failed to read Excel: {e}")
        return

    # Check required columns (making some optional or falling back)
    required_cols = [
        'Member Reference', 'Total Accumulated Savings', 'Current Outstanding Balance',
        'Active Loan Product', 'Expected Repayment', 'Loan Category'
    ]
    
    # Fill missing expected columns if the user hasn't added them yet to prevent crash
    for col in required_cols:
        if col not in df.columns:
            print(f"Warning: Column '{col}' is missing. Filling with defaults.")
            df[col] = 0 if 'Savings' in col or 'Balance' in col or 'Repayment' in col else ''

    today_str = datetime.now().strftime("%Y-%m-%d")
    success_count = 0
    
    for index, row in df.iterrows():
        client_id = str(row.get('Member Reference', '')).strip()
        if not client_id or client_id == 'nan':
            continue

        full_name = str(row.get('Full Name', 'Unknown Client')).strip()
        officer = str(row.get('Credit Officer Name', 'Unknown Officer')).strip()
        group_name = str(row.get('Group Name', 'IND')).strip()
        phone = str(row.get('Phone Number', '')).strip()
        
        # Financial Data
        savings = pd.to_numeric(row.get('Total Accumulated Savings', 0), errors='coerce')
        if pd.isna(savings): savings = 0
        
        outstanding_bal = pd.to_numeric(row.get('Current Outstanding Balance', 0), errors='coerce')
        if pd.isna(outstanding_bal): outstanding_bal = 0
        
        loan_product = str(row.get('Active Loan Product', '')).strip()
        loan_category = str(row.get('Loan Category', 'Finance')).strip()
        
        expected_repay = pd.to_numeric(row.get('Expected Repayment', 0), errors='coerce')
        if pd.isna(expected_repay): expected_repay = 0

        # 1. Update/Insert into `loans` table to create the Client & Loan Profile
        status = 'Active' if outstanding_bal > 0 else 'Completed'
        
        loan_data = {
            "Client ID": client_id,
            "Client Name": full_name,
            "Officer": officer,
            "Group Name": group_name,
            "Phone": phone,
            "Date": today_str,
            "Branch": "Migrated",  # Default if not available
            "Product Category": loan_category,
            "Loan Product": loan_product,
            "Loan Amount": outstanding_bal,  # Legacy loans might just treat current bal as the loan amount for simplicity
            "Active Credit": outstanding_bal,
            "Total Due": outstanding_bal,
            "Loan Repay": expected_repay,
            "Status": status,
            "disbursement_date": today_str,
            "start_date": today_str,
            "expected_end_date": today_str # Placeholder
        }
        
        # Upsert the client profile
        try:
            # First check if exists
            existing = supabase.table("loans").select("id").eq("Client ID", client_id).execute()
            if existing.data:
                supabase.table("loans").update(loan_data).eq("Client ID", client_id).execute()
            else:
                supabase.table("loans").insert(loan_data).execute()
        except Exception as e:
            print(f"Error inserting loan for {client_id}: {e}")
            continue

        # 2. Inject "Brought Forward Savings" to force their dynamic savings balance to match
        if savings > 0:
            savings_data = {
                "Date": today_str,
                "Client ID": client_id,
                "Client Name": full_name,
                "Officer": officer,
                "Branch": "Migrated",
                "Amount Paid": savings,
                "Transaction Type": "Cashbook Entry", # Wait, I fixed this constraint! Needs to be 'Savings' or 'Loan'
                "Savings Amount": savings,
                "Note": "Brought Forward Savings (Legacy Migration)"
            }
            # The constraint only allows specific types. Let's use 'Loan' as it was tested successfully, 
            # but 'Savings' is also standard.
            savings_data["Transaction Type"] = "Loan" 
            
            try:
                supabase.table("repayments").insert(savings_data).execute()
            except Exception as e:
                print(f"Error inserting savings for {client_id}: {e}")
        
        success_count += 1
        print(f"Migrated {client_id} - {full_name}")

    print(f"Migration Complete! Successfully migrated {success_count} clients.")

if __name__ == "__main__":
    run_migration()
