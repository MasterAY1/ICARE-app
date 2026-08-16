import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope

def test_portfolio_due_fix():
    with SupabaseUnitOfWork() as uow:
        scope = RBACScope(role="Admin", scope_level="ALL", branch_id=None, branch_name=None, assigned_branch_ids=[])
        p_data = PortfolioService.get_portfolio_data_for_scope(uow, scope)
        summary = p_data["summary"]
        
        print("=== PORTFOLIO SUMMARY ===")
        print(f"Total Active Credit:        NGN {summary['total_active_credit']:,.2f}")
        print(f"Total Outstanding Balance:  NGN {summary['total_outstanding_balance']:,.2f}")
        
        print("\n=== LOAN PRODUCT SUMMARY ===")
        for prod, metrics in summary["product_summary"].items():
            print(f"Product: {prod:<15} | Active Credit: NGN {metrics['active_credit']:>12,.2f} | Outstanding Balance: NGN {metrics['loan_balance']:>12,.2f}")
            
        print("\n=== GROUP PORTFOLIO SUMMARY ===")
        client_df = p_data["client_table"]
        print(client_df.to_string())
        
        # Assertions
        assert summary['total_active_credit'] == 1509000.0, f"Expected 1,509,000 got {summary['total_active_credit']}"
        assert summary['total_outstanding_balance'] == 825875.0, f"Expected 825,875 got {summary['total_outstanding_balance']}"
        assert summary['product_summary']['Weekly 12W']['loan_balance'] == 543500.0
        assert summary['product_summary']['Weekly 24W']['loan_balance'] == 282375.0

if __name__ == "__main__":
    test_portfolio_due_fix()
