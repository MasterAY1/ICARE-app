"""
Offline RBAC, Multi-Branch Scoping & Contract Tests for User Management and Audit Ledger.
Covers fixes implemented in Phase 1 (BIA-SYS-HARDCODE-001) & Phase 2 (BIA-SHARED-USER-AUDIT-002).
Uses FastAPI dependency overrides and MagicMock so tests execute deterministically offline.
"""
from datetime import date
from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from api.main import app
from api.dependencies import get_current_user, get_uow
from database.repositories.audit_repository import resolve_officer_id
from domain.entities.branch_closure import BranchClosure
from domain.entities.user import User
from models.user import CurrentUser
from services.financial_reconciliation_service import FinancialReconciliationService


client = TestClient(app)


def _make_chain_mock(data=None):
    table = MagicMock()
    for method in (
        "select", "eq", "neq", "in_", "is_", "ilike", "gte", "lte", "lt", "gt",
        "order", "limit", "update", "insert", "delete",
    ):
        getattr(table, method).return_value = table
    table.execute.return_value = MagicMock(data=data if data is not None else [])
    return table


def _make_uow(tables_data=None):
    uow = MagicMock()
    tables_data = tables_data or {}

    def _table(name):
        return _make_chain_mock(tables_data.get(name, []))

    uow.client.table.side_effect = _table
    return uow


@pytest.fixture(autouse=True)
def _clear_overrides():
    yield
    app.dependency_overrides.clear()


# =============================================================================
# 1. USER MANAGEMENT RBAC & CONTRACT TESTS
# =============================================================================

@pytest.mark.parametrize(
    "role",
    ["CO", "Credit Officer", "Director", "Account Manager", "Procurement Officer"],
)
def test_users_endpoint_blocks_unauthorized_roles(role):
    caller = CurrentUser(
        id="u-1", username="user1", role=role, branch="Ogijo", branch_id="b-1"
    )
    uow = _make_uow()
    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_uow] = lambda: uow

    resp = client.get("/api/v1/users")
    assert resp.status_code == 403


def test_users_get_populates_scoped_available_branches():
    am_caller = CurrentUser(
        id="am-1",
        username="AM1",
        role="AREA_MANAGER",
        branch="Ogijo",
        branch_id="b-1",
        assigned_branch_ids=["b-1", "b-2"],
    )
    uow = _make_uow({
        "branches": [
            {"branch_id": "b-1", "name": "Ogijo"},
            {"branch_id": "b-2", "name": "Ikorodu"},
            {"branch_id": "b-3", "name": "Kola"},
        ],
        "app_users": [],
    })
    app.dependency_overrides[get_current_user] = lambda: am_caller
    app.dependency_overrides[get_uow] = lambda: uow

    with patch("api.routes.users.UserService.list_users", return_value=[]):
        resp = client.get("/api/v1/users")

    assert resp.status_code == 200
    body = resp.json()
    branch_ids = {b["branch_id"] for b in body["available_branches"]}
    assert branch_ids == {"b-1", "b-2"}
    assert "b-3" not in branch_ids


def test_products_meta_no_hardcoded_fallback_when_db_empty():
    admin_caller = CurrentUser(
        id="adm-1", username="admin", role="ADMIN", branch="Head Office", branch_id="b-ho"
    )
    uow = _make_uow({"loan_products": []})
    app.dependency_overrides[get_current_user] = lambda: admin_caller
    app.dependency_overrides[get_uow] = lambda: uow

    with patch("api.routes.users.UserService.list_users", return_value=[]):
        resp = client.get("/api/v1/users/products/meta")

    assert resp.status_code == 200
    assert resp.json()["available_products"] == []


