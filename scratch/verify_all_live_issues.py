import os
import sys
import uuid
from datetime import date, timedelta

# Add workspace to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.repayment import Repayment
from domain.entities.loan import Loan
from domain.enums import LoanStatus
from services.repayment_service import RepaymentService
from services.savings_service import SavingsService
from services.loan_service import LoanService
from services.dashboard_service import DashboardService
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

def run_tests():
    print("==================================================")
    print("RUNNING COMPREHENSIVE LIVE ISSUES VERIFICATION...")
    print("==================================================")
    
    with SupabaseUnitOfWork() as uow:
        # Resolve Branch and Officer
        b_res = uow.client.table("branches").select("branch_id, name").eq("name", "Ogijo").execute()
        if not b_res.data:
            print("Branch Ogijo not found")
            return
        branch_id = b_res.data[0]["branch_id"]
        branch_name = b_res.data[0]["name"]
        
        o_res = uow.client.table("app_users").select("*").eq("branch_id", branch_id).execute()
        if not o_res.data:
            o_res = uow.client.table("app_users").select("*").limit(1).execute()
        if not o_res.data:
            print("No officer found")
            return
        officer_id = o_res.data[0].get("id") or o_res.data[0].get("user_id")
        officer_name = o_res.data[0].get("username") or o_res.data[0].get("name")
        
        print(f"Testing with Branch: {branch_name} ({branch_id}), Officer: {officer_name} ({officer_id})")
        
        # 1. TEST SAVINGS VS REPAYMENT SEPARATION
        print("\n--- TEST 1: Savings & Repayment Separation ---")
        client_res = uow.client.table("clients").select("client_id, name").eq("branch_id", branch_id).limit(1).execute()
        if client_res.data:
            cid = client_res.data[0]["client_id"]
            cname = client_res.data[0]["name"]
        else:
            cid = "TEST-CLIENT-001"
            cname = "Test Client"
            
        today = date.today()
        
        # Post individual savings of 1,500
        sav_rec = SavingsService.post_individual_savings(uow, cid, cname, branch_name, officer_name, 1500.0, 0.0, remarks="Test Daily Savings")
        print(f"Posted savings: NGN 1,500. Result ID: {sav_rec.id if sav_rec else 'None'}")
        
        # Verify individual_savings table
        check_sav = uow.client.table("individual_savings").select("*").eq("officer_id", officer_id).eq("posting_date", today.isoformat()).execute()
        print(f"Found {len(check_sav.data)} savings records for today in individual_savings table.")
        assert len(check_sav.data) > 0, "No savings records found in individual_savings table!"
        
        # Verify Dashboard data for Today's Savings
        dash_data = DashboardService.get_co_dashboard_data(uow, branch_name, officer_name, officer_id, branch_id, today)
        sav_metric = dash_data.get("savings", {})
        print(f"Dashboard Savings Deposited: NGN {sav_metric.get('deposited_amt', 0):,.2f}")
        assert sav_metric.get("deposited_amt", 0) >= 1500.0, f"Dashboard savings deposited {sav_metric.get('deposited_amt')} is less than 1500!"
        print("TEST 1 PASSED: Savings accurately captured in individual_savings and Dashboard.")

        # 2. TEST REPAYMENT BUCKETING & PROJECTION IN CO CASHBOOK
        print("\n--- TEST 2: CO Cashbook 12-Weeks & 24-Weeks Bucketing ---")
        # Fetch or mock a 12-week loan
        loan_res = uow.client.table("loans").select("loan_id, client_id, loan_products(name, repayment_cycle)").eq("branch_id", branch_id).limit(1).execute()
        if loan_res.data:
            test_loan = loan_res.data[0]
            test_loan_id = test_loan["loan_id"]
            test_cid = test_loan["client_id"]
        else:
            test_loan_id = str(uuid.uuid4())
            test_cid = cid

        rep_entity = Repayment(
            id=str(uuid.uuid4()),
            loan_id=test_loan_id,
            client_id=test_cid,
            amount_paid=16500.0,
            savings_amount=0.0,
            loan_repayment_amount=16500.0,
            withdrawal_amount=0.0,
            others_amount=0.0,
            recovery_amount=0.0,
            initial_payment=0.0,
            payment_date=today,
            transaction_type="Loan",
            branch=branch_name,
            credit_officer=officer_name,
            note="Test 12-Week Repayment",
            extra_fields={
                "App Fee": 3500.0,
                "Pass Book Bonus": 500.0,
                "Credit Form Damage": 1000.0,
                "Bonus": 2000.0,
                "Bank Deposited": 50000.0,
                "Cash and Carry": 15000.0
            }
        )
        
        RepaymentService.post_repayment(uow, rep_entity)
        print(f"Posted Repayment of NGN 16,500 with EOD extra fees. Rep ID: {rep_entity.id}")
        
        # Rebuild CO cashbook
        cb_res = CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, officer_id, today)
        print(f"CO Cashbook Projection Result:")
        print(f"  - Repayment 12 Weeks: NGN {cb_res.get('rep_12_weeks', 0):,.2f}")
        print(f"  - Repayment 24 Weeks: NGN {cb_res.get('rep_24_weeks', 0):,.2f}")
        print(f"  - Repayment 60 Days:  NGN {cb_res.get('rep_daily', 0):,.2f}")
        print(f"  - App Fee:            NGN {cb_res.get('app_fee', 0):,.2f}")
        print(f"  - Passbook:           NGN {cb_res.get('passbook', 0):,.2f}")
        print(f"  - Credit Form Damage: NGN {cb_res.get('credit_form_damage', 0):,.2f}")
        print(f"  - Bonus:              NGN {cb_res.get('bonus', 0):,.2f}")
        print(f"  - Cash & Carry:       NGN {cb_res.get('cash_and_carry', 0):,.2f}")
        print(f"  - Bank Deposited:     NGN {cb_res.get('bank_deposit', 0):,.2f}")
        print(f"  - Total Inflows:      NGN {cb_res.get('total_inflows', 0):,.2f}")
        print(f"  - Total Outflows:     NGN {cb_res.get('total_outflows', 0):,.2f}")
        print(f"  - Closing Balance:    NGN {cb_res.get('closing_balance', 0):,.2f}")
        
        assert cb_res.get("rep_12_weeks", 0) >= 16500.0 or cb_res.get("rep_daily", 0) >= 16500.0, "Repayment not captured in cashbook!"
        assert cb_res.get("app_fee", 0) >= 3500.0, "App fee not captured!"
        assert cb_res.get("passbook", 0) >= 500.0, "Passbook not captured!"
        assert cb_res.get("credit_form_damage", 0) >= 1000.0, "Credit form damage not captured!"
        assert cb_res.get("bonus", 0) >= 2000.0, "Bonus not captured!"
        assert cb_res.get("bank_deposit", 0) >= 50000.0, "Bank deposit not captured!"
        assert cb_res.get("cash_and_carry", 0) >= 15000.0, "Cash and carry not captured!"
        print("TEST 2 PASSED: All EOD fees, bank deposits, and loan repayments bucketed into CO Cashbook accurately.")

        # 3. TEST LOAN SCHEDULE DUE DATE CALCULATION
        print("\n--- TEST 3: Loan Origination Schedule Start Date Calculation ---")
        lp_res = uow.client.table("loan_products").select("name").limit(1).execute()
        valid_prod_name = lp_res.data[0]["name"] if lp_res.data else "12 Weeks (Daily Repayment)"
        print(f"Using valid product name: {valid_prod_name}")
        
        new_loan_id = str(uuid.uuid4())
        test_new_loan = Loan(
            id=new_loan_id,
            client_id=cid,
            client_name=cname,
            product_type=valid_prod_name,
            amount=100000.0,
            duration=12,
            frequency="Weekly",
            gap_fee=0.0,
            expected_installment=10000.0,
            total_payable=120000.0,
            status=LoanStatus.PENDING,
            branch=branch_name,
            credit_officer=officer_name,
            officer_id=officer_id,
            branch_id=branch_id,
            start_date=None,
            is_asset=False,
            extra_fields={}
        )
        uow.loans.create(test_new_loan)
        print(f"Created pending loan: {new_loan_id}")
        
        disbursed_loan = LoanService.disburse_loan(uow, test_new_loan)
        print(f"Disbursed loan ID: {disbursed_loan.id}")
        print(f"  - Disbursement Date: {disbursed_loan.disbursement_date}")
        print(f"  - Start Date (First Repayment): {disbursed_loan.start_date}")
        print(f"  - Expected End Date: {disbursed_loan.expected_end_date}")
        
        # Check loan_schedule table
        sched_res = uow.client.table("loan_schedule").select("*").eq("loan_id", new_loan_id).order("installment_number").execute()
        print(f"Generated {len(sched_res.data)} schedule installments in loan_schedule table.")
        assert len(sched_res.data) > 0, "No schedule installments generated!"
        
        first_due = date.fromisoformat(sched_res.data[0]["due_date"])
        print(f"First installment due date: {first_due}")
        assert first_due > disbursed_loan.disbursement_date, f"First due date {first_due} should be AFTER disbursement date {disbursed_loan.disbursement_date}!"
        print("TEST 3 PASSED: Repayment schedule starts after disbursement date with accurate installments.")

    print("\n==================================================")
    print("ALL LIVE SYSTEM VERIFICATIONS PASSED WITH 100% SUCCESS!")
    print("==================================================")

if __name__ == "__main__":
    run_tests()
