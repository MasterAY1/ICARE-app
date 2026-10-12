"""
Script: scripts/maintenance/migrate_branch_prefixed_officers.py
Purpose: Migrate Credit Officer usernames to branch-prefixed convention (OGI_CO1..4, IKD_CO1..4)
to eliminate multi-branch account collisions.
"""

import sys
import os
import bcrypt

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
from database.connection import get_supabase_client

IKORODU_BRANCH_ID = "4ab6e1c4-6783-4bb6-904f-9da51cfab505"
OGIJO_BRANCH_ID = "997d504e-7f5c-4772-887d-fdd5a4c1183b"
CREDIT_OFFICER_ROLE_ID = "bd8790ee-c0eb-485a-8b6a-93f54519965d"

def hash_pw(pw: str) -> str:
    return bcrypt.hashpw(pw.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def migrate_officers():
    client = get_supabase_client()
    print("=" * 60)
    print("STARTING BRANCH-PREFIXED OFFICER MIGRATION")
    print("=" * 60)

    # 1. Fetch current users
    users = client.table("app_users").select("id, username, full_name, branch_id").execute().data
    user_map_by_username = {u["username"]: u for u in users}
    user_map_by_id = {u["id"]: u for u in users}

    # 2. Rename Ogijo officers
    ogijo_renames = {
        "CO1": "OGI_CO1",
        "CO2": "OGI_CO2",
        "CO3": "OGI_CO3",
        "CO4": "OGI_CO4",
    }

    for old_u, new_u in ogijo_renames.items():
        if old_u in user_map_by_username:
            target_user = user_map_by_username[old_u]
            uid = target_user["id"]
            print(f"[RENAME] Ogijo: {old_u} -> {new_u} (User ID: {uid}, Name: {target_user['full_name']})")
            res = client.table("app_users").update({"username": new_u}).eq("id", uid).execute()
            if res.data:
                print(f"  -> Successfully updated to {new_u}")
            else:
                print(f"  -> FAILED to update {old_u}")
        elif new_u in user_map_by_username:
            print(f"[EXISTS] {new_u} already present in database.")
        else:
            print(f"[WARN] Neither {old_u} nor {new_u} found in database.")

    # 3. Rename Ikorodu officer CO_Ikorodu -> IKD_CO1
    if "CO_Ikorodu" in user_map_by_username:
        ikd_u1 = user_map_by_username["CO_Ikorodu"]
        uid = ikd_u1["id"]
        print(f"[RENAME] Ikorodu: CO_Ikorodu -> IKD_CO1 (User ID: {uid}, Name: {ikd_u1['full_name']})")
        res = client.table("app_users").update({"username": "IKD_CO1"}).eq("id", uid).execute()
        if res.data:
            print(f"  -> Successfully updated to IKD_CO1")
        else:
            print(f"  -> FAILED to update CO_Ikorodu")
    elif "IKD_CO1" in user_map_by_username:
        print("[EXISTS] IKD_CO1 already present in database.")
    else:
        # Check by ID c0111111-1111-4111-8111-111111111111
        ikd_uid = "c0111111-1111-4111-8111-111111111111"
        if ikd_uid in user_map_by_id:
            print(f"[RENAME by ID] Updating user {ikd_uid} to IKD_CO1")
            client.table("app_users").update({"username": "IKD_CO1"}).eq("id", ikd_uid).execute()

    # 4. Provision missing Ikorodu officers (IKD_CO2, IKD_CO3, IKD_CO4)
    default_pw_hash = hash_pw("1234")
    ikorodu_officers_to_create = [
        {
            "id": "c0111111-1111-4111-8111-111111111112",
            "username": "IKD_CO2",
            "full_name": "Mr. Kehinde Popoola",
            "branch_id": IKORODU_BRANCH_ID,
            "password_hash": default_pw_hash,
            "is_active": True
        },
        {
            "id": "c0111111-1111-4111-8111-111111111113",
            "username": "IKD_CO3",
            "full_name": "Mrs. Funmilayo Alabi",
            "branch_id": IKORODU_BRANCH_ID,
            "password_hash": default_pw_hash,
            "is_active": True
        },
        {
            "id": "c0111111-1111-4111-8111-111111111114",
            "username": "IKD_CO4",
            "full_name": "Mr. Samuel Oladipo",
            "branch_id": IKORODU_BRANCH_ID,
            "password_hash": default_pw_hash,
            "is_active": True
        }
    ]

    for officer in ikorodu_officers_to_create:
        uname = officer["username"]
        # Check if user already exists by username or id
        exists = client.table("app_users").select("id").or_(f"username.eq.{uname},id.eq.{officer['id']}").execute().data
        if not exists:
            print(f"[CREATE] Provisioning {uname} ({officer['full_name']}) in Ikorodu branch...")
            res = client.table("app_users").insert(officer).execute()
            if res.data:
                print(f"  -> Successfully created user {uname}")
                # Assign role in user_roles
                role_res = client.table("user_roles").insert({
                    "user_id": officer["id"],
                    "role_id": CREDIT_OFFICER_ROLE_ID
                }).execute()
                print(f"  -> Assigned Credit Officer role: {role_res.data}")
            else:
                print(f"  -> FAILED to create user {uname}")
        else:
            print(f"[EXISTS] Officer {uname} already exists.")

    print("=" * 60)
    print("MIGRATION COMPLETED SUCCESSFULLY")
    print("=" * 60)

if __name__ == "__main__":
    migrate_officers()
