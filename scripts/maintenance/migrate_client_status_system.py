"""
Client Lifecycle Status System — Data Seeding & Client Backfill
BR-CLI-001 through BR-CLI-009

Seeds:
  1. 9 predefined statuses in client_statuses
  2. Backfills all 360 existing clients with correct status_id based on loan data
  3. Transitions completed loans (balance = 0) to 'Completed'
  4. Records initial audit history in client_status_history
"""
import sys, os, uuid
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
from database.repositories.unit_of_work import SupabaseUnitOfWork

STATUSES = [
    {
        "status_id": "11111111-1111-1111-1111-111111110001",
        "name": "Registered",
        "description": "Client is onboarded but has never received a loan.",
        "color_code": "#9CA3AF",
        "icon": "circle",
        "sort_order": 1,
        "is_system": True,
        "auto_transition_rule": "Default on client creation"
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110002",
        "name": "Pending Loan",
        "description": "Loan application submitted, awaiting BM approval.",
        "color_code": "#F59E0B",
        "icon": "hourglass",
        "sort_order": 2,
        "is_system": True,
        "auto_transition_rule": "Auto: when loan application is submitted"
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110003",
        "name": "On Loan",
        "description": "Client has an active loan with outstanding balance > 0, approved by BM.",
        "color_code": "#22C55E",
        "icon": "check-circle",
        "sort_order": 3,
        "is_system": True,
        "auto_transition_rule": "Auto: when BM approves and loan is disbursed"
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110004",
        "name": "Completed",
        "description": "Recently finished paying a loan; expected to re-apply soon.",
        "color_code": "#3B82F6",
        "icon": "award",
        "sort_order": 4,
        "is_system": True,
        "auto_transition_rule": "Auto: when outstanding balance hits 0"
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110005",
        "name": "Dormant",
        "description": "Inactive for longer than the branch dormancy threshold (no loan, no savings activity).",
        "color_code": "#EAB308",
        "icon": "moon",
        "sort_order": 5,
        "is_system": True,
        "auto_transition_rule": "Auto: computed on portfolio load based on branch dormancy_threshold_days"
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110006",
        "name": "Inactive (Savings Only)",
        "description": "No longer borrows but still has savings with the company.",
        "color_code": "#6366F1",
        "icon": "piggy-bank",
        "sort_order": 6,
        "is_system": False,
        "auto_transition_rule": None
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110007",
        "name": "Closed",
        "description": "Client relationship fully terminated; no active products.",
        "color_code": "#6B7280",
        "icon": "x-circle",
        "sort_order": 7,
        "is_system": False,
        "auto_transition_rule": None
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110008",
        "name": "Suspended",
        "description": "Temporarily suspended (investigation, dispute).",
        "color_code": "#EF4444",
        "icon": "alert-triangle",
        "sort_order": 8,
        "is_system": False,
        "auto_transition_rule": None
    },
    {
        "status_id": "11111111-1111-1111-1111-111111110009",
        "name": "Defaulter",
        "description": "Overdue loan past maturity with no payments for > 30 days. WARNING ONLY - does not block new applications.",
        "color_code": "#DC2626",
        "icon": "alert-octagon",
        "sort_order": 9,
        "is_system": True,
        "auto_transition_rule": "Auto: past maturity + 30 days with no payments. Warning flag only."
    }
]


