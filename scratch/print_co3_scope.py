import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.rbac_scope_service import RBACScopeService

uow = SupabaseUnitOfWork()
user_co3 = {"id": "60fa48a4-16a2-4ab8-b9c5-d13d72a040cc", "username": "CO3", "role": "CO", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
scope_co3 = RBACScopeService.resolve_scope(user_co3)

print("scope_level:", scope_co3.scope_level)
print("user_id:", scope_co3.user_id)
print("username:", scope_co3.username)
print("branch:", scope_co3.branch)
print("branch_id:", scope_co3.branch_id)
