import sys
import os
from datetime import date
from database.connection import get_supabase_client
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

def force_rebuild():
    client = get_supabase_client()
    
    print(f"Force-rebuilding cashbook for today: {date.today().isoformat()}")
    
    with SupabaseUnitOfWork() as uow:
        # Get all active branches
        res_b = client.table("branches").select("branch_id, name").execute()
        if not res_b.data:
            print("No branches found.")
            return
            
        for branch in res_b.data:
            branch_id = branch["branch_id"]
            branch_name = branch["name"]
            print(f"\nProcessing Branch: {branch_name} ({branch_id})")
            
            # Rebuild CO cashbooks for this branch
            res_u = client.table("app_users").select("id, username").eq("branch_id", branch_id).execute()
            officers = res_u.data or []
            print(f"  Found {len(officers)} officers.")
            for off in officers:
                print(f"  Rebuilding CO Cashbook for: {off['username']}")
                CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, off["id"], date.today())
            
            # Rebuild Master Cashbook for this branch
            print(f"  Rebuilding Master Cashbook...")
            mb_data = MasterCashbookProjectionBuilder.rebuild_master_projection(uow, branch_id, date.today())
            if mb_data:
                print(f"  Master Cashbook Built! Closing Balance: {mb_data.get('closing_balance')}")
            else:
                print(f"  Master Cashbook returned None or failed.")

if __name__ == "__main__":
    force_rebuild()
