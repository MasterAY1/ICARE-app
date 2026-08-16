import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope

def test_client_dossier():
    with SupabaseUnitOfWork() as uow:
        scope = RBACScope(role="Admin", scope_level="ALL", branch_id=None, branch_name=None, assigned_branch_ids=[])
        
        # Test 1: get_portfolio_data_for_scope includes client_lookup
        print("1. Testing get_portfolio_data_for_scope...")
        p_data = PortfolioService.get_portfolio_data_for_scope(uow, scope)
        assert "client_lookup" in p_data, "client_lookup missing from portfolio data"
        print(f"Total client codes found: {len(p_data['client_codes'])}")
        
        # Test 2: get_client_360_drilldown for OGI-05-023
        target_code = "OGI-05-023" if "OGI-05-023" in p_data["client_codes"] else p_data["client_codes"][0]
        print(f"\n2. Testing get_client_360_drilldown for '{target_code}'...")
        dd = PortfolioService.get_client_360_drilldown(uow, target_code, scope)
        
        assert "customer_info" in dd, "customer_info missing"
        assert "loan_history" in dd, "loan_history missing"
        assert "repayment_history" in dd, "repayment_history missing"
        assert "savings_history" in dd, "savings_history missing"
        assert "collection_history" in dd, "collection_history missing"
        assert "audit_history" in dd, "audit_history missing"
        
        c_info = dd["customer_info"]
        print(f"Client Name:       {c_info.get('name')}")
        print(f"Client Code:       {c_info.get('client_code')}")
        print(f"Group:             {c_info.get('groups', {}).get('name') if isinstance(c_info.get('groups'), dict) else 'Individual'}")
        print(f"Loans Count:       {len(dd['loan_history'])}")
        print(f"Repayments Count:  {len(dd['repayment_history'])}")
        print(f"Savings Entries:   {len(dd['savings_history'])}")
        print("\n>>> CLIENT DOSSIER DRILLDOWN TEST PASSED WITH 100% SUCCESS! <<<")

if __name__ == "__main__":
    test_client_dossier()
