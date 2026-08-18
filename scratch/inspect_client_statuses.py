import sys, os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

with SupabaseUnitOfWork() as uow:
    # 1. Check current clients table columns
    print("=" * 80)
    print("CLIENTS TABLE - SAMPLE ROW")
    print("=" * 80)
    res = uow.client.table("clients").select("*").limit(1).execute()
    if res.data:
        for k, v in res.data[0].items():
            print(f"  {k}: {v}")
    
    # 2. Check all distinct client statuses
    print("\n" + "=" * 80)
    print("DISTINCT CLIENT STATUSES IN clients TABLE")
    print("=" * 80)
    res2 = uow.client.table("clients").select("status").execute()
    statuses = set(r.get("status") for r in (res2.data or []))
    for s in sorted(statuses, key=lambda x: str(x)):
        count = sum(1 for r in res2.data if r.get("status") == s)
        print(f"  '{s}': {count} clients")
    
    # 3. Check all distinct loan statuses
    print("\n" + "=" * 80)
    print("DISTINCT LOAN STATUSES IN loans TABLE")
    print("=" * 80)
    res3 = uow.client.table("loans").select("status").execute()
    loan_statuses = set(r.get("status") for r in (res3.data or []))
    for s in sorted(loan_statuses, key=lambda x: str(x)):
        count = sum(1 for r in res3.data if r.get("status") == s)
        print(f"  '{s}': {count} loans")
    
    # 4. Check if client_statuses table exists
    print("\n" + "=" * 80)
    print("CHECK IF client_statuses TABLE EXISTS")
    print("=" * 80)
    try:
        res4 = uow.client.table("client_statuses").select("*").limit(1).execute()
        print(f"  EXISTS: {len(res4.data or [])} rows found")
    except Exception as e:
        print(f"  DOES NOT EXIST: {e}")
    
    # 5. Clients with Active loans where outstanding balance is 0
    print("\n" + "=" * 80)
    print("CLIENTS WITH ACTIVE LOANS BUT OUTSTANDING BALANCE = 0")
    print("=" * 80)
    loans_res = uow.client.table("loans").select("loan_id, client_id, active_credit, total_due, status, clients(name, client_code)").in_("status", ["Active", "ACTIVE", "Approved"]).execute()
    for l in (loans_res.data or []):
        lid = l.get("loan_id")
        cid = l.get("client_id")
        act_cred = float(l.get("active_credit") or 0)
        tot_due = float(l.get("total_due") if l.get("total_due") is not None else act_cred)
        
        # Get total repayments
        rep_res = uow.client.table("repayments").select("amount_paid").eq("loan_id", lid).execute()
        total_paid = sum(float(r.get("amount_paid") or 0) for r in (rep_res.data or []))
        outstanding = max(0.0, tot_due - total_paid)
        
        c_info = l.get("clients") or {}
        c_name = c_info.get("name", "N/A")
        c_code = c_info.get("client_code", "N/A")
        
        if outstanding <= 0:
            print(f"  [!] {c_code} ({c_name}) -- Loan Status: {l.get('status')}, Active Credit: {act_cred:,.0f}, Total Paid: {total_paid:,.0f}, Outstanding: {outstanding:,.0f}")
