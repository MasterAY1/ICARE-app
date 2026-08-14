from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()
res = uow.client.table("posting_rules").select("*").execute()
print("=== POSTING RULES IN DB ===")
for r in (res.data or []):
    print(f"Event: {r.get('event_type'):<25} | Debit: {r.get('debit_account'):<6} | Credit: {r.get('credit_account'):<6} | Enabled: {r.get('enabled')}")
