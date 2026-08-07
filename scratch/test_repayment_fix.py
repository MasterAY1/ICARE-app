import os
import sys
import uuid
from datetime import date
sys.path.append(os.path.abspath("c:/Users/DELL/Desktop/Master_ AY Projects/trustmicro-credit"))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.repayment import Repayment
from services.repayment_service import RepaymentService
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

with SupabaseUnitOfWork() as uow:
    # 1. Setup mock loan
    client_id = "test_client_id"
    loan_id = "test_loan_id_24w"
    
    # 2. Insert mock loan into DB directly
    try:
        uow.client.table("loans").insert({
            "loan_id": loan_id,
            "client_id": client_id,
            "client_name": "Test Client",
            "product_type": "Weekly 24W Asset",
            "amount": 50000,
            "duration": 24,
            "frequency": "Weekly",
            "status": "Active",
            "branch": "Ogijo",
            "credit_officer": "CO2",
            "officer_id": "8432dcbc-9fde-4416-836f-eef4167be259", # CO2
            "branch_id": "40dc0c97-09d6-4e55-83e8-5b48bcff9985", # Ogijo
            "start_date": "2026-08-01",
            "extra_fields": {}
        }).execute()
    except Exception as e:
        print("Loan insert error (might exist):", e)
        pass

    # 3. Create mock repayment
    rep = Repayment(
        id=str(uuid.uuid4()),
        loan_id=loan_id,
        client_id=client_id,
        amount_paid=15000,
        savings_amount=0.0,
        loan_repayment_amount=5000,
        withdrawal_amount=0.0,
        others_amount=10000,
        recovery_amount=0.0,
        initial_payment=0.0,
        payment_date=date.today(),
        transaction_type="Collection",
        branch="Ogijo",
        credit_officer="CO2",
        payment_status="Completed",
        note="Test collection",
        extra_fields={
            "App Fee": 2000,
            "Bank Deposited": 8000
        }
    )
    
    # 4. Post Repayment
    RepaymentService.post_repayment(uow, rep)
    print("Repayment posted.")
    
    # 5. Rebuild Cashbook
    branch_id = "40dc0c97-09d6-4e55-83e8-5b48bcff9985"
    officer_id = "8432dcbc-9fde-4416-836f-eef4167be259"
    CoCashbookProjectionBuilder.build_projection(uow, branch_id, date.today(), officer_id=officer_id)
    print("Cashbook rebuilt.")
    
    # 6. Verify Cashbook
    res = uow.client.table("co_cashbooks").select("*").eq("branch_id", branch_id).eq("officer_id", officer_id).eq("date", date.today().isoformat()).execute()
    if res.data:
        c = res.data[0]
        print(f"Rep 24 Weeks: {c.get('rep_24_weeks')}")
        print(f"App Fee: {c.get('app_fee')}")
        print(f"Bank Deposited: {c.get('bank_deposit')}")
        print(f"Total Inflows: {c.get('total_inflows')}")
        print(f"Total Outflows: {c.get('total_outflows')}")
