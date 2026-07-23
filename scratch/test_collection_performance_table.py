import toml
import json
from supabase import create_client

secrets = toml.load('.streamlit/secrets.toml')
url = secrets["SUPABASE_URL"]
key = secrets["SUPABASE_KEY"]
supabase = create_client(url, key)

print("--- TESTING COLLECTION_PERFORMANCE TABLE IN SUPABASE ---")
try:
    res = supabase.table("collection_performance").select("*").limit(1).execute()
    print("[EXISTS] Table 'collection_performance' exists! Data:", res.data)
except Exception as e:
    print("[NOT FOUND] Table 'collection_performance' not found! Error:", e)
