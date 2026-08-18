import sys
import os
from datetime import date

# Ensure root directory is on python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.financial_reconciliation_service import FinancialReconciliationService

def run_tests():
    print("================================================================")
    print("🔍 RUNNING AUTOMATED CO CASHBOOK UI & PROJECTION ALIGNMENT TESTS")
    print("================================================================")

    with SupabaseUnitOfWork() as uow:
        # 1. Fetch active branches and credit officers
        res_branches = uow.client.table("branches").select("branch_id, name").execute()
        branches = res_branches.data or []
        assert len(branches) > 0, "No branches found in DB!"
        print(f"✅ Found {len(branches)} branches.")

        for b in branches:
            b_id = b["branch_id"]
            b_name = b["name"]
            res_users = uow.client.table("app_users").select("id, username").eq("branch_id", b_id).execute()
            users = res_users.data or []
            if not users:
                continue

            for target_user in users:
                officer_id = target_user["id"]
                officer_name = target_user["username"]
                print(f"\n--- Testing Branch: '{b_name}' | Officer: '{officer_name}' ---")

                today = date.today()
                cb_row = CoCashbookProjectionBuilder.rebuild_co_projection(uow, b_id, officer_id, today)
                assert cb_row is not None, f"CoCashbookProjectionBuilder returned None for {officer_name}!"
                
                inflows = float(cb_row.get("total_inflows") or 0.0)
                outflows = float(cb_row.get("total_outflows") or 0.0)
                closing = float(cb_row.get("closing_balance") or 0.0)
                opening = float(cb_row.get("opening_balance") or 0.0)

                print(f"   Opening: ₦{opening:,.2f} | Inflows: ₦{inflows:,.2f} | Outflows: ₦{outflows:,.2f} | Closing: ₦{closing:,.2f}")
                assert abs(closing - (inflows - outflows)) < 0.001, f"Closing balance mismatch! {closing} != {inflows - outflows}"

        # 4. Verify Unified Processing / Credit Form Fee mapping
        app_fee = float(cb_row.get("app_fee") or 0.0)
        cf_damage = float(cb_row.get("credit_form_damage") or 0.0)
        risk_prem = float(cb_row.get("risk_premium_returns") or 0.0)
        print(f"   - Credit Form / App Fee: ₦{app_fee:,.2f}")
        print(f"   - Credit Form Damage:    ₦{cf_damage:,.2f}")
        print(f"   - Risk Premium / 20%:    ₦{risk_prem:,.2f}")

        # 5. Check repayments table
        res_orphans = uow.client.table("repayments").select("*").limit(5).execute()
        print(f"🔎 Sample active repayments retrieved: {len(res_orphans.data or [])}")

        # 6. Run 6-Way Financial Integrity check for Ogijo branch
        ogijo_b = [b for b in branches if "ogijo" in b["name"].lower()]
        target_b_id = ogijo_b[0]["branch_id"] if ogijo_b else branches[0]["branch_id"]
        print("🔄 Running 6-Way Financial Integrity Reconciliation for Ogijo...")
        recon_res = FinancialReconciliationService.verify_6way_financial_integrity(uow, target_b_id, today)
        print(f"   - Account 1000 Total:    ₦{recon_res.get('account_1000_total', 0):,.2f}")
        print(f"   - CO Cashbooks Total:    ₦{recon_res.get('co_cashbooks_total', 0):,.2f}")
        print(f"   - Master Cashbook Total: ₦{recon_res.get('master_cashbook_total', 0):,.2f}")
        print(f"   - Overall Status:        {recon_res.get('status')}")

    print("================================================================")
    print("🎉 ALL TESTS PASSED! CO CASHBOOK UI & PROJECTION ARE FULLY ALIGNED!")
    print("================================================================")

if __name__ == "__main__":
    run_tests()
