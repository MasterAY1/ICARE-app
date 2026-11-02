"""
tests/test_security_and_access_control.py
Comprehensive automated test suite for Security & Access Control Hardening (Prompt 2 / BIA-SYS-SEC-001).
Complies with Strict Zero-Emoji Governance.
"""
import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from api.main import app
from auth.session import generate_session_token, validate_session_token
from auth.token_store import get_revocation_store
from services.rate_limiter import get_auth_rate_limiter
from models.user import CurrentUser
from api.dependencies import get_current_user, get_uow
from domain.entities.user import User


client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_security_state():
    """Ensure rate limiter, token revocation store, and dependency overrides are clean for each test."""
    app.dependency_overrides.clear()
    get_auth_rate_limiter().clear_all()
    get_revocation_store().clear_all()
    yield
    app.dependency_overrides.clear()
    get_auth_rate_limiter().clear_all()
    get_revocation_store().clear_all()


class TestSecurityAndAccessControl:

    def test_login_rate_limiting_lockout_on_fifth_failure(self):
        """
        Verify that 5 consecutive failed login attempts trigger lockout,
        and subsequent requests return HTTP 429 Too Many Requests with a valid Retry-After header.
        """
        mock_uow = MagicMock()
        mock_uow.users.find_by_username.return_value = None  # User not found
        app.dependency_overrides[get_uow] = lambda: mock_uow

        # First 5 failed attempts -> HTTP 401
        for _ in range(5):
            res = client.post("/api/v1/auth/login", json={"username": "target_user", "password": "wrong_password"})
            assert res.status_code == 401

        # 6th attempt while locked out -> Triggers lockout HTTP 429
        res6 = client.post("/api/v1/auth/login", json={"username": "target_user", "password": "wrong_password"})
        assert res6.status_code == 429
        data = res6.json()
        assert "Too many failed login attempts" in (data.get("message") or data.get("detail", ""))
        assert "retry-after" in res6.headers
        assert int(res6.headers["retry-after"]) > 0

    def test_login_rate_limiting_reset_on_success(self):
        """
        Verify that a successful login resets the failed attempt counter.
        """
        from datetime import datetime
        from auth.password import hash_password
        mock_uow = MagicMock()
        hashed = hash_password("ValidPassword123")
        valid_user = User(
            id="usr-test-01",
            username="valid_user",
            full_name="Valid Officer",
            role="Credit Officer",
            branch_name="Ikeja",
            password_hash=hashed,
            created_at=datetime.now(),
            branch_id="b-ikeja-uuid",
            is_active=True
        )

        app.dependency_overrides[get_uow] = lambda: mock_uow

        # 3 failed attempts
        mock_uow.users.find_by_username.return_value = None
        for _ in range(3):
            client.post("/api/v1/auth/login", json={"username": "valid_user", "password": "wrong"})

        # Successful login
        mock_uow.users.find_by_username.return_value = valid_user
        res_succ = client.post("/api/v1/auth/login", json={"username": "valid_user", "password": "ValidPassword123"})
        assert res_succ.status_code == 200

        # Verify rate limiter was reset (failures cleared)
        is_locked, _ = get_auth_rate_limiter().is_locked_out("valid_user")
        assert is_locked is False

    def test_explicit_logout_revokes_token_and_invalidates_subsequent_calls(self):
        """
        Verify that calling /api/v1/auth/logout registers the token in TokenRevocationStore,
        causing subsequent API requests with that token to be rejected with HTTP 401.
        """
        token = generate_session_token("usr-test-01", "co_sarah")
        assert validate_session_token(token) is not None

        mock_user = CurrentUser(
            id="usr-test-01",
            username="co_sarah",
            role="CO",
            branch="Ikeja",
            branch_id="b-ikeja-uuid"
        )
        app.dependency_overrides[get_current_user] = lambda: mock_user

        # Call logout
        res_logout = client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert res_logout.status_code == 200
        assert res_logout.json()["success"] is True

        # Verify token is now cryptographically revoked
        assert validate_session_token(token) is None
        assert get_revocation_store().is_token_revoked(token) is True

    def test_admin_revoke_user_sessions_invalidates_all_tokens_for_user(self):
        """
        Verify that an Admin calling /api/v1/users/{user_id}/revoke-sessions
        immediately invalidates all active tokens issued for that user.
        """
        token1 = generate_session_token("usr-victim-01", "compromised_user")
        assert validate_session_token(token1) is not None

        mock_admin = CurrentUser(
            id="usr-admin-01",
            username="super_admin",
            role="Super Admin",
            branch="Head Office",
            branch_id="b-hq-uuid"
        )
        from datetime import datetime
        mock_victim = User(
            id="usr-victim-01",
            username="compromised_user",
            full_name="Compromised Officer",
            role="Credit Officer",
            branch_name="Ikeja",
            password_hash="...",
            created_at=datetime.now(),
            branch_id="b-ikeja-uuid",
            is_active=True
        )

        mock_uow = MagicMock()
        mock_uow.users.find_by_id.return_value = mock_victim

        app.dependency_overrides[get_current_user] = lambda: mock_admin
        app.dependency_overrides[get_uow] = lambda: mock_uow

        res = client.post("/api/v1/users/usr-victim-01/revoke-sessions")
        assert res.status_code == 200
        assert res.json()["success"] is True

        # Victim's previously issued token must now fail validation
        assert validate_session_token(token1) is None

    def test_bm_cross_branch_client_update_approval_rejected(self):
        """
        Verify that a Branch Manager from Branch A cannot approve a client profile update
        belonging to Branch B (fails closed with HTTP 403 Forbidden).
        """
        bm_ikeja = CurrentUser(
            id="usr-bm-ikeja",
            username="bm_ikeja",
            role="Branch Manager",
            branch="Ikeja",
            branch_id="b-ikeja-uuid"
        )

        mock_uow = MagicMock()
        # Mock client update request belonging to Yaba branch
        mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [
            {"branch_id": "b-yaba-uuid", "request_id": "REQ-UPD-YABA-01"}
        ]

        app.dependency_overrides[get_current_user] = lambda: bm_ikeja
        app.dependency_overrides[get_uow] = lambda: mock_uow

        res = client.post("/api/v1/bm/approvals/client-updates/REQ-UPD-YABA-01/approve")
        assert res.status_code == 403
        data = res.json()
        assert "Forbidden" in (data.get("message") or data.get("detail", ""))

    def test_am_unassigned_branch_laps_sweep_rejected(self):
        """
        Verify that an Area Manager attempting to execute automated sweeps on a branch
        outside their assigned supervisory area is rejected with HTTP 403 Forbidden.
        """
        am_lagos = CurrentUser(
            id="usr-am-lagos",
            username="am_lagos",
            role="Area Manager",
            branch="Mainland",
            branch_id="b-mainland-uuid",
            assigned_branches=["Ikeja", "Yaba"],
            assigned_branch_ids=["b-ikeja-uuid", "b-yaba-uuid"]
        )

        mock_uow = MagicMock()
        app.dependency_overrides[get_current_user] = lambda: am_lagos
        app.dependency_overrides[get_uow] = lambda: mock_uow

        # AM attempts to sweep Ibadan branch (outside supervisory scope)
        res = client.post("/api/v1/bm/savings/sweep-laps?branch_id=b-ibadan-uuid")
        assert res.status_code == 403
        data = res.json()
        assert "Forbidden" in (data.get("message") or data.get("detail", ""))

    def test_director_financial_mutation_rejected(self):
        """
        Verify that a Director (strictly executive read-only) is rejected with HTTP 403
        when attempting financial write operations (e.g. loan approval or reversal).
        """
        director_user = CurrentUser(
            id="usr-dir-01",
            username="director_edward",
            role="Director",
            branch="Head Office",
            branch_id="b-hq-uuid"
        )
        app.dependency_overrides[get_current_user] = lambda: director_user

        # Director attempts high-value loan approval
        res = client.post(
            "/api/v1/am/approve-loan",
            json={"loan_id": "L-999", "disbursement_date": "2026-11-02"}
        )
        assert res.status_code == 403
        data = res.json()
        assert "Access forbidden" in (data.get("message") or data.get("detail", ""))

    def test_co_privilege_escalation_to_bm_approval_blocked(self):
        """
        Verify that a Credit Officer cannot invoke BM approval endpoints directly via API.
        """
        co_user = CurrentUser(
            id="usr-co-01",
            username="co_sarah",
            role="Credit Officer",
            branch="Ikeja",
            branch_id="b-ikeja-uuid"
        )
        app.dependency_overrides[get_current_user] = lambda: co_user

        res = client.post(
            "/api/v1/bm/approvals/client-updates/REQ-001/approve"
        )
        assert res.status_code == 403
        data = res.json()
        assert "Access forbidden" in (data.get("message") or data.get("detail", ""))

    def test_security_headers_middleware_present_in_responses(self):
        """
        Verify that SecurityHeadersMiddleware attaches nosniff, DENY, and XSS headers to responses.
        """
        res = client.get("/health")
        assert res.status_code == 200
        assert res.headers.get("x-content-type-options") == "nosniff"
        assert res.headers.get("x-frame-options") == "DENY"
        assert res.headers.get("x-xss-protection") == "1; mode=block"
        assert res.headers.get("referrer-policy") == "strict-origin-when-cross-origin"

    def test_cors_lockdown_blocks_unauthorized_external_origins(self):
        """
        Verify that unauthorized third-party origins are rejected by CORS.
        """
        res = client.options(
            "/api/v1/auth/login",
            headers={
                "Origin": "https://malicious-phishing-site.com",
                "Access-Control-Request-Method": "POST"
            }
        )
        assert res.headers.get("access-control-allow-origin") != "https://malicious-phishing-site.com"
