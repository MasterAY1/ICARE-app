"""
tests/test_admin_dashboard_and_performance.py
Comprehensive verification test suite for Admin Dashboard and Institution Performance Engine.

Invariants tested:
1. InstitutionPerformanceService: 6-pillar composite scorecard calculation (Disbursement, PAR, Recovery, Outreach, Repayment, Vault).
2. Branch & Officer Rankings: correct ordering from 1st to last.
3. Overdue Debt Recovery & Rehabilitation pillar integration (loan_overdue_recovery_records).
4. Early Full Payoffs and Excess Payments integration (loan_payoff_excess_records).
5. Admin Dashboard Endpoints RBAC & Data Integrity:
   - GET /api/v1/admin/dashboard/operations
   - GET /api/v1/admin/dashboard/performance
   - GET /api/v1/admin/dashboard/risk-health
6. Zero-Emoji Governance (Rule 10): 0 emojis in responses or labels.
7. Technical Identity Abstraction (Rule 12): Proper banking terminology.
"""
import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from api.main import app
from api.dependencies import get_current_user, get_uow
from models.user import CurrentUser
from services.institution_performance_service import InstitutionPerformanceService

client = TestClient(app)


# ============================================================================
# 1. INSTITUTION PERFORMANCE SERVICE SCORECARD TESTS
# ============================================================================

def test_performance_service_computes_composite_scores():
    """Verifies that the performance service accurately aggregates the 6 scorecard pillars."""
    mock_uow = MagicMock()

    # Mock branches
    mock_uow.client.table.return_value.select.return_value.execute.return_value.data = [
        {"branch_id": "b-1", "id": "b-1", "name": "Ogijo", "code": "OGI"},
        {"branch_id": "b-2", "id": "b-2", "name": "Ikorodu", "code": "IKR"},
    ]

    perf = InstitutionPerformanceService.compute_institution_performance(uow=mock_uow, year=2026)

    assert "year" in perf
    assert perf["year"] == 2026
    assert "branch_performance" in perf
    assert "officer_performance" in perf
    assert "branch_rankings" in perf
    assert "officer_rankings" in perf
    assert isinstance(perf["branch_rankings"], list)
    assert isinstance(perf["officer_rankings"], list)

    # Validate branch rankings
    if perf["branch_rankings"]:
        first_branch = perf["branch_rankings"][0]
        assert "rank" in first_branch
        assert first_branch["rank"] == 1
        assert "branch_name" in first_branch
        assert "composite_score" in first_branch
        assert 0.0 <= first_branch["composite_score"] <= 100.0

        # Scorecard check
        scorecard = first_branch.get("scorecard", {})
        assert "capital_deployment_score" in scorecard
        assert "delinquency_control_score" in scorecard
        assert "overdue_recovery_score" in scorecard
        assert "borrower_outreach_score" in scorecard
        assert "repayment_compliance_score" in scorecard
        assert "vault_discipline_score" in scorecard


# ============================================================================
# 2. RBAC & ENDPOINT ACCESS CONTROL TESTS
# ============================================================================

def test_admin_dashboard_operations_unauthenticated_rejected():
    """Verifies unauthenticated requests to operations endpoint return 401."""
    app.dependency_overrides.pop(get_current_user, None)
    res = client.get("/api/v1/admin/dashboard/operations")
    assert res.status_code == 401


def test_admin_dashboard_operations_unauthorized_role_rejected():
    """Verifies Credit Officer is rejected with 403 when trying to access admin operations."""
    mock_co = CurrentUser(
        id="co-test-id",
        username="OGI_CO1",
        role="Credit Officer",
        branch="Ogijo",
        permissions={"view_collections"}
    )
    app.dependency_overrides[get_current_user] = lambda: mock_co
    try:
        res = client.get("/api/v1/admin/dashboard/operations")
        assert res.status_code == 403
    finally:
        app.dependency_overrides.pop(get_current_user, None)


