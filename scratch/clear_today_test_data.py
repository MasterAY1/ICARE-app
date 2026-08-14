import os
import sys
from datetime import date

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

def clear_today():
    today_str = date.today().isoformat()
    print(f"Clearing test records created for today: {today_str}")
    
    with SupabaseUnitOfWork() as uow:
        # 1. Clear individual_savings for today
        uow.client.table("individual_savings").delete().eq("posting_date", today_str).execute()
        
        # 2. Clear repayments for today
        uow.client.table("repayments").delete().eq("date", today_str).execute()
        
        # 3. Clear co_cashbooks projections for today
        uow.client.table("co_cashbooks").delete().eq("date", today_str).execute()
        
        # 4. Clear master_cashbook projections for today
        uow.client.table("master_cashbook").delete().eq("date", today_str).execute()
        
        print("Cleaned today's test records.")
        
        # 5. Rebuild clean projections for all branches
        branches = uow.client.table("branches").select("branch_id").execute().data or []
        for b in branches:
            b_id = b["branch_id"]
            try:
                uow.cashbook.rebuild_projection(b_id, date.today())
            except Exception as e:
                pass
                
        print("Rebuilt projections cleanly.")

if __name__ == "__main__":
    clear_today()
