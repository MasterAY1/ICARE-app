import sys, os
from datetime import date
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope

def test_portfolio_row1():
    print("==================================================")
    print("🔍 TESTING PORTFOLIO ROW 1 CLIENT LIFECYCLE METRICS")
    print("==================================================")

    with SupabaseUnitOfWork() as uow:
        b_res = uow.client.table("branches").select("branch_id, name").eq("name", "Ogijo").execute()
        branch_id = b_res.data[0]["branch_id"]

        users_res = uow.client.table("app_users").select("id, username, branch_id").eq("branch_id", branch_id).execute()

        for u in (users_res.data or []):
            u_id = u["id"]
            uname = u["username"]
            urole = "BM" if "BM" in uname else ("AM" if "AM" in uname else ("Master" if "Master" in uname else "CO"))

            scope_lvl = "OFFICER" if urole == "CO" else ("BRANCH" if urole == "BM" else "INSTITUTION")
            scope = RBACScope(
                user_id=u_id,
                role=urole,
                branch_id=branch_id,
                username=uname,
                scope_level=scope_lvl
            )

            p_data = PortfolioService.get_portfolio_data_for_scope(
                uow=uow,
                scope=scope,
                selected_branch="All",
                selected_officer="All",
                selected_group="All",
                selected_product="All",
                start_date=date(2026, 8, 1),
                end_date=date(2026, 8, 31)
            )

            s = p_data["summary"]
            tot = s.get("total_clients", 0)
            reg = s.get("registered_clients", 0)
            act = s.get("active_clients", 0)
            sav_only = s.get("savings_only_clients", 0)
            comp = s.get("completed_clients", 0)
            pend = s.get("pending_loan_clients", 0)
            dorm = s.get("dormant_clients", 0)

            sum_breakdown = reg + act + sav_only + comp + pend + dorm
            is_additive = (sum_breakdown == tot)

            print(f"Role/User: {uname:10} ({urole:7}) | Total: {tot:3} | Reg: {reg:3} | On Loan: {act:2} | Sav Only: {sav_only:2} | Comp: {comp:2} | Additive: {is_additive}")

    print("==================================================")

if __name__ == "__main__":
    test_portfolio_row1()
