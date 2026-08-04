import sys
sys.path.append('.')
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope
from datetime import date

with SupabaseUnitOfWork() as uow:
    scope = RBACScope(scope_level="BRANCH", branch_id="b09f451c-6d9e-49b0-9519-cde8a4ab0f7b", branch_name="Ogijo", role="BM")
    print("Testing All")
    data_all = PortfolioService.get_portfolio_data_for_scope(
        uow, scope, selected_branch="All", selected_officer="All", selected_group="All",
        selected_product="All", start_date=date(2026, 8, 1), end_date=date(2026, 8, 31)
    )
    print("All - Loans:", len(data_all["client_table"]))
    print("All - Active Credit:", data_all["summary"]["total_active_credit"])

    print("\nTesting Daily 60 Days")
    data_60 = PortfolioService.get_portfolio_data_for_scope(
        uow, scope, selected_branch="All", selected_officer="All", selected_group="All",
        selected_product="Daily 60 Days", start_date=date(2026, 8, 1), end_date=date(2026, 8, 31)
    )
    print("60D - Loans:", len(data_60["client_table"]))
    print("60D - Active Credit:", data_60["summary"]["total_active_credit"])
