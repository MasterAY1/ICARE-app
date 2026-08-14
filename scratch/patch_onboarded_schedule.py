import os
import uuid
from datetime import date, timedelta
from database.repositories.unit_of_work import SupabaseUnitOfWork
import traceback

def patch_onboarded_schedule():
    uow = SupabaseUnitOfWork()
    
    print("Fetching active loans...")
    loans_res = uow.client.table("loans").select("*").in_("status", ["Active", "Approved"]).execute()
    loans = loans_res.data or []
    
    legacy_schedule_inserted = 0

    for loan in loans:
        lid = loan["loan_id"]
        act_cred = float(loan.get("active_credit") or 0.0)
        tot_due = float(loan.get("total_due") or act_cred)
        loan_date = loan.get("date") or date.today().isoformat()
        
        missing_paid = act_cred - tot_due
        if missing_paid > 0.01:
            # Check if we already inserted a legacy schedule row
            sch_res = uow.client.table("loan_schedule").select("id").eq("loan_id", lid).eq("installment_number", 0).execute()
            if not sch_res.data:
                try:
                    # Insert a dummy row for installment 0 to represent all past paid installments
                    uow.client.table("loan_schedule").insert({
                        "id": str(uuid.uuid4()),
                        "loan_id": lid,
                        "installment_number": 0,
                        "due_date": loan_date,
                        "principal": float(missing_paid),
                        "interest": 0.0,
                        "fees": 0.0,
                        "total_due": float(missing_paid),
                        "status": "Paid",
                        "paid_amount": float(missing_paid),
                        "paid_date": loan_date
                    }).execute()
                    legacy_schedule_inserted += 1
                    print(f"Inserted legacy schedule row of {missing_paid} for {lid}")
                except Exception as e:
                    print(f"Failed to insert legacy schedule for {lid}: {e}")

    print(f"Done! Inserted {legacy_schedule_inserted} legacy schedule rows.")

if __name__ == "__main__":
    patch_onboarded_schedule()
