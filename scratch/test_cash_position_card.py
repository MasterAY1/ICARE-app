from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

def test_cash_position():
    print("=== TESTING CO CASH POSITION CARDS ===")
    with SupabaseUnitOfWork() as uow:
        # Test CO3 (Designated Misc Officer who has 1,500 posted today)
        co3_id = "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc"
        b_id = "997d504e-7f5c-4772-887d-fdd5a4c1183b"
        
        co3_data = DashboardService.get_co_dashboard_data(uow, "Ogijo", "CO3", officer_id=co3_id, branch_id=b_id)
        cp3 = co3_data["cash_position"]
        print(f"CO3 Cash Position:")
        print(f"  Opening: {cp3['opening_balance']}")
        print(f"  Cash In: {cp3['cash_in']}")
        print(f"  Cash Out: {cp3['cash_out']}")
        print(f"  Closing: {cp3['closing_balance']}")
        print(f"  Status: {cp3['status']}")

        # Test CO2 (Officer with 0 transactions today)
        co2_id = "c32125e1-c7e5-4a85-8948-12d05b40eaa9"
        co2_data = DashboardService.get_co_dashboard_data(uow, "Ogijo", "CO2", officer_id=co2_id, branch_id=b_id)
        cp2 = co2_data["cash_position"]
        print(f"\nCO2 Cash Position:")
        print(f"  Opening: {cp2['opening_balance']}")
        print(f"  Cash In: {cp2['cash_in']}")
        print(f"  Cash Out: {cp2['cash_out']}")
        print(f"  Closing: {cp2['closing_balance']}")
        print(f"  Status: {cp2['status']}")

if __name__ == "__main__":
    test_cash_position()
