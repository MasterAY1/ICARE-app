"""
ICARE Microfinance — Seed Users Script
Run this ONCE to populate the app_users table with initial hashed credentials.
Usage: python seed_users.py
"""
import hashlib
import secrets
import os
import sys

# Add parent directory for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def hash_password(password: str, salt: str = None) -> tuple:
    """Hash a password with SHA-256 + salt. Returns (hash, salt)."""
    if salt is None:
        salt = secrets.token_hex(32)
    combined = f"{salt}{password}".encode('utf-8')
    password_hash = hashlib.sha256(combined).hexdigest()
    return password_hash, salt

def verify_password(password: str, stored_hash: str, stored_salt: str) -> bool:
    """Verify a password against stored hash and salt."""
    computed_hash, _ = hash_password(password, stored_salt)
    return computed_hash == stored_hash

# Default users to seed
SEED_USERS = [
    {"username": "admin", "password": "Icare@2026", "display_name": "System Admin", "role": "Admin", "branch": "Global"},
    {"username": "bm",    "password": "Icare@2026", "display_name": "Lagos Manager", "role": "BM",    "branch": "Lagos"},
    {"username": "co1",   "password": "Icare@2026", "display_name": "CO1",           "role": "Officer","branch": "Lagos"},
    {"username": "co2",   "password": "Icare@2026", "display_name": "CO2",           "role": "Officer","branch": "Lagos"},
]

if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv('.streamlit/secrets.toml')
    
    from supabase import create_client
    url = os.environ.get('SUPABASE_URL')
    key = os.environ.get('SUPABASE_KEY')
    
    if not url or not key:
        # Try streamlit secrets format
        import toml
        with open('.streamlit/secrets.toml', 'r') as f:
            secrets_data = toml.load(f)
        url = secrets_data.get('SUPABASE_URL')
        key = secrets_data.get('SUPABASE_KEY')
    
    supabase = create_client(url, key)
    
    print("🔐 Seeding users with hashed passwords...")
    
    for user in SEED_USERS:
        pw_hash, salt = hash_password(user["password"])
        
        record = {
            "username": user["username"],
            "password_hash": pw_hash,
            "salt": salt,
            "display_name": user["display_name"],
            "role": user["role"],
            "branch": user["branch"],
            "is_active": True
        }
        
        try:
            # Upsert to handle re-runs
            supabase.table("app_users").upsert(record, on_conflict="username").execute()
            print(f"  ✅ {user['username']} ({user['role']}) — seeded successfully")
        except Exception as e:
            print(f"  ❌ {user['username']} — Error: {e}")
    
    print(f"\n🎉 Done! All users seeded with default password: Icare@2026")
    print("⚠️  Change passwords immediately after first login!")
