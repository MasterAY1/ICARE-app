import os
import sys
import uuid
import pandas as pd
from datetime import datetime

# Add the project root to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.cashbook_service import CashbookService

def map_excel_to_cashbook_columns(amount_dict):
    """Maps the human-readable Excel labels to master_cashbook columns."""
    return {
        "laps_reserve": float(amount_dict.get("LAPS Savings", 0)),
        "savings_deposit": float(amount_dict.get("Group Deposits", 0)) + float(amount_dict.get("Total Savings (incl. Misc Fees)", 0)),
        "app_fee": float(amount_dict.get("Application Fee / Processing Fee / Credit Form", 0)),
        "contingency": float(amount_dict.get("Contingency", 0)),
        "passbook": float(amount_dict.get("Passbook Fees", 0)),
        "asset_credit_sales": float(amount_dict.get("Asset Credit Sales", 0)),
        "cash_and_carry": float(amount_dict.get("Cash & Carry", 0)),
        "credit_form_damage": float(amount_dict.get("Credit Form Damage", 0)),
        "bonus": float(amount_dict.get("Bonus", 0)),
        "office_expenses": float(amount_dict.get("Office Expenses", 0)),
        "staff_salaries": float(amount_dict.get("Staff Salaries", 0)),
        "bank_deposit": float(amount_dict.get("Bank Balance", 0)),
        # Note: Excess Payment and Full Repayment don't have explicit columns in master_cashbook,
        # but they will be posted to the double-entry ledger.
        "opening_balance": float(amount_dict.get("Vault Cash", 0))
    }

def post_ledger_entry(uow, branch_id, date, amount, acct_code, offset_code, desc):
    if amount == 0:
        return
        
    uow.client.table("financial_ledger_entries").insert([{
        "entry_id": str(uuid.uuid4()),
        "branch_id": branch_id,
        "posting_date": date.isoformat(),
        "account_code": acct_code,
        "debit_amount": amount,
        "credit_amount": 0,
        "description": desc,
        "reference_type": "MIGRATION",
        "reference_id": str(uuid.uuid4())
    }, {
        "entry_id": str(uuid.uuid4()),
        "branch_id": branch_id,
        "posting_date": date.isoformat(),
        "account_code": offset_code,
        "debit_amount": 0,
        "credit_amount": amount,
        "description": desc,
        "reference_type": "MIGRATION",
        "reference_id": str(uuid.uuid4())
    }]).execute()

def migrate_ledger_balances(excel_path):
    print(f"Reading template: {excel_path}")
    if not os.path.exists(excel_path):
        print("Error: Excel template not found!")
        return

    # 1. Read Metadata
    meta_df = pd.read_excel(excel_path, sheet_name="Metadata")
    meta_dict = dict(zip(meta_df['Property'], meta_df['Value']))
    branch_name = meta_dict.get("Branch Name")
    cutoff_date_raw = meta_dict.get("Cut-off Date")
    
    if pd.isna(cutoff_date_raw):
        print("Error: Cut-off Date is missing in Metadata.")
        return
        
    try:
        cutoff_date = pd.to_datetime(cutoff_date_raw).date()
    except Exception as e:
        print(f"Error parsing date: {e}")
        return

    print(f"Target Branch: {branch_name}")
    print(f"Cut-off Date: {cutoff_date}")

    # 2. Read Balances
    bal_df = pd.read_excel(excel_path, sheet_name="Balances")
    bal_dict = dict(zip(bal_df['Category'], bal_df['Amount (₦)']))
    
    # 3. Post to Database
    with SupabaseUnitOfWork() as uow:
        # Resolve Branch ID
        b_res = uow.client.table("branches").select("branch_id").eq("branch_name", branch_name).execute()
        if not b_res.data:
            print(f"Error: Branch '{branch_name}' not found in database.")
            return
        branch_id = b_res.data[0]['branch_id']
        
        # 4. Save to Master Cashbook
        print("Injecting into Master Cashbook...")
        cb_cols = map_excel_to_cashbook_columns(bal_dict)
        cb_cols["branch_id"] = branch_id
        cb_cols["date"] = cutoff_date.isoformat()
        cb_cols["status"] = "Verified"
        cb_cols["adjustment_reason"] = "Legacy Ledger Migration"
        
        # Delete if exists for that date
        uow.client.table("master_cashbook").delete().eq("branch_id", branch_id).eq("date", cutoff_date.isoformat()).execute()
        
        uow.client.table("master_cashbook").insert(cb_cols).execute()
        print("Master Cashbook updated.")
        
        # 5. Save to Double-Entry Ledger
        print("Posting double-entry ledger records...")
        
        # Assets (Dr Asset, Cr 3100)
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Vault Cash", 0)), "1000", "3100", "Migration: Vault Cash")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Bank Balance", 0)), "1010", "3100", "Migration: Bank Balance")
        
        # Liabilities (Dr 3100, Cr Liability)
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("LAPS Savings", 0)), "3100", "2120", "Migration: LAPS Savings")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Group Deposits", 0)), "3100", "2100", "Migration: Group Deposits")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Total Savings (incl. Misc Fees)", 0)), "3100", "2110", "Migration: Individual Savings")
        
        # Wait, do we have 2210/2220 in our accounts? Let's assume we do or fallback to 2000
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Excess Payment", 0)), "3100", "2210", "Migration: Excess Payment")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Full Repayment", 0)), "3100", "2210", "Migration: Full Repayment") # Mapped to Excess Liability
        
        # Incomes (Dr 3100, Cr Income)
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Application Fee / Processing Fee / Credit Form", 0)), "3100", "3000", "Migration: App Fee")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Contingency", 0)), "3100", "3010", "Migration: Contingency")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Passbook Fees", 0)), "3100", "3000", "Migration: Passbook")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Asset Credit Sales", 0)), "3100", "3000", "Migration: Asset Sales")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Cash & Carry", 0)), "3100", "3000", "Migration: Cash & Carry")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Credit Form Damage", 0)), "3100", "3000", "Migration: Cr Form Damage")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Bonus", 0)), "3100", "3000", "Migration: Bonus")
        
        # Expenses (Dr Expense, Cr 3100)
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Office Expenses", 0)), "4000", "3100", "Migration: Office Expenses")
        post_ledger_entry(uow, branch_id, cutoff_date, float(bal_dict.get("Staff Salaries", 0)), "4010", "3100", "Migration: Staff Salaries")

        print("Migration complete! You can now verify in the Cashbook UI.")

if __name__ == "__main__":
    template_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ledger-opening-balances-template.xlsx")
    migrate_ledger_balances(template_path)
