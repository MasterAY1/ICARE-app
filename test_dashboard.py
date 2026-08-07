import os
import sys
from dotenv import load_dotenv
sys.path.append(os.getcwd())
load_dotenv()

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def main():
    uow = SupabaseUnitOfWork()
    
    b_data = DashboardService.get_bm_dashboard_data(uow, "Test Branch")
    print("Branch dashboard data:", b_data.keys() if b_data else None)
    
    co_data = DashboardService.get_co_dashboard_data(uow, "Test Branch", "Test Officer")
    print("Officer dashboard data:", co_data.keys() if co_data else None)

if __name__ == "__main__":
    main()
