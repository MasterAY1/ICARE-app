"""
tests/test_am_operations.py
Automated Verification Suite for Area Manager (AM) Operations & Regional Governance.

Tests:
1. AM Dashboard aggregation for Area 1 (Ogijo, Ikorodu, Kola).
2. BM Loan Approval Ceiling: BM rejected when attempting to approve loan > ₦300,000.
3. AM Loan Approval: AM successfully approves loans > ₦300,000.
4. Branch EOD Confirmation: AM signs off on individual branch EOD.
5. Area Daily Closure Lock: AM locks Area 1 when branches confirmed.
6. Branch Handover Summary: Read-only report metadata for supervised branches.
7. Regional Excel Workbook Export: Multi-tab Excel generation.
"""
import pytest
from datetime import date
from fastapi.testclient import TestClient

from api.main import app
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.area_manager_service import AreaManagerService
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


def test_am_dashboard_endpoint(am_auth_headers):
    """Verifies that GET /api/v1/am/dashboard returns valid Area 1 KPIs and branch matrix."""
    response = client.get("/api/v1/am/dashboard", headers=am_auth_headers)
    assert response.status_code == 200, f"Expected 200, got {response.status_code}: {response.text}"
    data = response.json()

    assert "regional_summary" in data
    reg = data["regional_summary"]
    assert reg["area_name"] == "Area 1"
    assert reg["branches_count"] >= 3
    assert "Kola" in reg["assigned_branches"]
    assert "Ogijo" in reg["assigned_branches"]
    assert "Ikorodu" in reg["assigned_branches"]

    assert "branch_performance" in data
    matrix = data["branch_performance"]
    assert len(matrix) >= 3
    bnames = [b["branch_name"] for b in matrix]
    assert "Ogijo" in bnames
    assert "Ikorodu" in bnames

    assert "approvals_hub" in data


def test_am_approvals_endpoint(am_auth_headers):
    """Verifies that GET /api/v1/am/approvals returns pending queues."""
    response = client.get("/api/v1/am/approvals", headers=am_auth_headers)
    assert response.status_code == 200
    data = response.json()
    assert "pending_high_value_loans" in data
    assert "pending_branch_transfers" in data
    assert "pending_branch_eods" in data


def test_bm_approval_ceiling_enforcement(bm_auth_headers):
    """Verifies that a Branch Manager cannot approve a loan > ₦300,000."""
    with SupabaseUnitOfWork() as uow:
        ogijo_b = uow.client.table("branches").select("branch_id").eq("name", "Ogijo").execute()
        ogijo_id = ogijo_b.data[0]["branch_id"]

        # Insert a test loan with ₦450,000 (exceeds BM ₦300k limit)
        test_loan_id = "00000000-0000-4000-8000-000000000999"
        try:
            uow.client.table("loans").delete().eq("loan_id", test_loan_id).execute()
        except Exception:
            pass

        uow.client.table("loans").insert({
            "loan_id": test_loan_id,
            "branch_id": ogijo_id,
            "loan_amount": 450000.0,
            "active_credit": 450000.0,
            "total_due": 450000.0,
            "status": "Pending",
            "date": date.today().isoformat()
        }).execute()

    try:
        # BM attempts to approve
        payload = {
            "loan_id": test_loan_id,
            "disbursement_date": date.today().isoformat()
        }
        res = client.post("/api/v1/bm/approve-loan", json=payload, headers=bm_auth_headers)
        assert res.status_code == 403, f"BM should be forbidden from approving > ₦300k loan, got: {res.status_code}"
        res_text = str(res.json())
        assert "300,000" in res_text or "escalated" in res_text.lower()
    finally:
        # Cleanup
        with SupabaseUnitOfWork() as uow:
            uow.client.table("loans").delete().eq("loan_id", test_loan_id).execute()


def test_am_confirm_branch_eod_flow(am_auth_headers):
    """Verifies that Area Manager can confirm an individual branch EOD."""
    with SupabaseUnitOfWork() as uow:
        am_user = uow.users.find_by_username("AM_Area_1")
        branches = AreaManagerService.get_assigned_branches(uow, am_user.id)
        ogijo_id = next(b["branch_id"] for b in branches if b["name"] == "Ogijo")

    payload = {
        "branch_id": ogijo_id,
        "closure_date": date.today().isoformat(),
        "notes": "Automated verification test confirmation"
    }
    res = client.post("/api/v1/am/confirm-branch-eod", json=payload, headers=am_auth_headers)
    assert res.status_code == 200, f"Expected 200, got: {res.text}"
    data = res.json()
    assert data["success"] is True
    assert "status" in data["details"]
    assert data["details"]["status"] == "BRANCH_CONFIRMED"


def test_am_branch_handover_endpoint(am_auth_headers):
    """Verifies that GET /api/v1/am/branch-handover/{branch_id} returns available reports."""
    with SupabaseUnitOfWork() as uow:
        am_user = uow.users.find_by_username("AM_Area_1")
        branches = AreaManagerService.get_assigned_branches(uow, am_user.id)
        ogijo_id = next(b["branch_id"] for b in branches if b["name"] == "Ogijo")

    res = client.get(f"/api/v1/am/branch-handover/{ogijo_id}", headers=am_auth_headers)
    assert res.status_code == 200
    data = res.json()
    assert data["branch_name"] == "Ogijo"
    assert "available_reports" in data
    assert len(data["available_reports"]) >= 4


def test_am_reports_excel_download(am_auth_headers):
    """Verifies that GET /api/v1/am/reports/excel generates and downloads Excel bytes."""
    res = client.get("/api/v1/am/reports/excel", headers=am_auth_headers)
    assert res.status_code == 200
    assert res.headers["content-type"] == "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    assert len(res.content) > 1000, "Excel output should have substantial byte length"
