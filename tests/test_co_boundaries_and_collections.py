"""
Unit tests for Step 4: CO Cashbook Boundaries, Field Collections Scoping, and Savings Independence.
Validates:
1. Strict cross-branch RBAC isolation on CO Cashbook and Client Fees.
2. Scoped Portfolio filter options per role/scope level (OFFICER, BRANCH, REGION, INSTITUTION).
3. 360° Client Dossier boundary enforcement.
4. Absolute independence between Loan Repayment and Savings Deposit in save_repayments.
5. Officer-level ledger aggregation in CoCashbookProjectionBuilder.
"""
import pytest
from unittest.mock import MagicMock, patch
from datetime import date
from fastapi import HTTPException
from models.user import CurrentUser
from services.rbac_scope_service import RBACScope
from api.routes.co.cashbook import (
    get_co_cashbook,
    record_client_fee,
    get_client_fees,
    RecordClientFeeInput
)
from api.routes.co.portfolio import get_portfolio_overview, get_client_dossier


def test_co_cashbook_rejects_unauthorized_cross_branch_viewing():
    """A Credit Officer must be forbidden from passing another branch to view cashbook."""
    user = CurrentUser(
        id="usr-co-1",
        username="co_sarah",
        role="CO",
        branch="Ikeja",
        branch_id="b-ikeja-uuid"
    )
    mock_uow = MagicMock()
    mock_uow.cashbook._resolve_branch_id.side_effect = lambda b: "b-yaba-uuid" if b == "Yaba" else "b-ikeja-uuid"

    with pytest.raises(HTTPException) as exc_info:
        get_co_cashbook(
            date_str="2026-11-01",
            officer=None,
            branch="Yaba",
            current_user=user,
            uow=mock_uow
        )
    assert exc_info.value.status_code == 403
    assert "Credit Officers cannot view another branch" in exc_info.value.detail


def test_co_cashbook_supervisory_branch_access():
    """An Area Manager cannot view a branch outside their supervisory area."""
    user = CurrentUser(
        id="usr-am-1",
        username="am_david",
        role="Area Manager",
        branch="Lagos Mainland",
        branch_id="b-mainland-uuid",
        assigned_branches=["Ikeja", "Yaba"],
        assigned_branch_ids=["b-ikeja-uuid", "b-yaba-uuid"]
    )
    mock_uow = MagicMock()
    mock_uow.cashbook._resolve_branch_id.side_effect = lambda b: "b-kano-uuid" if b == "Kano" else "b-ikeja-uuid"

    # Unauthorized branch
    with pytest.raises(HTTPException) as exc_info:
        get_co_cashbook(
            date_str="2026-11-01",
            officer=None,
            branch="Kano",
            current_user=user,
            uow=mock_uow
        )
    assert exc_info.value.status_code == 403
    assert "branch outside your supervisory area" in exc_info.value.detail


def test_record_client_fee_branch_isolation():
    """A Credit Officer cannot record fees against clients in another branch."""
    user = CurrentUser(
        id="usr-co-1",
        username="co_sarah",
        role="CO",
        branch="Ikeja",
        branch_id="b-ikeja-uuid"
    )
    mock_uow = MagicMock()
    # Client belongs to Yaba branch
    mock_table = MagicMock()
    mock_table.select.return_value.eq.return_value.execute.return_value.data = [
        {"client_id": "c-100", "client_code": "CL-100", "name": "Jane Doe", "branch_id": "b-yaba-uuid"}
    ]
    mock_uow.client.table.return_value = mock_table

    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")):
        with pytest.raises(HTTPException) as exc_info:
            record_client_fee(
                payload=RecordClientFeeInput(client_id="c-100", fee_type="Passbook", amount=500.0),
                current_user=user,
                uow=mock_uow
            )
        assert exc_info.value.status_code == 403
        assert "belonging to another branch" in exc_info.value.detail


