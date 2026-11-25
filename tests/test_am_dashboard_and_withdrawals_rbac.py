"""
tests/test_am_dashboard_and_withdrawals_rbac.py
Regression & Governance Verification Suite for BIA-AM-WD-005:
1. AM Dashboard HTTP 500 Regression Fix:
   - Verifies AreaManagerService.get_branch_performance_matrix aligns 100% with Pydantic BranchPerformanceItem
     (expected_collection, collected, outstanding_today, cash_variance, net_loan_count).
   - Verifies GET /api/v1/am/dashboard returns HTTP 200 OK for Area Manager users.
2. Zero Hardcoded Compliance Rates (Rule #13 / FP-006):
   - Eliminates hardcoded 96.5 and 100.0 fallbacks in AreaManagerService & CollectionPerformanceService.
   - Verifies live schedule-based compliance math for CO productivity and honest 0.0 when unscheduled.
3. Withdrawal Operations Strict RBAC (CO + BM Only):
   - Verifies Admin, Super Admin, AM, and Area Manager are strictly rejected (403 Forbidden) on all
     /api/v1/co/withdrawals/* operational and approval endpoints.
   - Verifies Credit Officers can access CO operational endpoints (while rejected on BM-only approvals),
     and Branch Managers can access both operational and approval endpoints.
"""
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from api.main import app
from api.dependencies import get_current_user, get_uow
from api.schemas.am_dashboard import AmDashboardResponse, BranchPerformanceItem
from models.user import CurrentUser
from services.area_manager_service import AreaManagerService
from services.collection_performance_service import CollectionPerformanceService

client = TestClient(app)


class _FakeQuery:
    def __init__(self, rows):
        self._rows = list(rows)
        self._filters = []

    def select(self, *args, **kwargs):
        return self

    def eq(self, field, value):
        self._filters.append(("eq", field, value))
        return self

    def neq(self, field, value):
        return self

    def in_(self, field, values):
        self._filters.append(("in", field, set(values or [])))
        return self

    def gte(self, field, value):
        return self

    def lte(self, field, value):
        return self

    def gt(self, field, value):
        return self

    def lt(self, field, value):
        return self

    def is_(self, field, value):
        return self

    def or_(self, expr):
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def range(self, *args, **kwargs):
        return self

    def execute(self):
        rows = self._rows
        for op, field, val in self._filters:
            if op == "eq":
                rows = [r for r in rows if not isinstance(r, dict) or field not in r or r.get(field) == val]
            elif op == "in":
                rows = [r for r in rows if not isinstance(r, dict) or field not in r or r.get(field) in val]
        res = MagicMock()
        res.data = rows
        return res


def _build_mock_am_uow(schedule_rows=None, repayment_rows=None):
    tables = {
        "loans": [
            {
                "loan_id": "ln-1",
                "client_id": "cl-1",
                "branch_id": "br-ikeja",
                "officer_id": "co-1",
                "loan_amount": 100000.0,
                "active_credit": 150000.0,
                "status": "Active",
                "created_at": "2026-11-25T09:00:00",
                "disbursement_date": "2026-11-25",
            }
        ],
        "loan_schedule": schedule_rows if schedule_rows is not None else [],
        "repayments": repayment_rows if repayment_rows is not None else [],
        "financial_ledger_entries": [
            {
                "branch_id": "br-ikeja",
                "account_code": "1000",
                "amount": 500000.0,
                "entry_type": "DEBIT",
            }
        ],
        "branch_closures": [],
        "area_eod_confirmations": [],
        "master_cashbook": [],
        "correction_requests": [],
        "loan_payoff_excess_records": [],
        "client_transfers": [],
        "withdrawal_requests": [],
        "clients": [],
        "groups": [],
        "individual_savings": [],
        "group_savings": [],
        "internal_savings": [],
        "laps_savings": [],
        "business_dates": [],
    }

    mock_client = MagicMock()
    mock_client.table.side_effect = lambda name: _FakeQuery(tables.get(name, []))

    mock_uow = MagicMock()
    mock_uow.client = mock_client
    mock_uow.users.load_am_assignments.return_value = [
        {"branch_id": "br-ikeja", "name": "Ikeja Branch", "area_name": "Area 1"}
    ]
    mock_uow.users.find_by_branch_ids.return_value = [
        SimpleNamespace(
            id="bm-1",
            username="ikeja_bm",
            full_name="Adebayo T.",
            role="Branch Manager",
            branch_id="br-ikeja",
        )
    ]
    mock_uow.users.find_by_branch_id.return_value = [
        SimpleNamespace(
            id="co-1",
            username="ikeja_co1",
            full_name="Tunde B.",
            role="Credit Officer",
            branch_id="br-ikeja",
        )
    ]
    mock_uow.users.find_by_id.return_value = SimpleNamespace(
        id="am-1",
        username="mrs_shobande",
        full_name="Mrs. Shobande",
        role="Area Manager",
        assigned_branch_ids=["br-ikeja"],
    )
    mock_uow.loans._resolve_officer_id.return_value = "co-1"
    return mock_uow


