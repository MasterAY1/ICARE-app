import toml
from supabase import create_client

def inspect_all_dates():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    print("=== INDIVIDUAL SAVINGS (All Dates) ===")
    res_ind = client.table("individual_savings").select("*").order("created_at", desc=True).limit(20).execute()
    for s in (res_ind.data or []):
        print(f"Date: {s.get('posting_date')} | Client: {s.get('client_id')} | Officer: {s.get('officer_id')} | Dep: {s.get('deposit_amount')} | Wd: {s.get('withdrawal_amount')} | Remarks: {s.get('remarks')}")

    print("\n=== GROUP SAVINGS (All Dates) ===")
    res_grp = client.table("group_savings").select("*").order("created_at", desc=True).limit(20).execute()
    for g in (res_grp.data or []):
        print(f"Date: {g.get('posting_date')} | Group: {g.get('group_id')} | Officer: {g.get('officer_id')} | Dep: {g.get('deposit_amount')} | Wd: {g.get('withdrawal_amount')} | Remarks: {g.get('remarks')}")

if __name__ == "__main__":
    inspect_all_dates()
