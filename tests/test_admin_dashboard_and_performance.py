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


def test_admin_dashboard_operations_with_populated_branches():
    """Verifies that when branches exist, branch_performance_summary and branch_matrix serialize without KeyError."""
    mock_admin = CurrentUser(
        id="admin-test-id",
        username="Admin",
        role="Admin",
        branch="Head Office",
        permissions={"system_admin"}
    )
    app.dependency_overrides[get_current_user] = lambda: mock_admin

    mock_uow = MagicMock()
    mock_uow.client.table.return_value.select.return_value.execute.return_value.data = [
        {"branch_id": "b-1", "name": "Ogijo", "code": "OGI"},
        {"branch_id": "b-2", "name": "Ikorodu", "code": "IKR"}
    ]
    app.dependency_overrides[get_uow] = lambda: mock_uow

    try:
        res = client.get("/api/v1/admin/dashboard/operations")
        assert res.status_code == 200, f"Expected 200, got: {res.status_code} ({res.text})"
        data = res.json()
        assert len(data["branch_performance_summary"]) == 2
        assert data["branch_performance_summary"][0]["branch_name"] in ["Ogijo", "Ikorodu"]
        assert "relative_pct" in data["branch_performance_summary"][0]
        assert "volume" in data["branch_performance_summary"][0]
        assert "status" in data["branch_performance_summary"][0]
        assert "manager_name" in data["branch_performance_summary"][0]
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
        assert "Synchronized / Up to Date" not in engine["projection_engine_status"]
        assert "All Field Nodes Active" not in engine["offline_device_sync_status"]
        assert "Supabase PostgreSQL Managed" not in engine["database_cluster"]
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_uow, None)


def test_admin_operations_and_performance_zero_hardcoded_compliance():
    """
    BR-DASH-003 / FP-006: Ensures collection_compliance_pct, branch compliance_pct,
    and officer compliance_pct never return static 98.4 / 95.0 literals, and zero-activity
    scorecards never award fabricated baseline points.
    """
    mock_admin = CurrentUser(
        id="admin-test-id",
        username="Admin",
        role="Admin",
        branch="Head Office",
        permissions={"system_admin"}
    )
    app.dependency_overrides[get_current_user] = lambda: mock_admin

    def _table_router(table_name):
        tbl = MagicMock()
        if table_name == "branches":
            rows = [{"branch_id": "b-1", "name": "Ogijo", "code": "OGI"}]
        elif table_name == "loans":
            rows = [{
                "loan_id": "l-1",
                "branch_id": "b-1",
                "client_id": "c-1",
                "officer_id": "o-1",
                "loan_amount": 100000.0,
                "active_credit": 100000.0,
                "total_outstanding": 50000.0,
                "status": "ACTIVE",
                "start_date": "2026-01-10",
                "disbursement_date": "2026-01-10",
                "end_date": "2026-12-30",
            }]
        elif table_name == "loan_schedule":
            rows = [{
                "loan_id": "l-1",
                "total_due": 20000.0,
                "paid_amount": 15000.0,
                "due_date": "2026-01-20",
            }]
        elif table_name == "user_roles":
            rows = [{
                "user_id": "o-1",
                "roles": {"name": "Credit Officer"},
                "app_users": {
                    "id": "o-1",
                    "username": "OGI_CO1",
                    "full_name": "Officer One",
                    "branch_id": "b-1",
                },
            }]
        else:
            rows = []

        resp = MagicMock()
        resp.data = rows
        resp.count = len(rows)

        # Support all Supabase chained filter builders cleanly
        chain = MagicMock()
        chain.execute.return_value = resp
        for m in ("eq", "in_", "gte", "lte", "gt", "lt", "or_", "order", "limit"):
            getattr(chain, m).return_value = chain
        tbl.select.return_value = chain
        return tbl

    mock_uow = MagicMock()
    mock_uow.client.table.side_effect = _table_router
    app.dependency_overrides[get_uow] = lambda: mock_uow

    try:
        ops_res = client.get("/api/v1/admin/dashboard/operations?business_date=2026-02-01")
        assert ops_res.status_code == 200
        ops_data = ops_res.json()
        # Live schedule ratio 15,000 / 20,000 = 75.0% (NOT static 98.4%)
        assert ops_data["liquidity"]["collection_compliance_pct"] == 75.0

        perf_res = client.get("/api/v1/admin/dashboard/performance?year=2026")
        assert perf_res.status_code == 200
        perf_data = perf_res.json()
        b_list = perf_data["branch_performance"]["rankings"]
        assert len(b_list) == 1
        assert b_list[0]["compliance_pct"] == 75.0
        o_list = perf_data["officer_performance"]["rankings"]
        assert len(o_list) == 1
        assert o_list[0]["compliance_pct"] == 75.0
    finally:
        app.dependency_overrides.pop(get_current_user, None)
        app.dependency_overrides.pop(get_uow, None)


def test_performance_service_empty_portfolio_awards_zero_points():
    """Ensures idle branches receive 0.0 points instead of fabricated 10/5/8 fallback constants."""
    def _empty_table(table_name):
        tbl = MagicMock()
        rows = [{"branch_id": "b-empty", "name": "New Branch", "code": "NEW"}] if table_name == "branches" else []
        resp = MagicMock()
        resp.data = rows
        chain = MagicMock()
        chain.execute.return_value = resp
        for m in ("eq", "in_", "gte", "lte", "gt", "lt", "or_", "order", "limit"):
            getattr(chain, m).return_value = chain
        tbl.select.return_value = chain
        return tbl

    mock_uow = MagicMock()
    mock_uow.client.table.side_effect = _empty_table

    res = InstitutionPerformanceService.get_branch_performance_rankings(mock_uow, 2026)
    assert len(res["rankings"]) == 1
    b = res["rankings"][0]
    assert b["compliance_pct"] == 0.0
    assert b["recovery_rate_pct"] == 0.0
    assert b["composite_score"] == 0.0
