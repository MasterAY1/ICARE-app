import toml
from supabase import create_client

secrets = toml.load('.streamlit/secrets.toml')
supabase = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

print("--- TESTING AUDIT VIEWS QUERY ---")

# Test 1: Direct public query or schema("audit")
try:
    res = supabase.schema("audit").table("processing_fees").select("*").limit(5).execute()
    print("[SUCCESS] Query via schema('audit').table('processing_fees'):", len(res.data), "rows")
except Exception as e:
    print("[REST SCHEMA EXPOSURE NOTICE]:", e)

try:
    res2 = supabase.table("fees").select("*").eq("fee_type", "PROCESSING_FEE").limit(5).execute()
    print("[SUCCESS] Query via public.fees fallback:", len(res2.data), "rows")
except Exception as e:
    print("[ERROR public.fees]:", e)
