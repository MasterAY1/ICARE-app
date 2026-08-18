import os
import json
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def run_investigation():
    print("=== INVESTIGATING DASHBOARD REPAYMENTS & SAVINGS ===")
    with SupabaseUnitOfWork() as uow:
        # 1. Fetch branches & users
        branches_res = uow.client.table("branches").select("*").execute()
        branches = branches_res.data or []
        print(f"Branches: {len(branches)}")
        for b in branches:
            print(f"  Branch: {b.get('name')} (ID: {b.get('branch_id')})")

        users_res = uow.client.table("app_users").select("*").execute()
        users = users_res.data or []
        print(f"Users: {len(users)}")
        for u in users:
            print(f"  User: {u.get('username')} (ID: {u.get('id')}, Role: {u.get('role', 'N/A')}, Branch: {u.get('branch_id')})")

        # 2. Check today's repayments table records
        today_str = date.today().isoformat()
        print(f"\n--- REPAYMENTS TABLE (Date: {today_str}) ---")
        reps_res = uow.client.table("repayments").select("*").eq("date", today_str).execute()
        reps = reps_res.data or []
        print(f"Total repayments for {today_str}: {len(reps)}")
        for r in reps:
            print(f"  ID: {r.get('id')}, Client: {r.get('client_id')}, Amount Paid: {r.get('amount_paid')}, Loan ID: {r.get('loan_id')}, Officer: {r.get('officer_id')}, Note: {r.get('note')}, Type: {r.get('transaction_type')}")

        # 3. Check all repayments if today is empty
        if not reps:
            print("\nChecking most recent repayments across all dates:")
            all_reps_res = uow.client.table("repayments").select("*").order("created_at", desc=True).limit(10).execute()
            all_reps = all_reps_res.data or []
            print(f"Recent repayments ({len(all_reps)}):")
            for r in all_reps:
                print(f"  Date: {r.get('date')}, Amount Paid: {r.get('amount_paid')}, Savings: {r.get('savings_amount')}, Client: {r.get('client_id')}, Officer: {r.get('officer_id')}, Note: {r.get('note')}, Type: {r.get('transaction_type')}")

        # 4. Check individual_savings table
        print(f"\n--- INDIVIDUAL SAVINGS (Date: {today_str}) ---")
        sav_res = uow.client.table("individual_savings").select("*").eq("posting_date", today_str).execute()
        savs = sav_res.data or []
        print(f"Total individual savings for {today_str}: {len(savs)}")
        for s in savs:
            print(f"  ID: {s.get('id')}, Client: {s.get('client_id')}, Deposit: {s.get('deposit_amount')}, Withdrawal: {s.get('withdrawal_amount')}, Officer: {s.get('officer_id')}, Remarks: {s.get('remarks')}")

        if not savs:
            print("Checking most recent individual savings:")
            all_sav_res = uow.client.table("individual_savings").select("*").order("created_at", desc=True).limit(10).execute()
            all_savs = all_sav_res.data or []
            for s in all_savs:
                print(f"  Date: {s.get('posting_date')}, Client: {s.get('client_id')}, Deposit: {s.get('deposit_amount')}, Withdrawal: {s.get('withdrawal_amount')}, Remarks: {s.get('remarks')}")

        # 5. Check DashboardService data for each officer
        print("\n--- DASHBOARD SERVICE OUTPUT ---")
        for u in users:
            u_id = u.get("id")
            u_name = u.get("username")
            b_id = u.get("branch_id")
            b_name = next((b["name"] for b in branches if b["branch_id"] == b_id), "Ogijo")
            
            try:
                co_dash = DashboardService.get_co_dashboard_data(uow, b_name, u_name, officer_id=u_id, branch_id=b_id)
                rep_s = co_dash.get("repayment_summary", {})
                sav_s = co_dash.get("savings", {})
                cash_pos = co_dash.get("cash_position", {})
                print(f"\nOfficer: {u_name} ({b_name})")
                print(f"  Repayment Summary: {json.dumps(rep_s, default=str)}")
                print(f"  Savings Summary: {json.dumps(sav_s, default=str)}")
                print(f"  Cash Position: {json.dumps(cash_pos, default=str)}")
            except Exception as e:
                print(f"  Error getting CO dashboard for {u_name}: {e}")

if __name__ == "__main__":
    run_investigation()
