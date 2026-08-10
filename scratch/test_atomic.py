import sys
import os
import uuid
from datetime import date
from database.connection import get_db_client
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.loan import Loan
from domain.entities.repayment import Repayment
from services.loan_service import LoanService
from services.repayment_service import RepaymentService

def test_atomicity():
    client = get_db_client()
    
    print("Testing Atomic Loan Disbursement...")
    with SupabaseUnitOfWork(client) as uow:
        # We need a branch and officer
        res_u = client.table("app_users").select("username, branches(name)").limit(1).execute()
        if not res_u.data:
            print("No users found.")
            return
        
        user = res_u.data[0]
        officer = user["username"]
        branch = user["branches"]["name"] if user.get("branches") else "TestBranch"
        
        # Test Loan
        loan_id = str(uuid.uuid4())
        client_code = "ATOMIC-TEST-CLIENT"
        
        loan = Loan(
            id=loan_id,
            client_id=client_code,
            client_name="Test Atomic Client",
            product_type="11% Profit Sales - 60 Days",
            branch=branch,
            credit_officer=officer,
            amount=50000.0,
            start_date=date.today(),
            status="Pending",
            extra_fields={"average_monthly_income": 100000.0, "product_category": "Finance"}
        )
        
        try:
            disbursed_loan = LoanService.disburse_loan(uow, loan)
            print(f"Success! Disbursed loan ID: {disbursed_loan.id}")
        except Exception as e:
            print(f"Disbursement Error: {e}")
            import traceback
            traceback.print_exc()

        print("\nTesting Atomic Repayment...")
        repayment = Repayment(
            id=str(uuid.uuid4()),
            payment_date=date.today(),
            loan_id=loan_id,
            client_id=client_code,
            amount_paid=2000.0,
            loan_repayment_amount=1500.0,
            branch=branch,
            credit_officer=officer,
            extra_fields={"Bank Deposited": 500.0}
        )
        try:
            posted_rep = RepaymentService.post_repayment(uow, repayment)
            print(f"Success! Repayment ID: {posted_rep.id}")
        except Exception as e:
            print(f"Repayment Error: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    test_atomicity()