# ============================================================================
# 1. AREA MANAGER DASHBOARD HTTP 500 FIX & SCHEMA ALIGNMENT
# ============================================================================

def test_am_branch_performance_matrix_matches_pydantic_schema():
    """Ensures get_branch_performance_matrix returns exact Pydantic BranchPerformanceItem fields."""
    mock_uow = _build_mock_am_uow(
        schedule_rows=[
            {"loan_id": "ln-1", "due_date": "2026-11-25", "total_due": 10000.0, "paid_amount": 8000.0, "status": "Partial"}
        ],
        repayment_rows=[
            {"id": "rep-1", "branch_id": "br-ikeja", "officer_id": "co-1", "amount_paid": 8000.0, "date": "2026-11-25T10:00:00"}
        ],
    )

    matrix = AreaManagerService.get_branch_performance_matrix(
        uow=mock_uow,
        am_user_id="am-1",
        target_date=date(2026, 11, 25),
    )

    assert len(matrix) == 1
    row = matrix[0]
    assert "expected_collection" in row
    assert "collected" in row
    assert "outstanding_today" in row
    assert "cash_variance" in row
    assert "net_loan_count" in row

    validated = BranchPerformanceItem(**row)
    assert validated.branch_name == "Ikeja Branch"
    assert validated.expected_collection == 10000.0
    assert validated.collected == 8000.0
    assert validated.outstanding_today == 2000.0
    assert validated.compliance_pct == 80.0


def test_get_am_dashboard_endpoint_returns_200_no_500_validation_error():
    """Verifies GET /api/v1/am/dashboard serializes cleanly (prevents Mrs. Shobande HTTP 500 crash)."""
    mock_am = CurrentUser(
        id="am-shobande",
        username="mrs_shobande",
        full_name="Mrs. Shobande",
        role="Area Manager",
        branch="Area 1",
        branch_id="br-ikeja",
        assigned_branch_ids=["br-ikeja"],
        assigned_branches=["Ikeja Branch"],
    )
    mock_uow = _build_mock_am_uow(
        schedule_rows=[
            {"loan_id": "ln-1", "due_date": "2026-11-25", "total_due": 5000.0, "paid_amount": 4000.0, "status": "Partial"}
        ],
        repayment_rows=[
            {"id": "rep-1", "branch_id": "br-ikeja", "officer_id": "co-1", "amount_paid": 4000.0, "date": "2026-11-25T10:00:00"}
        ],
    )

    app.dependency_overrides[get_current_user] = lambda: mock_am
    app.dependency_overrides[get_uow] = lambda: mock_uow
    try:
        res = client.get("/api/v1/am/dashboard?target_date=2026-11-25")
        assert res.status_code == 200, f"Expected 200 OK, got {res.status_code}: {res.text}"
        body = res.json()
        parsed = AmDashboardResponse(**body)
        assert len(parsed.branch_performance) == 1
        assert parsed.branch_performance[0].expected_collection == 5000.0
        assert parsed.branch_performance[0].collected == 4000.0
        assert parsed.branch_performance[0].compliance_pct == 80.0
    finally:
        app.dependency_overrides.clear()


