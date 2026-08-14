from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== co_cashbooks sample ===")
try:
    c = uow.client.table("co_cashbooks").select("*").limit(1).execute()
    print("co_cashbooks columns:", list(c.data[0].keys()) if c.data else "empty")
except Exception as e:
    print("co_cashbooks error:", e)

print("\n=== master_cashbook sample ===")
try:
    m = uow.client.table("master_cashbook").select("*").limit(1).execute()
    print("master_cashbook columns:", list(m.data[0].keys()) if m.data else "empty")
except Exception as e:
    print("master_cashbook error:", e)
