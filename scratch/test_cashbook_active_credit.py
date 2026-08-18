import sys, os
from datetime import date
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

def test_today_cashbook_active_credit():
    print("==================================================")
    print("🔍 TESTING CO CASHBOOK ACTIVE CREDIT PROJECTIONS")
    print("==================================================")

    today_date = date(2026, 8, 18)
    with SupabaseUnitOfWork() as uow:
        # Check Ogijo branch
        b_res = uow.client.table("branches").select("branch_id, name").eq("name", "Ogijo").execute()
        branch_id = b_res.data[0]["branch_id"]

        users_res = uow.client.table("app_users").select("id, username, full_name").eq("branch_id", branch_id).execute()
        
        for u in (users_res.data or []):
            o_id = u["id"]
            uname = u["username"]

            cb_data = CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, o_id, today_date)
            if cb_data:
                weekly_act = cb_data.get("weekly_active", 0.0)
                daily_act = cb_data.get("daily_active", 0.0)
                asset_cr_sales = cb_data.get("asset_credit_sales", 0.0)
                bank_wd = cb_data.get("bank_withdrawal", 0.0)
                tot_inflows = cb_data.get("total_inflows", 0.0)
                tot_outflows = cb_data.get("total_outflows", 0.0)
                closing = cb_data.get("closing_balance", 0.0)

                print(f"Officer: {uname:15} | Weekly Active: ₦{weekly_act:,.2f} | Asset Credit Sales: ₦{asset_cr_sales:,.2f} | Bank W/D: ₦{bank_wd:,.2f} | Total Inflows: ₦{tot_inflows:,.2f} | Closing: ₦{closing:,.2f}")

    print("==================================================")

if __name__ == "__main__":
    test_today_cashbook_active_credit()
