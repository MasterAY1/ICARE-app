import toml
from supabase import create_client

with open(".streamlit/secrets.toml", "r") as f:
    secrets = toml.load(f)

url = secrets["SUPABASE_URL"]
key = secrets["SUPABASE_KEY"]
client = create_client(url, key)

try:
    res = client.table("loans").select("guarantor_name").limit(1).execute()
    print("Success:", res.data)
except Exception as e:
    print(f"Error details: {e}")
