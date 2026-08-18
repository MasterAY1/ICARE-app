import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScopeService

uow = SupabaseUnitOfWork()

user_co2 = {"id": "c32125e1-c7e5-4a85-8948-12d05b40eaa9", "username": "CO2", "role": "CO", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
scope_co2 = RBACScopeService.resolve_scope(user_co2)

p_data = PortfolioService.get_portfolio_data_for_scope(uow, scope_co2)
df = p_data["client_table"]
print("Sum of Savings Balance in client_table:", df["Savings Balance"].sum())
print("Non-zero client savings count:", (df["Savings Balance"] > 0).sum())
print("Sample rows with savings:")
print(df[df["Savings Balance"] > 0][["Client Code", "Client Name", "Group", "Savings Balance"]])
