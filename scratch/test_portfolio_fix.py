import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.rbac_scope_service import RBACScope
from services.portfolio_service import PortfolioService

def main():
    uow = SupabaseUnitOfWork()
    scope = RBACScope(scope_level="GLOBAL")
    
    print("Testing PortfolioService.get_portfolio_data_for_scope...")
    data = PortfolioService.get_portfolio_data_for_scope(
        uow=uow,
        scope=scope,
        start_date=date.today(),
        end_date=date.today(),
        selected_product="All",
        selected_group="All",
        selected_officer="All",
        selected_branch="All"
    )
    
    summary = data.get("summary", {})
    print("\n=== SUMMARY METRICS ===")
    print("Total Active Credit:", summary.get("total_active_credit"))
    print("Total Expected Repayment:", summary.get("total_expected_repayment"))
    print("Total Outstanding Balance:", summary.get("total_outstanding_balance"))
    
    client_table = data.get("client_table")
    print("\n=== RETURNED CLIENT TABLE (Group Summary Rollup) ===")
    if client_table is not None and not client_table.empty:
        print("Shape:", client_table.shape)
        print(client_table.to_string())
    else:
        print("Empty DataFrame.")

if __name__ == "__main__":
    main()