# ============================================================================
# 2. ZERO HARDCODED COMPLIANCE RATES (NO 96.5 / 100.0 FALLBACKS)
# ============================================================================

def test_area_manager_compliance_never_returns_hardcoded_96_5_or_fake_100():
    """Verifies AreaManagerService & CollectionPerformanceService use live schedule math or 0.0."""
    # Case A: No scheduled installments due -> must be 0.0 (never 100.0)
    empty_sched_uow = _build_mock_am_uow(
        schedule_rows=[],
        repayment_rows=[
            {"id": "rep-1", "branch_id": "br-ikeja", "officer_id": "co-1", "amount_paid": 12000.0, "date": "2026-11-25T10:00:00"}
        ],
    )
    officers_empty_resp = AreaManagerService.get_branch_officer_productivity(
        uow=empty_sched_uow,
        am_user_id="am-1",
        branch_id="br-ikeja",
        start_date=date(2026, 11, 25),
        end_date=date(2026, 11, 25),
    )
    assert len(officers_empty_resp["officers"]) == 1
    assert officers_empty_resp["officers"][0]["compliance_pct"] == 0.0

    meeting_empty = CollectionPerformanceService.get_branch_meeting_summary(
        uow=empty_sched_uow,
        branch_id="br-ikeja",
        meeting_date=date(2026, 11, 25),
    )
    assert meeting_empty["compliance_pct"] == 0.0

    # No branches assigned to AM -> honest 0.0 compliance
    no_branch_uow = _build_mock_am_uow()
    no_branch_uow.users.load_am_assignments.return_value = []
    no_branch_uow.users.find_by_id.return_value = SimpleNamespace(
        id="am-none",
        username="am_none",
        full_name="No Branch AM",
        role="Area Manager",
        branch_id=None,
        assigned_branch_ids=[],
    )
    reg_empty = AreaManagerService.get_regional_summary(no_branch_uow, "am-none", date(2026, 11, 25))
    assert reg_empty["compliance_pct"] == 0.0

    # Case B: Scheduled 10,000, paid 7,500 -> exact 75.0 (never hardcoded 96.5)
    live_sched_uow = _build_mock_am_uow(
        schedule_rows=[
            {"loan_id": "ln-1", "due_date": "2026-11-25", "total_due": 10000.0, "paid_amount": 7500.0, "status": "Partial"}
        ],
        repayment_rows=[
            {"id": "rep-1", "branch_id": "br-ikeja", "officer_id": "co-1", "amount_paid": 7500.0, "date": "2026-11-25T10:00:00"}
        ],
    )
    officers_live_resp = AreaManagerService.get_branch_officer_productivity(
        uow=live_sched_uow,
        am_user_id="am-1",
        branch_id="br-ikeja",
        start_date=date(2026, 11, 25),
        end_date=date(2026, 11, 25),
    )
    assert officers_live_resp["officers"][0]["compliance_pct"] == 75.0


# ============================================================================
# 3. WITHDRAWAL OPERATIONS STRICT RBAC (CO + BM ONLY; BLOCK ADMIN & AM)
# ============================================================================

WITHDRAWAL_GET_ENDPOINTS = [
    "/api/v1/co/withdrawals/individual-options",
    "/api/v1/co/withdrawals/group-options",
    "/api/v1/co/withdrawals/misc-balance",
    "/api/v1/co/withdrawals/laps-options",
    "/api/v1/co/withdrawals/requests",
    "/api/v1/co/withdrawals/daily-withdrawals",
    "/api/v1/co/withdrawals/pending-approvals",
]


