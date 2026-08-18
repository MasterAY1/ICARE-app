import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

res_l = uow.client.table("loans").select("*").limit(5).execute()
print("All columns of a loan record:")
if res_l.data:
    loan = res_l.data[0]
    for k, v in loan.items():
        print(f"  {k}: {v}")

print("\nAll 10 loans summary:")
res_all = uow.client.table("loans").select("loan_id, client_id, loan_amount, active_credit, start_date, expected_end_date, created_at, status, extra_fields").execute()
for l in (res_all.data or []):
    print(l)
