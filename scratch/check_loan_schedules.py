from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CHECKING LOAN SCHEDULE COLUMNS ===")
res_s = uow.client.table("loan_schedule").select("*").limit(5).execute()
if res_s.data:
    print("Columns in loan_schedule:", list(res_s.data[0].keys()))
    for row in res_s.data:
        print(row)
else:
    print("loan_schedule table is EMPTY!")
