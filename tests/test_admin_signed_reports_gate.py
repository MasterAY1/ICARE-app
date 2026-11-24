"""
tests/test_admin_signed_reports_gate.py
Verification suite proving Executive Admin ONLY views, previews, exports,
and locks monthly branch reports that were submitted by BM and formally
reviewed & signed by an Area Manager (AM_VERIFIED, AREA_SEALED, ADMIN_LOCKED).
"""
from types import SimpleNamespace
from fastapi.testclient import TestClient
import pytest

from api.main import app
from api.dependencies import get_uow, get_current_user
from models.user import CurrentUser
from services.monthly_report_workflow_service import MonthlyReportWorkflowService


class _MemoryQuery:
    def __init__(self, rows):
        self._rows = rows
        self._filters = []
        self._in_filters = {}
        self._limit = None
        self._pending_update = None

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, col, val):
        self._filters.append((col, val))
        return self

    def in_(self, col, vals):
        self._in_filters[col] = set(vals)
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, n):
        self._limit = n
        return self

    def update(self, payload):
        self._pending_update = dict(payload)
        return self

    def execute(self):
        matched = []
        for row in self._rows:
            ok = True
            for col, val in self._filters:
                if row.get(col) != val:
                    ok = False
                    break
            if ok:
                for col, vals in self._in_filters.items():
                    if row.get(col) not in vals:
                        ok = False
                        break
            if ok:
                matched.append(row)

        if self._pending_update is not None:
            for row in matched:
                row.update(self._pending_update)
            return SimpleNamespace(data=list(matched))

        if self._limit is not None:
            matched = matched[: self._limit]
        return SimpleNamespace(data=[dict(r) for r in matched])


class _FakeClient:
    def __init__(self, tables):
        self._tables = tables

    def table(self, name):
        return _MemoryQuery(self._tables.setdefault(name, []))


class _FakeUsersRepo:
    def __init__(self, users_by_id):
        self._users_by_id = users_by_id

    def find_by_id(self, uid):
        return self._users_by_id.get(uid)


class _FakeUoW:
    def __init__(self, tables, users_by_id):
        self.client = _FakeClient(tables)
        self.users = _FakeUsersRepo(users_by_id)


def _sample_tables_and_users():
    tables = {
        "branches": [
            {"branch_id": "b-1", "name": "Ikeja", "is_active": True},
            {"branch_id": "b-2", "name": "Ogijo", "is_active": True},
            {"branch_id": "b-3", "name": "Sagamu", "is_active": True},
            {"branch_id": "b-4", "name": "Ikorodu", "is_active": True},
        ],
        "monthly_report_submissions": [
            {
                "id": "sub-1",
                "branch_id": "b-1",
                "area_name": "Lagos Area",
                "year": 2026,
                "month": 11,
                "status": "AM_VERIFIED",
                "disbursed_principal": 1500000.0,
                "upfront_fees": 75000.0,
                "net_active_credit": 1725000.0,
                "collections": 980000.0,
                "closing_credit": 4200000.0,
                "closing_savings": 1100000.0,
                "vault_cash_acct_1000": 320000.0,
                "bank_deposits_acct_1050": 500000.0,
                "is_gl_balanced": True,
                "gl_variance": 0.0,
                "bm_name": "Tunde B.",
                "bm_submitted_at": "2026-11-20T09:00:00",
                "am_name": "Ngozi K.",
                "am_notes": "Trial balance & cash reconciled.",
                "am_endorsed_at": "2026-11-21T14:30:00",
            },
            {
                "id": "sub-2",
                "branch_id": "b-2",
                "area_name": "Ogun Area",
                "year": 2026,
                "month": 11,
                "status": "BM_SUBMITTED",
                "disbursed_principal": 900000.0,
                "collections": 410000.0,
                "closing_credit": 2300000.0,
                "closing_savings": 650000.0,
                "vault_cash_acct_1000": 150000.0,
                "is_gl_balanced": True,
                "bm_name": "Seyi O.",
                "bm_submitted_at": "2026-11-22T11:00:00",
            },
            {
                "id": "sub-3",
                "branch_id": "b-3",
                "area_name": "Ogun Area",
                "year": 2026,
                "month": 11,
                "status": "RETURNED_FOR_CORRECTION",
                "disbursed_principal": 600000.0,
                "collections": 200000.0,
                "closing_credit": 1400000.0,
                "closing_savings": 400000.0,
                "vault_cash_acct_1000": 95000.0,
                "is_gl_balanced": False,
                "bm_name": "Kemi A.",
                "am_query_notes": "Clarify bank transit mismatch.",
            },
        ],
    }
    users = {
        "u-admin": SimpleNamespace(id="u-admin", username="admin", full_name="Head Admin", role="Admin"),
        "u-am": SimpleNamespace(id="u-am", username="am_1", full_name="Ngozi K.", role="Area Manager"),
    }
    return _FakeUoW(tables, users)


