"""
tests/test_monthly_report_workflow.py
Verification suite for Phase 8.9 Three-Tier Monthly Report Workflow (BM -> AM -> Admin).

Tests:
1. Status Query: Default status is DRAFT.
2. Tier 1: BM verifies and submits report (transitions to BM_SUBMITTED).
3. Tier 2: AM returns report for correction (transitions to RETURNED_FOR_CORRECTION).
4. Re-submit: BM re-submits report (transitions back to BM_SUBMITTED).
5. Tier 2: AM endorses report (transitions to AM_VERIFIED).
6. Approvals Hub: AM lists pending submissions across supervised branches.
7. Tier 3: Admin locks and archives report (transitions to ADMIN_LOCKED).
"""
import pytest
from fastapi.testclient import TestClient

from api.main import app
from database.repositories.unit_of_work import SupabaseUnitOfWork
from auth.session import generate_session_token

client = TestClient(app)


@pytest.fixture
def am_auth_headers():
    with SupabaseUnitOfWork() as uow:
        am_user = uow.users.find_by_username("AM_Area_1")
        assert am_user is not None, "AM_Area_1 user must exist in app_users"
        token = generate_session_token(am_user.id, am_user.username)
        return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def bm_auth_headers():
    with SupabaseUnitOfWork() as uow:
        bm_user = uow.users.find_by_username("BM_Ogijo")
        assert bm_user is not None, "BM_Ogijo user must exist in app_users"
        token = generate_session_token(bm_user.id, bm_user.username)
        return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def admin_auth_headers():
    with SupabaseUnitOfWork() as uow:
        admin_user = uow.users.find_by_username("Admin")
        if not admin_user:
            admin_user = uow.users.find_by_username("admin")
        assert admin_user is not None, "Admin user must exist in app_users"
        token = generate_session_token(admin_user.id, admin_user.username)
        return {"Authorization": f"Bearer {token}"}


def test_monthly_workflow_full_cycle(bm_auth_headers, am_auth_headers, admin_auth_headers):
    """Verifies the complete BM -> AM -> Admin monthly report workflow."""
    test_year = 2026
    test_month = 9
    branch = "Ogijo"

    # Clean up any existing test submission for this month/branch
    with SupabaseUnitOfWork() as uow:
        b_res = uow.client.table("branches").select("branch_id").eq("name", branch).execute()
        assert b_res.data, "Ogijo branch must exist"
        ogijo_id = b_res.data[0]["branch_id"]
        uow.client.table("monthly_report_submissions") \
            .delete() \
            .eq("branch_id", ogijo_id) \
            .eq("year", test_year) \
            .eq("month", test_month) \
            .execute()

    # 1. Query status before submission (should be DRAFT)
    res = client.get(
        f"/api/v1/reports/monthly-workflow/status?branch_name={branch}&year={test_year}&month={test_month}",
        headers=bm_auth_headers
    )
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["status"] == "DRAFT"
    assert data["branch_id"] == ogijo_id

    # 2. Tier 1: BM submits monthly report
    submit_res = client.post(
        "/api/v1/reports/monthly-workflow/submit",
        json={"branch_name": branch, "year": test_year, "month": test_month, "notes": "Ogijo month-end verified."},
        headers=bm_auth_headers
    )
    assert submit_res.status_code == 200, submit_res.text
    sub_data = submit_res.json()
    assert sub_data["success"] is True
    assert sub_data["status"] == "BM_SUBMITTED"

    # Verify status transitioned to BM_SUBMITTED
    res = client.get(
        f"/api/v1/reports/monthly-workflow/status?branch_name={branch}&year={test_year}&month={test_month}",
        headers=bm_auth_headers
    )
    assert res.status_code == 200
    assert res.json()["status"] == "BM_SUBMITTED"
    assert res.json()["bm_name"] is not None

    # 3. Tier 2: AM returns report with query notes
    return_res = client.post(
        "/api/v1/reports/monthly-workflow/return",
        json={"branch_name": branch, "year": test_year, "month": test_month, "query_notes": "Please verify Annex-1 stationery subtotal."},
        headers=am_auth_headers
    )
    assert return_res.status_code == 200, return_res.text
    assert return_res.json()["status"] == "RETURNED_FOR_CORRECTION"

    # Verify status is RETURNED_FOR_CORRECTION
    res = client.get(
        f"/api/v1/reports/monthly-workflow/status?branch_name={branch}&year={test_year}&month={test_month}",
        headers=bm_auth_headers
    )
    assert res.json()["status"] == "RETURNED_FOR_CORRECTION"
    assert "stationery" in (res.json()["am_query_notes"] or "")

    # 4. Re-submit by BM
    submit_res2 = client.post(
        "/api/v1/reports/monthly-workflow/submit",
        json={"branch_name": branch, "year": test_year, "month": test_month, "notes": "Amended and re-verified."},
        headers=bm_auth_headers
    )
    assert submit_res2.status_code == 200
    assert submit_res2.json()["status"] == "BM_SUBMITTED"

    # 5. AM Approvals Hub: List pending submissions
    pending_res = client.get(
        f"/api/v1/reports/monthly-workflow/pending-am?year={test_year}&month={test_month}",
        headers=am_auth_headers
    )
    assert pending_res.status_code == 200, pending_res.text
    pending_items = pending_res.json()
    assert isinstance(pending_items, list)
    ogijo_item = next((item for item in pending_items if item["branch_name"] == "Ogijo"), None)
    assert ogijo_item is not None
    assert ogijo_item["status"] == "BM_SUBMITTED"

    # 6. Tier 2: AM endorses monthly report
    endorse_res = client.post(
        "/api/v1/reports/monthly-workflow/endorse",
        json={"branch_name": branch, "year": test_year, "month": test_month, "notes": "Endorsed with zero variance."},
        headers=am_auth_headers
    )
    assert endorse_res.status_code == 200, endorse_res.text
    assert endorse_res.json()["status"] == "AM_VERIFIED"

    # 7. Tier 3: Admin locks institutional report
    lock_res = client.post(
        "/api/v1/reports/monthly-workflow/lock",
        json={"branch_name": branch, "year": test_year, "month": test_month, "notes": "Audited and permanently archived."},
        headers=admin_auth_headers
    )
    assert lock_res.status_code == 200, lock_res.text
    assert lock_res.json()["status"] == "ADMIN_LOCKED"

    # Verify final locked status
    final_res = client.get(
        f"/api/v1/reports/monthly-workflow/status?branch_name={branch}&year={test_year}&month={test_month}",
        headers=admin_auth_headers
    )
    assert final_res.status_code == 200
    final_data = final_res.json()
    assert final_data["status"] == "ADMIN_LOCKED"
    assert final_data["admin_name"] is not None
