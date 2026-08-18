import toml
import json
from datetime import date
from supabase import create_client

def inspect_all_savings():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    today_str = date.today().isoformat()
    print(f"=== INSPECTING SAVINGS TABLES FOR TODAY ({today_str}) ===")

    # 1. Individual Savings
    res_ind = client.table("individual_savings").select("*").eq("posting_date", today_str).execute()
    ind_data = res_ind.data or []
    print(f"Individual Savings Today ({len(ind_data)}):")
    for s in ind_data:
        print(f"  ID: {s.get('id')} | Client: {s.get('client_id')} | Officer: {s.get('officer_id')} | Dep: {s.get('deposit_amount')} | Wd: {s.get('withdrawal_amount')} | Ref: {s.get('reference')} | Remarks: {s.get('remarks')}")

    # 2. Group Savings
    res_grp = client.table("group_savings").select("*").eq("posting_date", today_str).execute()
    grp_data = res_grp.data or []
    print(f"\nGroup Savings Today ({len(grp_data)}):")
    for g in grp_data:
        print(f"  ID: {g.get('id')} | Group: {g.get('group_id')} | Officer: {g.get('officer_id')} | Dep: {g.get('deposit_amount')} | Wd: {g.get('withdrawal_amount')} | Remarks: {g.get('remarks')}")

    # 3. Internal Savings (Misc Savings)
    res_misc = client.table("internal_savings").select("*").eq("posting_date", today_str).execute()
    misc_data = res_misc.data or []
    print(f"\nMisc Savings (internal_savings) Today ({len(misc_data)}):")
    for m in misc_data:
        print(f"  ID: {m.get('id')} | Branch: {m.get('branch_id')} | Officer: {m.get('officer_id')} | Dep: {m.get('deposit_amount')} | Wd: {m.get('withdrawal_amount')} | Remarks: {m.get('remarks')}")

    # 4. Check all users to see officer IDs
    res_users = client.table("app_users").select("id, username, role, branch_id").execute()
    print(f"\nApp Users:")
    for u in (res_users.data or []):
        print(f"  User: {u.get('username')} | ID: {u.get('id')} | Role: {u.get('role')}")

if __name__ == "__main__":
    inspect_all_savings()
