import os
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope
from services.savings_service import SavingsService

def test_portfolio_and_savings():
    print("==================================================")
    print("1. Testing Portfolio Data & Repayment Status Categorization (Admin Scope)")
    print("==================================================")
    uow = SupabaseUnitOfWork()
    scope = RBACScope(user_id='admin', username='admin', role='Admin', scope_level='GLOBAL')
    
    data = PortfolioService.get_portfolio_data_for_scope(uow, scope)
    summary = data['summary']
    
    print(f"Total Registered Clients: {summary['total_registered_clients']}")
    print(f"Active Clients: {summary['active_clients']}")
    print(f"Total Active Credit: ₦{summary['total_active_credit']:,.2f}")
    print(f"Total Outstanding Balance: ₦{summary['total_outstanding_balance']:,.2f}")
    print(f"Total Expected Repayment: ₦{summary['total_expected_repayment']:,.2f}")
    print(f"Today Collection: ₦{summary['today_collection']:,.2f}")
    print(f"Normal Payments Count: {summary['normal_payments']['count']}, Amount: ₦{summary['normal_payments']['amount']:,.2f}")
    print(f"Excess Payments Count: {summary['excess_payments']['count']}, Amount: ₦{summary['excess_payments']['amount']:,.2f}")
    print(f"Total Savings Balance (All 3 Tiers): ₦{summary['total_savings_balance']:,.2f}")
    
    # Assertions
    assert summary['excess_payments']['count'] == 0, f"Expected 0 excess payments from historical data, got {summary['excess_payments']['count']}"
    assert summary['total_expected_repayment'] > 0, "Expected positive total expected repayment"
    assert summary['total_outstanding_balance'] > 0, "Expected positive total outstanding balance"
    assert summary['total_outstanding_balance'] < summary['total_active_credit'], "Remaining balance must be less than active credit due to historical payments"
    print(">> Portfolio Summary Assertions PASSED!")
    
    print("\n==================================================")
    print("2. Testing Group Summary Table with Group Savings (BR-SAV-003)")
    print("==================================================")
    client_df = data['client_table']
    print(client_df.head(10))
    assert not client_df.empty, "Expected non-empty group summary table"
    print(">> Group Summary Table verified!")
    
    print("\n==================================================")
    print("3. Testing CO3 Misc Savings Routing (BR-SAV-002)")
    print("==================================================")
    m_id, m_name = SavingsService.get_branch_misc_savings_officer(uow, "Ogijo")
    print(f"Ogijo Misc Savings Officer: {m_name} (ID: {m_id})")
    assert m_name == "CO3"
    print(">> Officer Misc Savings Routing verified!")
    
    print("\n==================================================")
    print("ALL TESTS PASSED SUCCESSFULLY!")
    print("==================================================")

if __name__ == "__main__":
    test_portfolio_and_savings()
