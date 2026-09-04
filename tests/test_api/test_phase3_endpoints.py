"""
Tests for Phase 3 Atomic Financial Writes & Ledger Postings.
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


def test_batch_collections_closed_date(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(False, "Branch Holiday")):
        payload = {
            "group_name": "Market Group",
            "collections": [
                {
                    "client_id": "c-1",
                    "client_name": "Balogun Kudirat",
                    "loan_repayment_amount": 5000.0
                }
            ]
        }
        res = client.post("/api/v1/co/collections/batch-submit", json=payload, headers=HEADERS)
        assert res.status_code == 403
        assert "Cannot submit new collections today" in res.json()["detail"]


def test_batch_collections_empty(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        payload = {
            "group_name": "Market Group",
            "collections": []
        }
        res = client.post("/api/v1/co/collections/batch-submit", json=payload, headers=HEADERS)
        assert res.status_code == 422


def test_batch_collections_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
         patch("app.save_repayment") as mock_save_rep:
        mock_uow.cashbook._resolve_branch_id.return_value = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"
        mock_uow.loans._resolve_officer_id.return_value = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"

        payload = {
            "group_name": "Market Group",
            "collections": [
                {
                    "client_id": "c-1",
                    "client_name": "Balogun Kudirat",
                    "loan_product": "Daily 60 Days",
                    "loan_repayment_amount": 5000.0,
                    "savings_deposit_amount": 1000.0,
                    "app_fee": 500.0,
                    "expected_amount": 5000.0
                },
                {
                    "client_id": "c-2",
                    "client_name": "Adeola Funke",
                    "loan_product": "Daily 60 Days",
                    "loan_repayment_amount": 0.0,
                    "mark_not_paid": True,
                    "expected_amount": 3000.0
                }
            ],
            "group_savings_deposit": 2000.0
        }

        res = client.post("/api/v1/co/collections/batch-submit", json=payload, headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["total_repayments"] == 5000.0
        assert data["total_savings"] == 3000.0  # 1000 individual + 2000 group
        assert data["total_cash_in"] == 8500.0  # 5000 + 1000 + 500 + 2000
        assert mock_save_rep.call_count == 3   # 2 clients + 1 group meeting
        mock_uow.cashbook.rebuild_projection.assert_called_once()


def test_eod_adjustments_closed_date(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(False, "Sunday Closure")):
        payload = {
            "office_expenses": 2000.0
        }
        res = client.post("/api/v1/co/cashbook/eod-adjustments", json=payload, headers=HEADERS)
        assert res.status_code == 403


def test_eod_adjustments_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
         patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_ev:
        mock_uow.cashbook._resolve_branch_id.return_value = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"
        mock_uow.loans._resolve_officer_id.return_value = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
        mock_uow.client.table().select().eq().eq().eq().execute.return_value = MagicMock(data=[
            {
                "app_fee": 1000.0,
                "office_expenses": 500.0,
                "bank_deposit": 0.0
            }
        ])

        payload = {
            "opening_balance": 15000.0,
            "app_fee": 2500.0,          # Delta +1500
            "office_expenses": 1200.0,   # Delta +700
            "bank_deposit": 5000.0       # Delta +5000
        }

        res = client.post("/api/v1/co/cashbook/eod-adjustments", json=payload, headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert mock_post_ev.call_count == 3  # 3 deltas posted
        mock_uow.cashbook.rebuild_projection.assert_called_once()
