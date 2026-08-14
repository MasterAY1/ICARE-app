import os
import uuid
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
import traceback

def patch_onboarded_loans():
    uow = SupabaseUnitOfWork()
    
    print("Fetching active loans...")
    loans_res = uow.client.table("loans").select("*").in_("status", ["Active", "Approved"]).execute()
    loans = loans_res.data or []
    
    patched_repay_count = 0
    legacy_repayment_inserted = 0

    for loan in loans:
        lid = loan["loan_id"]
        cid = loan["client_id"]
        bid = loan.get("branch_id")
        oid = loan.get("officer_id")
        act_cred = float(loan.get("active_credit") or 0.0)
        tot_due = float(loan.get("total_due") or act_cred)
        loan_repay = float(loan.get("loan_repay") or 0.0)
        
        # 1. Fix missing loan_repay
        if loan_repay == 0.0:
            sch_res = uow.client.table("loan_schedule").select("total_due").eq("loan_id", lid).order("installment_number").limit(1).execute()
            if sch_res.data:
                inst_amt = float(sch_res.data[0]["total_due"])
                if inst_amt > 0:
                    uow.client.table("loans").update({"loan_repay": inst_amt}).eq("loan_id", lid).execute()
                    patched_repay_count += 1
                    print(f"Patched loan_repay for {lid} to {inst_amt}")

        # 2. Fix missing legacy payments
        missing_paid = act_cred - tot_due
        if missing_paid > 0.01:
            # Check if we already inserted a legacy repayment
            rep_res = uow.client.table("repayments").select("id").eq("loan_id", lid).eq("note", "Legacy Repayments Onboarded").execute()
            if not rep_res.data:
                # Also check if there's any repayment at all that covers this.
                all_rep = uow.client.table("repayments").select("amount_paid").eq("loan_id", lid).execute()
                tot_already = sum(float(r["amount_paid"]) for r in (all_rep.data or []))
                
                if tot_already < missing_paid:
                    diff = missing_paid - tot_already
                    try:
                        uow.client.table("repayments").insert({
                            "id": str(uuid.uuid4()),
                            "loan_id": lid,
                            "client_id": cid,
                            "branch_id": bid,
                            "officer_id": oid,
                            "amount_paid": float(diff),
                            "transaction_type": "Cash",
                            "payment_status": "Completed",
                            "date": date.today().isoformat(),
                            "note": "Legacy Repayments Onboarded"
                        }).execute()
                        legacy_repayment_inserted += 1
                        print(f"Inserted legacy repayment of {diff} for {lid} (Active: {act_cred}, Due: {tot_due})")
                    except Exception as e:
                        print(f"Failed to insert legacy repayment for {lid}: {e}")

    print(f"Done! Patched {patched_repay_count} loan_repay values. Inserted {legacy_repayment_inserted} legacy repayments.")

if __name__ == "__main__":
    patch_onboarded_loans()
