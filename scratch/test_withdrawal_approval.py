import uuid
from datetime import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.savings_service import SavingsService

uow = SupabaseUnitOfWork()

print("=== TESTING WITHDRAWAL APPROVAL FLOWS ===")

# Test 1: Individual Cash Withdrawal Approval
test_wr_id = str(uuid.uuid4())
test_cid = "b57adacd-4646-47e1-bbf1-ae33b55392b6" # Kehinde Hannah
test_name = "Kehinde Hannah"
test_branch = "Ogijo"
test_co = "CO2"
test_amt = 100.0

try:
    print("Testing SavingsService.post_individual_savings (Withdrawal)...")
    SavingsService.post_individual_savings(
        uow=uow, client_id=test_cid, client_name=test_name,
        branch=test_branch, officer=test_co, deposit_amount=0.0, withdrawal_amount=test_amt,
        reference=test_wr_id, remarks="[TEST APPROVAL] Verification"
    )
    print(">> post_individual_savings SUCCESSFUL!")

    # Test 2: Misc Savings Withdrawal Approval
    print("Testing SavingsService.post_misc_savings (Withdrawal)...")
    SavingsService.post_misc_savings(
        uow=uow, client_id=test_cid, client_name=test_name,
        branch=test_branch, officer=test_co, deposit_amount=0.0, withdrawal_amount=test_amt,
        reference=test_wr_id, remarks="[TEST APPROVAL] Misc Verification"
    )
    print(">> post_misc_savings SUCCESSFUL!")

    # Clean up test records
    # 1. Clean individual savings
    uow.client.table("individual_savings").delete().eq("reference", test_wr_id).execute()
    # 2. Clean misc savings
    uow.client.table("misc_savings").delete().eq("reference", test_wr_id).execute()
    # 3. Clean financial transactions & ledger
    res_tx = uow.client.table("financial_transactions").select("transaction_id, event_id").eq("reference", test_wr_id).execute()
    for tx in (res_tx.data or []):
        tid = tx["transaction_id"]
        eid = tx.get("event_id")
        uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tid).execute()
        uow.client.table("financial_transactions").delete().eq("transaction_id", tid).execute()
        if eid:
            uow.client.table("event_processing").delete().eq("event_id", eid).execute()
            uow.client.table("event_store").delete().eq("event_id", eid).execute()
    # 4. Clean audit logs
    uow.client.table("audit_logs").delete().gte("created_at", datetime.now().strftime("%Y-%m-%d")).execute()

    print(">> All withdrawal approval test operations passed and database cleaned up!")

except Exception as e:
    print(f"FAILED withdrawal approval test: {e}")
    # Cleanup in case of error
    uow.client.table("individual_savings").delete().eq("reference", test_wr_id).execute()
    uow.client.table("misc_savings").delete().eq("reference", test_wr_id).execute()
    raise e