def test_am_cannot_assign_products_outside_supervised_branches():
    am_caller = CurrentUser(
        id="am-1",
        username="AM1",
        role="AREA_MANAGER",
        branch="Ogijo",
        branch_id="b-1",
        assigned_branch_ids=["b-1", "b-2"],
    )
    foreign_co = User(
        id="co-9",
        username="CO_Kola",
        full_name="Kola CO",
        password_hash="x",
        role="Credit Officer",
        branch_id="b-3",
        branch_name="Kola",
        created_at=None,
    )
    uow = _make_uow()
    uow.users.find_by_username.return_value = foreign_co

    app.dependency_overrides[get_current_user] = lambda: am_caller
    app.dependency_overrides[get_uow] = lambda: uow

    resp = client.post(
        "/api/v1/users/products/assign",
        json={"username": "CO_Kola", "allowed_products": ["Daily 60 Days"]},
    )
    assert resp.status_code == 403


def test_delete_closure_enforces_bm_am_ownership_and_preserves_404():
    bm_caller = CurrentUser(
        id="bm-1", username="BM1", role="BRANCH_MANAGER", branch="Ogijo", branch_id="b-1"
    )
    other_closure = BranchClosure(
        id="cl-2",
        start_date=date(2026, 12, 25),
        end_date=date(2026, 12, 25),
        reason="Holiday",
        branch_id="b-2",
    )
    uow = _make_uow()
    uow.branch_closures.find_all.return_value = [other_closure]

    app.dependency_overrides[get_current_user] = lambda: bm_caller
    app.dependency_overrides[get_uow] = lambda: uow

    resp_403 = client.delete("/api/v1/users/closures/cl-2")
    assert resp_403.status_code == 403

    resp_404 = client.delete("/api/v1/users/closures/non-existent")
    assert resp_404.status_code == 404


def test_revoke_sessions_enforces_am_branch_and_revokes_store():
    am_caller = CurrentUser(
        id="am-1",
        username="AM1",
        role="Area Manager",
        branch="Ogijo",
        branch_id="b-1",
        assigned_branch_ids=["b-1"],
    )
    target_co = User(
        id="co-1",
        username="CO1",
        full_name="Officer One",
        password_hash="x",
        role="Credit Officer",
        branch_id="b-1",
        branch_name="Ogijo",
        created_at=None,
    )
    foreign_co = User(
        id="co-9",
        username="CO9",
        full_name="Officer Nine",
        password_hash="x",
        role="Credit Officer",
        branch_id="b-9",
        branch_name="Other",
        created_at=None,
    )
    uow = _make_uow()
    app.dependency_overrides[get_current_user] = lambda: am_caller
    app.dependency_overrides[get_uow] = lambda: uow

    uow.users.find_by_id.return_value = foreign_co
    assert client.post("/api/v1/users/co-9/revoke-sessions").status_code == 403

    uow.users.find_by_id.return_value = target_co
    fake_store = MagicMock()
    with patch("auth.token_store.get_revocation_store", return_value=fake_store), \
         patch("services.audit_log_service.AuditLogService.log_user_action"):
        resp = client.post("/api/v1/users/co-1/revoke-sessions")
    assert resp.status_code == 200
    assert resp.json()["success"] is True
    fake_store.revoke_user_sessions.assert_called_once_with("co-1")


# =============================================================================
# 2. AUDIT LEDGER RBAC, CONTRACTS & ZERO-FALLBACK TESTS
# =============================================================================

@pytest.mark.parametrize(
    "role",
    ["Director", "Executive Director", "Branch Manager", "Area Manager", "CO"],
)
def test_reconciliation_repair_blocks_director_and_non_admins(role):
    caller = CurrentUser(
        id="u-2", username="exec", role=role, branch="Head Office", branch_id="b-1"
    )
    uow = _make_uow()
    app.dependency_overrides[get_current_user] = lambda: caller
    app.dependency_overrides[get_uow] = lambda: uow

    resp = client.post(
        "/api/v1/audit/reconciliation-wizard/repair",
        json={"branch_id": "b-1", "reconciliation_date": "2026-11-20"},
    )
    assert resp.status_code == 403


