import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
import json

uow = SupabaseUnitOfWork()

print("=== INDIVIDUAL SAVINGS SAMPLE ===")
res_ind = uow.client.table("individual_savings").select("*").limit(10).execute()
for r in (res_ind.data or []):
    print(r)

print("\n=== GROUP SAVINGS SAMPLE ===")
res_grp = uow.client.table("group_savings").select("*").limit(10).execute()
for r in (res_grp.data or []):
    print(r)

print("\n=== INTERNAL (MISC) SAVINGS SAMPLE ===")
res_misc = uow.client.table("internal_savings").select("*").limit(10).execute()
for r in (res_misc.data or []):
    print(r)

