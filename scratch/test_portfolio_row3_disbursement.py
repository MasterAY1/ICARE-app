import sys, os
from datetime import date
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope
from services.financial_reconciliation_service import FinancialReconciliationService

def test_row3_disbursement_summary():
    print("==================================================")
    print("🔍 TESTING PORTFOLIO ROW 3 DISBURSEMENT SUMMARY (OPTION B)")
    print("==================================================")

    with SupabaseUnitOfWork() as uow:
        b_res = uow.client.table("branches").select("branch_id, name").eq("name", "Ogijo").execute()
        b_id = b_res.data[0]["branch_id"]
        b_name = b_res.data[0]["name"]

        u_res = uow.client.table("app_users").select("id, username").eq("username", "CO2").execute()
        u_id = u_res.data[0]["id"]

        # 1. Test for CO2
        scope_co2 = RBACScope(
            user_id=u_id,
            username="CO2",
            role="CO",
            branch_id=b_id,
            branch_name=b_name,
            scope_level="OFFICER"
        )
        port_co2 = PortfolioService.get_portfolio_data_for_scope(
            uow=uow,
            scope=scope_co2,
            start_date=date(2026, 8, 1),
            end_date=date(2026, 8, 31)
        )
        d_sum_co2 = port_co2["summary"]["disbursement_summary"]
        print(f"CO2 Portfolio Row 3 (Option B):")
        print(f"  Loans Disbursed in August:  {d_sum_co2['count']} Loans ({d_sum_co2['client_count']} Clients)")
        print(f"  Total Amount Disbursed:     ₦{d_sum_co2['amount']:,.2f}")
        print(f"  Total Active Credit (Row 4): ₦{port_co2['summary']['total_active_credit']:,.2f} ({port_co2['summary']['active_loans_count']} Loans)")

        assert d_sum_co2['count'] == 0, f"Expected 0 live disbursements on Day 0, got {d_sum_co2['count']}"
        assert d_sum_co2['amount'] == 0.0, f"Expected 0.00, got {d_sum_co2['amount']}"
        assert port_co2['summary']['active_loans_count'] == 13, f"Expected 13 active loans in portfolio, got {port_co2['summary']['active_loans_count']}"

        # 2. Test for Branch Manager
        scope_bm = RBACScope(
            username="BM_Ogijo",
            role="Branch Manager",
            branch_id=b_id,
            branch_name=b_name,
            scope_level="BRANCH"
        )
        port_bm = PortfolioService.get_portfolio_data_for_scope(
            uow=uow,
            scope=scope_bm,
            start_date=date(2026, 8, 1),
            end_date=date(2026, 8, 31)
        )
        d_sum_bm = port_bm["summary"]["disbursement_summary"]
        print(f"\nBM_Ogijo Portfolio Row 3 (Option B):")
        print(f"  Loans Disbursed in August:  {d_sum_bm['count']} Loans ({d_sum_bm['client_count']} Clients)")
        print(f"  Total Amount Disbursed:     ₦{d_sum_bm['amount']:,.2f}")
        print(f"  Total Active Credit (Row 4): ₦{port_bm['summary']['total_active_credit']:,.2f} ({port_bm['summary']['active_loans_count']} Loans)")

        assert d_sum_bm['count'] == 0
        assert d_sum_bm['amount'] == 0.0
        assert port_bm['summary']['active_loans_count'] == 13

        # 3. 6-Way Financial Recon
        recon = FinancialReconciliationService.verify_6way_financial_integrity(uow, b_id, date(2026, 8, 18))
        print(f"\n6-Way Financial Recon: {recon['status_emoji']} {recon['status_text']}")
        assert recon['is_balanced'] is True

    print("\n🎉 ALL TESTS PASSED! ROW 3 OPTION B VERIFIED.")
    print("==================================================")

if __name__ == "__main__":
    test_row3_disbursement_summary()
