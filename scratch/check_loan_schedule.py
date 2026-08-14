from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CHECKING LOAN SCHEDULE PAID AMOUNTS ===")
res_sch = uow.client.table("loan_schedule").select("id, loan_id, installment_number, total_due, paid_amount, status, paid_date").gt("paid_amount", 0).execute()
print(f"Installments with paid_amount > 0: {len(res_sch.data or [])}")
for s in (res_sch.data or []):
    print("  Schedule:", s.get("loan_id"), "Inst:", s.get("installment_number"), "Due:", s.get("total_due"), "Paid:", s.get("paid_amount"), "Status:", s.get("status"), "Date:", s.get("paid_date"))
