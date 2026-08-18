import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
import traceback

def test_eod_save():
    with SupabaseUnitOfWork() as uow:
        # Check tables schema for client_id column types
        target_co = "CO2"
        BRANCH = "Ogijo"
        date_str = "2026-08-16"
        
        g_out = {
            "Date": date_str, "Client ID": f"GLOBAL-{target_co}", "Client Name": f"{target_co} End of Day",
            "Officer": target_co, "Branch": BRANCH,
            "Amount Paid": 1000.0,
            "Transaction Type": "End of Day", "Note": "Branch/Officer Global Inputs",
            "Opening Balance": 0, "Savings Amount": 0, "Withdrawal Amount": 0, "Laps Reserved": 0,
            "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
            "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0,
            "Bank Withdrawal": 0, "Asset Sales": 0, "App Fee": 1000.0, "Pass Book Bonus": 0,
            "Misc Fees": 0, "Asset Credit Sales": 0, "Cash and Carry": 0, "Credit Form": 0, "Credit Form Damage": 0, "Bonus": 0,
            "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
            "Product Withdrawal": 0, "Expenses": 500.0, "Bank Deposited": 2000.0, "Laps Transferred": 0,
            "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
        }
        
        # Test which step throws the error in save_repayment
        from app import save_repayment
        try:
            save_repayment(g_out, override_uow=uow)
            print("save_repayment succeeded!")
        except Exception as e:
            print("save_repayment failed with exception:")
            traceback.print_exc()

if __name__ == "__main__":
    test_eod_save()
