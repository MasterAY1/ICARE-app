from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("=== CHECKING LOANS TABLE LOAN_REPAY VALUES ===")
res_l = uow.client.table("loans").select("loan_id, client_id, active_credit, loan_repay, total_due, extra_fields").execute()
for l in (res_l.data or []):
    print("Loan ID:", l.get("loan_id"), "Active Credit:", l.get("active_credit"), "loan_repay:", l.get("loan_repay"), "total_due:", l.get("total_due"), "extra_fields.installment:", (l.get("extra_fields") or {}).get("installment_amount"))
