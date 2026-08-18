import sys, os, uuid
from datetime import date, datetime
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.loan import Loan
from domain.enums import LoanStatus
from services.loan_service import LoanService
from services.client_status_service import ClientStatusService
from services.financial_reconciliation_service import FinancialReconciliationService

def test_bm_approval_flow():
    print("==================================================")
    print("🔍 TESTING BM LOAN APPROVAL & DISBURSEMENT ENGINE")
    print("==================================================")

    with SupabaseUnitOfWork() as uow:
        # Fetch branch & a test client
        b_res = uow.client.table("branches").select("branch_id, name").eq("name", "Ogijo").execute()
        branch_id = b_res.data[0]["branch_id"]
        branch_name = b_res.data[0]["name"]

        # Pick a registered client
        c_res = uow.client.table("clients").select("client_id, name, client_code, officer_id").eq("status_id", "11111111-1111-1111-1111-111111110001").limit(1).execute()
        client = c_res.data[0]
        client_id = client["client_id"]
        client_name = client["name"]
        officer_id = client["officer_id"]

        print(f"Testing with Client: {client_name} ({client['client_code']})")

        # 1. Create a Pending Loan
        test_loan_id = str(uuid.uuid4())
        loan_entity = Loan(
            id=test_loan_id,
            client_id=client_id,
            client_name=client_name,
            product_type="Weekly 12W",
            amount=50000.0,
            duration=12,
            frequency="Weekly",
            gap_fee=0.0,
            expected_installment=4583.33,
            total_payable=55000.0,
            status=LoanStatus.PENDING,
            branch=branch_name,
            credit_officer="CO2",
            officer_id=officer_id,
            branch_id=branch_id,
            start_date=date.today(),
            is_asset=False,
            extra_fields={
                "lifecycle_status": "Submitted",
                "product_category": "Finance",
                "active_credit": 50000.0,
                "loan_repay": 4583.33,
                "total_due": 55000.0
            }
        )
        uow.loans.create(loan_entity)
        ClientStatusService.on_loan_submitted(uow, client_id, test_loan_id, officer_id)

        # Check client status is Pending Loan
        c_check = uow.client.table("clients").select("status_id, client_statuses(name)").eq("client_id", client_id).execute()
        c_status_name = c_check.data[0]["client_statuses"]["name"]
        print(f"Step 1: Submitted Loan Application → Client Status: {c_status_name}")
        assert c_status_name == "Pending Loan", f"Expected Pending Loan, got {c_status_name}"

        # 2. BM Approves and Disburses Loan
        print("Step 2: BM Approving and Disbursing Loan...")
        disbursed_loan = LoanService.approve_and_disburse_loan(uow, test_loan_id, "BM_Ogijo")

        # Check loan status is Active
        l_check = uow.client.table("loans").select("status").eq("loan_id", test_loan_id).execute()
        assert l_check.data[0]["status"] in ["Active", "ACTIVE"], f"Expected Active, got {l_check.data[0]['status']}"

        # Check client status transitioned to On Loan
        c_check2 = uow.client.table("clients").select("status_id, client_statuses(name)").eq("client_id", client_id).execute()
        c_status_name2 = c_check2.data[0]["client_statuses"]["name"]
        print(f"Step 3: Post-Approval → Client Status: {c_status_name2}")
        assert c_status_name2 == "On Loan", f"Expected On Loan, got {c_status_name2}"

        # Check Ledger entry was created for Account 1000
        led_check = uow.client.table("financial_ledger_entries").select("*").eq("account_code", "1000").eq("side", "CREDIT").execute()
        print(f"Step 4: Ledger entries created for Account 1000: {len(led_check.data or [])}")

        print("\n🎉 BM LOAN APPROVAL TEST PASSED PERFECTLY!")
        print("==================================================")

if __name__ == "__main__":
    test_bm_approval_flow()
