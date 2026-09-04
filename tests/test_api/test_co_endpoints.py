"""
Tests for CO Dashboard, Portfolio, Collections, Cashbook, and Withdrawal APIs using FastAPI dependency overrides.
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch
from api.main import app
from api.dependencies import get_uow, get_current_user
from auth.session import generate_session_token
from models.user import CurrentUser
from auth.authorization import PERMISSIONS

client = TestClient(app)

TOKEN = generate_session_token("a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", "co_ayomide")
HEADERS = {"Authorization": f"Bearer {TOKEN}"}


@pytest.fixture(autouse=True)
def setup_dependencies():
    mock_uow = MagicMock()
    mock_user = CurrentUser(
        id="a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11",
        username="co_ayomide",
        full_name="Mr. Ayomide",
        role="Credit Officer",
        branch="Ogijo",
        branch_id="b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
        permissions=PERMISSIONS.get("Credit Officer", set())
    )

    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: mock_user

    yield mock_uow, mock_user

    app.dependency_overrides.clear()


def test_co_dashboard_unauthorized():
    app.dependency_overrides.clear()
    res = client.get("/api/v1/co/dashboard")
    assert res.status_code == 401


def test_co_dashboard_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.dashboard_service.DashboardService.get_co_dashboard_data") as mock_dash:
        mock_dash.return_value = {
            "welcome": {
                "officer_name": "co_ayomide",
                "branch_name": "Ogijo",
                "date_str": "30 August 2026",
                "meeting_day": "Sunday",
                "time_str": "12:00 PM"
            },
            "branch_closure": {"is_closed": False, "reason": None},
            "repayment_summary": {
                "rep_12_weeks_amt": 50000.0,
                "rep_12_weeks_clients": 5,
                "rep_24_weeks_amt": 30000.0,
                "rep_24_weeks_clients": 2,
                "rep_daily_amt": 0.0,
                "rep_daily_clients": 0,
                "total_collected_today": 80000.0
            },
            "meeting_portfolio": [],
            "savings": {
                "deposited_amt": 15000.0,
                "deposited_clients": 3,
                "withdrawn_amt": 5000.0,
                "withdrawn_clients": 1,
                "net_savings": 10000.0
            },
            "repayment_status": {
                "full_payment": {"count": 2, "amount": 20000.0},
                "part_payment": {"count": 1, "amount": 5000.0},
                "excess_payment": {"count": 1, "amount": 2000.0},
                "not_paid": {"count": 0, "amount": 0.0}
            },
            "cash_position": {
                "opening_balance": 10000.0,
                "cash_in": 95000.0,
                "cash_out": 5000.0,
                "closing_balance": 100000.0,
                "status": "Balanced",
                "difference": 0.0
            },
            "attention_list": []
        }

        res = client.get("/api/v1/co/dashboard", headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["welcome"]["officer_name"] == "co_ayomide"
        assert data["repayment_summary"]["total_collected_today"] == 80000.0


def test_co_portfolio_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.portfolio_service.PortfolioService.get_portfolio_data_for_scope") as mock_port:
        mock_port.return_value = {
            "metrics": {
                "total_clients": 25,
                "total_active_credit": 1500000.0,
                "total_outstanding": 900000.0,
                "total_fixed_repayment": 25000.0,
                "total_paid": 600000.0,
                "collection_rate": 88.5,
                "par_30_amount": 0.0,
                "par_30_count": 0
            },
            "groups": [],
            "clients": []
        }

        res = client.get("/api/v1/co/portfolio", headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["metrics"]["total_clients"] == 25
        assert data["metrics"]["total_active_credit"] == 1500000.0


def test_co_collections_sheet_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        mock_uow.loans._resolve_officer_id.return_value = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
        mock_uow.client.table().select().eq().execute.return_value = MagicMock(data=[
            {
                "client_id": "c-1",
                "client_code": "OGI-01-001",
                "name": "Adebayo Omotola",
                "status": "Active",
                "groups": {"name": "Market Group"}
            }
        ])
        mock_uow.individual_savings.get_total_balance.return_value = 45000.0

        res = client.get("/api/v1/co/collections/sheet?group_name=Market Group", headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["is_open"] is True
        assert data["group_name"] == "Market Group"


def test_co_cashbook_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        mock_uow.cashbook._resolve_branch_id.return_value = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"
        mock_uow.loans._resolve_officer_id.return_value = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
        mock_uow.client.table().select().eq().eq().eq().execute.return_value = MagicMock(data=[
            {
                "opening_balance": 15000.0,
                "savings_deposit": 5000.0,
                "rep_daily": 25000.0,
                "total_inflows": 45000.0,
                "total_outflows": 0.0,
                "closing_balance": 45000.0
            }
        ])

        res = client.get("/api/v1/co/cashbook?date=2026-08-30", headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["inflows"]["opening_balance"] == 15000.0
        assert data["total_inflows"] == 45000.0


def test_withdrawal_individual_options(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    mock_uow.loans._resolve_officer_id.return_value = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
    mock_uow.client.table().select().eq().execute.return_value = MagicMock(data=[
        {
            "client_id": "c-1",
            "client_code": "OGI-01-001",
            "name": "Adebayo Omotola",
            "status": "Active",
            "client_memberships": [{"groups": {"name": "Market Group"}}]
        }
    ])
    mock_uow.individual_savings.get_total_balance.return_value = 50000.0

    res = client.get("/api/v1/co/withdrawals/individual-options", headers=HEADERS)
    assert res.status_code == 200
    data = res.json()
    assert "Market Group" in data["groups"]
    assert len(data["clients"]) == 1
    assert data["clients"][0]["savings_balance"] == 50000.0


def test_withdrawal_request_insufficient_balance(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        mock_uow.individual_savings.get_total_balance.return_value = 5000.0

        res = client.post("/api/v1/co/withdrawals/request", json={
            "savings_type": "Individual",
            "operation_type": "Cash Withdrawal",
            "client_id": "c-1",
            "amount": 20000.0
        }, headers=HEADERS)

        assert res.status_code == 400
        assert "Insufficient balance" in res.json()["detail"]


def test_withdrawal_request_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        mock_uow.individual_savings.get_total_balance.return_value = 50000.0
        mock_uow.client.table().select().eq().execute.return_value = MagicMock(data=[{"name": "Adebayo Omotola"}])
        mock_uow.client.table().insert().execute.return_value = MagicMock(data=[{"id": "req-123"}])

        res = client.post("/api/v1/co/withdrawals/request", json={
            "savings_type": "Individual",
            "operation_type": "Cash Withdrawal",
            "client_id": "c-1",
            "amount": 10000.0,
            "remarks": "Emergency funds"
        }, headers=HEADERS)

        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["status"] == "PENDING"
        assert "REF-WTH-" in data["reference"]


def test_withdrawal_misc_balance_co_role(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    mock_uow.misc_savings.get_total_balance.return_value = 92500.0

    res = client.get("/api/v1/co/withdrawals/misc-balance", headers=HEADERS)
    assert res.status_code == 200
    data = res.json()
    assert data["misc_balance"] == 92500.0
    assert data["can_withdraw"] is False
    assert "Managed by the Branch Manager" in data["role_notice"] or "Branch Manager" in data["role_notice"]


def test_withdrawal_laps_options(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    mock_uow.client.table().select().execute.return_value = MagicMock(data=[
        {
            "id": "laps-1",
            "client_id": "c-closed-1",
            "deposit_amount": 50000.0,
            "withdrawal_amount": 15000.0,
            "remarks": "Closed client pool",
            "created_at": "2026-08-01"
        }
    ])

    res = client.get("/api/v1/co/withdrawals/laps-options", headers=HEADERS)
    assert res.status_code == 200
    data = res.json()
    assert len(data["records"]) == 1
    assert data["records"][0]["balance"] == 35000.0


def test_withdrawal_request_closed_branch(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(False, "Public Holiday")):
        res = client.post("/api/v1/co/withdrawals/request", json={
            "savings_type": "Individual",
            "operation_type": "Cash Withdrawal",
            "client_id": "c-1",
            "amount": 5000.0
        }, headers=HEADERS)

        assert res.status_code == 403
        assert "Operational Activity Suspended" in res.json()["detail"]


def test_withdrawal_request_negative_amount(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        res = client.post("/api/v1/co/withdrawals/request", json={
            "savings_type": "Individual",
            "operation_type": "Cash Withdrawal",
            "client_id": "c-1",
            "amount": -500.0
        }, headers=HEADERS)

        assert res.status_code == 422

