import uuid
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork

def inject_repayments():
    print("Injecting legacy repayments to reconcile dynamic outstanding balance...")
    with SupabaseUnitOfWork() as uow:
        l_res = uow.client.table("loans").select("*").eq("status", "Active").execute()
        
        count = 0
        for l in l_res.data:
            act_cred = float(l.get("active_credit") or 0.0)
            tot_due = float(l.get("total_due") or 0.0)
            c_id = l.get("client_id")
            
            if act_cred > 0 and tot_due < act_cred:
                diff = act_cred - tot_due
                
                r_check = uow.client.table("repayments").select("id").eq("client_id", c_id).eq("note", "Legacy Pre-Migration Repayment").execute()
                if not r_check.data:
                    r_id = str(uuid.uuid4())
                    payload = {
                        "id": r_id,
                        "client_id": c_id,
                        "loan_id": l.get("loan_id"),
                        "branch_id": l.get("branch_id"),
                        "officer_id": l.get("officer_id"),
                        "amount_paid": diff,
                        "date": l.get("date"),
                        "transaction_type": "Cash",
                        "note": "Legacy Pre-Migration Repayment"
                    }
                    uow.client.table("repayments").insert(payload).execute()
                    print(f"Injected {diff} repayment for client {c_id}")
                    count += 1
                    
        print(f"Injected {count} legacy repayments.")

if __name__ == '__main__':
    inject_repayments()
