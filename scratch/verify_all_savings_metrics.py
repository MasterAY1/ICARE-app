from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService
from services.savings_service import SavingsService

def verify_savings_metrics():
    print("=== VERIFYING UNIFIED SAVINGS METRICS ===")
    with SupabaseUnitOfWork() as uow:
        # 1. Check designated Misc Savings officer for Ogijo
        misc_off_id, misc_off_name = SavingsService.get_branch_misc_savings_officer(uow, "Ogijo")
        print(f"Designated Misc Savings Officer for Ogijo: {misc_off_name} ({misc_off_id})")

        # 2. Query designated officer's CO Dashboard
        co_misc_data = DashboardService.get_co_dashboard_data(uow, "Ogijo", misc_off_name, officer_id=misc_off_id, branch_id="997d504e-7f5c-4772-887d-fdd5a4c1183b")
        sav_misc = co_misc_data["savings"]
        print(f"\nDesignated Officer ({misc_off_name}) Savings Today:")
        print(f"  Deposited: NGN {sav_misc['deposited_amt']:,.2f}")
        print(f"  Withdrawn: NGN {sav_misc['withdrawn_amt']:,.2f}")
        print(f"  Net: NGN {sav_misc['net_savings']:,.2f}")
        # Today we posted 1,500 in misc savings for this branch, so CO3 should include it
        assert sav_misc['deposited_amt'] >= 1500.0, f"Expected at least 1500.0 for designated officer, got {sav_misc['deposited_amt']}"
        print("  >>> PASS: Designated officer correctly includes branch Misc Savings.")

        # 3. Query non-designated officer's CO Dashboard (e.g. CO2 / c32125e1...)
        co2_id = "c32125e1-c7e5-4a85-8948-12d05b40eaa9"
        co2_data = DashboardService.get_co_dashboard_data(uow, "Ogijo", "CO2", officer_id=co2_id, branch_id="997d504e-7f5c-4772-887d-fdd5a4c1183b")
        sav_co2 = co2_data["savings"]
        print(f"\nRegular Officer (CO2) Savings Today:")
        print(f"  Deposited: NGN {sav_co2['deposited_amt']:,.2f}")
        print(f"  Withdrawn: NGN {sav_co2['withdrawn_amt']:,.2f}")
        print(f"  Net: NGN {sav_co2['net_savings']:,.2f}")
        assert sav_co2['deposited_amt'] == 0.0, f"Expected 0.0 for non-designated officer, got {sav_co2['deposited_amt']}"
        print("  >>> PASS: Non-designated officer excludes branch Misc Savings.")

        # 4. Query Global Admin Dashboard
        admin_data = DashboardService.get_admin_dashboard_data(uow, date.today())
        ops = admin_data["today_operations"]
        print(f"\nGlobal Admin Dashboard Savings Today:")
        print(f"  Today's Savings Deposit: NGN {ops['today_savings_deposit']:,.2f}")
        print(f"  Today's Savings Withdrawal: NGN {ops['today_savings_withdrawal']:,.2f}")
        assert ops['today_savings_deposit'] >= 1500.0, f"Expected at least 1500.0 for Admin, got {ops['today_savings_deposit']}"
        print("  >>> PASS: Global Admin dashboard aggregates all institutional savings (Individual + Group + Misc).")

    print("\n=== ALL SAVINGS VERIFICATION CHECKS PASSED ===")

if __name__ == "__main__":
    verify_savings_metrics()
