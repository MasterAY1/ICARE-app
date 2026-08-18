import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScopeService
from datetime import date

uow = SupabaseUnitOfWork()

print("--- 1. CHECKING BRANCHES DROPDOWN QUERY IN APP.PY ---")
res_b = uow.client.table("branches").select("name").execute()
branches = [b["name"] for b in (res_b.data or []) if b.get("name")]
print("Branches in DB:", branches)

print("\n--- 2. CHECKING LOANS START_DATE vs CREATED_AT ---")
res_loans = uow.client.table("loans").select("loan_id, client_id, loan_amount, start_date, created_at, status, loan_products(name)").execute()
print(f"Total loans in DB: {len(res_loans.data or [])}")
for l in (res_loans.data or [])[:5]:
    print(f"Loan: {l.get('loan_id')[:8]} | Product: {(l.get('loan_products') or {}).get('name')} | Amount: {l.get('loan_amount')} | start_date: {l.get('start_date')} | created_at: {l.get('created_at')[:10]}")

print("\n--- 3. CHECKING SAVINGS TRANSACTIONS FOR SPECIFIC DATES ---")
res_sav = uow.client.table("individual_savings").select("posting_date, deposit_amount, withdrawal_amount").execute()
date_counts = {}
for s in (res_sav.data or []):
    d = s.get("posting_date")
    date_counts[d] = date_counts.get(d, 0) + float(s.get("deposit_amount") or 0)
print("Individual savings deposits by date:", date_counts)

res_gsav = uow.client.table("group_savings").select("posting_date, deposit_amount, withdrawal_amount").execute()
g_date_counts = {}
for s in (res_gsav.data or []):
    d = s.get("posting_date")
    g_date_counts[d] = g_date_counts.get(d, 0) + float(s.get("deposit_amount") or 0)
print("Group savings deposits by date:", g_date_counts)

print("\n--- 4. CHECKING REPAYMENTS TRANSACTIONS FOR SPECIFIC DATES ---")
res_rep = uow.client.table("repayments").select("date, amount_paid, transaction_type, note").execute()
rep_counts = {}
for r in (res_rep.data or []):
    d = str(r.get("date") or "")[:10]
    rep_counts[d] = rep_counts.get(d, 0) + float(r.get("amount_paid") or 0)
print("Repayments by date:", rep_counts)

