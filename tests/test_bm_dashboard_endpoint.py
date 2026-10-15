"""
tests/test_bm_dashboard_endpoint.py
Verifies Branch Manager (BM) Dashboard endpoint performance, data integrity, and responsiveness.
"""
import pytest
import time
from fastapi.testclient import TestClient

from api.main import app
from database.repositories.unit_of_work import SupabaseUnitOfWork
from auth.session import generate_session_token

client = TestClient(app)


@pytest.fixture
def bm_auth_headers():
    with SupabaseUnitOfWork() as uow:
        bm_user = uow.users.find_by_username("BM_Ogijo")
        assert bm_user is not None, "BM_Ogijo user must exist in app_users"
        token = generate_session_token(bm_user.id, bm_user.username)
        return {"Authorization": f"Bearer {token}"}


def test_bm_dashboard_endpoint_fast_response_and_payload(bm_auth_headers):
    """
    Verifies that GET /api/v1/bm/dashboard responds within 15 seconds (no timeouts)
    and contains all authoritative presentation keys.
    """
    t0 = time.time()
    res = client.get("/api/v1/bm/dashboard", headers=bm_auth_headers)
    elapsed = time.time() - t0

    assert res.status_code == 200, f"Expected 200, got: {res.status_code} ({res.text})"
    assert elapsed < 15.0, f"BM Dashboard exceeded 15s budget: took {elapsed:.2f}s"

    data = res.json()
    assert data["branch_name"] == "Ogijo"
    assert "branch_summary" in data
    assert "branch_cash_position" in data
    assert "officer_collection_status" in data
    assert "pending_loans" in data
    assert "pending_withdrawals" in data
    assert "pending_corrections" in data

    summary = data["branch_summary"]
    assert summary["active_clients"] > 0
    assert summary["active_loans"] > 0
    assert summary["active_savings"] > 0.0
