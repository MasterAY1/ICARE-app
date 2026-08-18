from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def test_breakdown():
    with SupabaseUnitOfWork() as uow:
        # Test on Friday 2026-08-14 (the meeting date for Anuoluwapo and Ojurere groups)
        friday = date(2026, 8, 14)
        breakdown_friday = DashboardService._calculate_payment_breakdown(uow, friday)
        print(f"=== BREAKDOWN ON FRIDAY 2026-08-14 ===")
        print(breakdown_friday)

        # Test on Saturday 2026-08-15 (Today)
        saturday = date(2026, 8, 15)
        breakdown_saturday = DashboardService._calculate_payment_breakdown(uow, saturday)
        print(f"\n=== BREAKDOWN ON SATURDAY 2026-08-15 (Today) ===")
        print(breakdown_saturday)

if __name__ == "__main__":
    test_breakdown()