def test_loan_timeline_blocks_cross_branch_bm_and_cross_officer_co():
    bm_caller = CurrentUser(
        id="bm-1", username="BM1", role="Branch Manager", branch="Ogijo", branch_id="b-1"
    )
    uow = _make_uow({
        "loans": [{"loan_id": "ln-9", "branch_id": "b-2", "officer_id": "co-2"}],
    })
    app.dependency_overrides[get_current_user] = lambda: bm_caller
    app.dependency_overrides[get_uow] = lambda: uow

    assert (
        client.get("/api/v1/audit/explorer/loan-timeline?loan_id=ln-9").status_code
        == 403
    )

    co_caller = CurrentUser(
        id="co-1", username="CO1", role="CO", branch="Ogijo", branch_id="b-2"
    )
    app.dependency_overrides[get_current_user] = lambda: co_caller
    assert (
        client.get("/api/v1/audit/explorer/loan-timeline?loan_id=ln-9").status_code
        == 403
    )


def test_withdrawals_audit_returns_normalized_fields_and_am_scope():
    am_caller = CurrentUser(
        id="am-1",
        username="AM1",
        role="AM",
        branch="Ogijo",
        branch_id="b-1",
        assigned_branch_ids=["b-1", "b-2"],
    )
    uow = _make_uow({
        "branches": [{"branch_id": "b-1", "name": "Ogijo"}],
        "withdrawal_requests": [
            {
                "id": "wr-1",
                "branch_id": "b-1",
                "operational_date": "2026-11-20",
                "created_at": "2026-11-20T10:00:00",
                "client_name": "Ada Obi",
                "savings_type": "Individual",
                "operation_type": "Withdrawal",
                "payout_method": "Cash",
                "amount": 5000.0,
                "requested_by": "CO1",
                "approved_by": "BM1",
                "status": "APPROVED",
                "reference": "WR-001",
            }
        ],
        "user_audit_logs": [],
    })
    app.dependency_overrides[get_current_user] = lambda: am_caller
    app.dependency_overrides[get_uow] = lambda: uow

    resp = client.get("/api/v1/audit/withdrawals?date_from=2026-11-01&date_to=2026-11-25")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["requests"]) == 1
    row = body["requests"][0]
    for key in (
        "operational_date", "client_name", "savings_type", "operation_type",
        "payout_method", "requested_by", "approved_by", "branch",
    ):
        assert key in row
    assert row["branch"] == "Ogijo"


def test_collection_audit_zero_expected_does_not_return_100_percent():
    admin_caller = CurrentUser(
        id="adm-1", username="admin", role="Admin", branch="Head Office", branch_id="b-ho"
    )
    uow = _make_uow({"loans": [], "repayments": [], "clients": []})
    app.dependency_overrides[get_current_user] = lambda: admin_caller
    app.dependency_overrides[get_uow] = lambda: uow

    with patch("api.routes.audit.AuditEnricher") as mock_enricher_cls:
        mock_enricher = MagicMock()
        mock_enricher.enrich_collection_records.return_value = []
        mock_enricher_cls.return_value = mock_enricher
        resp = client.get("/api/v1/audit/collections?date_from=2026-11-01&date_to=2026-11-25")

    assert resp.status_code == 200
    assert resp.json()["metrics"]["meeting_compliance_ratio"] == 0.0


def test_exception_reports_handles_empty_list_and_multi_branch_list():
    uow = _make_uow()
    empty_res = FinancialReconciliationService.run_15_exception_reports(uow, [])
    assert empty_res["total_exceptions"] == 0
    assert empty_res["exception_rules_evaluated"] == 15
    assert "inactive_clients_active_loan" in empty_res["details"]

    multi_res = FinancialReconciliationService.run_15_exception_reports(uow, ["b-1", "b-2"])
    assert multi_res["exception_rules_evaluated"] == 15
    assert "inactive_clients_active_loan" in multi_res["details"]


def test_audit_repository_resolve_officer_id_never_returns_zero_uuid():
    mock_uow = _make_uow({"app_users": []})
    assert resolve_officer_id(mock_uow.client, "nonexistent_officer_xyz_999") is None
