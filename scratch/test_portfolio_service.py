import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScopeService

uow = SupabaseUnitOfWork()

# Test CO2 scope
user_co2 = {"id": "c32125e1-c7e5-4a85-8948-12d05b40eaa9", "username": "CO2", "role": "CO", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
scope_co2 = RBACScopeService.resolve_scope(user_co2)

p_data = PortfolioService.get_portfolio_data_for_scope(uow, scope_co2)
summary = p_data["summary"]
print("=== PORTFOLIO SUMMARY FOR CO2 ===")
print("Total Savings Deposit:", summary.get("total_savings_deposit"))
print("Total Savings Withdrawal:", summary.get("total_savings_withdrawal"))
print("Total Savings Balance:", summary.get("total_savings_balance"))

print("\n=== CLIENT TABLE SAMPLE (FIRST 5 ROWS) ===")
df = p_data["client_table"]
print(df.head())
