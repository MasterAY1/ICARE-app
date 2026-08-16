import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.portfolio_service import PortfolioService
from services.rbac_scope_service import RBACScopeService
from datetime import date

def test_all_portfolio_filters():
    uow = SupabaseUnitOfWork()
    user_bm = {"id": "f2656341-a85a-4e06-a1c8-d62cfef19b08", "username": "BM_Ogijo", "role": "BM", "branch": "Ogijo", "branch_id": "997d504e-7f5c-4772-887d-fdd5a4c1183b"}
    scope_bm = RBACScopeService.resolve_scope(user_bm)
    
    print("==================================================")
    print("1. TEST CURRENT MONTH (2026-08-01 to 2026-08-31)")
    p_month = PortfolioService.get_portfolio_data_for_scope(uow, scope_bm, start_date=date(2026, 8, 1), end_date=date(2026, 8, 31))
    s_m = p_month["summary"]
    print(f"Loans Disbursed in August:  {s_m['disbursement_summary']['count']} Loans (NGN {s_m['disbursement_summary']['amount']:,.2f})")
    print(f"Total Active Credit:        NGN {s_m['total_active_credit']:,.2f}")
    print(f"Total Outstanding Balance:  NGN {s_m['total_outstanding_balance']:,.2f}")
    assert s_m['disbursement_summary']['count'] == 0, "No new loans were disbursed in August (all are opening balances)"
    assert s_m['disbursement_summary']['amount'] == 0.0, "Disbursed amount in August must be 0.0"
    assert s_m['total_active_credit'] == 1509000.0, "Total active credit must remain 1,509,000"
    assert s_m['total_outstanding_balance'] == 825875.0, f"Total outstanding balance must be 825,875, got {s_m['total_outstanding_balance']}"

    print("\n==================================================")
    print("2. TEST CUSTOM DATE RANGE: 2026-08-03 to 2026-08-03")
    p1 = PortfolioService.get_portfolio_data_for_scope(uow, scope_bm, start_date=date(2026, 8, 3), end_date=date(2026, 8, 3))
    s1 = p1["summary"]
    print(f"Period Deposits:    NGN {s1['period_savings_deposit']:,.2f}")
    print(f"Period Withdrawals: NGN {s1['period_savings_withdrawal']:,.2f}")
    print(f"Total Savings Bal:  NGN {s1['total_savings_balance']:,.2f}")
    print(f"Loans Disbursed:    {s1['disbursement_summary']['count']}")
    assert s1['period_savings_deposit'] == 0.0
    assert s1['period_savings_withdrawal'] == 0.0
    assert s1['total_savings_balance'] == 364475.0
    assert s1['disbursement_summary']['count'] == 0

    print("\n==================================================")
    print("3. TEST LOAN PRODUCT FILTER: 'Weekly 12W'")
    p2 = PortfolioService.get_portfolio_data_for_scope(uow, scope_bm, selected_product="Weekly 12W")
    s2 = p2["summary"]
    print(f"Active Credit:      NGN {s2['total_active_credit']:,.2f}")
    print(f"Clients Count:      {s2['total_registered_clients']}")
    assert s2['total_active_credit'] == 840000.0
    assert s2['total_registered_clients'] == 6

    print("\n==================================================")
    print("4. TEST GROUP FILTER: 'Favour'")
    p3 = PortfolioService.get_portfolio_data_for_scope(uow, scope_bm, selected_group="Favour")
    s3 = p3["summary"]
    print(f"Active Credit:      NGN {s3['total_active_credit']:,.2f}")
    print(f"Total Savings Bal:  NGN {s3['total_savings_balance']:,.2f}")
    assert s3['total_active_credit'] == 1185000.0
    assert s3['total_savings_balance'] == 255275.0

    print("\n==================================================")
    print("5. TEST OFFICER FILTER: 'CO2'")
    p4 = PortfolioService.get_portfolio_data_for_scope(uow, scope_bm, selected_officer="CO2")
    s4 = p4["summary"]
    print(f"Active Credit:      NGN {s4['total_active_credit']:,.2f}")
    print(f"Total Savings Bal:  NGN {s4['total_savings_balance']:,.2f}")
    print(f"Clients Count:      {s4['total_registered_clients']}")
    assert s4['total_savings_balance'] == 364475.0
    assert s4['total_registered_clients'] == 83

    print("\n==================================================")
    print("6. TEST BRANCH FILTER: 'Ogijo'")
    p5 = PortfolioService.get_portfolio_data_for_scope(uow, scope_bm, selected_branch="Ogijo")
    s5 = p5["summary"]
    print(f"Total Savings Bal:  NGN {s5['total_savings_balance']:,.2f}")
    print(f"Clients Count:      {s5['total_registered_clients']}")
    assert s5['total_savings_balance'] >= 365975.0
    assert s5['total_registered_clients'] == 353

    print("\n>>> ALL PORTFOLIO TESTS (INCLUDING DISBURSEMENT IN PERIOD) PASSED WITH 100% SUCCESS! <<<")

if __name__ == "__main__":
    test_all_portfolio_filters()
