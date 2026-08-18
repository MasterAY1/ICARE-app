from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def verify_cash_position_fix():
    print("=== VERIFYING CASH POSITION PROJECTION FIX ===")
    with SupabaseUnitOfWork() as uow:
        b_id = "997d504e-7f5c-4772-887d-fdd5a4c1183b"
        
        # 1. CO3 (has 1500 opening balance rolled over from yesterday)
        co3_id = "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc"
        co3_data = DashboardService.get_co_dashboard_data(uow, "Ogijo", "CO3", officer_id=co3_id, branch_id=b_id)
        cp3 = co3_data["cash_position"]
        print(f"CO3 Cash Position:")
        print(f"  Opening Balance: NGN {cp3['opening_balance']:,.2f}")
        print(f"  Cash In (Today): NGN {cp3['cash_in']:,.2f}")
        print(f"  Cash Out: NGN {cp3['cash_out']:,.2f}")
        print(f"  Closing Balance: NGN {cp3['closing_balance']:,.2f}")
        print(f"  Status: {cp3['status']} (Diff: NGN {cp3['difference']:,.2f})")
        
        # Verify: Opening (1500) + Cash In (0) - Cash Out (0) == Closing (1500)
        assert cp3['opening_balance'] == 1500.0, f"Expected opening balance 1500.0, got {cp3['opening_balance']}"
        assert cp3['cash_in'] == 0.0, f"Expected cash_in today to be 0.0, got {cp3['cash_in']}"
        assert cp3['closing_balance'] == 1500.0, f"Expected closing balance 1500.0, got {cp3['closing_balance']}"
        assert cp3['status'] == "Balanced", f"Expected status Balanced, got {cp3['status']}"
        print("  >>> PASS: Opening balance correctly isolated from Today's Cash In!")

        # 2. BM Dashboard
        bm_data = DashboardService.get_bm_dashboard_data(uow, "Ogijo", branch_id=b_id)
        bcp = bm_data["branch_cash_position"]
        print(f"\nBranch Manager Cash Position:")
        print(f"  Opening Balance: NGN {bcp['opening_balance']:,.2f}")
        print(f"  Cash In (Today): NGN {bcp['cash_in']:,.2f}")
        print(f"  Cash Out: NGN {bcp['cash_out']:,.2f}")
        print(f"  Closing Balance: NGN {bcp['closing_balance']:,.2f}")
        print(f"  Status: {bcp['status']} (Diff: NGN {bcp['difference']:,.2f})")
        assert bcp['status'] == "Balanced", f"Expected BM status Balanced, got {bcp['status']}"
        print("  >>> PASS: Branch Cash Position is perfectly balanced!")

    print("\n=== ALL CASH POSITION CHECKS PASSED ===")

if __name__ == "__main__":
    verify_cash_position_fix()
