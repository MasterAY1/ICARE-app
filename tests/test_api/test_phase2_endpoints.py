"""
Tests for Phase 2 Endpoints: Client Registration, Loan Application, and Reversal Requests.
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


def test_register_client_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    mock_uow.loans._resolve_officer_id.return_value = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
    mock_uow.clients.get_next_sequence_number.return_value = 5
    mock_uow.client.table().select().limit().execute.return_value = MagicMock(data=[{"product_id": "prod-1"}])
    mock_uow.client.table().insert().execute.return_value = MagicMock(data=[{"id": "loan-stub-1"}])

    payload = {
        "full_name": "Balogun Kudirat",
        "phone": "08012345678",
        "address": "12 Market Street, Ogijo",
        "marital_status": "Married",
        "business_type": "Trader",
        "daily_income": 5000.0,
        "id_means": "National ID (NIN)",
        "id_number": "12345678901",
        "guarantor": {
            "full_name": "Balogun Lateef",
            "phone": "08098765432",
            "address": "12 Market Street, Ogijo",
            "occupation": "Artisan",
            "relationship": "Husband"
        }
    }

    res = client.post("/api/v1/co/origination/register-client", json=payload, headers=HEADERS)
    assert res.status_code == 200
    data = res.json()
    assert data["success"] is True
    assert "OGI-00-005" in data["client_code"]
    mock_uow.clients.create.assert_called_once()


def test_apply_loan_invalid_amount(setup_dependencies):
    payload = {
        "client_id": "c-1",
        "requested_amount": -1000.0
    }
    res = client.post("/api/v1/co/origination/apply", json=payload, headers=HEADERS)
    assert res.status_code == 422


def test_apply_loan_client_not_found(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    mock_uow.clients.find_by_id.return_value = None

    payload = {
        "client_id": "non-existent-client",
        "product_category": "Finance",
        "product_name": "Daily 60 Days",
        "requested_amount": 100000.0
    }
    res = client.post("/api/v1/co/origination/apply", json=payload, headers=HEADERS)
    assert res.status_code == 404
    assert "Client not found" in res.json()["detail"]


def test_apply_loan_success(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    mock_client = MagicMock()
    mock_client.id = "c-1"
    mock_client.name = "Balogun Kudirat"
    mock_client.officer_id = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
    mock_client.branch_id = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"

    mock_uow.clients.find_by_id.return_value = mock_client

    with patch("services.loan_product_engine.LoanProductEngine.calculate_loan_setup") as mock_setup, \
         patch("services.schedule_service.ScheduleService.generate_schedule"):
        mock_setup.return_value = {
            "interest": 20000.0,
            "duration": 60,
            "freq": "Daily",
            "gapFee": 0.0
        }

        payload = {
            "client_id": "c-1",
            "product_category": "Finance",
            "product_name": "Daily 60 Days",
            "requested_amount": 100000.0,
            "gap_fee": 0.0,
            "notes": "Trader expansion"
        }

        res = client.post("/api/v1/co/origination/apply", json=payload, headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["status"] == "Pending"
        assert data["active_credit"] == 100000.0
        mock_uow.loans.create.assert_called_once()


def test_repayment_reversal_request(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.correction_service.CorrectionService.request_correction", return_value="req-corr-1"):
        payload = {
            "record_id": "rep-tx-123",
            "record_type": "Repayment",
            "reason": "Duplicate posting recorded during field meeting"
        }

        res = client.post("/api/v1/co/collections/reversal-request", json=payload, headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["request_id"] == "req-corr-1"
        assert data["status"] == "Pending"


def test_cashbook_reversal_request(setup_dependencies):
    mock_uow, mock_user = setup_dependencies
    with patch("services.correction_service.CorrectionService.request_correction", return_value="req-cb-1"):
        payload = {
            "record_id": "cb-exp-456",
            "record_type": "Cashbook",
            "reason": "Wrong office expense amount entered"
        }

        res = client.post("/api/v1/co/cashbook/reversal-request", json=payload, headers=HEADERS)
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["request_id"] == "req-cb-1"
        assert data["status"] == "Pending"
