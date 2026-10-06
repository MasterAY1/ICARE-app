import os
import sys
from dotenv import load_dotenv
sys.path.append(os.getcwd())
load_dotenv()

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope

def main():
    uow = SupabaseUnitOfWork()
    scope = RBACScope(scope_level="SYSTEM", user_id="system", role="System Admin", username="sys")
    
    data = PortfolioService.get_portfolio_data_for_scope(uow, scope)
    print("Total Active Credit:", data['summary']['total_active_credit'])
    print("Total Outstanding Balance:", data['summary']['total_outstanding_balance'])

if __name__ == "__main__":
    main()
