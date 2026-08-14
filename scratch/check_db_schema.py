from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("\n--- App Users sample ---")
u = uow.client.table("app_users").select("*").execute()
for usr in (u.data or []):
    print(f"User: {usr.get('username')} | Name: {usr.get('full_name')} | ID: {usr.get('id')} | Branch: {usr.get('branch_id')}")

print("\n--- Loan Products ---")
lp = uow.client.table("loan_products").select("product_id, name, repayment_cycle, installments").execute()
for p in (lp.data or []):
    print(f"Product: {p.get('name')} | ID: {p.get('product_id')} | Cycle: {p.get('repayment_cycle')} | Inst: {p.get('installments')}")
