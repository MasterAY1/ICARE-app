import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork

def test_collections_and_withdrawals_client_loading():
    print("==================================================")
    print("🔍 TESTING CLIENT LOADING ON COLLECTIONS & WITHDRAWALS")
    print("==================================================")

    with SupabaseUnitOfWork() as uow:
        # Check Ogijo branch
        b_res = uow.client.table("branches").select("branch_id, name").eq("name", "Ogijo").execute()
        branch_id = b_res.data[0]["branch_id"]

        users_res = uow.client.table("app_users").select("id, username, full_name").eq("branch_id", branch_id).execute()
        
        for u in (users_res.data or []):
            o_id = u["id"]
            uname = u["username"]

            # Query without the broken .eq("status", "Active")
            res_c = uow.client.table("clients").select(
                "client_id, client_code, name, status, status_id, group_id, groups(name), client_memberships(groups(name)), client_statuses(name)"
            ).eq("officer_id", o_id).execute()

            clients = res_c.data or []
            active_rel_clients = [
                c for c in clients 
                if ((c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")) not in ["Closed", "Suspended"]
            ]

            print(f"Officer: {uname:15} | Total Clients: {len(clients):3} | Active Relationship: {len(active_rel_clients):3}")

    print("==================================================")

if __name__ == "__main__":
    test_collections_and_withdrawals_client_loading()
