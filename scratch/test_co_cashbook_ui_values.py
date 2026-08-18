import sys, os
from datetime import date
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.financial_reconciliation_service import FinancialReconciliationService

def test_co_cashbook_breakdown():
    print("==================================================")
    print("🔍 TESTING CO CASHBOOK UI BREAKDOWN & ZERO OUTFLOWS")
    print("==================================================")

    date_str = "2026-08-18"

    with SupabaseUnitOfWork() as uow:
        # Resolve Branch & CO2
        b_res = uow.client.table("branches").select("branch_id").eq("name", "Ogijo").execute()
        branch_id = b_res.data[0]["branch_id"]

        u_res = uow.client.table("app_users").select("id, username").eq("username", "CO2").execute()
        o_id = u_res.data[0]["id"]

        # Run the exact query as app.py
        d_act = w_act_12 = w_act_24 = m_act = 0.0
        res_l = uow.client.table("loans").select("loan_amount, active_credit, extra_fields, loan_products(name, repayment_cycle)") \
            .eq("officer_id", o_id).eq("branch_id", branch_id).eq("disbursement_date", date_str) \
            .in_("status", ["Active", "Approved", "Completed"]).execute()

        for l in (res_l.data or []):
            if isinstance(l.get("extra_fields"), dict) and l["extra_fields"].get("is_legacy") is True:
                continue
            act_cr = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
            lp = l.get("loan_products") or {}
            p_name = str(lp.get("name") or "").lower()
            cycle = lp.get("repayment_cycle") or ("Daily" if "daily" in p_name else "Weekly")
            if cycle == "Daily":
                d_act += act_cr
            elif cycle == "Weekly":
                if "24" in p_name: w_act_24 += act_cr
                else: w_act_12 += act_cr
            elif cycle == "Monthly":
                m_act += act_cr
            else:
                w_act_12 += act_cr

        print(f"Active Loan (Daily):    ₦{d_act:,.2f}")
        print(f"Active Loan (12 Weeks): ₦{w_act_12:,.2f}")
        print(f"Active Loan (24 Weeks): ₦{w_act_24:,.2f}")
        print(f"Active Loan (Monthly):  ₦{m_act:,.2f}")

        assert d_act == 0.0, f"Expected 0, got {d_act}"
        assert w_act_12 == 0.0, f"Expected 0, got {w_act_12}"
        assert w_act_24 == 0.0, f"Expected 0, got {w_act_24}"
        assert m_act == 0.0, f"Expected 0, got {m_act}"

        # Check projection table
        uow.cashbook.rebuild_projection(branch_id, date(2026, 8, 18), officer_id=o_id)
        res_co = uow.client.table("co_cashbooks").select("*").eq("date", date_str).eq("branch_id", branch_id).eq("officer_id", o_id).execute()
        cb = res_co.data[0]
        print(f"\nCO Cashbook Database Projection for CO2:")
        print(f"  Total Inflows:  ₦{cb['total_inflows']:,.2f}")
        print(f"  Total Outflows: ₦{cb['total_outflows']:,.2f}")
        print(f"  Closing Bal:    ₦{cb['closing_balance']:,.2f}")

        assert cb['total_outflows'] == 0.0
        assert cb['closing_balance'] == 0.0

        recon = FinancialReconciliationService.verify_6way_financial_integrity(uow, branch_id, date(2026, 8, 18))
        print(f"\n6-Way Financial Recon: {recon['status_emoji']} {recon['status_text']}")
        assert recon['is_balanced'] is True

    print("\n🎉 ALL TESTS PASSED! CO CASHBOOK ZERO-OUTFLOW VERIFIED.")
    print("==================================================")

if __name__ == "__main__":
    test_co_cashbook_breakdown()
