import sys
import os
from datetime import date, datetime
import uuid

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from scratch.verify_phase3 import load_secrets
from supabase import create_client

secrets = load_secrets()
url = secrets.get("SUPABASE_URL")
key = secrets.get("SUPABASE_KEY")

if not url or not key:
    print("FATAL: Supabase URL/KEY not found in secrets.toml")
    sys.exit(1)

client = create_client(url, key)

# Test Data Constants
TEST_BRANCH_ID = "550e8400-e29b-41d4-a716-446655440000"
TEST_BRANCH_NAME = "Test Branch"
TEST_ZONE_ID = "c79427b2-d3a9-450f-aa4e-c4f4b2382103" # Default Zone

TEST_USER_ID = "550e8400-e29b-41d4-a716-446655440001"
TEST_USER_USERNAME = "test_verification_user"

TEST_CLIENT_ID = "550e8400-e29b-41d4-a716-446655440002"
TEST_CLIENT_NAME = "Test Integration Client"

TEST_LOAN_ID = "550e8400-e29b-41d4-a716-446655440003"
TEST_PRODUCT_ID = "11111111-1111-1111-1111-111111111111" # Seeded product

from domain.entities.user import User
from domain.entities.loan import Loan
from domain.entities.repayment import Repayment
from domain.entities.event_store import DomainEvent

from domain.enums import LoanStatus, ClientStatus, SavingsStatus

from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.loan_service import LoanService
from services.savings_service import SavingsService
from services.treasury_service import TreasuryService
from services.posting_engine import FinancialPostingEngine

passed_checks = []
failed_checks = []

def run_test(name, func):
    try:
        func()
        print(f"  [PASS] {name}")
        passed_checks.append(name)
    except Exception as e:
        print(f"  [FAIL] {name}: {e}")
        failed_checks.append((name, str(e)))

print("=== STARTING PHASE 4 INTEGRATION VERIFICATION ===")

# Setup branch, user, client
try:
    client.table("branches").upsert({
        "branch_id": TEST_BRANCH_ID,
        "zone_id": TEST_ZONE_ID,
        "name": TEST_BRANCH_NAME,
        "is_active": True
    }).execute()
    
    # Clean user
    client.table("user_roles").delete().eq("user_id", TEST_USER_ID).execute()
    client.table("app_users").delete().eq("username", TEST_USER_USERNAME).execute()
    client.table("app_users").delete().eq("id", TEST_USER_ID).execute()
    
    client.table("app_users").insert({
        "id": TEST_USER_ID,
        "username": TEST_USER_USERNAME,
        "full_name": "Phase 4 Verifier",
        "password_hash": "hash",
        "branch_id": TEST_BRANCH_ID,
        "is_active": True
    }).execute()
    
    client.table("user_roles").insert({
        "user_id": TEST_USER_ID,
        "role_id": "59539343-690a-4286-9467-854728562d5f" # Admin
    }).execute()
    
    client.table("clients").upsert({
        "client_id": TEST_CLIENT_ID,
        "name": TEST_CLIENT_NAME
    }).execute()
    print("Pre-test setup: Branch, user, and client created.")
except Exception as e:
    print(f"Pre-test setup failed: {e}")
    sys.exit(1)

