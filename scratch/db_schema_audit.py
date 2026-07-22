import toml
import json
import urllib.request
from supabase import create_client

secrets = toml.load('.streamlit/secrets.toml')
url = secrets["SUPABASE_URL"]
key = secrets["SUPABASE_KEY"]
supabase = create_client(url, key)

print("--- LIVE SUPABASE SCHEMA AUDIT VIA OPENAPI ---")

spec_url = f"{url}/rest/v1/"
req = urllib.request.Request(spec_url)
req.add_header("apikey", key)
req.add_header("Authorization", f"Bearer {key}")
req.add_header("Accept", "application/openapi+json")

try:
    with urllib.request.urlopen(req) as response:
        spec = json.loads(response.read().decode())
    print("Successfully fetched OpenAPI schema spec from Supabase!")
    
    definitions = spec.get("definitions", {})
    tables = sorted(list(definitions.keys()))
    print(f"\nFound {len(tables)} tables/views in live schema:")
    
    table_details = {}
    
    for t in tables:
        props = definitions[t].get("properties", {})
        required = definitions[t].get("required", [])
        
        cols = []
        for col_name, col_meta in props.items():
            cols.append({
                "name": col_name,
                "type": col_meta.get("type"),
                "format": col_meta.get("format"),
                "description": col_meta.get("description")
            })
            
        row_count = 0
        try:
            res_c = supabase.table(t).select("count", count="exact").limit(1).execute()
            row_count = res_c.count if res_c.count is not None else len(res_c.data or [])
        except Exception as ex:
            row_count = f"Error: {ex}"

        table_details[t] = {
            "row_count": row_count,
            "description": definitions[t].get("description", ""),
            "required_fields": required,
            "columns": cols
        }
        print(f" - {t}: {row_count} rows, {len(cols)} columns")

    with open("scratch/live_db_audit.json", "w") as f:
        json.dump(table_details, f, indent=2)

    print("\nSaved full live database schema to scratch/live_db_audit.json")

except Exception as e:
    print("Error fetching OpenAPI spec:", e)
