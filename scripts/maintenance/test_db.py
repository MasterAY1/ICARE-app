import os
import sys
from dotenv import load_dotenv

sys.path.append(os.getcwd())
load_dotenv()

from database.repositories.unit_of_work import SupabaseUnitOfWork

def main():
    uow = SupabaseUnitOfWork()
    
    loans = uow.client.table("loans").select("*").limit(5).execute()
    print("Loans schema/data:")
    for l in loans.data:
        print({k: v for k, v in l.items() if k in ['id', 'loan_amount', 'active_credit', 'gap_fee', 'loan_repay']})

if __name__ == "__main__":
    main()
