import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
import json

def investigate():
    with SupabaseUnitOfWork() as uow:
        # 1. Look up Kehinde Hannah
        c_res = uow.client.table("clients").select("*").ilike("name", "%Kehinde%").execute()
        print("=== CLIENTS ===")
        print(json.dumps(c_res.data, indent=2, default=str))
        
        if c_res.data:
            c = c_res.data[0]
            cid = c.get("id") or c.get("client_id")
            c_code = c.get("client_code")
            
            # 2. Look up Loans for this client
            l_res = uow.client.table("loans").select("*").or_(f"client_id.eq.{cid},client_id.eq.{c_code}").execute()
            print("\n=== LOANS ===")
            print(json.dumps(l_res.data, indent=2, default=str))
            
            # 3. Look up Repayments for this client / loan
            r_res = uow.client.table("repayments").select("*").or_(f"client_id.eq.{cid},client_id.eq.{c_code}").execute()
            print("\n=== REPAYMENTS (by client_id) ===")
            print(json.dumps(r_res.data, indent=2, default=str))
            
            if l_res.data:
                loan_id_pk = l_res.data[0].get("id") or l_res.data[0].get("loan_id")
                r_by_loan = uow.client.table("repayments").select("*").eq("loan_id", str(loan_id_pk)).execute()
                print("\n=== REPAYMENTS (by loan_id) ===")
                print(json.dumps(r_by_loan.data, indent=2, default=str))

        # 4. Check all repayments in DB
        all_reps = uow.client.table("repayments").select("*").limit(10).execute()
        print("\n=== SAMPLE REPAYMENTS IN DB ===")
        print(json.dumps(all_reps.data, indent=2, default=str))

if __name__ == "__main__":
    investigate()
