from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def test_savings_metric():
    with SupabaseUnitOfWork() as uow:
        # Get one of the officers
        user_res = uow.client.table("app_users").select("id, username, branch_id").limit(1).execute()
        user = user_res.data[0]
        u_id = user["id"]
        u_name = user["username"]
        b_id = user["branch_id"]

        co_data = DashboardService.get_co_dashboard_data(uow, "Ogijo", u_name, officer_id=u_id, branch_id=b_id)
        sav = co_data.get("savings", {})
        print("=== TODAY'S SAVINGS METRIC TEST ===")
        print(f"Officer: {u_name} ({u_id})")
        print(f"Savings Deposited: NGN {sav.get('deposited_amt', 0):,.2f} ({sav.get('deposited_clients', 0)} Clients)")
        print(f"Savings Withdrawn: NGN {sav.get('withdrawn_amt', 0):,.2f} ({sav.get('withdrawn_clients', 0)} Clients)")
        print(f"Net Savings: NGN {sav.get('net_savings', 0):,.2f}")

if __name__ == "__main__":
    test_savings_metric()
