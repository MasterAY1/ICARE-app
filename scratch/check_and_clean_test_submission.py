from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CHECKING TEST SUBMISSION RECORDS ===")
# Check individual_savings created on today's date
res_s = uow.client.table("individual_savings").select("*").eq("posting_date", "2026-08-14").execute()
print(f"Individual Savings on 2026-08-14: {len(res_s.data or [])}")
for s in (res_s.data or []):
    print("  Savings record:", s.get("id"), s.get("client_id"), s.get("deposit_amount"), s.get("remarks"))

# Check repayments created on today's date
res_r = uow.client.table("repayments").select("*").eq("date", "2026-08-14").execute()
print(f"Repayments on 2026-08-14: {len(res_r.data or [])}")
for r in (res_r.data or []):
    print("  Repayment record:", r.get("id"), r.get("client_id"), r.get("amount_paid"), r.get("note"))

# Check financial transactions on today's date
res_tx = uow.client.table("financial_transactions").select("*").eq("posting_date", "2026-08-14").execute()
print(f"Financial Transactions on 2026-08-14: {len(res_tx.data or [])}")
for t in (res_tx.data or []):
    print("  Tx record:", t.get("id"), t.get("narration"), t.get("reference"))