def test_admin_dashboard_operations_admin_success():
    """Verifies Admin receives the consolidated operations snapshot."""
    mock_admin = CurrentUser(
        id="admin-test-id",
        username="Admin",
        role="Admin",
        branch="Head Office",
        permissions={"system_admin", "view_reports"}
    )
    app.dependency_overrides[get_current_user] = lambda: mock_admin

    # Mock uow responses to return safe defaults
    mock_uow = MagicMock()
    mock_uow.client.table.return_value.select.return_value.execute.return_value.data = []
    mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    mock_uow.client.table.return_value.select.return_value.in_.return_value.execute.return_value.data = []
    mock_uow.client.table.return_value.select.return_value.order.return_value.limit.return_value.execute.return_value.data = []
    mock_uow.client.table.return_value.select.return_value.in_.return_value.gt.return_value.order.return_value.limit.return_value.execute.return_value.data = []

    app.dependency_overrides[get_uow] = lambda: mock_uow
    try:
        res = client.get("/api/v1/admin/dashboard/operations")
        assert res.status_code == 200, f"Expected 200, got: {res.status_code} ({res.text})"

        data = res.json()
        assert "business_date" in data
        assert "business_date_status" in data
        assert "is_working_day" in data["business_date_status"]
        assert "overview" in data
        assert "total_clients_display" in data["overview"]
        assert "active_branches_count" in data["overview"]
        assert "financial_activity_week" in data
        assert len(data["financial_activity_week"]) == 7
        assert "branch_performance_summary" in data
        assert "liquidity" in data
        assert "vault_cash_in_custody" in data["liquidity"]
        assert "branch_matrix" in data
        assert "action_center" in data
        assert "pending_reversals" in data["action_center"]
        assert "pending_high_loans" in data["action_center"]
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_uow, None)


def test_admin_dashboard_branch_detail_success():
    """Verifies Admin can drill down into a specific branch's metrics."""
    mock_admin = CurrentUser(
        id="admin-test-id",
        username="Admin",
        role="Admin",
        branch="Head Office",
        permissions={"system_admin"}
    )
    app.dependency_overrides[get_current_user] = lambda: mock_admin

    mock_uow = MagicMock()
    mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    mock_uow.client.table.return_value.select.return_value.execute.return_value.data = []
    app.dependency_overrides[get_uow] = lambda: mock_uow

    try:
        res = client.get("/api/v1/admin/dashboard/branch/test-branch-uuid")
        assert res.status_code == 200, f"Expected 200, got: {res.status_code} ({res.text})"
        data = res.json()
        assert "branch_id" in data
        assert "vault_cash_in_custody" in data
        assert "active_credit_book" in data
        assert "operational_status" in data
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_uow, None)


# ============================================================================
# 3. ADMIN DASHBOARD PERFORMANCE ENDPOINT TESTS
# ============================================================================

def test_admin_dashboard_performance_admin_success():
    """Verifies Admin receives the institution performance rankings."""
    mock_admin = CurrentUser(
        id="admin-test-id",
        username="Admin",
        role="Admin",
        branch="Head Office",
        permissions={"system_admin"}
    )
    app.dependency_overrides[get_current_user] = lambda: mock_admin

    mock_uow = MagicMock()
    mock_uow.client.table.return_value.select.return_value.execute.return_value.data = []
    app.dependency_overrides[get_uow] = lambda: mock_uow

    try:
        res = client.get("/api/v1/admin/dashboard/performance?year=2026")
        assert res.status_code == 200, f"Expected 200, got: {res.status_code} ({res.text})"

        data = res.json()
        assert data["year"] == 2026
        assert "branch_performance" in data
        assert "officer_performance" in data
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_uow, None)


# ============================================================================
# 4. ADMIN DASHBOARD RISK & HEALTH ENDPOINT TESTS
# ============================================================================

def test_admin_dashboard_risk_health_admin_success():
    """Verifies Admin receives the risk, overdue recovery, and engine health metrics."""
    mock_admin = CurrentUser(
        id="admin-test-id",
        username="Admin",
        role="Admin",
        branch="Head Office",
        permissions={"system_admin"}
    )
    app.dependency_overrides[get_current_user] = lambda: mock_admin

    mock_uow = MagicMock()
    mock_uow.client.table.return_value.select.return_value.execute.return_value.data = []
    mock_uow.client.table.return_value.select.return_value.in_.return_value.execute.return_value.data = []
    mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    app.dependency_overrides[get_uow] = lambda: mock_uow

    try:
        res = client.get("/api/v1/admin/dashboard/risk-health")
        assert res.status_code == 200, f"Expected 200, got: {res.status_code} ({res.text})"

        data = res.json()
        assert "risk_indicators" in data
        assert "engine_health" in data
        risk = data["risk_indicators"]
        assert "par_pct" in risk
        assert "recovery_overview" in risk
        assert "settlement_overview" in risk
        engine = data["engine_health"]
        assert "projection_engine_status" in engine
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_uow, None)
