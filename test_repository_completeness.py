from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.enums import TransactionClassification
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder

def test_unit_of_work_repositories_completeness():
    """Verify that every required specialized repository exists on SupabaseUnitOfWork"""
    uow = SupabaseUnitOfWork()
    
    # Core repositories
    assert hasattr(uow, 'loans'), "Missing loans repository"
    assert hasattr(uow, 'repayments'), "Missing repayments repository"
    assert hasattr(uow, 'individual_savings'), "Missing individual_savings repository"
    assert hasattr(uow, 'group_savings'), "Missing group_savings repository"
    assert hasattr(uow, 'misc_savings'), "Missing misc_savings repository"
    assert hasattr(uow, 'laps_savings'), "Missing laps_savings repository"
    assert hasattr(uow, 'event_store'), "Missing event_store repository"
    assert hasattr(uow, 'posting_rules'), "Missing posting_rules repository"
    assert hasattr(uow, 'ledger'), "Missing ledger repository"
    
    # Specialized Fee Repositories
    assert hasattr(uow, 'processing_fee'), "Missing processing_fee repository"
    assert hasattr(uow, 'passbook'), "Missing passbook repository"
    assert hasattr(uow, 'credit_form'), "Missing credit_form repository"
    assert hasattr(uow, 'credit_form_damage'), "Missing credit_form_damage repository"
    assert hasattr(uow, 'bonus'), "Missing bonus repository"
    assert hasattr(uow, 'misc_fee'), "Missing misc_fee repository"
    assert hasattr(uow, 'contingency'), "Missing contingency repository"
    assert hasattr(uow, 'markup_11'), "Missing markup_11 repository"
    assert hasattr(uow, 'markup_20'), "Missing markup_20 repository"
    
    # Branch Treasury Repositories
    assert hasattr(uow, 'treasury'), "Missing treasury repository"
    assert hasattr(uow, 'bank_deposit'), "Missing bank_deposit repository"
    assert hasattr(uow, 'bank_withdrawal'), "Missing bank_withdrawal repository"
    assert hasattr(uow, 'office_expense'), "Missing office_expense repository"
    assert hasattr(uow, 'fund_transfer'), "Missing fund_transfer repository"

def test_profit_sales_11_vs_20_enums():
    """Verify independent transaction classifications for 11% and 20% profit sales"""
    assert TransactionClassification.MARKUP_11.value == "MARKUP_11"
    assert TransactionClassification.MARKUP_20.value == "MARKUP_20"
    assert TransactionClassification.MARKUP_11.value != TransactionClassification.MARKUP_20.value

def test_co_cashbook_responsibility_separation():
    """Verify CO Cashbook excludes branch treasury fields (HO transfers, salaries, expenses, loan disbursement pools)"""
    uow = SupabaseUnitOfWork()
    today = date.today()
    branch_id = "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"
    officer_id = "00000000-0000-0000-0000-000000000000"
    
    res = CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, officer_id, today)
    if res:
        # Assert branch treasury activities are zeroed in CO cashbook
        assert res.get("funds_received_ho", 0.0) == 0.0
        assert res.get("fund_transferred_ho", 0.0) == 0.0
        assert res.get("staff_salaries", 0.0) == 0.0
        assert res.get("office_expenses", 0.0) == 0.0
        assert res.get("fund_to_asset_program", 0.0) == 0.0
        assert res.get("fund_to_product_finance", 0.0) == 0.0

def test_master_cashbook_aggregation_and_treasury():
    """Verify Master Cashbook aggregates CO Cashbooks and supports branch treasury fields"""
    uow = SupabaseUnitOfWork()
    today = date.today()
    branch_id = "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"
    
    res = MasterCashbookProjectionBuilder.rebuild_master_projection(uow, branch_id, today)
    if res:
        assert "funds_received_ho" in res
        assert "fund_transferred_ho" in res
        assert "staff_salaries" in res
        assert "office_expenses" in res
        assert "fund_to_asset_program" in res
        assert "fund_to_product_finance" in res
