from datetime import date
import toml
from supabase import create_client
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def test_patched_breakdown():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    # 1. Update loans with loan_repay from schedule
    res_l = client.table("loans").select("loan_id").execute()
    for l in (res_l.data or []):
        lid = l["loan_id"]
        res_s = client.table("loan_schedule").select("total_due").eq("loan_id", lid).order("installment_number").limit(1).execute()
        if res_s.data:
            inst_amt = res_s.data[0]["total_due"]
            client.table("loans").update({"loan_repay": inst_amt}).eq("loan_id", lid).execute()

    print("Updated loans table with loan_repay values from schedule.")

    with SupabaseUnitOfWork() as uow:
        # Test on Friday 2026-08-14
        friday = date(2026, 8, 14)
        breakdown_fri = DashboardService._calculate_payment_breakdown(uow, friday)
        print("\n=== BREAKDOWN ON FRIDAY 2026-08-14 (Meeting Day) ===")
        print(breakdown_fri)

        # Test on Saturday 2026-08-15 (Weekend / Non-meeting Day)
        sat = date(2026, 8, 15)
        breakdown_sat = DashboardService._calculate_payment_breakdown(uow, sat)
        print("\n=== BREAKDOWN ON SATURDAY 2026-08-15 (Non-Meeting Day) ===")
        print(breakdown_sat)

if __name__ == "__main__":
    test_patched_breakdown()
