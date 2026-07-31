import toml
from supabase import create_client

with open(".streamlit/secrets.toml", "r") as f:
    secrets = toml.load(f)

client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])
res = client.table("repayments").select("*").limit(1).execute()
if res.data:
    print("repayments columns:", list(res.data[0].keys()))
else:
    print("repayments table is empty or inaccessible")
