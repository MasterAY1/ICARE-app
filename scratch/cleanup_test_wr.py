from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()
test_wr_id = "fdfd0b81-a0ad-4645-a2da-d3c8f1d7afd7"

uow.client.table("internal_savings").delete().eq("reference", test_wr_id).execute()
uow.client.table("individual_savings").delete().eq("reference", test_wr_id).execute()

res_tx = uow.client.table("financial_transactions").select("transaction_id, event_id").eq("reference", test_wr_id).execute()
for tx in (res_tx.data or []):
    tid = tx["transaction_id"]
    eid = tx.get("event_id")
    uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tid).execute()
    uow.client.table("financial_transactions").delete().eq("transaction_id", tid).execute()
    if eid:
        uow.client.table("event_processing").delete().eq("event_id", eid).execute()
        uow.client.table("event_store").delete().eq("event_id", eid).execute()

print("Cleaned up test withdrawal reference.")
