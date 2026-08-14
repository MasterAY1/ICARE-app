from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CLEARING ALL TODAY'S TEST TRANSACTIONS ===")

# 1. Reset loan_schedule rows modified today (keep Inst 0 onboarding legacy payments intact)
res_sch = uow.client.table("loan_schedule").update({
    "paid_amount": 0.0,
    "status": "Pending",
    "paid_date": None
}).gt("installment_number", 0).execute()
print("Reset loan schedules with installment_number > 0 to 0 paid amount.")

# Also ensure any schedule with paid_date = 2026-08-14 is reset
uow.client.table("loan_schedule").update({
    "paid_amount": 0.0,
    "status": "Pending",
    "paid_date": None
}).eq("paid_date", "2026-08-14").execute()

# 2. Delete non-onboarding repayments
uow.client.table("repayments").delete().neq("date", "1970-01-01").execute()
print("Deleted any non-onboarding repayments.")

# 3. Delete non-onboarding individual savings
uow.client.table("individual_savings").delete().neq("remarks", "Initial Onboarding Savings").execute()
print("Deleted any non-onboarding individual savings.")

# 4. Clean financial transactions and ledger entries for today
res_tx = uow.client.table("financial_transactions").select("transaction_id, event_id").gte("posting_date", "2026-08-14").execute()
for tx in (res_tx.data or []):
    tid = tx["transaction_id"]
    eid = tx.get("event_id")
    uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tid).execute()
    uow.client.table("financial_transactions").delete().eq("transaction_id", tid).execute()
    if eid:
        uow.client.table("event_processing").delete().eq("event_id", eid).execute()
        uow.client.table("event_store").delete().eq("event_id", eid).execute()
print("Deleted financial transactions and ledger entries for today.")

# 5. Clean audit logs created today
uow.client.table("audit_logs").delete().gte("created_at", "2026-08-14T00:00:00").execute()
print("Deleted today's audit logs.")

# 6. Rebuild CO and Master Cashbooks for Ogijo
branch_id = uow.cashbook._resolve_branch_id("Ogijo")
uow.cashbook.rebuild_projection(branch_id, date.today())
print("Rebuilt CO and Master Cashbooks for Ogijo.")

print("\n=== CLEANUP COMPLETE! ===")
