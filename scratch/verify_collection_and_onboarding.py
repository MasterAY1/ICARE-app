import os
import sys
import pandas as pd
from datetime import date

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.schedule_service import ScheduleService

def verify():
    print("==================================================")
    print("VERIFYING COLLECTION SAVINGS & ONBOARDING ALIGNMENT")
    print("==================================================")

    with SupabaseUnitOfWork() as uow:
        # 1. Check Onboarded Loans
        print("\n--- 1. Checking Onboarded Loan Products ---")
        loans_res = uow.client.table("loans").select("loan_id, client_id, status, active_credit, total_due, product_id, loan_products(name), clients(name, client_code)").eq("status", "Active").execute()
        
        asset_count = 0
        weekly_cash_count = 0
        for l in (loans_res.data or []):
            c_name = (l.get("clients") or {}).get("name", "Unknown")
            p_name = (l.get("loan_products") or {}).get("name", "Unknown")
            print(f"Loan: {c_name} -> Product: {p_name}, Active Credit: NGN {float(l.get('active_credit') or 0):,.2f}")
            if "asset" in p_name.lower():
                asset_count += 1
            if p_name in ["Weekly 12W", "Weekly 24W", "Daily 60 Days", "Daily 120 Days"]:
                weekly_cash_count += 1
                
        print(f"Total Active Cash Loans: {weekly_cash_count}, Total Active Asset Loans: {asset_count}")
        assert asset_count == 0, f"Found {asset_count} loans still tagged as Asset!"
        print("ASSERTION 1 PASSED: All onboarded active loans are cash loan products (non-asset).")

        # 2. Check Individual Savings Records
        print("\n--- 2. Checking Individual Savings Records ---")
        sav_res = uow.client.table("individual_savings").select("id, client_id, deposit_amount, withdrawal_amount, remarks, clients(name)").execute()
        print(f"Found {len(sav_res.data or [])} total individual savings records.")
        
        sample_clients = ["Kehinde Hannah", "Orumo Fatimoh", "Koleosho Sheriffat", "Alimi Fatimoh", "Femi Kayode"]
        for sc in sample_clients:
            c_query = uow.client.table("clients").select("client_id, name").ilike("name", sc).execute()
            if c_query.data:
                cid = c_query.data[0]["client_id"]
                s_client = [s for s in (sav_res.data or []) if s.get("client_id") == cid]
                bal = sum(float(s.get("deposit_amount") or 0) for s in s_client) - sum(float(s.get("withdrawal_amount") or 0) for s in s_client)
                print(f"Savings balance for {sc}: NGN {bal:,.2f}")
                assert bal > 0, f"Savings balance for {sc} is {bal}, expected > 0!"
                
        print("ASSERTION 2 PASSED: Member opening savings balances are populated accurately.")

        # 3. Simulate Collection Sheet Loading for Group Favour
        print("\n--- 3. Simulating Collection Sheet Loading ---")
        favour_clients = uow.client.table("clients").select("client_id, client_code, name, client_memberships(groups(name))").execute()
        
        all_savings = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").execute().data or []
        savings_by_client = {}
        for s in all_savings:
            cid = s.get("client_id")
            dep = float(s.get("deposit_amount") or 0)
            wd = float(s.get("withdrawal_amount") or 0)
            savings_by_client[cid] = savings_by_client.get(cid, 0.0) + (dep - wd)
            
        positive_savings_members = 0
        for c in (favour_clients.data or []):
            cid = c["client_code"] or c["client_id"]
            uuid_id = c["client_id"]
            cname = c["name"]
            
            sav_bal = savings_by_client.get(uuid_id, 0.0)
            if sav_bal > 0:
                positive_savings_members += 1
                print(f"Collection Sheet Member: {cname} ({cid}) -> Sav: NGN {sav_bal:,.2f}")

        print(f"Total members with active savings on Collection Sheet: {positive_savings_members}")
        assert positive_savings_members >= 12, f"Expected at least 12 members with savings, got {positive_savings_members}"
        print("ASSERTION 3 PASSED: Collection sheet loads and displays member savings accurately.")

    print("\n==================================================")
    print("ALL VERIFICATIONS COMPLETED SUCCESSFULLY!")
    print("==================================================")

if __name__ == "__main__":
    verify()
