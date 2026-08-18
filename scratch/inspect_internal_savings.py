import toml
from supabase import create_client

def inspect_internal_savings():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    res_m = client.table("internal_savings").select("*").execute()
    print("=== INTERNAL SAVINGS ROWS ===")
    for r in (res_m.data or []):
        print(r)

if __name__ == "__main__":
    inspect_internal_savings()