def test_portfolio_overview_scoping_officer():
    """Credit Officer filter options are strictly scoped to self and own branch."""
    user = CurrentUser(
        id="usr-co-1",
        username="co_sarah",
        full_name="Sarah Connor",
        role="CO",
        branch="Ikeja",
        branch_id="b-ikeja-uuid"
    )
    scope = RBACScope(
        user_id="usr-co-1",
        username="co_sarah",
        role="CO",
        branch_id="b-ikeja-uuid",
        branch_name="Ikeja",
        scope_level="OFFICER"
    )
    mock_uow = MagicMock()
    with patch("services.portfolio_service.PortfolioService.get_portfolio_data_for_scope", return_value={}):
        res = get_portfolio_overview(
            branch=None,
            officer=None,
            group=None,
            product=None,
            time_period="Today",
            start_date_param=None,
            end_date_param=None,
            current_user=user,
            scope=scope,
            uow=mock_uow
        )
        assert res.filter_options.available_branches == ["Ikeja"]
        assert len(res.filter_options.available_officers) == 1
        assert res.filter_options.available_officers[0]["username"] == "co_sarah"


def test_portfolio_overview_scoping_area_manager():
    """Area Manager filter options include 'All' and assigned branches only."""
    user = CurrentUser(
        id="usr-am-1",
        username="am_david",
        role="Area Manager",
        branch="Mainland",
        branch_id="b-mainland-uuid",
        assigned_branches=["Ikeja", "Yaba"],
        assigned_branch_ids=["b-ikeja-uuid", "b-yaba-uuid"]
    )
    scope = RBACScope(
        user_id="usr-am-1",
        username="am_david",
        role="Area Manager",
        branch_id="b-mainland-uuid",
        branch_name="Mainland",
        assigned_branch_ids=["b-ikeja-uuid", "b-yaba-uuid"],
        assigned_branch_names=["Ikeja", "Yaba"],
        scope_level="REGION"
    )
    mock_uow = MagicMock()
    with patch("services.portfolio_service.PortfolioService.get_portfolio_data_for_scope", return_value={}):
        res = get_portfolio_overview(
            branch=None,
            officer=None,
            group=None,
            product=None,
            time_period="Today",
            start_date_param=None,
            end_date_param=None,
            current_user=user,
            scope=scope,
            uow=mock_uow
        )
        assert res.filter_options.available_branches == ["All", "Ikeja", "Yaba"]


def test_client_dossier_cross_officer_boundary():
    """Credit Officer cannot view dossiers for clients assigned to another officer."""
    scope = RBACScope(
        user_id="usr-co-1",
        username="co_sarah",
        role="CO",
        branch_id="b-ikeja-uuid",
        branch_name="Ikeja",
        scope_level="OFFICER"
    )
    mock_uow = MagicMock()
    dossier_data = {
        "customer_info": {
            "client_id": "c-200",
            "client_code": "CL-200",
            "name": "Bob Smith",
            "branch_id": "b-ikeja-uuid",
            "officer_id": "usr-co-2"  # Different officer
        }
    }
    with patch("services.portfolio_service.PortfolioService.get_client_360_drilldown", return_value=dossier_data):
        with pytest.raises(HTTPException) as exc_info:
            get_client_dossier(
                client_code="CL-200",
                scope=scope,
                uow=mock_uow
            )
        assert exc_info.value.status_code == 403
        assert "only view dossiers for clients assigned to your portfolio" in exc_info.value.detail


def test_save_repayments_savings_loan_separation():
    """
    Core Banking Invariant: Savings deposits and loan repayments must be handled independently.
    Never merge savings into repayments.amount_paid.
    """
    from app import save_repayments

    records = [
        {
            "Client ID": "c-100",
            "Client Name": "Alice Johnson",
            "Amount Paid": 5000.0,
            "Loan Repayment Amount": 5000.0,
            "Savings Amount": 2000.0,
            "Transaction Type": "Loan",
            "Payment Status": "PAID",
            "Branch": "Ikeja",
            "Officer": "co_sarah"
        }
    ]

    with patch("services.collection_batch_service.SupabaseUnitOfWork") as MockUOW1, \
         patch("database.repositories.unit_of_work.SupabaseUnitOfWork") as MockUOW2, \
         patch("app.save_repayment") as mock_save_single:

        uow_inst = MagicMock()
        MockUOW1.return_value.__enter__.return_value = uow_inst
        MockUOW2.return_value.__enter__.return_value = uow_inst

        # Mock empty existing idempotency checks
        mock_table = MagicMock()
        mock_table.select.return_value.in_.return_value.execute.return_value.data = []
        uow_inst.client.table.return_value = mock_table

        receipt = save_repayments(records, batch_id="BATCH-TEST-001")

        assert receipt is not None
        assert receipt["total_repayment"] == 5000.0
        assert receipt["total_savings"] == 2000.0
        assert receipt["total_cash"] == 7000.0
        
        # Verify save_repayment was invoked with the un-merged record
        assert mock_save_single.call_count == 1
        saved_arg = mock_save_single.call_args[0][0]
        assert saved_arg["Amount Paid"] == 5000.0
        assert saved_arg["Savings Amount"] == 2000.0

