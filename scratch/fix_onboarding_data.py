import os
import uuid
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork

def remediate_onboarding_data():
    uow = SupabaseUnitOfWork()
    print("--- 1. Remediating Legacy Repayments Dates & Transaction Types ---")
    
    # 1. Update existing legacy repayments to date='1970-01-01' and transaction_type='ONBOARDING_LEGACY'
    rep_res = uow.client.table("repayments").select("*").eq("note", "Legacy Repayments Onboarded").execute()
    legacy_reps = rep_res.data or []
    print(f"Found {len(legacy_reps)} legacy repayments to update...")
    
    for r in legacy_reps:
        uow.client.table("repayments").update({
            "date": "1970-01-01",
            "transaction_type": "ONBOARDING_LEGACY",
            "payment_status": "Completed"
        }).eq("id", r["id"]).execute()
        print(f"Updated legacy repayment {r['id']} for loan {r.get('loan_id')}")

    # 2. Update existing legacy schedule rows to due_date='1970-01-01'
    print("\n--- 2. Remediating Legacy Schedule Rows ---")
    sch_res = uow.client.table("loan_schedule").select("*").eq("installment_number", 0).execute()
    legacy_schs = sch_res.data or []
    print(f"Found {len(legacy_schs)} legacy schedule rows to update...")
    for s in legacy_schs:
        uow.client.table("loan_schedule").update({
            "due_date": "1970-01-01",
            "paid_date": "1970-01-01",
            "status": "Paid"
        }).eq("id", s["id"]).execute()
        print(f"Updated legacy schedule row {s['id']} for loan {s.get('loan_id')}")

    # 3. Ensure all active loans have loan_repay set
    print("\n--- 3. Verifying and Setting loan_repay on All Active Loans ---")
    loans_res = uow.client.table("loans").select("*, loan_products(installments)").in_("status", ["Active", "Approved"]).execute()
    active_loans = loans_res.data or []
    print(f"Checking {len(active_loans)} active loans...")
    
    fixed_repay = 0
    for l in active_loans:
        lid = l["loan_id"]
        act_cred = float(l.get("active_credit") or 0.0)
        curr_repay = float(l.get("loan_repay") or 0.0)
        
        if curr_repay <= 0 and act_cred > 0:
            prod_info = l.get("loan_products") or {}
            inst_count = int(prod_info.get("installments") or 24)
            calc_repay = round(act_cred / inst_count, 2) if inst_count > 0 else 0.0
            
            # Check schedule if there are positive installments
            sch_sub = uow.client.table("loan_schedule").select("total_due").eq("loan_id", lid).gt("installment_number", 0).limit(1).execute()
            if sch_sub.data and float(sch_sub.data[0].get("total_due") or 0) > 0:
                calc_repay = float(sch_sub.data[0].get("total_due"))
                
            if calc_repay > 0:
                uow.client.table("loans").update({"loan_repay": calc_repay}).eq("loan_id", lid).execute()
                fixed_repay += 1
                print(f"Set loan_repay = {calc_repay} for loan {lid}")
                
    print(f"\nRemediation Complete! Fixed {fixed_repay} loan_repay values.")

if __name__ == "__main__":
    remediate_onboarding_data()