def run_migration():
    with SupabaseUnitOfWork() as uow:
        print("=" * 80)
        print("STEP 1: Seeding predefined statuses into client_statuses")
        print("=" * 80)

        existing_res = uow.client.table("client_statuses").select("name, status_id").execute()
        existing_map = {r["name"]: r["status_id"] for r in (existing_res.data or [])}

        for s in STATUSES:
            if s["name"] in existing_map:
                print(f"  [EXISTS] '{s['name']}' ({existing_map[s['name']]})")
            else:
                uow.client.table("client_statuses").insert(s).execute()
                print(f"  [CREATED] '{s['name']}' ({s['status_id']})")

        # Fetch authoritative lookup
        all_statuses_res = uow.client.table("client_statuses").select("*").order("sort_order").execute()
        status_lookup = {s["name"]: s["status_id"] for s in (all_statuses_res.data or [])}

        print(f"\n  Authoritative Status Lookup ({len(status_lookup)} statuses):")
        for name, sid in status_lookup.items():
            print(f"    {name:25} -> {sid}")

        # ──────────────────────────────────────────────────────────────────
        # STEP 2: Analyze loans and identify completed vs active vs pending
        # ──────────────────────────────────────────────────────────────────
        print("\n" + "=" * 80)
        print("STEP 2: Analyzing loans and resolving client loan states")
        print("=" * 80)

        loans_res = uow.client.table("loans").select("loan_id, client_id, status, active_credit, total_due, loan_amount").execute()
        all_loans = loans_res.data or []
        print(f"  Total loans in DB: {len(all_loans)}")

        # Fetch all repayments to calculate dynamic balances
        reps_res = uow.client.table("repayments").select("loan_id, client_id, amount_paid").execute()
        reps_by_loan = {}
        for r in (reps_res.data or []):
            lid_s = str(r.get("loan_id") or "")
            if lid_s:
                reps_by_loan[lid_s] = reps_by_loan.get(lid_s, 0.0) + float(r.get("amount_paid") or 0.0)

        active_loan_clients = set()
        pending_loan_clients = set()
        completed_loan_clients = set()

        for l in all_loans:
            cid = str(l.get("client_id") or "")
            lid = str(l.get("loan_id") or "")
            loan_status = str(l.get("status") or "")
            act_cred = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
            tot_due_base = float(l.get("total_due") if l.get("total_due") is not None else act_cred)
            tot_paid = reps_by_loan.get(lid, 0.0)
            outstanding = max(0.0, tot_due_base - tot_paid)

            if loan_status in ["Active", "ACTIVE", "Approved"]:
                if outstanding <= 0.0 and act_cred > 0:
                    # Completed loan!
                    uow.client.table("loans").update({"status": "Completed"}).eq("loan_id", lid).execute()
                    completed_loan_clients.add(cid)
                    print(f"  [LOAN TRANSITION] Loan {lid[:8]}... (Client {cid[:8]}...) -> Status updated to 'Completed' (Outstanding = 0)")
                else:
                    active_loan_clients.add(cid)
            elif loan_status == "Pending":
                # Only count real pending loan applications (loan_amount > 0)
                if float(l.get("loan_amount") or 0.0) > 0:
                    pending_loan_clients.add(cid)

        # Clients with active loans override completed
        completed_loan_clients -= active_loan_clients
        pending_loan_clients -= active_loan_clients

        print(f"  Active Loan Clients:    {len(active_loan_clients)}")
        print(f"  Completed Loan Clients: {len(completed_loan_clients)}")
        print(f"  Pending Loan Clients:   {len(pending_loan_clients)}")

        # ──────────────────────────────────────────────────────────────────
        # STEP 3: Backfill all clients
        # ──────────────────────────────────────────────────────────────────
        print("\n" + "=" * 80)
        print("STEP 3: Backfilling client status_id on clients table")
        print("=" * 80)

        clients_res = uow.client.table("clients").select("client_id, client_code, name, status_id").execute()
        all_clients = clients_res.data or []

        registered_id = status_lookup["Registered"]
        on_loan_id = status_lookup["On Loan"]
        completed_id = status_lookup["Completed"]
        pending_id = status_lookup["Pending Loan"]

        counts = {"Registered": 0, "On Loan": 0, "Completed": 0, "Pending Loan": 0}
        history_batch = []

        for c in all_clients:
            cid = str(c.get("client_id") or "")
            c_name = c.get("name") or "N/A"
            c_code = c.get("client_code") or "N/A"

            if cid in active_loan_clients:
                target_status_id = on_loan_id
                target_status_name = "On Loan"
            elif cid in completed_loan_clients:
                target_status_id = completed_id
                target_status_name = "Completed"
            elif cid in pending_loan_clients:
                target_status_id = pending_id
                target_status_name = "Pending Loan"
            else:
                target_status_id = registered_id
                target_status_name = "Registered"

            uow.client.table("clients").update({
                "status_id": target_status_id,
                "status_changed_at": "2026-08-18T06:30:00+01:00",
                "status_note": f"Initial Lifecycle Classification: {target_status_name}"
            }).eq("client_id", cid).execute()

            history_batch.append({
                "id": str(uuid.uuid4()),
                "client_id": cid,
                "old_status_id": None,
                "new_status_id": target_status_id,
                "changed_at": "2026-08-18T06:30:00+01:00",
                "reason": f"System backfill: {target_status_name}",
                "trigger_type": "SYSTEM",
                "trigger_reference": "initial_lifecycle_migration"
            })

            counts[target_status_name] = counts.get(target_status_name, 0) + 1

        # Insert history records in batches of 50
        for i in range(0, len(history_batch), 50):
            batch = history_batch[i:i+50]
            uow.client.table("client_status_history").insert(batch).execute()

        print(f"  Backfilled {len(all_clients)} clients:")
        for sname, cnt in counts.items():
            print(f"    {sname:20}: {cnt} clients")

        # ──────────────────────────────────────────────────────────────────
        # STEP 4: Verification
        # ──────────────────────────────────────────────────────────────────
        print("\n" + "=" * 80)
        print("STEP 4: Verification & Audit")
        print("=" * 80)

        chk_res = uow.client.table("clients").select("client_id, client_code, name, status_id, client_statuses(name)").execute()
        assigned_map = {}
        unassigned = 0
        for r in (chk_res.data or []):
            cs = r.get("client_statuses")
            sname = cs.get("name") if isinstance(cs, dict) else "UNASSIGNED"
            assigned_map[sname] = assigned_map.get(sname, 0) + 1
            if sname == "UNASSIGNED":
                unassigned += 1

        print(f"  Client Status Distribution across all {len(chk_res.data or [])} clients:")
        for sname, cnt in sorted(assigned_map.items()):
            print(f"    {sname:25}: {cnt} clients")

        assert unassigned == 0, f"FAILED: {unassigned} clients have no status_id assigned!"

        # Specific test for Kareem Nurudeen
        kareem = next((c for c in (chk_res.data or []) if "kareem" in str(c.get("name", "")).lower()), None)
        if kareem:
            k_status = (kareem.get("client_statuses") or {}).get("name")
            print(f"\n  Special Case: {kareem.get('client_code')} ({kareem.get('name')})")
            print(f"    Current Status: {k_status}")
            assert k_status == "Completed", f"FAILED: Kareem Nurudeen status is '{k_status}', expected 'Completed'"
            print("    [PASSED] Kareem Nurudeen is correctly marked as 'Completed'!")

        print("\n================================================================================")
        print("MIGRATION & BACKFILL COMPLETED 100% SUCCESSFULLY!")
        print("================================================================================")


if __name__ == "__main__":
    run_migration()
