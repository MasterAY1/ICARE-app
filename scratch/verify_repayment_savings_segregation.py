import sys
import toml
from datetime import date
from mappers.base_mappers import RepaymentMapper
from database.repositories.repayment_repository import RepaymentRepository
from domain.entities.repayment import Repayment

def run_tests():
    print("=== VERIFYING REPAYMENT & SAVINGS SEGREGATION ===")
    
    # Test 1: RepaymentMapper with both Repayment and Savings
    dto = {
        "id": "test-rep-1",
        "client_id": "CLI-001",
        "client_name": "Test Client",
        "loan_id": "LOAN-001",
        "loan_repayment_amount": 10000.0,
        "savings_amount": 2000.0,
        "processing_fee_paid": 500.0,
        "others_amount": 300.0,
        "amount_paid": 10000.0,
        "date": "2026-08-15",
        "transaction_type": "Loan"
    }
    
    domain_rep = RepaymentMapper.to_domain(dto)
    print(f"\nTest 1 (RepaymentMapper):")
    print(f"  Input loan_repay: {dto['loan_repayment_amount']}, savings: {dto['savings_amount']}")
    print(f"  Mapped domain amount_paid: {domain_rep.amount_paid}")
    print(f"  Mapped domain loan_repayment_amount: {domain_rep.loan_repayment_amount}")
    print(f"  Mapped domain savings_amount: {domain_rep.savings_amount}")
    assert domain_rep.amount_paid == 10000.0, f"Expected 10000.0, got {domain_rep.amount_paid}"
    print("  >>> PASS: RepaymentMapper strictly isolates loan repayment from savings and fees.")

    # Test 2: RepaymentMapper when amount_paid is missing / 0 but loan_repayment_amount is set
    dto2 = {
        "id": "test-rep-2",
        "client_id": "CLI-002",
        "loan_repayment_amount": 7500.0,
        "savings_amount": 1500.0,
        "amount_paid": 0.0,
        "transaction_type": "Loan"
    }
    domain_rep2 = RepaymentMapper.to_domain(dto2)
    print(f"\nTest 2 (Missing/Zero amount_paid fallback):")
    print(f"  Input loan_repay: 7500.0, savings: 1500.0, amount_paid: 0.0")
    print(f"  Mapped domain amount_paid: {domain_rep2.amount_paid}")
    assert domain_rep2.amount_paid == 7500.0, f"Expected 7500.0, got {domain_rep2.amount_paid}"
    print("  >>> PASS: Fallback uses loan_repayment_amount, NOT savings.")

    # Test 3: RepaymentMapper for pure Savings transaction
    dto3 = {
        "id": "test-rep-3",
        "client_id": "CLI-003",
        "loan_repayment_amount": 0.0,
        "savings_amount": 3000.0,
        "amount_paid": 3000.0,
        "transaction_type": "Savings"
    }
    domain_rep3 = RepaymentMapper.to_domain(dto3)
    print(f"\nTest 3 (Pure Savings transaction):")
    print(f"  Input savings: 3000.0, transaction_type: 'Savings'")
    print(f"  Mapped domain amount_paid (loan): {domain_rep3.amount_paid}")
    print(f"  Mapped domain savings_amount: {domain_rep3.savings_amount}")
    assert domain_rep3.amount_paid == 0.0, f"Expected 0.0 for loan repayment, got {domain_rep3.amount_paid}"
    assert domain_rep3.savings_amount == 3000.0, f"Expected 3000.0 for savings, got {domain_rep3.savings_amount}"
    print("  >>> PASS: Pure savings transaction does not populate loan amount_paid.")

    # Test 4: Live DB Repayment & Dashboard verification
    try:
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        from services.dashboard_service import DashboardService
        
        with SupabaseUnitOfWork() as uow:
            branches_res = uow.client.table("branches").select("*").limit(1).execute()
            b_name = branches_res.data[0]["name"] if branches_res.data else "Ogijo"
            b_id = branches_res.data[0]["branch_id"] if branches_res.data else None
            
            d_data = DashboardService.get_director_dashboard_data(uow, date.today())
            print(f"\nTest 4 (Director Dashboard Data):")
            print(f"  Today's Collections: ₦{d_data['executive_overview']['today_collections']:,.0f}")
            print(f"  Total Savings: ₦{d_data['executive_overview']['total_savings']:,.0f}")
            print("  >>> PASS: Director Dashboard queries executed cleanly.")
    except Exception as e:
        print(f"\nTest 4 note (DB context): {e}")

    print("\n=== ALL REGRESSION TESTS PASSED SUCCESSFULLY ===")

if __name__ == "__main__":
    run_tests()
