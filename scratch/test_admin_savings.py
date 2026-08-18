import toml
from datetime import date
from supabase import create_client
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def test_admin_and_co_savings():
    with SupabaseUnitOfWork() as uow:
        # Check admin dashboard
        admin_data = DashboardService.get_admin_dashboard_data(uow, date.today())
        ops = admin_data["today_operations"]
        print("=== GLOBAL ADMIN TODAY'S SAVINGS ===")
        print(f"Today's Savings Deposit: {ops.get('today_savings_deposit')}")
        print(f"Today's Savings Withdrawal: {ops.get('today_savings_withdrawal')}")

if __name__ == "__main__":
    test_admin_and_co_savings()
