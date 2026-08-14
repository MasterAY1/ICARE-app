import os
import sys
import uuid
import datetime
import pandas as pd

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from database.repositories.unit_of_work import SupabaseUnitOfWork

def remediate():
    excel_path = "icare-group-member-onboarding-template.xlsx"
    print(f"Reading {excel_path}...")
    df_groups = pd.read_excel(excel_path, sheet_name="Groups", header=2)
    df_members = pd.read_excel(excel_path, sheet_name="Members", header=2)

    with SupabaseUnitOfWork() as uow:
        # 1. Fetch products
        p_res = uow.client.table("loan_products").select("product_id, name").execute()
        products = {p["name"]: p["product_id"] for p in p_res.data or []}
        
        prod_12w = products.get("Weekly 12W")
        prod_24w = products.get("Weekly 24W")
        prod_12w_asset = products.get("Weekly 12W Asset")
        prod_24w_asset = products.get("Weekly 24W Asset")

        print(f"Weekly 12W ID: {prod_12w}, Weekly 24W ID: {prod_24w}")
        print(f"Weekly 12W Asset ID: {prod_12w_asset}, Weekly 24W Asset ID: {prod_24w_asset}")

        # 2. Fix product_id on existing onboarded loans
        if prod_12w_asset and prod_12w:
            res_up12 = uow.client.table("loans").update({"product_id": prod_12w}).eq("product_id", prod_12w_asset).execute()
            print(f"Updated {len(res_up12.data or [])} loans from 'Weekly 12W Asset' to 'Weekly 12W'")

        if prod_24w_asset and prod_24w:
            res_up24 = uow.client.table("loans").update({"product_id": prod_24w}).eq("product_id", prod_24w_asset).execute()
            print(f"Updated {len(res_up24.data or [])} loans from 'Weekly 24W Asset' to 'Weekly 24W'")

        # 3. Load all clients and groups from DB
        clients_res = uow.client.table("clients").select("client_id, name, branch_id, officer_id, group_id").execute()
        client_name_map = {c["name"].strip().lower(): c for c in clients_res.data or []}

        groups_res = uow.client.table("groups").select("group_id, name, branch_id, officer_id").execute()
        group_name_map = {g["name"].strip().lower(): g for g in groups_res.data or []}

        base_date_str = "1970-01-01"

        # 4. Insert Group Opening Savings
        print("\n--- POPULATING GROUP OPENING SAVINGS ---")
        for _, row in df_groups.iterrows():
            g_name = str(row.get('Group Name*')).strip()
            g_sav = row.get('Group Savings')
            if pd.notna(g_sav) and float(g_sav) > 0 and g_name.lower() in group_name_map:
                g_info = group_name_map[g_name.lower()]
                gid = g_info["group_id"]
                amt = float(g_sav)

                # Check if already exists
                ex_res = uow.client.table("group_savings").select("id").eq("group_id", gid).eq("remarks", "Initial Onboarding Group Savings").execute()
                if not ex_res.data:
                    uow.client.table("group_savings").insert({
                        "id": str(uuid.uuid4()),
                        "group_id": gid,
                        "posting_date": base_date_str,
                        "branch_id": g_info["branch_id"],
                        "officer_id": g_info["officer_id"],
                        "deposit_amount": amt,
                        "withdrawal_amount": 0.0,
                        "reference": "ONBOARDING-GROUP-OPENING",
                        "remarks": "Initial Onboarding Group Savings"
                    }).execute()
                    print(f"Inserted Group Savings: NGN {amt:,.2f} for group {g_name}")
                else:
                    print(f"Group savings already present for group {g_name}")

        # 5. Insert Member Opening Savings
        print("\n--- POPULATING MEMBER OPENING SAVINGS ---")
        inserted_count = 0
        for _, row in df_members.iterrows():
            f_name = str(row.get('Full Name*')).strip()
            s_bal = row.get('Savings Balance*')
            if pd.notna(s_bal) and float(s_bal) > 0 and f_name.lower() in client_name_map:
                c_info = client_name_map[f_name.lower()]
                cid = c_info["client_id"]
                amt = float(s_bal)

                # Check if already exists
                ex_res = uow.client.table("individual_savings").select("id").eq("client_id", cid).eq("remarks", "Initial Onboarding Savings").execute()
                if not ex_res.data:
                    uow.client.table("individual_savings").insert({
                        "id": str(uuid.uuid4()),
                        "client_id": cid,
                        "posting_date": base_date_str,
                        "branch_id": c_info["branch_id"],
                        "officer_id": c_info["officer_id"],
                        "deposit_amount": amt,
                        "withdrawal_amount": 0.0,
                        "reference": "ONBOARDING-MEMBER-OPENING",
                        "remarks": "Initial Onboarding Savings"
                    }).execute()
                    inserted_count += 1
                    print(f"Inserted Individual Savings: NGN {amt:,.2f} for {f_name}")
                else:
                    # Update deposit_amount in case existing row had 0
                    uow.client.table("individual_savings").update({
                        "deposit_amount": amt,
                        "withdrawal_amount": 0.0,
                        "posting_date": base_date_str,
                        "branch_id": c_info["branch_id"],
                        "officer_id": c_info["officer_id"]
                    }).eq("id", ex_res.data[0]["id"]).execute()
                    print(f"Updated Individual Savings: NGN {amt:,.2f} for {f_name}")

        print(f"\nCompleted! Total new individual savings records inserted: {inserted_count}")

if __name__ == "__main__":
    remediate()
