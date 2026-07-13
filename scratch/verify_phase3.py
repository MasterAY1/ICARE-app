import sys
import os
from datetime import date, datetime
import uuid

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def load_secrets():
    secrets = {}
    try:
        # Resolve path relative to project root
        proj_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        path = os.path.join(proj_root, ".streamlit", "secrets.toml")
        with open(path, "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or line.startswith("["):
                    continue
                if "=" in line:
                    key, val = line.split("=", 1)
                    key = key.strip()
                    val = val.strip().strip('"').strip("'").strip()
                    secrets[key] = val
    except Exception as e:
        print(f"Error loading secrets: {e}")
    return secrets

def run_verification():
    secrets = load_secrets()
    url = secrets.get("SUPABASE_URL")
    key = secrets.get("SUPABASE_KEY")

    if not url or not key:
        print("FATAL: Supabase URL/KEY not found in secrets.toml")
        sys.exit(1)

    from supabase import create_client
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
    from domain.entities.savings import IndividualSavings, GroupSavings, MiscSavings, LapsSavings
    from domain.entities.cashbook_entry import CashbookEntry
    from domain.entities.audit_event import AuditEvent

    from domain.enums import LoanStatus, ClientStatus, SavingsStatus

    from database.repositories.user_repository import SupabaseUserRepository
    from database.repositories.loan_repository import SupabaseLoanRepository
    from database.repositories.repayment_repository import SupabaseRepaymentRepository
    from database.repositories.savings_repository import (
        SupabaseIndividualSavingsRepository,
        SupabaseGroupSavingsRepository,
        SupabaseMiscSavingsRepository,
        SupabaseLapsSavingsRepository
    )
    from database.repositories.cashbook_repository import SupabaseCashbookRepository
    from database.repositories.audit_repository import SupabaseAuditRepository

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

    print("=== STARTING INTEGRATION VERIFICATION ===")

    # Pre-clean just in case a previous run failed mid-cleanup
    try:
        client.table("audit_logs").delete().eq("user_id", TEST_USER_ID).execute()
        client.table("master_cashbook").delete().eq("branch_id", TEST_BRANCH_ID).execute()
        client.table("individual_savings").delete().eq("client_id", TEST_CLIENT_ID).execute()
        client.table("internal_savings").delete().eq("client_id", TEST_CLIENT_ID).execute()
        client.table("laps_savings").delete().eq("client_id", TEST_CLIENT_ID).execute()
        client.table("repayments").delete().eq("client_id", TEST_CLIENT_ID).execute()
        client.table("loans").delete().eq("loan_id", TEST_LOAN_ID).execute()
        client.table("clients").delete().eq("client_id", TEST_CLIENT_ID).execute()
        client.table("user_roles").delete().eq("user_id", TEST_USER_ID).execute()
        client.table("app_users").delete().eq("username", TEST_USER_USERNAME).execute()
        client.table("app_users").delete().eq("id", TEST_USER_ID).execute()
        client.table("branches").delete().eq("branch_id", TEST_BRANCH_ID).execute()
    except Exception:
        pass

    # Setup branch first
    try:
        client.table("branches").upsert({
            "branch_id": TEST_BRANCH_ID,
            "zone_id": TEST_ZONE_ID,
            "name": TEST_BRANCH_NAME,
            "is_active": True
        }).execute()
        print("Pre-test setup: Branch created/upserted.")
    except Exception as e:
        print(f"Pre-test setup branch failed: {e}")
        sys.exit(1)

    # Initialize repositories
    user_repo = SupabaseUserRepository(client)
    loan_repo = SupabaseLoanRepository(client)
    repay_repo = SupabaseRepaymentRepository(client)
    ind_savings_repo = SupabaseIndividualSavingsRepository(client)
    grp_savings_repo = SupabaseGroupSavingsRepository(client)
    misc_savings_repo = SupabaseMiscSavingsRepository(client)
    laps_savings_repo = SupabaseLapsSavingsRepository(client)
    cashbook_repo = SupabaseCashbookRepository(client)
    audit_repo = SupabaseAuditRepository(client)

    try:
        # UserRepository tests
        def test_user_repo():
            # 1. Create
            u = User(
                id=TEST_USER_ID,
                username=TEST_USER_USERNAME,
                full_name="Integration Verifier",
                role="Admin",
                branch_name=TEST_BRANCH_NAME,
                password_hash="test_hash",
                created_at=datetime.now()
            )
            user_repo.create(u)
            
            # 2. Read
            fetched = user_repo.find_by_username(TEST_USER_USERNAME)
            assert fetched is not None, "Failed to retrieve user by username"
            assert fetched.full_name == "Integration Verifier", "User full name mismatch"
            assert fetched.role == "Admin", "User role join mapping failed"
            assert fetched.branch_name == TEST_BRANCH_NAME, "User branch join mapping failed"
            
            # 3. Update
            fetched.full_name = "Integration Verifier Updated"
            user_repo.update(fetched)
            updated = user_repo.find_by_id(TEST_USER_ID)
            assert updated.full_name == "Integration Verifier Updated", "User update failed"

        run_test("UserRepository CRUD and relationships", test_user_repo)

        # LoanRepository tests
        def test_loan_repo():
            # 1. Create (should auto-create client in clients table)
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
            loan_repo.create(l)
            
            # 2. Read client mapping
            client_res = client.table("clients").select("*").eq("client_id", TEST_CLIENT_ID).execute()
            assert len(client_res.data) > 0, "Client profile was not auto-created in clients table"
            assert client_res.data[0]["name"] == TEST_CLIENT_NAME, "Client name mismatch"

            # 3. Read loan mapping & Joins
            loans = loan_repo.find_by_client_id(TEST_CLIENT_ID)
            assert len(loans) > 0, "Failed to find loan by client ID"
            fetched_loan = loans[0]
            assert fetched_loan.id == TEST_LOAN_ID, "Loan ID mismatch"
            assert fetched_loan.client_name == TEST_CLIENT_NAME, "Client name join reconstruction failed"
            assert fetched_loan.branch == TEST_BRANCH_NAME, "Branch join reconstruction failed"
            assert fetched_loan.credit_officer == "Integration Verifier Updated", "Officer name/full_name join mapping failed"
            
            # 4. Update
            fetched_loan.status = LoanStatus.ACTIVE
            loan_repo.update(fetched_loan)
            updated_loan = loan_repo.find_by_id(TEST_LOAN_ID)
            assert updated_loan.status == LoanStatus.ACTIVE, "Loan update failed"

        run_test("LoanRepository CRUD and auto-upsert relationships", test_loan_repo)

        # RepaymentRepository tests
        def test_repay_repo():
            # 1. Create repayment
            rep = Repayment(
                id=str(uuid.uuid4()),
                loan_id=TEST_LOAN_ID,
                client_id=TEST_CLIENT_ID,
                amount_paid=1500.0,
                savings_amount=500.0,
                loan_repayment_amount=1000.0,
                withdrawal_amount=0.0,
                others_amount=0.0,
                recovery_amount=0.0,
                initial_payment=0.0,
                payment_date=date.today(),
                transaction_type="Loan",
                branch=TEST_BRANCH_NAME,
                credit_officer=TEST_USER_USERNAME,
                note="Test Repayment Note"
            )
            repay_repo.create(rep)
            
            # 2. Read repayments & joins
            reps = repay_repo.find_by_loan(TEST_LOAN_ID)
            assert len(reps) > 0, "Repayments find_by_loan failed"
            fetched_rep = reps[0]
            print("Fetched repayment extra_fields:", fetched_rep.extra_fields)
            assert fetched_rep.amount_paid == 1000.0 or fetched_rep.amount_paid == 1500.0, "Repayment amount mismatch"
            assert fetched_rep.branch == TEST_BRANCH_NAME, "Repayment branch name join failed"
            assert fetched_rep.extra_fields.get("client_name") == TEST_CLIENT_NAME, "Repayment client name join failed"

        run_test("RepaymentRepository CRUD and join mappings", test_repay_repo)

        # SavingsRepository tests
        def test_savings_repos():
            # 1. Individual
            ind = IndividualSavings(
                client_id=TEST_CLIENT_ID,
                client_name=TEST_CLIENT_NAME,
                branch=TEST_BRANCH_NAME,
                officer=TEST_USER_USERNAME,
                deposit_amount=2000.0,
                date=datetime.now()
            )
            ind_savings_repo.create(ind)
            
            # 2. Misc/Internal
            misc = MiscSavings(
                client_id=TEST_CLIENT_ID,
                client_name=TEST_CLIENT_NAME,
                branch=TEST_BRANCH_NAME,
                officer=TEST_USER_USERNAME,
                deposit_amount=500.0,
                date=datetime.now()
            )
            misc_savings_repo.create(misc)
            
            # 3. Laps
            laps = LapsSavings(
                client_id=TEST_CLIENT_ID,
                client_name=TEST_CLIENT_NAME,
                branch=TEST_BRANCH_NAME,
                officer=TEST_USER_USERNAME,
                deposit_amount=1000.0,
                date=datetime.now()
            )
            laps_savings_repo.create(laps)
            
            # Verify totals
            bal_ind = ind_savings_repo.get_total_balance(TEST_BRANCH_NAME)
            bal_misc = misc_savings_repo.get_total_balance(TEST_BRANCH_NAME)
            bal_laps = laps_savings_repo.get_total_balance(TEST_BRANCH_NAME)
            
            assert bal_ind == 2000.0, "Individual savings balance mismatch"
            assert bal_misc == 500.0, "Internal savings balance mismatch"
            assert bal_laps == 1000.0, "Laps savings balance mismatch"

        run_test("SavingsRepository (Individual, Internal, LAPS) operations", test_savings_repos)

        # CashbookRepository tests
        def test_cashbook_repo():
            cb = CashbookEntry(
                id=None,
                date=date.today(),
                branch=TEST_BRANCH_NAME,
                opening_balance=10000.0,
                savings_deposit=2000.0,
                closing_balance=12000.0
            )
            cashbook_repo.create(cb)
            
            fetched = cashbook_repo.find_by_date_and_branch(date.today().isoformat(), TEST_BRANCH_NAME)
            assert fetched is not None, "Cashbook find_by_date_and_branch failed"
            assert fetched.opening_balance == 10000.0, "Opening balance mismatch"
            assert fetched.branch == TEST_BRANCH_NAME, "Cashbook branch join mismatch"

        run_test("CashbookRepository project and joins", test_cashbook_repo)

        # AuditRepository tests
        def test_audit_repo():
            audit_repo.log_action(
                user=TEST_USER_USERNAME,
                role="Admin",
                action="Integration Verification Run",
                table_name="audit_logs",
                record_id=None,
                old_value="none",
                new_value="passed"
            )
            logs = audit_repo.get_logs(10)
            assert len(logs) > 0, "Audit retrieval failed"
            assert logs[0].user == TEST_USER_USERNAME, "Audit username join mapping failed"

        run_test("AuditRepository logging and join fetching", test_audit_repo)

    finally:
        # ==========================================
        # CLEAN UP (Delete test data from DB)
        # ==========================================
        print("\nCleaning up verification records...")
        try:
            # Delete from audit logs
            client.table("audit_logs").delete().eq("user_id", TEST_USER_ID).execute()
            # Delete cashbook entries
            client.table("master_cashbook").delete().eq("branch_id", TEST_BRANCH_ID).execute()
            # Delete savings records
            client.table("individual_savings").delete().eq("client_id", TEST_CLIENT_ID).execute()
            client.table("internal_savings").delete().eq("client_id", TEST_CLIENT_ID).execute()
            client.table("laps_savings").delete().eq("client_id", TEST_CLIENT_ID).execute()
            # Delete repayments
            client.table("repayments").delete().eq("client_id", TEST_CLIENT_ID).execute()
            # Delete loan
            client.table("loans").delete().eq("loan_id", TEST_LOAN_ID).execute()
            # Delete client
            client.table("clients").delete().eq("client_id", TEST_CLIENT_ID).execute()
            # Delete user roles and user
            client.table("user_roles").delete().eq("user_id", TEST_USER_ID).execute()
            client.table("app_users").delete().eq("username", TEST_USER_USERNAME).execute()
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

if __name__ == "__main__":
    run_verification()
