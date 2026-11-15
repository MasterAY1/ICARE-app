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

    def mock_table(table_name):
        t = MagicMock()
        if table_name == "branches":
            t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[{"name": "Ogijo", "code": "OGI"}])
        elif table_name == "clients":
            t.select.return_value.is_.return_value.eq.return_value.execute.return_value = MagicMock(count=4, data=[])
            t.insert.return_value.execute.return_value = MagicMock(data=[{"client_id": "c-1"}])
        else:
            t.select.return_value.execute.return_value = MagicMock(data=[])
            t.insert.return_value.execute.return_value = MagicMock(data=[{"id": "stub-1"}])
        return t
    mock_uow.client.table.side_effect = mock_table

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
    assert "OGI" in data["client_code"] and "005" in data["client_code"]
    mock_uow.client.rpc.assert_any_call("atomic_execute_operations", mock_uow.client.rpc.call_args[0][1])
    ops = mock_uow.client.rpc.call_args[0][1]["p_operations"]
    assert any(op.get("table") == "clients" and op.get("type") == "insert" for op in ops)


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
    mock_uow.individual_savings.get_total_balance.return_value = 25000.0

    def mock_table(table_name):
        t = MagicMock()
        if table_name == "individual_savings":
            t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[{"deposit_amount": 25000.0, "withdrawal_amount": 0.0}])
        elif table_name == "loans":
            t.select.return_value.eq.return_value.eq.return_value.execute.return_value = MagicMock(data=[])
            t.insert.return_value.execute.return_value = MagicMock(data=[{"loan_id": "l-1"}])
        elif table_name == "branches":
            t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[{"name": "Ogijo"}])
        elif table_name == "loan_products":
            t.select.return_value.eq.return_value.limit.return_value.execute.return_value = MagicMock(data=[{"product_id": "prod-daily-60"}])
        else:
            t.select.return_value.execute.return_value = MagicMock(data=[])
        return t
    mock_uow.client.table.side_effect = mock_table

    with patch("services.renewal_service.RenewalService.check_eligibility", return_value=(True, [], [])), \
         patch("services.loan_product_engine.LoanProductEngine.calculate_loan_setup") as mock_setup, \
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
        assert mock_uow.client.rpc.called
        ops = mock_uow.client.rpc.call_args[0][1]["p_operations"]
        assert any(op.get("table") == "loans" and op.get("type") == "insert" for op in ops)


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


def test_preview_schedule_endpoint(setup_dependencies):
    mock_uow, _mock_user = setup_dependencies

    def mock_table(table_name):
        t = MagicMock()
        t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[])
        t.select.return_value.execute.return_value = MagicMock(data=[])
        return t

    mock_uow.client.table.side_effect = mock_table

    payload = {
        "product_category": "Finance",
        "product_type": "Weekly 12W",
        "requested_amount": 120000.0,
        "gap_fee": 0.0,
        "application_date": "2026-10-12",
    }
    res = client.post("/api/v1/co/origination/preview-schedule", json=payload, headers=HEADERS)
    assert res.status_code == 200
    data = res.json()
    assert data["duration"] == 12
    assert data["frequency"] == "Weekly"
    assert len(data["installments"]) == 12
    assert data["first_due_date"] == data["installments"][0]["due_date"]
    assert data["expected_end_date"] == data["installments"][-1]["due_date"]


def test_disburse_bm_ceiling_enforced():
    mock_uow = MagicMock()
    bm_user = CurrentUser(
        id="bm-1",
        username="bm_ogijo",
        full_name="BM Ogijo",
        role="Branch Manager",
        branch="Ogijo",
        branch_id="b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
        permissions=PERMISSIONS.get("Branch Manager", set()),
    )

    def mock_table(table_name):
        t = MagicMock()
        if table_name == "loans":
            t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[{
                "loan_id": "loan-big-1",
                "client_id": "c-1",
                "branch_id": "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
                "status": "Pending",
                "loan_amount": 500000.0,
                "product_category": "Finance",
                "loan_products": {"name": "Weekly 12W"},
                "clients": {"name": "Client One", "group_id": None},
            }])
        else:
            t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[])
        return t

    mock_uow.client.table.side_effect = mock_table
    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: bm_user

    try:
        res = client.post(
            "/api/v1/co/origination/disburse",
            json={"loan_id": "loan-big-1", "disbursement_date": "2026-10-12"},
            headers=HEADERS,
        )
        assert res.status_code == 403
        assert "Exceeds" in res.json()["detail"] or "exceeds Branch Manager limit" in res.json()["detail"]
    finally:
        app.dependency_overrides.clear()


def test_disburse_am_allows_over_bm_ceiling():
    mock_uow = MagicMock()
    am_user = CurrentUser(
        id="am-1",
        username="am_region",
        full_name="Area Manager",
        role="Area Manager",
        branch="Ogijo",
        branch_id="b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
        assigned_branch_ids=["b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"],
        permissions=PERMISSIONS.get("Area Manager", set()),
    )

    def mock_table(table_name):
        t = MagicMock()
        if table_name == "loans":
            t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[{
                "loan_id": "loan-big-1",
                "client_id": "c-1",
                "branch_id": "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22",
                "officer_id": "co-1",
                "status": "Pending",
                "loan_amount": 500000.0,
                "active_credit": 500000.0,
                "loan_repay": 41666.67,
                "total_due": 500000.0,
                "product_category": "Finance",
                "loan_products": {"name": "Weekly 12W"},
                "branches": {"name": "Ogijo"},
                "app_users": {"username": "co_ayomide", "full_name": "Mr. Ayomide"},
                "clients": {"name": "Client One", "group_id": None},
                "extra_fields": {"product_type": "Weekly 12W"},
            }])
        elif table_name == "loan_schedule":
            t.select.return_value.eq.return_value.order.return_value.execute.return_value = MagicMock(data=[])
        else:
            t.select.return_value.eq.return_value.execute.return_value = MagicMock(data=[])
        return t

    mock_uow.client.table.side_effect = mock_table
    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: am_user

    try:
        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "")), \
             patch("services.loan_service.LoanService.disburse_loan") as mock_disburse:
            res = client.post(
                "/api/v1/co/origination/disburse",
                json={"loan_id": "loan-big-1", "disbursement_date": "2026-10-12"},
                headers=HEADERS,
            )
            assert res.status_code == 200
            assert res.json()["success"] is True
            assert mock_disburse.called
    finally:
        app.dependency_overrides.clear()
