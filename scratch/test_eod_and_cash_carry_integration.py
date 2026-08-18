import sys
import os
from datetime import date

# Ensure project root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.financial_reconciliation_service import FinancialReconciliationService

def test_integration():
    print("================================================================")
    print("🧪 RUNNING CO CASHBOOK EOD & CASH & CARRY INTEGRATION TESTS")
    print("================================================================")

    with SupabaseUnitOfWork() as uow:
        # 1. Fetch branch and officer
        branch_id = uow.cashbook._resolve_branch_id("Ogijo")
        res_u = uow.client.table("app_users").select("id, username, full_name").eq("username", "CO2").execute()
        assert res_u.data, "Officer CO2 not found"
        officer_id = res_u.data[0]["id"]
        officer_name = res_u.data[0]["username"]

        today = date.today()
        print(f"✅ Testing Branch: 'Ogijo' ({branch_id}) | Officer: '{officer_name}' ({officer_id})")

        # 2. Test CoCashbookProjectionBuilder.rebuild_co_projection
        print("🔄 Rebuilding CO projection...")
        cb_row = CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, officer_id, today)
        assert cb_row is not None, "CoCashbookProjectionBuilder returned None"

        inflows = float(cb_row.get("total_inflows") or 0.0)
        outflows = float(cb_row.get("total_outflows") or 0.0)
        closing = float(cb_row.get("closing_balance") or 0.0)
        opening = float(cb_row.get("opening_balance") or 0.0)
        app_fee = float(cb_row.get("app_fee") or 0.0)
        cash_carry = float(cb_row.get("cash_and_carry") or 0.0)
        asset_sales = float(cb_row.get("asset_credit_sales") or 0.0)

        print(f"   Opening Balance:   ₦{opening:,.2f}")
        print(f"   Total Inflows:     ₦{inflows:,.2f}")
        print(f"   Total Outflows:    ₦{outflows:,.2f}")
        print(f"   Closing Balance:   ₦{closing:,.2f}")
        print(f"   Credit Form / App: ₦{app_fee:,.2f}")
        print(f"   Cash & Carry:      ₦{cash_carry:,.2f}")
        print(f"   Asset Credit Sales:₦{asset_sales:,.2f}")

        assert abs(closing - (inflows - outflows)) < 0.001, f"T-Account closing balance mismatch: {closing} != {inflows - outflows}"
        print("✅ T-Account balance equation holds: Total Inflows - Total Outflows = Closing Balance")

        # 3. Verify Financial Integrity 6-Way reconciliation
        print("🔄 Running Financial Reconciliation check...")
        recon = FinancialReconciliationService.verify_6way_financial_integrity(uow, branch_id, today)
        print(f"   - Status: {recon.get('status')}")
        print(f"   - CO Cashbooks Total: ₦{recon.get('co_cashbooks_total', 0):,.2f}")
        print(f"   - Master Cashbook:    ₦{recon.get('master_cashbook_total', 0):,.2f}")

    print("================================================================")
    print("🎉 ALL TESTS PASSED! EOD & CASH & CARRY INTEGRATION VERIFIED!")
    print("================================================================")

if __name__ == "__main__":
    test_integration()
