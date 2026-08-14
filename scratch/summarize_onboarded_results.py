from database.repositories.unit_of_work import SupabaseUnitOfWork
import pandas as pd

uow = SupabaseUnitOfWork()

print("=== 1. GROUPS WITH LEADERS & GROUP SAVINGS ===")
g_res = uow.client.table("groups").select("group_id, name, meeting_day, leader_name, officer_id, app_users(full_name)").execute()
gs_res = uow.client.table("group_savings").select("group_id, deposit_amount").execute()
gs_map = {g["group_id"]: g["deposit_amount"] for g in (gs_res.data or [])}

for g in (g_res.data or []):
    gid = g["group_id"]
    leader = g.get("leader_name")
    gsav = gs_map.get(gid, 0.0)
    co = (g.get("app_users") or {}).get("full_name")
    if leader or gsav > 0:
        print(f"Group: {g['name']:<15} | Leader: {str(leader):<20} | Group Savings: ₦{gsav:>10,.2f} | Meeting: {g['meeting_day']:<10} | Officer: {co}")

print("\n=== 2. ONBOARDED ACTIVE LOANS ===")
l_res = uow.client.table("loans").select("loan_id, active_credit, total_due, loan_repay, status, clients(name, client_code), loan_products(name)").eq("status", "Active").execute()
for l in (l_res.data or []):
    c = l.get("clients") or {}
    p = l.get("loan_products") or {}
    print(f"Client: {c.get('name', 'N/A'):<20} ({c.get('client_code', 'N/A')}) | Product: {p.get('name', 'N/A'):<12} | Active Credit: ₦{float(l.get('active_credit') or 0):>10,.2f} | Remaining Bal: ₦{float(l.get('total_due') or 0):>10,.2f} | Weekly Repay: ₦{float(l.get('loan_repay') or 0):>9,.2f}")

print("\n=== 3. INDIVIDUAL SAVINGS DEPOSITS ===")
s_res = uow.client.table("individual_savings").select("deposit_amount, clients(name, client_code)").execute()
for s in (s_res.data or []):
    c = s.get("clients") or {}
    print(f"Client: {c.get('name', 'N/A'):<20} ({c.get('client_code', 'N/A')}) | Savings Deposit: ₦{float(s.get('deposit_amount') or 0):>10,.2f}")
