import uuid
from datetime import datetime, date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.savings_service import SavingsService
from services.financial_reconciliation_service import FinancialReconciliationService

if __name__ == "__main__":
    with SupabaseUnitOfWork() as uow:
        print("Starting E2E Financial Flow Test...")
        client_id = str(uuid.uuid4())
        loan_id = str(uuid.uuid4())
        branch = "Ogijo"
        officer = "Olamide"
        
        # 1. Deposit Savings
        print("1. Depositing Savings (100,000 NGN)")
        SavingsService.post_individual_savings(
            uow, client_id, "E2E Client", branch, officer, deposit_amount=100000.0, remarks="Initial Deposit"
        )
        
        # 2. Offset Loan from Savings
        print("2. Offsetting Loan from Savings (25,000 NGN)")
        SavingsService.post_loan_offset_from_savings(
            uow, client_id, "E2E Client", loan_id, branch, officer, 25000.0, "IndividualSavings"
        )
        
        # 3. Transfer to Laps
        print("3. Transferring to LAPS (15,000 NGN)")
        SavingsService.transfer_to_laps(
            uow, client_id, "E2E Client", branch, officer, 15000.0, "IndividualSavings"
        )
        
        # 4. Laps Payout (Cash)
        print("4. Paying out LAPS in Cash (5,000 NGN)")
        SavingsService.pay_laps(
            uow, client_id, "E2E Client", branch, officer, 5000.0, cash_paid=True
        )
        
        # Verify 6-way integrity
        print("\nVerifying 6-way integrity...")
        res = FinancialReconciliationService.verify_6way_financial_integrity(uow, None, date.today())
        print(f"Is Balanced: {res['is_balanced']}")
        print(f"Status: {res['status_text']}")
        print(f"Ledger: {res['ledger_total']}")
        print(f"Audit Views: {res['audit_views_total']}")
        print(f"CO Cashbooks: {res['co_cashbooks_total']}")
        print(f"Master Cashbook: {res['master_cashbook_total']}")
        if res.get('variances'):
            print("Variances:", res['variances'])
        
        print("E2E Complete.")
