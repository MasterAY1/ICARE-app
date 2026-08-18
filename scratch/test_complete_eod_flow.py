import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from datetime import date

def test_full_eod():
    with SupabaseUnitOfWork() as uow:
        target_co = "CO2"
        BRANCH = "Ogijo"
        date_str = date.today().isoformat()
        
        g_out = {
            "Date": date_str, "Client ID": f"GLOBAL-{target_co}", "Client Name": f"{target_co} End of Day",
            "Officer": target_co, "Branch": BRANCH,
            "Amount Paid": sum([1500, 500, 1000, 200, 3000, 500, 1000]),
            "Transaction Type": "End of Day", "Note": "Branch/Officer Global Inputs Test",
            "Opening Balance": 5000, "Savings Amount": 0, "Withdrawal Amount": 0, "Laps Reserved": 0,
            "Loan Repayment Amount": 0, "Repayment 12 Weeks": 0, "Repayment 24 Weeks": 0,
            "Repayment 60 Days": 0, "Repayment 120 Days": 0, "Monthly": 0,
            "Bank Withdrawal": 0, "Asset Sales": 0, "App Fee": 1500.0, "Pass Book Bonus": 500.0,
            "Misc Fees": 1000.0, "Asset Credit Sales": 0, "Cash and Carry": 3000.0, "Credit Form": 200.0, "Credit Form Damage": 500.0, "Bonus": 1000.0,
            "Contingency": 0, "Daily 11%": 0, "Daily 20%": 0, "Weekly 11%": 0, "Weekly 20%": 0, "Monthly 11%/20%": 0,
            "Product Withdrawal": 0, "Expenses": 1200.0, "Bank Deposited": 8000.0, "Laps Transferred": 0,
            "Group Savings Deposit": 0, "Group Savings Withdrawal": 0
        }
        
        print("1. Submitting End of Day via save_repayment...")
        from app import save_repayment
        save_repayment(g_out, override_uow=uow)
        print("save_repayment succeeded without any UUID error!")
        
        print("\n2. Rebuilding CO Cashbook projection...")
        branch_id = uow.cashbook._resolve_branch_id(BRANCH)
        res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
        officer_id = res_u.data[0]["id"] if res_u.data else None
        
        uow.cashbook.rebuild_projection(branch_id, date.today(), officer_id=officer_id)
        
        print("\n3. Querying rebuilt CO Cashbook projection...")
        res_co = uow.client.table("co_cashbooks").select("*").eq("date", date_str).eq("branch_id", branch_id).eq("officer_id", officer_id).execute()
        if res_co.data:
            c = res_co.data[0]
            print(f"App Fee:            NGN {c.get('app_fee')}")
            print(f"Pass Book:          NGN {c.get('passbook')}")
            print(f"Bonus:              NGN {c.get('bonus')}")
            print(f"Credit Form:        NGN {c.get('credit_form')}")
            print(f"Credit Form Damage: NGN {c.get('credit_form_damage')}")
            print(f"Cash & Carry:       NGN {c.get('cash_and_carry')}")
            print(f"Office Expenses:    NGN {c.get('office_expenses')}")
            print(f"Bank Deposit:       NGN {c.get('bank_deposit')}")
            print(f"Total Inflows:      NGN {c.get('total_inflows')}")
            print(f"Total Outflows:     NGN {c.get('total_outflows')}")
            print(f"Closing Balance:    NGN {c.get('closing_balance')}")
            
            assert float(c.get('app_fee') or 0) >= 1500.0, "App fee mismatch"
            assert float(c.get('passbook') or 0) >= 500.0, "Passbook mismatch"
            assert float(c.get('bonus') or 0) >= 1000.0, "Bonus mismatch"
            assert float(c.get('credit_form') or 0) >= 200.0, "Credit form mismatch"
            assert float(c.get('credit_form_damage') or 0) >= 500.0, "Credit form damage mismatch"
            assert float(c.get('cash_and_carry') or 0) >= 3000.0, "Cash & carry mismatch"
            assert float(c.get('office_expenses') or 0) >= 1200.0, "Office expenses mismatch"
            assert float(c.get('bank_deposit') or 0) >= 8000.0, "Bank deposit mismatch"
            print("\n>>> ALL ASSERTIONS PASSED WITH 100% SUCCESS! <<<")
        else:
            raise Exception("No row found in co_cashbooks!")

if __name__ == "__main__":
    test_full_eod()
