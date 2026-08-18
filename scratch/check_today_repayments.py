from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CHECKING REPAYMENTS ON 2026-08-14 ===")
res_r = uow.client.table("repayments").select("id, client_id, amount_paid, note, date, created_at, clients(name, client_code), loans(loan_id, loan_repay, active_credit, loan_products(name))").eq("date", "2026-08-14").execute()
for r in (res_r.data or []):
    c = r.get("clients") or {}
    l = r.get("loans") or {}
    lp = l.get("loan_products") or {}
    print(f"Client: {c.get('name')} ({c.get('client_code')}) | Paid: {r.get('amount_paid')} | Expected Installment: {l.get('loan_repay')} | Product: {lp.get('name')} | Note: {r.get('note')}")
