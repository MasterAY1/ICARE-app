import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScopeService

def test_group_resolution():
    with SupabaseUnitOfWork() as uow:
        print("=" * 80)
        print("TEST 1: CO AYOMIDE (CO2) PORTFOLIO")
        print("=" * 80)
        u_res = uow.client.table("app_users").select("*").execute()
        user_ayo = next((u for u in (u_res.data or []) if "ayomide" in str(u.get("full_name", "")).lower() or "co2" in str(u.get("username", "")).lower()), None)
        assert user_ayo is not None, "CO Ayomide user not found"
        
        scope_ayo = RBACScopeService.resolve_scope(user_ayo)
        p_ayo = PortfolioService.get_portfolio_data_for_scope(uow, scope_ayo)
        df_ayo = p_ayo["client_table"]
        
        m_ayo = df_ayo[df_ayo["Client Code"] == "OGI-19-002"]
        assert len(m_ayo) == 1, f"Expected 1 record for OGI-19-002, got {len(m_ayo)}"
        row_ayo = m_ayo.iloc[0]
        
        print(f"Client Code:         {row_ayo['Client Code']}")
        print(f"Client Name:         {row_ayo['Client Name']}")
        print(f"Group:               {row_ayo['Group']}")
        print(f"Active Loan:         NGN {row_ayo['Active Loan']:,.2f}")
        print(f"Outstanding Balance: NGN {row_ayo['Outstanding Balance']:,.2f}")
        print(f"Savings Balance:     NGN {row_ayo['Savings Balance']:,.2f}")
        print(f"Status:              {row_ayo['Status']}")
        
        assert row_ayo['Group'] == "Feresisemi", f"FAILED: Expected Group 'Feresisemi', got '{row_ayo['Group']}'"
        assert row_ayo['Group'] != "Olorunsogo", f"FAILED: Monsurat Oladeji is still showing in Olorunsogo!"
        print(">>> TEST 1 PASSED: Monsurat Oladeji (OGI-19-002) is correctly in 'Feresisemi' <<<")

        print("\n" + "=" * 80)
        print("TEST 2: CO OLUWASEUN (CO4) PORTFOLIO")
        print("=" * 80)
        user_seun = next((u for u in (u_res.data or []) if "oluwaseun" in str(u.get("full_name", "")).lower() or "co4" in str(u.get("username", "")).lower()), None)
        assert user_seun is not None, "CO Oluwaseun user not found"
        
        scope_seun = RBACScopeService.resolve_scope(user_seun)
        p_seun = PortfolioService.get_portfolio_data_for_scope(uow, scope_seun)
        df_seun = p_seun["client_table"]
        
        m_seun = df_seun[df_seun["Client Code"] == "OGI-12-003"]
        assert len(m_seun) == 1, f"Expected 1 record for OGI-12-003, got {len(m_seun)}"
        row_seun = m_seun.iloc[0]
        
        print(f"Client Code:         {row_seun['Client Code']}")
        print(f"Client Name:         {row_seun['Client Name']}")
        print(f"Group:               {row_seun['Group']}")
        print(f"Active Loan:         NGN {row_seun['Active Loan']:,.2f}")
        print(f"Outstanding Balance: NGN {row_seun['Outstanding Balance']:,.2f}")
        print(f"Savings Balance:     NGN {row_seun['Savings Balance']:,.2f}")
        print(f"Status:              {row_seun['Status']}")
        
        assert row_seun['Group'] == "Olorunsogo", f"FAILED: Expected Group 'Olorunsogo', got '{row_seun['Group']}'"
        assert row_seun['Group'] != "Feresisemi", f"FAILED: Monsurat oladeji (CO4) is showing in Feresisemi!"
        print(">>> TEST 2 PASSED: Monsurat oladeji (OGI-12-003) is correctly in 'Olorunsogo' <<<")

        print("\n" + "=" * 80)
        print("TEST 3: ZERO MULTIPLE MEMBERSHIPS IN DB")
        print("=" * 80)
        m_res = uow.client.table("client_memberships").select("client_id, group_id").execute()
        from collections import Counter
        counts = Counter(m['client_id'] for m in (m_res.data or []))
        duplicates = {cid: cnt for cid, cnt in counts.items() if cnt > 1}
        print(f"Total memberships: {len(m_res.data or [])}")
        print(f"Clients with duplicate memberships: {len(duplicates)}")
        assert len(duplicates) == 0, f"FAILED: Still have duplicate memberships in DB: {duplicates}"
        print(">>> TEST 3 PASSED: Zero duplicate memberships in database <<<")
        
        print("\n================================================================================")
        print("ALL REGRESSION TESTS PASSED 100%!")
        print("================================================================================")

if __name__ == "__main__":
    test_group_resolution()
