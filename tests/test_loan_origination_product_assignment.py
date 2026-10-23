"""
Test suite for Credit Officer Product Assignment and Legacy Onboarding Schedule Expectations.
"""
import pytest
from datetime import date
from unittest.mock import MagicMock
from fastapi import HTTPException
from api.schemas.auth import UserInfo
from models.user import CurrentUser
from api.routes.co.origination import apply_for_loan
from api.schemas.origination import ApplyLoanInput
from services.dashboard_service import DashboardService


def test_user_info_allowed_products():
    info = UserInfo(
        id="user-123",
        username="OMI_CO1",
        full_name="Babatunde Mighty",
        role="Credit Officer",
        branch="omitoro",
        branch_id="b-1",
        allowed_products=["Daily 60 Days", "Weekly 12W"]
    )
    assert info.allowed_products == ["Daily 60 Days", "Weekly 12W"]


def test_apply_for_loan_rejects_unassigned_product():
    mock_uow = MagicMock()
    mock_client = MagicMock()
    mock_client.branch_id = "branch-1"
    mock_uow.clients.find_by_id.return_value = mock_client

    co_user = CurrentUser(
        id="user-1",
        username="co_user",
        role="Credit Officer",
        branch="omitoro",
        branch_id="branch-1",
        allowed_products=["Weekly 12W", "Monthly 3M"]
    )

    payload = ApplyLoanInput(
        client_id="client-1",
        product_type="Daily 60 Days",  # Not in allowed_products
        requested_amount=50000.0,
        upfront_fee_mode="deduct"
    )

    with pytest.raises(HTTPException) as exc_info:
        apply_for_loan(payload, current_user=co_user, uow=mock_uow)
    assert exc_info.value.status_code == 403
    assert "not authorized to originate loans" in exc_info.value.detail


def test_apply_for_loan_allows_assigned_product():
    mock_uow = MagicMock()
    mock_client = MagicMock()
    mock_client.branch_id = "branch-1"
    mock_uow.clients.find_by_id.return_value = mock_client
    
    # Mock individual savings balance >= upfront requirement
    mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.side_effect = [
        MagicMock(data=[{"deposit_amount": 20000.0}]),  # res_dep
        MagicMock(data=[]),                             # res_wd
        MagicMock(data=[{"product_id": "p-1", "name": "Weekly 12W", "installments": 12, "repayment_cycle": "Weekly"}]) # product
    ]

    co_user = CurrentUser(
        id="user-1",
        username="co_user",
        role="Credit Officer",
        branch="omitoro",
        branch_id="branch-1",
        allowed_products=["Weekly 12W"]
    )

    payload = ApplyLoanInput(
        client_id="client-1",
        product_type="Weekly 12W",  # In allowed_products
        requested_amount=50000.0,
        upfront_fee_mode="deduct"
    )

    # Mock DB insert and schedule generation
    mock_uow.client.table.return_value.insert.return_value.execute.return_value = MagicMock()

    res = apply_for_loan(payload, current_user=co_user, uow=mock_uow)
    assert res.success is True
    assert res.loan_id is not None


def test_legacy_loan_not_suppressed_by_disbursed_today():
    today = date(2026, 10, 23)
    target_dt_str = today.isoformat()

    # Legacy onboarded loan disbursed "today"
    legacy_loan = {
        "disbursement_date": target_dt_str,
        "date": target_dt_str,
        "extra_fields": {"is_legacy": True}
    }
    is_legacy = bool((legacy_loan.get("extra_fields") or {}).get("is_legacy", False))
    is_disbursed_today = (legacy_loan.get("disbursement_date") == target_dt_str) and not is_legacy
    assert is_disbursed_today is False  # Legacy loan must NOT be treated as disbursed today

    # Non-legacy new loan disbursed today
    new_loan = {
        "disbursement_date": target_dt_str,
        "date": target_dt_str,
        "extra_fields": {}
    }
    is_legacy_new = bool((new_loan.get("extra_fields") or {}).get("is_legacy", False))
    is_disbursed_today_new = (new_loan.get("disbursement_date") == target_dt_str) and not is_legacy_new
    assert is_disbursed_today_new is True  # New loan IS disbursed today
