import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()
users_res = uow.client.table("app_users").select("*").execute()
for u in (users_res.data or []):
    print(u)
