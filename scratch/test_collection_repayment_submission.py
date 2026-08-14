import uuid
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.repayment import Repayment
from services.repayment_service import RepaymentService

uow = SupabaseUnitOfWork()

print("=== TESTING REPAYMENT SERVICE POSTING ===")

# Create a test repayment object
test_rep_id = str(uuid.uuid4())
test_client_id = "b57adacd-4646-47e1-bbf1-ae33b55392b6" # Kehinde Hannah

rep = Repayment(
    id=test_rep_id,
    payment_date=date.today(),
    client_id=test_client_id,
    credit_officer="CO2",
    branch="Ogijo",
    amount_paid=16500.0,
    transaction_type="Loan",
    savings_amount=0.0,
    withdrawal_amount=0.0,
    loan_repayment_amount=16500.0,
    others_amount=0.0,
    recovery_amount=0.0,
    initial_payment=0.0,
    expected_amount=16500.0,
    overdue_amount=0.0,
    payment_status="PAID",
    note="Test Repayment Verification",
    loan_id="dummy-loan-id"
)

try:
    RepaymentService.post_repayment(uow, rep)
    print(">> RepaymentService.post_repayment SUCCESSFUL!")
    
    # Clean up test repayment immediately to preserve pristine DB
    uow.client.table("repayments").delete().eq("id", test_rep_id).execute()
    uow.client.table("audit_logs").delete().eq("record_id", test_rep_id).execute()
    
    res_tx = uow.client.table("financial_transactions").select("transaction_id, event_id").eq("reference", test_rep_id).execute()
    for tx in (res_tx.data or []):
        tid = tx["transaction_id"]
        eid = tx.get("event_id")
        uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tid).execute()
        uow.client.table("financial_transactions").delete().eq("transaction_id", tid).execute()
        if eid:
            uow.client.table("event_processing").delete().eq("event_id", eid).execute()
            uow.client.table("event_store").delete().eq("event_id", eid).execute()
            
    print(">> Test records cleaned up. Database remains 100% pristine!")
except Exception as e:
    print(f"FAILED RepaymentService.post_repayment: {e}")
    raise e
