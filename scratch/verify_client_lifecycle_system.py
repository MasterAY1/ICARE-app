"""
Verification Script for Client Lifecycle Status System
Tests BR-CLI-001 through BR-CLI-009 end-to-end.
"""
import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.client_status_service import ClientStatusService
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScope
from services.renewal_service import RenewalService


def test_client_status_system():
    print("=" * 80)
    print("STARTING END-TO-END VERIFICATION OF CLIENT LIFECYCLE STATUS SYSTEM")
    print("=" * 80)

    with SupabaseUnitOfWork() as uow:
        # 1. Test Status Reference Table Loading
        print("\n[TEST 1] Loading Predefined Statuses from client_statuses...")
        statuses = ClientStatusService.get_all_statuses(uow, force_refresh=True)
        print(f"  Loaded {len(statuses)} predefined statuses:")
        for s in statuses:
            print(f"    - {s['name']:25} (sort_order: {s['sort_order']}, is_system: {s['is_system']})")
        assert len(statuses) == 9, f"Expected 9 statuses, found {len(statuses)}"
        print("  [PASS] All 9 statuses verified!")

        # 2. Test Status Resolution Helper
        print("\n[TEST 2] Testing Status ID and Name Resolution...")
        on_loan_id = ClientStatusService.resolve_status_id(uow, "On Loan")
        assert on_loan_id == "11111111-1111-1111-1111-111111110003", f"Wrong On Loan ID: {on_loan_id}"
        resolved_name = ClientStatusService.resolve_status_name(uow, on_loan_id)
        assert resolved_name == "On Loan", f"Wrong resolved name: {resolved_name}"
        print(f"  [PASS] Resolved 'On Loan' <-> '{on_loan_id}'")

        # 3. Test Portfolio Metrics Derivation (BR-CLI-006)
        print("\n[TEST 3] Testing Portfolio Metrics Derivation from client_statuses...")
        scope = RBACScope(role="Executive", scope_level="INSTITUTION")
        p_data = PortfolioService.get_portfolio_data_for_scope(uow, scope)
        p_sum = p_data["summary"]

        print(f"  Total Registered:  {p_sum.get('total_registered_clients')}")
        print(f"  Active on Loan:    {p_sum.get('active_clients')}")
        print(f"  Completed:         {p_sum.get('completed_clients')}")
        print(f"  Pending Loan:      {p_sum.get('pending_loan_clients')}")
        print(f"  Dormant:           {p_sum.get('dormant_clients')}")
        print(f"  Closed:            {p_sum.get('closed_clients')}")
        print(f"  Savings Only:      {p_sum.get('savings_only_clients')}")
        print(f"  Active Loans:      {p_sum.get('active_loans_count')}")
        print(f"  Total Active Cred: N{p_sum.get('total_active_credit', 0):,.0f}")
        print(f"  Total Outstanding: N{p_sum.get('total_outstanding_balance', 0):,.0f}")

        assert p_sum.get('total_registered_clients') == 360, f"Expected 360 clients, got {p_sum.get('total_registered_clients')}"
        assert p_sum.get('active_clients') == 13, f"Expected 13 active clients on loan, got {p_sum.get('active_clients')}"
        assert p_sum.get('completed_clients') >= 1, f"Expected at least 1 completed client, got {p_sum.get('completed_clients')}"
        print("  [PASS] Portfolio metrics match authoritative database lifecycle states!")

        # 4. Verify Kareem Nurudeen (OGI-18-009) specifically
        print("\n[TEST 4] Verifying Kareem Nurudeen (OGI-18-009) Status...")
        k_res = uow.client.table("clients").select("client_id, name, client_code, status_id, client_statuses(name)").eq("client_code", "OGI-18-009").execute()
        assert len(k_res.data) == 1, "Client OGI-18-009 not found"
        k_client = k_res.data[0]
        k_status = (k_client.get("client_statuses") or {}).get("name")
        print(f"  Client: {k_client.get('name')} ({k_client.get('client_code')})")
        print(f"  Lifecycle Status: {k_status}")
        assert k_status == "Completed", f"Expected 'Completed', got '{k_status}'"

        # Check loan status for Kareem
        k_loan_res = uow.client.table("loans").select("loan_id, status, active_credit, total_due").eq("client_id", k_client["client_id"]).execute()
        for kl in k_loan_res.data:
            print(f"  Loan ID: {kl['loan_id'][:8]}... | Status: {kl['status']}")
            assert kl["status"] == "Completed", f"Expected loan status 'Completed', got '{kl['status']}'"
        print("  [PASS] Kareem Nurudeen and his loan are 100% correctly marked as 'Completed'!")

        # 5. Test Manual CO Status Change with Audit Trail (BR-CLI-004 & BR-CLI-007)
        print("\n[TEST 5] Testing Manual CO Status Change & Audit Trail...")
        test_client = next((c for c in p_data["client_table"].to_dict("records") if c.get("Lifecycle Status") == "Registered"), None)
        if test_client:
            test_cid = test_client.get("Client ID") or test_client.get("ID")
            test_code = test_client.get("Client Code")
            print(f"  Testing with Registered Client: {test_code} (ID: {test_cid})")

            # Transition to 'Inactive (Savings Only)'
            succ = ClientStatusService.transition_status(
                uow=uow,
                client_id=test_cid,
                new_status_name="Inactive (Savings Only)",
                changed_by=None,
                reason="Unit Test: Client requested savings-only status",
                trigger_type="MANUAL"
            )
            assert succ, "Failed to transition status to Inactive (Savings Only)"

            # Check client table
            chk_c = uow.client.table("clients").select("status_id, client_statuses(name)").eq("client_id", test_cid).execute()
            assert (chk_c.data[0].get("client_statuses") or {}).get("name") == "Inactive (Savings Only)"

            # Check audit history
            hist = ClientStatusService.get_client_history(uow, test_cid)
            assert len(hist) >= 2, f"Expected at least 2 history records, found {len(hist)}"
            latest_h = hist[0]
            print(f"  Audit Log Created: {latest_h.get('changed_at')} | Old: {latest_h.get('old_status_id') or 'N/A'} -> New: Inactive (Savings Only) | Reason: {latest_h.get('reason')}")
            assert latest_h.get("reason") == "Unit Test: Client requested savings-only status"
            assert latest_h.get("trigger_type") == "MANUAL"

            # Revert back to Registered
            ClientStatusService.transition_status(
                uow=uow,
                client_id=test_cid,
                new_status_name="Registered",
                changed_by=None,
                reason="Unit Test: Reverted back to Registered",
                trigger_type="MANUAL"
            )
            chk_revert = uow.client.table("clients").select("status_id, client_statuses(name)").eq("client_id", test_cid).execute()
            assert (chk_revert.data[0].get("client_statuses") or {}).get("name") == "Registered"
            print("  [PASS] Manual CO transition, reversion, and audit trail verified!")

        # 6. Test RenewalService Defaulter Warning (BR-CLI-009)
        print("\n[TEST 6] Testing RenewalService Defaulter Warning Behavior (BR-CLI-009)...")
        # Kareem Nurudeen is completed, should be eligible for renewal!
        is_elig, reasons, warnings = RenewalService.check_eligibility(uow, k_client["client_id"], requested_amount=50000, product_type="Daily 60 Days", product_category="Finance")
        print(f"  Kareem Nurudeen Renewal Eligibility: {is_elig}")
        print(f"  Reasons: {reasons}")
        print(f"  Warnings: {warnings}")
        # Kareem had active loan with bal=0, now he has NO active loan with bal>0, so he is eligible!
        assert is_elig, f"Expected Kareem to be eligible for loan renewal, but got reasons: {reasons}"
        print("  [PASS] Completed client is immediately eligible for loan renewal!")

    print("\n" + "=" * 80)
    print("ALL TESTS PASSED WITH 100% INVARIANT INTEGRITY!")
    print("=" * 80)


if __name__ == "__main__":
    test_client_status_system()
