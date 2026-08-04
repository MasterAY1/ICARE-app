import sys
sys.path.append('.')
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope
from datetime import date

with SupabaseUnitOfWork() as uow:
    scope = RBACScope(scope_level="BRANCH", branch_id="dummy", branch_name="dummy", role="BM")
    try:
        data = PortfolioService.get_portfolio_data_for_scope(
            uow, scope, selected_branch="All", selected_officer="All", selected_group="All",
            selected_product="All", start_date=date.today(), end_date=date.today()
        )
        print("Success")
    except Exception as e:
        import traceback
        traceback.print_exc()