def test_withdrawals_strictly_block_admin_and_area_manager_roles():
    """Admin, Super Admin, AM, and Area Manager MUST receive 403 Forbidden on all withdrawal routes."""
    blocked_roles = ["Admin", "Super Admin", "AM", "Area Manager"]

    for role_name in blocked_roles:
        user = CurrentUser(
            id=f"u-{role_name.lower().replace(' ', '_')}",
            username="blocked_user",
            role=role_name,
            branch="Ikeja Branch",
            branch_id="br-ikeja",
            assigned_branch_ids=["br-ikeja"],
        )
        mock_uow = _build_mock_am_uow()
        app.dependency_overrides[get_current_user] = lambda u=user: u
        app.dependency_overrides[get_uow] = lambda uow=mock_uow: uow
        try:
            for endpoint in WITHDRAWAL_GET_ENDPOINTS:
                res = client.get(endpoint)
                assert res.status_code == 403, f"{role_name} was NOT blocked on GET {endpoint} (got {res.status_code})"

            res_req = client.post(
                "/api/v1/co/withdrawals/request",
                json={"savings_type": "Individual", "operation_type": "Cash Withdrawal", "amount": 1000.0},
            )
            assert res_req.status_code == 403, f"{role_name} was NOT blocked on POST /request (got {res_req.status_code})"

            res_app = client.post(
                "/api/v1/co/withdrawals/approve",
                json={"request_id": "wr-1"},
            )
            assert res_app.status_code == 403, f"{role_name} was NOT blocked on POST /approve (got {res_app.status_code})"

            res_rej = client.post(
                "/api/v1/co/withdrawals/reject",
                json={"request_id": "wr-1", "rejection_reason": "test"},
            )
            assert res_rej.status_code == 403, f"{role_name} was NOT blocked on POST /reject (got {res_rej.status_code})"
        finally:
            app.dependency_overrides.clear()


def test_withdrawals_allow_credit_officer_and_branch_manager():
    """Credit Officer accesses operational routes (403 on approvals); Branch Manager accesses approvals too."""
    co_user = CurrentUser(
        id="co-1",
        username="ikeja_co1",
        role="Credit Officer",
        branch="Ikeja Branch",
        branch_id="br-ikeja",
    )
    bm_user = CurrentUser(
        id="bm-1",
        username="ikeja_bm",
        role="Branch Manager",
        branch="Ikeja Branch",
        branch_id="br-ikeja",
    )
    mock_uow = _build_mock_am_uow()

    app.dependency_overrides[get_current_user] = lambda: co_user
    app.dependency_overrides[get_uow] = lambda: mock_uow
    try:
        for co_endpoint in [
            "/api/v1/co/withdrawals/individual-options",
            "/api/v1/co/withdrawals/group-options",
            "/api/v1/co/withdrawals/laps-options",
            "/api/v1/co/withdrawals/daily-withdrawals",
        ]:
            res = client.get(co_endpoint)
            assert res.status_code != 403, f"Credit Officer should be allowed on {co_endpoint}, got {res.status_code}"

        # CO must still be blocked from manager-only approval endpoints
        assert client.get("/api/v1/co/withdrawals/pending-approvals").status_code == 403
        assert client.post("/api/v1/co/withdrawals/approve", json={"request_id": "wr-1"}).status_code == 403
    finally:
        app.dependency_overrides.clear()

    app.dependency_overrides[get_current_user] = lambda: bm_user
    app.dependency_overrides[get_uow] = lambda: mock_uow
    try:
        for bm_endpoint in [
            "/api/v1/co/withdrawals/individual-options",
            "/api/v1/co/withdrawals/daily-withdrawals",
            "/api/v1/co/withdrawals/pending-approvals",
        ]:
            res = client.get(bm_endpoint)
            assert res.status_code == 200, f"Branch Manager failed on {bm_endpoint}: {res.status_code} {res.text}"
    finally:
        app.dependency_overrides.clear()
