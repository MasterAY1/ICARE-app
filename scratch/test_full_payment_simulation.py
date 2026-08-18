import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.dashboard_service import DashboardService
from services.rbac_scope_service import RBACScopeService

def test_full_payment_simulation():
    with SupabaseUnitOfWork() as uow:
        print("=" * 80)
        print("1. INSPECTING ACTIVE LOANS IN DB")
        print("=" * 80)
        u_res = uow.client.table("app_users").select("*").execute()
        user_ayo = next((u for u in (u_res.data or []) if "ayomide" in str(u.get("full_name", "")).lower() or "co2" in str(u.get("username", "")).lower()), None)
        
        # Test Ayomide's clients
        scope_ayo = RBACScopeService.resolve_scope(user_ayo)
        p_data = PortfolioService.get_portfolio_data_for_scope(uow, scope_ayo)
        df = p_data["client_table"]
        summary = p_data["summary"]
        
        print(f"Total Active Credit:        NGN {summary['total_active_credit']:,.2f}")
        print(f"Total Outstanding Balance:  NGN {summary['total_outstanding_balance']:,.2f}")
        print(f"Active Loans Count:         {summary['active_loans_count']}")
        print(f"Active Clients:             {summary['active_clients']}")
        
        print("\n--- CLIENTS WITH LOANS ---")
        loan_clients = df[df["Active Loan"] > 0][["Client Code", "Client Name", "Group", "Active Loan", "Outstanding Balance", "Fixed Repayment", "Total Paid", "Status"]]
        print(loan_clients.to_string())

        # Test payment breakdown calculation in DashboardService
        today = date.today()
        branch_id = user_ayo.get("branch_id")
        officer_id = user_ayo.get("id")
        breakdown = DashboardService._calculate_payment_breakdown(uow, today, branch_id=branch_id, officer_id=officer_id)
        print("\n--- DASHBOARD SERVICE PAYMENT BREAKDOWN ---")
        print(breakdown)

if __name__ == "__main__":
    test_full_payment_simulation()
