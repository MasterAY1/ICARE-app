import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScopeService

def test_portfolio_service_savings():
    uow = SupabaseUnitOfWork()
    
    # 1. Test CO2
    user_co2 = {"id": "c32125e1-c7e5-4a85-8948-12d05b40eaa9", "username": "CO2", "role": "CO", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
    scope_co2 = RBACScopeService.resolve_scope(user_co2)
    p_data_co2 = PortfolioService.get_portfolio_data_for_scope(uow, scope_co2)
    s_co2 = p_data_co2["summary"]
    
    print("=== TEST CO2 ===")
    print(f"Total Deposits:    NGN {s_co2['total_savings_deposit']:,.2f}")
    print(f"Total Withdrawals: NGN {s_co2['total_savings_withdrawal']:,.2f}")
    print(f"Net Balance:       NGN {s_co2['total_savings_balance']:,.2f}")
    assert s_co2['total_savings_deposit'] == 364475.0, f"Expected 364475.0, got {s_co2['total_savings_deposit']}"
    assert s_co2['total_savings_withdrawal'] == 0.0, f"Expected 0.0, got {s_co2['total_savings_withdrawal']}"
    assert s_co2['total_savings_balance'] == 364475.0, f"Expected 364475.0, got {s_co2['total_savings_balance']}"
    
    # Check client table
    df_co2 = p_data_co2["client_table"]
    print("CO2 Table columns:", list(df_co2.columns))
    # When selected_group == "All", group_df is returned
    if "Total Savings Balance" in df_co2.columns:
        tot_grp_savings = df_co2["Total Savings Balance"].sum()
        print(f"CO2 Total Group Savings in table: NGN {tot_grp_savings:,.2f}")
        assert tot_grp_savings == 364475.0, f"Expected 364475.0, got {tot_grp_savings}"
        
    # Test specific group drilldown for CO2 (e.g. Favour)
    p_data_favour = PortfolioService.get_portfolio_data_for_scope(uow, scope_co2, selected_group="Favour")
    df_favour = p_data_favour["client_table"]
    print("Favour group clients count:", len(df_favour))
    if "Savings Balance" in df_favour.columns:
        favour_client_savings = df_favour["Savings Balance"].sum()
        print(f"Favour clients savings sum: NGN {favour_client_savings:,.2f}")
        assert favour_client_savings > 0, "Favour clients should have non-zero savings!"
        
    # 2. Test CO3 (Misc designated officer)
    user_co3 = {"id": "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc", "username": "CO3", "role": "CO", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
    scope_co3 = RBACScopeService.resolve_scope(user_co3)
    p_data_co3 = PortfolioService.get_portfolio_data_for_scope(uow, scope_co3)
    s_co3 = p_data_co3["summary"]
    print("\n=== TEST CO3 ===")
    print(f"Total Deposits:    NGN {s_co3['total_savings_deposit']:,.2f}")
    print(f"Total Withdrawals: NGN {s_co3['total_savings_withdrawal']:,.2f}")
    print(f"Net Balance:       NGN {s_co3['total_savings_balance']:,.2f}")
    assert s_co3['total_savings_deposit'] == 1500.0
    assert s_co3['total_savings_balance'] == 1500.0
    
    # 3. Test BM_Ogijo (Branch scope)
    user_bm = {"id": "f2656341-a85a-4e06-a1c8-d62cfef19b08", "username": "BM_Ogijo", "role": "BM", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
    scope_bm = RBACScopeService.resolve_scope(user_bm)
    p_data_bm = PortfolioService.get_portfolio_data_for_scope(uow, scope_bm)
    s_bm = p_data_bm["summary"]
    print("\n=== TEST BM_OGIJO ===")
    print(f"Total Deposits:    NGN {s_bm['total_savings_deposit']:,.2f}")
    print(f"Total Withdrawals: NGN {s_bm['total_savings_withdrawal']:,.2f}")
    print(f"Net Balance:       NGN {s_bm['total_savings_balance']:,.2f}")
    assert s_bm['total_savings_deposit'] == 365975.0
    assert s_bm['total_savings_balance'] == 365975.0
    
    print("\n>>> ALL PORTFOLIO SAVINGS TESTS PASSED SUCCESSFULLY! <<<")

if __name__ == "__main__":
    test_portfolio_service_savings()
