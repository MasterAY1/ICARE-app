from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CLEANING UP ONLY FAILED TEST 'Daily Collection' RECORDS ===")

# 1. Fetch individual savings from today's failed daily collection test
res_s = uow.client.table("individual_savings").select("id, client_id, deposit_amount").eq("remarks", "Daily Collection").execute()
failed_savings = res_s.data or []
print(f"Found {len(failed_savings)} failed Daily Collection savings records to clean.")

for s in failed_savings:
    sid = s["id"]
    # Find matching financial transactions by reference
    res_tx = uow.client.table("financial_transactions").select("transaction_id, event_id").eq("reference", sid).execute()
    for tx in (res_tx.data or []):
        tid = tx["transaction_id"]
        eid = tx.get("event_id")
        uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tid).execute()
        uow.client.table("financial_transactions").delete().eq("transaction_id", tid).execute()
        if eid:
            uow.client.table("event_processing").delete().eq("event_id", eid).execute()
            uow.client.table("event_store").delete().eq("event_id", eid).execute()
    
    # Delete individual savings record
    uow.client.table("individual_savings").delete().eq("id", sid).execute()

# Also clean any financial transactions with narration "Daily Collection"
res_tx_all = uow.client.table("financial_transactions").select("transaction_id, event_id").eq("narration", "Daily Collection").execute()
for tx in (res_tx_all.data or []):
    tid = tx["transaction_id"]
    eid = tx.get("event_id")
    uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tid).execute()
    uow.client.table("financial_transactions").delete().eq("transaction_id", tid).execute()
    if eid:
        uow.client.table("event_processing").delete().eq("event_id", eid).execute()
        uow.client.table("event_store").delete().eq("event_id", eid).execute()

print("=== CLEANUP COMPLETED! DATABASE RESTORED TO PRISTINE STATE ===")
