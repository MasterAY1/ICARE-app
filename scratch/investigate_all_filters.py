import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScopeService
from datetime import date

uow = SupabaseUnitOfWork()

print("==================================================")
print("1. CHECKING BRANCHES TABLE COLUMNS")
res_b = uow.client.table("branches").select("*").limit(5).execute()
print("Sample branch:", res_b.data[0] if res_b.data else "No data")

print("\n==================================================")
print("2. CHECKING LOANS TABLE START DATES AND REPAYMENTS DATES")
res_l = uow.client.table("loans").select("loan_id, loan_amount, start_date, created_at, status").limit(10).execute()
print("Sample loans:")
for l in (res_l.data or []):
    print(l)

res_r = uow.client.table("repayments").select("id, amount_paid, date, created_at, transaction_type, note").limit(10).execute()
print("\nSample repayments:")
for r in (res_r.data or []):
    print(r)

print("\n==================================================")
print("3. TESTING ALL 5 FILTERS VIA PortfolioService")

user_bm = {"id": "f2656341-a85a-4e06-a1c8-d62cfef19b08", "username": "BM_Ogijo", "role": "BM", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
scope_bm = RBACScopeService.resolve_scope(user_bm)

# Test 1: Custom Date Range (e.g. 2026-08-03 to 2026-08-03)
print("\n--- TEST A: Custom Date Range 2026-08-03 to 2026-08-03 ---")
try:
    p_data = PortfolioService.get_portfolio_data_for_scope(
        uow, scope_bm, start_date=date(2026, 8, 3), end_date=date(2026, 8, 3)
    )
    print("Summary:", p_data["summary"])
except Exception as e:
    print("ERROR in Test A:", type(e), e)

# Test 2: Filter Product
print("\n--- TEST B: Filter Product = 'Daily Loan' ---")
try:
    p_data = PortfolioService.get_portfolio_data_for_scope(
        uow, scope_bm, selected_product="Daily Loan"
    )
    print("Summary:", p_data["summary"])
except Exception as e:
    print("ERROR in Test B:", type(e), e)

# Test 3: Filter Group
print("\n--- TEST C: Filter Group = 'Favour' ---")
try:
    p_data = PortfolioService.get_portfolio_data_for_scope(
        uow, scope_bm, selected_group="Favour"
    )
    print("Summary:", p_data["summary"])
except Exception as e:
    print("ERROR in Test C:", type(e), e)

# Test 4: Filter Officer
print("\n--- TEST D: Filter Officer = 'CO2' ---")
try:
    p_data = PortfolioService.get_portfolio_data_for_scope(
        uow, scope_bm, selected_officer="CO2"
    )
    print("Summary:", p_data["summary"])
except Exception as e:
    print("ERROR in Test D:", type(e), e)

# Test 5: Filter Branch
print("\n--- TEST E: Filter Branch = 'Ogijo' ---")
try:
    p_data = PortfolioService.get_portfolio_data_for_scope(
        uow, scope_bm, selected_branch="Ogijo"
    )
    print("Summary:", p_data["summary"])
except Exception as e:
    print("ERROR in Test E:", type(e), e)