def test_co_projection_builder_separates_savings_and_repayments():
    """
    Validates that CoCashbookProjectionBuilder separates Account 1000 debits
    into repayments (rep_12_weeks) and savings (savings_deposit).
    """
    from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

    mock_uow = MagicMock()
    branch_id = "b-ikeja-uuid"
    officer_id = "usr-co-1"
    target_date = date(2026, 11, 1)

    # 1. Mock opening balance = 10,000.0
    mock_co_cb = MagicMock()
    mock_co_cb.select.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {"closing_balance": 10000.0}
    ]

    # 2. Mock ledger entries:
    # Entry 1: Repayment of 5,000.0 (Debit 1000, RepaymentReceived)
    # Entry 2: Savings Deposit of 3,000.0 (Debit 1000, SavingsDeposited)
    mock_fle = MagicMock()
    mock_fle.select.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
        {
            "account_code": "1000",
            "side": "Debit",
            "amount": 5000.0,
            "aggregate_id": "loan-101",
            "aggregate_type": "Loan",
            "financial_transactions": {
                "event_id": "ev-rep-1",
                "officer_id": officer_id,
                "posting_date": "2026-11-01",
                "event_store": {
                    "event_type": "RepaymentReceived",
                    "payload": {"loan_id": "loan-101"}
                }
            }
        },
        {
            "account_code": "1000",
            "side": "Debit",
            "amount": 3000.0,
            "aggregate_id": "sav-101",
            "aggregate_type": "IndividualSavings",
            "financial_transactions": {
                "event_id": "ev-sav-1",
                "officer_id": officer_id,
                "posting_date": "2026-11-01",
                "event_store": {
                    "event_type": "SavingsDeposited",
                    "payload": {}
                }
            }
        }
    ]

    # Mock loans lookup for loan-101 (12-week product)
    mock_loans = MagicMock()
    mock_loans.select.return_value.eq.return_value.execute.return_value.data = [
        {
            "loan_id": "loan-101",
            "product_id": "p-12w",
            "loan_products": {"name": "12 Weeks Business Loan", "repayment_cycle": "Weekly"}
        }
    ]

    captured_upsert = {}
    def fake_table(tname):
        if tname == "co_cashbooks":
            m = MagicMock()
            m.select.return_value.eq.return_value.eq.return_value.eq.return_value.execute.return_value.data = [
                {"closing_balance": 10000.0}
            ]
            def fake_upsert(data, **kwargs):
                captured_upsert.update(data)
                m_exec = MagicMock()
                m_exec.execute.return_value.data = [data]
                return m_exec
            m.upsert.side_effect = fake_upsert
            return m
        elif tname == "financial_ledger_entries":
            return mock_fle
        elif tname == "loans":
            return mock_loans
        return MagicMock()

    mock_uow.client.table.side_effect = fake_table

    with patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value="usr-other-co"):
        result = CoCashbookProjectionBuilder.rebuild_co_projection(
            uow=mock_uow,
            branch_id=branch_id,
            officer_id=officer_id,
            posting_date=target_date
        )

    assert result is not None
    assert captured_upsert.get("opening_balance") == 10000.0
    assert captured_upsert.get("rep_12_weeks") == 5000.0
    assert captured_upsert.get("savings_deposit") == 3000.0
    assert captured_upsert.get("branch_id") == branch_id
    assert captured_upsert.get("officer_id") == officer_id
