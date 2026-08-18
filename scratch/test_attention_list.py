import sys, os
from datetime import date
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.dashboard_service import DashboardService

def test_attention_list():
    print("==================================================")
    print("🔍 AUDITING TODAY'S ATTENTION LIST ON CO DASHBOARD")
    print("==================================================")

    today = date.today()
    print(f"Target Date: {today} ({today.strftime('%A')})")

    with SupabaseUnitOfWork() as uow:
        # Check active loans and scheduled repayments due today
        b_res = uow.client.table("branches").select("branch_id, name").eq("name", "Ogijo").execute()
        assert b_res.data, "Branch Ogijo not found"
        branch_id = b_res.data[0]["branch_id"]

        users_res = uow.client.table("app_users").select("id, username, full_name").eq("branch_id", branch_id).execute()
        for u in (users_res.data or []):
            o_id = u["id"]
            uname = u["username"]
            data = DashboardService.get_co_dashboard_data(uow, "Ogijo", uname, branch_id=branch_id, officer_id=o_id, target_date=today)
            att_df = data.get("attention_list")
            mp_df = data.get("meeting_portfolio")
            print(f"\n--- Officer: {uname} ({u.get('full_name')}) ---")
            print(f"Total Meeting Groups Today: {len(mp_df)}")
            print(f"Total Attention List Rows: {len(att_df)}")
            if not att_df.empty:
                print(att_df[["Client Code", "Client Name", "Group", "Expected", "Paid", "Outstanding", "Reason"]].to_string(index=False))
            else:
                print("Attention list is empty (either no active loans scheduled for today, or all paid).")

    print("\n==================================================")
    print("✅ TEST COMPLETE")
    print("==================================================")

if __name__ == "__main__":
    test_attention_list()
