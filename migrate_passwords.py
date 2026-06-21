import os
import bcrypt
from supabase import create_client

def run_migration():
    # Load environment variables or define them here for local run
    # For Streamlit secrets compatibility locally, let's load from .streamlit/secrets.toml
    url = ""
    key = ""
    
    try:
        import toml
        with open(".streamlit/secrets.toml", "r") as f:
            secrets = toml.load(f)
            url = secrets.get("SUPABASE_URL")
            key = secrets.get("SUPABASE_KEY")
    except:
        url = os.environ.get("SUPABASE_URL")
        key = os.environ.get("SUPABASE_KEY")
    
    if not url or not key:
        print("Please set SUPABASE_URL and SUPABASE_KEY in .streamlit/secrets.toml or as environment variables.")
        return
        
    supabase = create_client(url, key)
    
    print("Fetching all users from app_users...")
    res = supabase.table("app_users").select("id, username, password").execute()
    
    if not res.data:
        print("No users found.")
        return
        
    users = res.data
    print(f"Found {len(users)} users. Hashing passwords...")
    
    success_count = 0
    
    for user in users:
        username = user['username']
        current_pw = user['password']
        
        # Skip if already hashed (bcrypt hashes start with $2a$, $2b$, or $2y$)
        if str(current_pw).startswith("$2"):
            print(f"Skipping {username} (already hashed)")
            continue
            
        try:
            # Hash password
            hashed = bcrypt.hashpw(str(current_pw).encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
            
            # Update in Supabase
            supabase.table("app_users").update({"password": hashed}).eq("id", user['id']).execute()
            print(f"Successfully hashed password for: {username}")
            success_count += 1
        except Exception as e:
            print(f"Failed for {username}: {e}")
            
    print(f"Migration complete! {success_count} passwords successfully hashed.")

if __name__ == "__main__":
    run_migration()