def test_admin_signed_service_filters_and_enriches_am_signed_only():
    uow = _sample_tables_and_users()
    rows = MonthlyReportWorkflowService.get_admin_signed_submissions(
        uow=uow,
        admin_user_id="u-admin",
        year=2026,
        month=11,
    )

    assert len(rows) == 1
    assert rows[0]["branch_name"] == "Ikeja"
    assert rows[0]["status"] == "AM_VERIFIED"
    assert rows[0]["am_name"] == "Ngozi K."
    assert rows[0]["am_notes"] == "Trial balance & cash reconciled."
    assert rows[0]["am_endorsed_at"] == "2026-11-21T14:30:00"


def test_lock_by_admin_rejects_unendorsed_reports():
    uow = _sample_tables_and_users()

    with pytest.raises(ValueError, match="reviewed and signed by the Area Manager"):
        MonthlyReportWorkflowService.lock_by_admin(
            uow=uow,
            admin_user_id="u-admin",
            branch_id="b-2",  # BM_SUBMITTED only
            year=2026,
            month=11,
        )

    res = MonthlyReportWorkflowService.lock_by_admin(
        uow=uow,
        admin_user_id="u-admin",
        branch_id="b-1",  # AM_VERIFIED
        year=2026,
        month=11,
    )
    assert res["status"] == "ADMIN_LOCKED"


def test_admin_endpoints_filter_queue_and_block_unreviewed_statements_and_exports(monkeypatch):
    uow = _sample_tables_and_users()
    monkeypatch.setattr(
        "services.area_manager_service.AreaManagerService.get_assigned_branches",
        lambda _uow, _uid: [
            {"branch_id": "b-1", "name": "Ikeja"},
            {"branch_id": "b-2", "name": "Ogijo"},
        ],
    )

    client = TestClient(app)
    admin_user = CurrentUser(
        id="u-admin",
        username="admin",
        full_name="Head Admin",
        role="Admin",
        branch="Head Office",
    )
    am_user = CurrentUser(
        id="u-am",
        username="am_1",
        full_name="Ngozi K.",
        role="Area Manager",
        branch="Ikeja",
        assigned_branches=["Ikeja", "Ogijo"],
        assigned_branch_ids=["b-1", "b-2"],
    )

    active_user = [admin_user]
    app.dependency_overrides[get_uow] = lambda: uow
    app.dependency_overrides[get_current_user] = lambda: active_user[0]

    try:
        # 1. Admin /admin-signed returns ONLY Ikeja (AM_VERIFIED)
        res_signed = client.get("/api/v1/reports/monthly-workflow/admin-signed?year=2026&month=11")
        assert res_signed.status_code == 200
        data_signed = res_signed.json()
        assert [row["branch_name"] for row in data_signed] == ["Ikeja"]

        # 2. Admin /pending-am also enforces AM-signed filter
        res_pending_admin = client.get("/api/v1/reports/monthly-workflow/pending-am?year=2026&month=11")
        assert res_pending_admin.status_code == 200
        assert [row["branch_name"] for row in res_pending_admin.json()] == ["Ikeja"]

        # 3. Admin CANNOT view unreviewed/unsigned branch statements or exports
        for blocked_url in [
            "/api/v1/reports/monthly-parity?branch_name=Ogijo&year=2026&month=11",
            "/api/v1/reports/official-statements?branch_name=Ogijo&year=2026&month=11",
            "/api/v1/reports/annex-1?branch_name=Ogijo&year=2026&month=11",
            "/api/v1/reports/export/monthly-parity-pdf?branch_name=Ogijo&year=2026&month=11",
            "/api/v1/reports/export/monthly-parity-excel?branch_name=Ogijo&year=2026&month=11",
            "/api/v1/reports/export/excel?branch_name=Ogijo&year=2026&month=11",
        ]:
            resp = client.get(blocked_url)
            assert resp.status_code == 403, f"Expected 403 for {blocked_url}, got {resp.status_code}"

        # 4. Empty month (zero AM-signed branches) returns empty queue + blocks Admin statement fetch
        res_empty = client.get("/api/v1/reports/monthly-workflow/admin-signed?year=2026&month=12")
        assert res_empty.status_code == 200
        assert res_empty.json() == []

        res_empty_stmt = client.get("/api/v1/reports/official-statements?year=2026&month=12")
        assert res_empty_stmt.status_code == 403

        # 5. Area Manager caller on /pending-am still sees BM_SUBMITTED branches
        active_user[0] = am_user
        res_am = client.get("/api/v1/reports/monthly-workflow/pending-am?year=2026&month=11")
        assert res_am.status_code == 200
        statuses = {row["branch_name"]: row["status"] for row in res_am.json()}
        assert statuses["Ikeja"] == "AM_VERIFIED"
        assert statuses["Ogijo"] == "BM_SUBMITTED"
    finally:
        app.dependency_overrides.clear()
