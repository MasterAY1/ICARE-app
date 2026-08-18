import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def clear_tables():
    with SupabaseUnitOfWork() as uow:
        print("Clearing loan_schedule...")
        uow.client.table("loan_schedule").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        
        print("Clearing repayments...")
        uow.client.table("repayments").delete().neq("repayment_id", "00000000-0000-0000-0000-000000000000").execute()
        
        print("Clearing loans...")
        uow.client.table("loans").delete().neq("loan_id", "00000000-0000-0000-0000-000000000000").execute()
        
        print("Clearing individual_savings...")
        uow.client.table("individual_savings").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        
        print("Clearing group_savings...")
        uow.client.table("group_savings").delete().neq("id", "00000000-0000-0000-0000-000000000000").execute()
        
        print("Clearing client_memberships...")
        uow.client.table("client_memberships").delete().neq("client_id", "00000000-0000-0000-0000-000000000000").execute()
        
        print("Clearing clients...")
        uow.client.table("clients").delete().neq("client_id", "00000000-0000-0000-0000-000000000000").execute()
        
        print(">>> ALL TABLES CLEARED SAFELY <<<")

if __name__ == "__main__":
    clear_tables()
