import os
import sys
import pandas as pd
import datetime

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.schedule_service import ScheduleService

def verify():
    print("==================================================")
    print("VERIFYING SCHEDULE, COLLECTION BALANCES & CASHBOOK")
    print("==================================================")

    with SupabaseUnitOfWork() as uow:
        # 1. Verify Schedule Start Dates
        print("\n--- 1. Checking Repayment Schedule Due Dates ---")
        sch_res = uow.client.table("loan_schedule").select("loan_id, installment_number, due_date, total_due, loans(client_id, clients(name))").eq("installment_number", 1).execute()
        today_str = datetime.date.today().isoformat()
        for s in (sch_res.data or []):
            cname = ((s.get("loans") or {}).get("clients") or {}).get("name", "Unknown")
            due = s.get("due_date")
            print(f"Client: {cname} -> First Due Date: {due}, Installment: NGN {float(s.get('total_due') or 0):,.2f}")
            assert due == today_str, f"Expected first due date to be {today_str}, got {due}!"
            
        print("ASSERTION 1 PASSED: All onboarded loans have schedule starting on today's collection day.")

        # 2. Verify Remaining Balance Calculation
        print("\n--- 2. Checking Remaining Balance Calculation ---")
        loans_res = uow.client.table("loans").select("loan_id, client_id, active_credit, total_due, clients(name, client_code)").eq("status", "Active").execute()
        
        expected_balances = {
            "Kehinde Hannah": (198000.0, 132000.0),
            "Koleosho Sheriffat": (246000.0, 92250.0),
            "Femi Kayode": (246000.0, 102500.0),
            "Lawani Abibat": (198000.0, 99000.0),
            "Orumo Fatimoh": (198000.0, 132000.0),
            "Isiaka Motunrayo": (99000.0, 49500.0),
            "Raimi Rasheedat": (48000.0, 32000.0),
            "Wahab Ganiyat": (78000.0, 42250.0),
            "Taiwo Jacob": (99000.0, 45375.0),
            "Ojei Elizabeth": (99000.0, 99000.0),
        }

        for l in (loans_res.data or []):
            cname = (l.get("clients") or {}).get("name")
            if cname in expected_balances:
                exp_act, exp_rem = expected_balances[cname]
                act_cr = float(l.get("active_credit") or 0.0)
                tot_due = float(l.get("total_due") or 0.0)
                
                paid, _ = ScheduleService.get_total_paid(uow, l["loan_id"])
                calc_rem = tot_due - paid
                
                print(f"Client: {cname} -> Active Cr: NGN {act_cr:,.2f} (Exp: {exp_act:,.2f}), Rem Bal: NGN {calc_rem:,.2f} (Exp: {exp_rem:,.2f})")
                assert abs(act_cr - exp_act) < 1.0, f"Active Credit mismatch for {cname}: {act_cr} != {exp_act}"
                assert abs(calc_rem - exp_rem) < 1.0, f"Remaining Balance mismatch for {cname}: {calc_rem} != {exp_rem}"

        print("ASSERTION 2 PASSED: Remaining Balance matches Current Credit Balance across all members.")

        # 3. Verify CO Cashbook Projection
        print("\n--- 3. Checking CO Cashbook Projection Builder ---")
        b_id = uow.cashbook._resolve_branch_id("Ogijo")
        o_id = uow.loans._resolve_officer_id("CO2")
        print(f"Resolved branch_id: {b_id}, officer_id: {o_id}")
        assert b_id is not None, "Branch ID resolution failed!"
        assert o_id is not None, "Officer ID resolution failed!"
        
        uow.cashbook.rebuild_projection(b_id, datetime.date.today(), officer_id=o_id)
        cb_res = uow.client.table("co_cashbooks").select("*").eq("date", today_str).eq("branch_id", b_id).eq("officer_id", o_id).execute()
        print(f"CO Cashbook records for officer: {len(cb_res.data or [])}")
        assert len(cb_res.data or []) > 0, "CO Cashbook projection row not generated!"
        print("ASSERTION 3 PASSED: CO Cashbook projection builds and persists cleanly.")

    print("\n==================================================")
    print("ALL VERIFICATIONS COMPLETED SUCCESSFULLY!")
    print("==================================================")

if __name__ == "__main__":
    verify()
