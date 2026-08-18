import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
import uuid
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine
from datetime import date

def test_fixed_eod():
    with SupabaseUnitOfWork() as uow:
        target_co = "CO2"
        BRANCH = "Ogijo"
        date_str = date.today().isoformat()
        
        # Resolve officer ID (a valid UUID)
        res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
        officer_id = res_u.data[0]["id"] if res_u.data else str(uuid.uuid4())
        branch_id = uow.cashbook._resolve_branch_id(BRANCH)
        
        print(f"Officer ID: {officer_id}, Branch ID: {branch_id}")
        
        # Test 1: BankDeposited event with officer_id as aggregate_id
        ev_bdep = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=officer_id,
            aggregate_type="Bank",
            event_type="BankDeposited",
            payload={"branch": BRANCH, "branch_id": branch_id, "officer": target_co, "officer_id": officer_id, "amount": 2500.0, "date": date_str, "narration": f"End of Day cash deposit to bank by {target_co}"}
        )
        uow.event_store.append(ev_bdep)
        FinancialPostingEngine.post_event(uow, ev_bdep)
        print("1. BankDeposited posted successfully!")

        # Test 2: ExpenseRecorded event
        ev_exp = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=officer_id,
            aggregate_type="Expense",
            event_type="ExpenseRecorded",
            payload={"branch": BRANCH, "branch_id": branch_id, "officer": target_co, "officer_id": officer_id, "amount": 750.0, "date": date_str, "narration": f"Office expenses paid by {target_co}"}
        )
        uow.event_store.append(ev_exp)
        FinancialPostingEngine.post_event(uow, ev_exp)
        print("2. ExpenseRecorded posted successfully!")

        # Test 3: FeeCharged event
        ev_app = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=officer_id,
            aggregate_type="Fee",
            event_type="FeeCharged",
            payload={"branch": BRANCH, "branch_id": branch_id, "officer": target_co, "officer_id": officer_id, "amount": 1000.0, "date": date_str, "narration": f"Processing Fee from {target_co} End of Day"}
        )
        uow.event_store.append(ev_app)
        FinancialPostingEngine.post_event(uow, ev_app)
        print("3. FeeCharged posted successfully!")

        # Rebuild CO Cashbook projection
        uow.cashbook.rebuild_projection(branch_id, date.today(), officer_id=officer_id)
        
        # Query projection
        res_co = uow.client.table("co_cashbooks").select("*").eq("date", date_str).eq("branch_id", branch_id).eq("officer_id", officer_id).execute()
        print("\nRebuilt CO Cashbook Row:")
        if res_co.data:
            c = res_co.data[0]
            print(f"App Fee:         NGN {c.get('app_fee')}")
            print(f"Office Expenses: NGN {c.get('office_expenses')}")
            print(f"Bank Deposit:    NGN {c.get('bank_deposit')}")
            print(f"Total Inflows:   NGN {c.get('total_inflows')}")
            print(f"Total Outflows:  NGN {c.get('total_outflows')}")
            print(f"Closing Balance: NGN {c.get('closing_balance')}")
        else:
            print("No CO Cashbook row found!")

if __name__ == "__main__":
    test_fixed_eod()