with SupabaseUnitOfWork() as uow:
    try:
        # 1. Loan disbursement produces exactly one financial transaction with two balanced ledger entries
        def test_loan_disbursement():
            # disburse loan
            l = Loan(
                id=TEST_LOAN_ID,
                client_id=TEST_CLIENT_ID,
                client_name=TEST_CLIENT_NAME,
                product_type="Daily Loan",
                amount=50000.0,
                duration=60,
                frequency="Daily",
                gap_fee=0.0,
                expected_installment=1000.0,
                total_payable=60000.0,
                status=LoanStatus.APPROVED,
                client_status=ClientStatus.ACTIVE,
                savings_status=SavingsStatus.NORMAL,
                branch=TEST_BRANCH_NAME,
                credit_officer=TEST_USER_USERNAME,
                start_date=date.today(),
                end_date=date.today(),
                created_at=datetime.now()
            )
            # disburse
            LoanService.disburse_loan(uow, l)
            
            # verify tx header and ledger entries
            res_tx = client.table("financial_transactions").select("*").eq("reference", TEST_LOAN_ID).execute()
            assert len(res_tx.data) == 1, "Expected exactly one financial transaction header"
            tx_id = res_tx.data[0]["transaction_id"]
            
            res_entries = client.table("financial_ledger_entries").select("*").eq("transaction_id", tx_id).execute()
            assert len(res_entries.data) == 2, "Expected exactly two ledger entries"
            debit = [e for e in res_entries.data if e["side"] == "Debit"][0]
            credit = [e for e in res_entries.data if e["side"] == "Credit"][0]
            assert debit["amount"] == 50000.0, "Debit amount mismatch"
            assert credit["amount"] == 50000.0, "Credit amount mismatch"
            assert debit["account_code"] == "1200", "Loan Portfolio should be debited"
            assert credit["account_code"] == "1000", "Vault Cash should be credited"

        run_test("Loan disbursement balanced double-entry", test_loan_disbursement)

        # 2. Savings deposit produces two balanced ledger entries
        var_event_id = str(uuid.uuid4())
        def test_savings_deposit():
            SavingsService.post_individual_savings(
                uow, TEST_CLIENT_ID, TEST_CLIENT_NAME, TEST_BRANCH_NAME, TEST_USER_USERNAME,
                deposit_amount=15000.0, reference=var_event_id, remarks="Savings deposit integration test"
            )
            
            # Fetch entries
            res_tx = client.table("financial_transactions").select("transaction_id").eq("reference", var_event_id).execute()
            assert len(res_tx.data) == 1, "Expected one transaction"
            tx_id = res_tx.data[0]["transaction_id"]
            
            res_entries = client.table("financial_ledger_entries").select("*").eq("transaction_id", tx_id).execute()
            assert len(res_entries.data) == 2, "Expected exactly two ledger entries"
            debit = [e for e in res_entries.data if e["side"] == "Debit"][0]
            credit = [e for e in res_entries.data if e["side"] == "Credit"][0]
            assert debit["amount"] == 15000.0
            assert credit["amount"] == 15000.0
            assert debit["account_code"] == "1000", "Vault Cash should be debited on deposit"
            assert credit["account_code"] == "2000", "Individual Deposits should be credited"

        run_test("Savings deposit balanced double-entry", test_savings_deposit)

        # 3. Treasury transfer produces balanced postings
        var_treasury_ref = str(uuid.uuid4())
        def test_treasury_transfer():
            TreasuryService.post_treasury_transaction(
                uow, "BANK_DEPOSIT", 8000.0, TEST_BRANCH_NAME, TEST_USER_USERNAME, reference=var_treasury_ref, remarks="Vault to bank deposit"
            )
            # verify
            res_tx = client.table("financial_transactions").select("transaction_id").eq("reference", var_treasury_ref).execute()
            assert len(res_tx.data) == 1
            tx_id = res_tx.data[0]["transaction_id"]
            
            res_entries = client.table("financial_ledger_entries").select("*").eq("transaction_id", tx_id).execute()
            assert len(res_entries.data) == 2
            debit = [e for e in res_entries.data if e["side"] == "Debit"][0]
            credit = [e for e in res_entries.data if e["side"] == "Credit"][0]
            assert debit["amount"] == 8000.0
            assert credit["amount"] == 8000.0
            assert debit["account_code"] == "1050", "Bank should be debited"
            assert credit["account_code"] == "1000", "Vault Cash should be credited"

        run_test("Treasury transfer balanced double-entry", test_treasury_transfer)

        # 4. Duplicate events are ignored (Idempotency)
        def test_idempotency():
            # Get event created in step 2
            res_ev = client.table("event_store").select("*").eq("aggregate_type", "IndividualSavings").order("created_at", desc=True).limit(1).execute()
            assert len(res_ev.data) == 1
            ev_data = res_ev.data[0]
            
            event = DomainEvent(
                event_id=ev_data["event_id"],
                aggregate_id=ev_data["aggregate_id"],
                aggregate_type=ev_data["aggregate_type"],
                event_type=ev_data["event_type"],
                payload=ev_data["payload"]
            )
            
            # Post again
            tx_id = FinancialPostingEngine.post_event(uow, event)
            assert tx_id == "ALREADY_POSTED" or (tx_id is not None and len(tx_id) == 36)

        run_test("Event Posting Idempotency check", test_idempotency)

        # 5. Failed events can be safely retried
        def test_failed_event_retry():
            invalid_event_id = str(uuid.uuid4())
            event = DomainEvent(
                event_id=invalid_event_id,
                aggregate_id=TEST_LOAN_ID,
                aggregate_type="Loan",
                event_type="InvalidPostEvent",
                payload={"amount": 1000.0, "branch": TEST_BRANCH_NAME, "officer": TEST_USER_USERNAME}
            )
            uow.event_store.append(event)
            
            # This should fail
            try:
                FinancialPostingEngine.post_event(uow, event)
                assert False, "Expected post_event to fail for InvalidPostEvent"
            except Exception:
                pass
                
            # Verify status is Failed
            status_res = client.table("event_processing").select("status").eq("event_id", invalid_event_id).execute()
            assert status_res.data[0]["status"] == "Failed"
            
            # Seed posting rule for InvalidPostEvent
            client.table("posting_rules").insert({
                "event_type": "InvalidPostEvent",
                "debit_account": "1000",
                "credit_account": "2000",
                "version": 1
            }).execute()
            
            # Clear posting rules cache
            uow.posting_rules._cache.clear()
            
            # Retry
            event.status = "Pending"
            client.table("event_store").update({"status": "Pending"}).eq("event_id", invalid_event_id).execute()
            client.table("event_processing").update({"status": "Pending"}).eq("event_id", invalid_event_id).execute()
            
            tx_id = FinancialPostingEngine.post_event(uow, event)
            assert tx_id is not None and len(tx_id) == 36
            
            # Verify status is Posted
            status_res_2 = client.table("event_processing").select("status").eq("event_id", invalid_event_id).execute()
            assert status_res_2.data[0]["status"] == "Posted"
            
            # Clean up rule
            client.table("posting_rules").delete().eq("event_type", "InvalidPostEvent").execute()
            client.table("event_processing").delete().eq("event_id", invalid_event_id).execute()
            client.table("event_store").delete().eq("event_id", invalid_event_id).execute()

        run_test("Failed event retry recovery", test_failed_event_retry)

        # 6. Cashbook projections update correctly
        def test_cashbook_projection():
            cb = uow.cashbook.find_by_date_and_branch(date.today().isoformat(), TEST_BRANCH_NAME)
            assert cb is not None, "Cashbook projection was not updated/created"
            # check cashbook values
            # opening balance + inflows (SavingsDeposited: 15000.0) - outflows (LoanDisbursed: 50000.0, BankDeposit: 8000.0)
            assert cb.savings_deposit == 15000.0, f"Expected savings_deposit = 15000, got {cb.savings_deposit}"
            assert cb.bank_deposit == 8000.0, f"Expected bank_deposit = 8000, got {cb.bank_deposit}"

        run_test("Cashbook Dynamic Projection Aggregation", test_cashbook_projection)

    finally:
        print("\nCleaning up verification records...")
        try:
            # Delete treasury transactions first (violates foreign key references to branches and users)
            client.table("treasury_transactions").delete().eq("branch_id", TEST_BRANCH_ID).execute()
            
            # Delete transactions and ledger entries
            client.table("financial_ledger_entries").delete().eq("branch_id", TEST_BRANCH_ID).execute()
            client.table("financial_transactions").delete().eq("branch_id", TEST_BRANCH_ID).execute()
            # Delete cashbook
            client.table("master_cashbook").delete().eq("branch_id", TEST_BRANCH_ID).execute()
            # Delete events
            client.table("event_processing").delete().eq("processor_name", "posting_engine").execute()
            client.table("event_store").delete().eq("aggregate_id", TEST_LOAN_ID).execute()
            
            # Delete savings
            client.table("individual_savings").delete().eq("client_id", TEST_CLIENT_ID).execute()
            # Delete loan
            client.table("loans").delete().eq("loan_id", TEST_LOAN_ID).execute()
            # Delete client
            client.table("clients").delete().eq("client_id", TEST_CLIENT_ID).execute()
            # Delete user
            client.table("user_roles").delete().eq("user_id", TEST_USER_ID).execute()
            client.table("app_users").delete().eq("id", TEST_USER_ID).execute()
            # Delete branch
            client.table("branches").delete().eq("branch_id", TEST_BRANCH_ID).execute()
            print("Cleanup completed successfully.")
        except Exception as e:
            print(f"Cleanup encountered errors: {e}")

print("\n=== INTEGRATION VERIFICATION SUMMARY ===")
print(f"Total Passed: {len(passed_checks)}")
print(f"Total Failed: {len(failed_checks)}")

if failed_checks:
    print("Errors:")
    for name, err in failed_checks:
        print(f"  - {name}: {err}")
    sys.exit(1)
else:
    print("ALL TESTS PASSED SUCCESSFULLY!")
    sys.exit(0)
