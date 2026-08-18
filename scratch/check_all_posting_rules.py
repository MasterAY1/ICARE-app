from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CHECKING POSTING RULES ===")
res = uow.client.table("posting_rules").select("*").execute()
for r in (res.data or []):
    print(f"Event: {r.get('event_type')} | Debit: {r.get('debit_account')} | Credit: {r.get('credit_account')} | Active: {r.get('is_active')}")
