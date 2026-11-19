"""
tests/test_p2_auth_and_rbac.py
Priority 2 verification suite covering:
1. Durable cross-instance token & user session revocation with fail-closed DB behavior
   and same-second revocation/re-issuance ordering.
2. Session revocation on user deactivation, permanent deletion, and password reset.
3. Strict fail-closed exact role normalization (preventing substring privilege escalation).
4. MFA enforcement after initial password rotation + single-use challenge tokens.
5. Web HttpOnly session cookies, double-submit CSRF verification, /api/v1/auth/me, and logout.
Complies with Strict Zero-Emoji Governance.
"""
from datetime import datetime
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
import pytest
from fastapi.testclient import TestClient

from api.main import app
from api.dependencies import get_uow, get_current_user, require_role, check_branch_access, get_current_scope
from auth.cookies import SESSION_COOKIE_NAME, CSRF_COOKIE_NAME
from auth.mfa import (
    clear_replay_cache,
    generate_mfa_challenge_token,
    generate_totp_code,
    generate_totp_secret,
    validate_mfa_challenge_token,
)
from auth.password import hash_password
from auth.session import (
    generate_password_change_token,
    generate_session_token,
    validate_password_change_token,
    validate_session_token,
)
from auth.session_cache import invalidate_user_session_cache
from auth.token_store import TokenRevocationStore, get_revocation_store
from domain.entities.user import User
from models.user import CurrentUser
from services.rate_limiter import get_auth_rate_limiter
from services.rbac_scope_service import RBACScopeService, UnknownRoleError


client = TestClient(app)


class _FakeTableQuery:
    def __init__(self, rows, on_conflict_key: str, fail_on_read: bool = False):
        self._rows = rows
        self._on_conflict_key = on_conflict_key
        self._fail_on_read = fail_on_read
        self._filters = {}

    def select(self, *_args, **_kwargs):
        return self

    def eq(self, col, val):
        self._filters[col] = val
        return self

    def limit(self, *_args, **_kwargs):
        return self

    def upsert(self, payload, on_conflict=None):
        self._pending_upsert = dict(payload)
        self._pending_conflict = on_conflict or self._on_conflict_key
        return self

    def execute(self):
        if hasattr(self, "_pending_upsert"):
            key_col = self._pending_conflict
            key_val = self._pending_upsert[key_col]
            self._rows[key_val] = dict(self._pending_upsert)
            return SimpleNamespace(data=[self._rows[key_val]])
        if self._fail_on_read:
            raise ConnectionError("Simulated shared database outage")
        results = list(self._rows.values())
        for col, val in self._filters.items():
            results = [r for r in results if r.get(col) == val]
        return SimpleNamespace(data=results)


class _FakeSharedSupabase:
    def __init__(self):
        self.tables = {
            "revoked_tokens": {},
            "user_session_revocations": {},
        }
        self.fail_on_read = False

    def table(self, name: str):
        pk = "token_hash" if name == "revoked_tokens" else "user_id"
        return _FakeTableQuery(self.tables[name], pk, fail_on_read=self.fail_on_read)


@pytest.fixture(autouse=True)
def clean_p2_state():
    app.dependency_overrides.clear()
    get_auth_rate_limiter().clear_all()
    get_revocation_store().clear_all()
    clear_replay_cache()
    invalidate_user_session_cache()
    yield
    app.dependency_overrides.clear()
    get_auth_rate_limiter().clear_all()
    get_revocation_store().clear_all()
    clear_replay_cache()
    invalidate_user_session_cache()


class TestDurableTokenRevocation:

    def test_token_and_user_revocation_shared_across_instances_and_restarts(self):
        shared_db = _FakeSharedSupabase()
        instance_a = TokenRevocationStore(client_provider=lambda: shared_db)
        instance_b = TokenRevocationStore(client_provider=lambda: shared_db)

        token_1 = generate_session_token("usr-shared-1", "co_ada")
        instance_a.revoke_token(token_1, ttl_seconds=3600, user_id="usr-shared-1")

        # Instance B starts with empty L1 cache and still detects the revocation
        assert instance_b.is_token_revoked(token_1) is True

        # User-wide revocation on Instance A invalidates prior tokens on Instance B
        instance_a.revoke_user_sessions("usr-shared-2")
        assert instance_b.is_user_revoked("usr-shared-2", float(int(datetime.now().timestamp()))) is True

        # Simulating same-second issuance after user-level revocation via global store
        shared_store = get_revocation_store()
        with patch.object(shared_store, "_is_persistence_enabled", return_value=True), \
             patch.object(shared_store, "_get_client", return_value=shared_db):
            prior_tok = generate_session_token("usr-race-1", "bm_race")
            assert validate_session_token(prior_tok) is not None

            shared_store.revoke_user_sessions("usr-race-1")
            assert validate_session_token(prior_tok) is None

            fresh_tok = generate_session_token("usr-race-1", "bm_race")
            parsed_fresh = validate_session_token(fresh_tok)
            assert parsed_fresh is not None
            assert isinstance(parsed_fresh["timestamp"], int)
            assert validate_session_token(prior_tok) is None

    def test_revocation_lookup_fails_closed_when_shared_db_unavailable(self):
        shared_db = _FakeSharedSupabase()
        store = TokenRevocationStore(client_provider=lambda: shared_db)
        shared_db.fail_on_read = True

        assert store.is_token_revoked("some-unexpired-looking-token") is True
        assert store.is_user_revoked("usr-123", float(datetime.now().timestamp())) is True

    def test_deactivation_deletion_and_password_reset_revoke_target_sessions(self):
        admin_user = CurrentUser(
            id="usr-admin-1",
            username="admin_root",
            role="Super Admin",
            branch="Head Office",
            branch_id="b-hq",
        )
        target_tok_1 = generate_session_token("usr-target-1", "co_target")
        assert validate_session_token(target_tok_1) is not None

        app.dependency_overrides[get_current_user] = lambda: admin_user

        with patch("api.routes.users.UserService.deactivate_user", return_value={
            "success": True,
            "message": "User deactivated.",
            "user_id": "usr-target-1",
            "username": "co_target",
        }):
            res_deact = client.post("/api/v1/users/usr-target-1/status", json={"activate": False})
        assert res_deact.status_code == 200
        assert validate_session_token(target_tok_1) is None

        target_tok_2 = generate_session_token("usr-target-2", "co_target_2")
        assert validate_session_token(target_tok_2) is not None
        mock_uow = MagicMock()
        mock_uow.users.find_by_username.return_value = SimpleNamespace(id="usr-target-2", username="co_target_2")
        app.dependency_overrides[get_uow] = lambda: mock_uow
        with patch("api.routes.users.UserService.reset_password", return_value={
            "success": True,
            "message": "Password reset.",
            "user_id": "usr-target-2",
            "username": "co_target_2",
        }):
            res_reset = client.post(
                "/api/v1/users/password-reset",
                json={"username": "co_target_2", "new_password": "NewSecurePassword1!"},
            )
        assert res_reset.status_code == 200
        assert validate_session_token(target_tok_2) is None

        target_tok_3 = generate_session_token("usr-target-3", "co_target_3")
        assert validate_session_token(target_tok_3) is not None
        with patch("api.routes.users.UserService.remove_user_permanently", return_value={
            "success": True,
            "message": "User deleted.",
            "user_id": "usr-target-3",
            "username": "co_target_3",
        }):
            res_del = client.delete("/api/v1/users/usr-target-3")
        assert res_del.status_code == 200
        assert validate_session_token(target_tok_3) is None


class TestStrictRoleNormalization:

    @pytest.mark.parametrize("bad_role", [
        "FAKE_ADMIN",
        "SHADOW_ADMIN_TEST",
        "NOT_A_BRANCH_USER",
        "EXTERNAL_MANAGER",
        "Guest",
        "",
        None,
    ])
    def test_unknown_roles_fail_closed_across_helpers(self, bad_role):
        with pytest.raises(UnknownRoleError):
            RBACScopeService.normalize_role(bad_role)

        bad_user = CurrentUser(
            id="usr-bad-role",
            username="bad_role_user",
            role=bad_role if bad_role is not None else "",
            branch="Ikeja",
            branch_id="b-ikeja",
        )
        with pytest.raises(Exception) as scope_exc:
            get_current_scope(bad_user)
        assert getattr(scope_exc.value, "status_code", None) == 403

        checker = require_role(["CO", "Admin"])
        with pytest.raises(Exception) as role_exc:
            checker(bad_user)
        assert getattr(role_exc.value, "status_code", None) == 403

        with pytest.raises(Exception) as branch_exc:
            check_branch_access(bad_user, "b-ikeja", "access branch records")
        assert getattr(branch_exc.value, "status_code", None) == 403

    def test_login_rejects_unrecognized_role_with_403(self):
        mock_uow = MagicMock()
        mock_uow.users.find_by_username.return_value = User(
            id="usr-rogue",
            username="rogue_admin_str",
            full_name="Rogue Substring",
            role="SHADOW_ADMIN_TEST",
            branch_name="Ikeja",
            password_hash=hash_password("ValidPass123!"),
            created_at=datetime.now(),
            branch_id="b-ikeja",
            is_active=True,
        )
        app.dependency_overrides[get_uow] = lambda: mock_uow

        res = client.post("/api/v1/auth/login", json={"username": "rogue_admin_str", "password": "ValidPass123!"})
        assert res.status_code == 403

    def test_account_manager_and_accountant_map_explicitly_without_admin_elevation(self):
        assert RBACScopeService.normalize_role("Account Manager") == "Account Manager"
        assert RBACScopeService.normalize_role("Accountant") == "Account Manager"
        scope = RBACScopeService.resolve_scope({
            "id": "usr-acct-1",
            "username": "acct_ikeja",
            "role": "Accountant",
            "branch": "Ikeja",
            "branch_id": "b-ikeja",
        })
        assert scope.role == "Account Manager"
        assert scope.scope_level == "BRANCH"

        acct_user = CurrentUser(
            id="usr-acct-1",
            username="acct_ikeja",
            role="Account Manager",
            branch="Ikeja",
            branch_id="b-ikeja",
        )
        check_branch_access(acct_user, "b-ikeja", "view branch report")
        with pytest.raises(Exception) as cross_exc:
            check_branch_access(acct_user, "b-yaba", "view branch report")
        assert getattr(cross_exc.value, "status_code", None) == 403


class TestMfaAfterPasswordChangeAndSingleUseTokens:

    def test_change_initial_password_with_mfa_enabled_requires_mfa_and_consumes_tokens(self):
        secret = generate_totp_secret()
        old_hashed = hash_password("DefaultBM2026!")
        bm_user = User(
            id="usr-bm-mfa-1",
            username="bm_mfa_user",
            full_name="BM With MFA",
            role="Branch Manager",
            branch_name="Ikeja",
            password_hash=old_hashed,
            created_at=datetime.now(),
            branch_id="b-ikeja",
            is_active=True,
            extra_fields={
                "must_change_password": True,
                "mfa_enabled": True,
                "mfa_secret": secret,
                "mfa_backup_codes": [],
            },
        )
        mock_uow = MagicMock()
        mock_uow.users.find_by_id.return_value = bm_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        temp_token = generate_password_change_token(bm_user.id, bm_user.username)
        res = client.post(
            "/api/v1/auth/change-initial-password",
            json={
                "temp_token": temp_token,
                "current_password": "DefaultBM2026!",
                "new_password": "StrongRotatedPassword2026!",
            },
        )
        assert res.status_code == 200
        body = res.json()
        assert body["access_token"] is None
        assert body["mfa_required"] is True
        assert body["mfa_token"] is not None
        assert SESSION_COOKIE_NAME not in res.cookies

        # Consumed temp_token cannot be replayed
        assert validate_password_change_token(temp_token) is None
        res_replay_temp = client.post(
            "/api/v1/auth/change-initial-password",
            json={
                "temp_token": temp_token,
                "current_password": "DefaultBM2026!",
                "new_password": "AnotherPassword2026!",
            },
        )
        assert res_replay_temp.status_code == 401

        # Complete MFA challenge
        mfa_token = body["mfa_token"]
        totp = generate_totp_code(secret)
        res_mfa = client.post(
            "/api/v1/auth/mfa/challenge",
            json={"mfa_token": mfa_token, "code": totp},
        )
        assert res_mfa.status_code == 200
        mfa_body = res_mfa.json()
        assert mfa_body["access_token"] is not None
        assert mfa_body["mfa_required"] is False

        # Consumed mfa_token cannot be replayed
        assert validate_mfa_challenge_token(mfa_token) is None
        res_replay_mfa = client.post(
            "/api/v1/auth/mfa/challenge",
            json={"mfa_token": mfa_token, "code": totp},
        )
        assert res_replay_mfa.status_code == 401

        assert generate_mfa_challenge_token("u", "u") is not None


class TestWebCookieAuthAndCsrfProtection:

    def test_cookie_login_me_csrf_enforcement_and_logout_revocation(self):
        co_user = User(
            id="usr-web-co-1",
            username="web_co_1",
            full_name="Web Officer",
            role="Credit Officer",
            branch_name="Ikeja",
            password_hash=hash_password("WebPass123!"),
            created_at=datetime.now(),
            branch_id="b-ikeja",
            is_active=True,
        )
        mock_uow = MagicMock()
        mock_uow.users.find_by_username.return_value = co_user
        mock_uow.users.find_by_id.return_value = co_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        # 1. Production HTTPS login under cookie mode sets HttpOnly; Secure; SameSite=none and omits access_token
        https_client = TestClient(app)
        res_https = https_client.post(
            "/api/v1/auth/login",
            json={"username": "web_co_1", "password": "WebPass123!"},
            headers={"X-Auth-Mode": "cookie", "X-Forwarded-Proto": "https"},
        )
        assert res_https.status_code == 200
        https_data = res_https.json()
        assert https_data["access_token"] is None
        assert https_data["csrf_token"]
        assert https_data["user"]["username"] == "web_co_1"
        set_cookie_headers = [v for k, v in res_https.headers.raw if k.lower() == b"set-cookie"]
        session_header = next(h.decode() for h in set_cookie_headers if SESSION_COOKIE_NAME.encode() in h)
        assert "HttpOnly" in session_header
        assert "Secure" in session_header
        assert "samesite=none" in session_header.lower()

        # 2. HTTP localhost cookie login works with TestClient cookie jar
        web_client = TestClient(app)
        res_login = web_client.post(
            "/api/v1/auth/login",
            json={"username": "web_co_1", "password": "WebPass123!"},
            headers={"X-Auth-Mode": "cookie"},
        )
        assert res_login.status_code == 200
        login_body = res_login.json()
        csrf_token = login_body["csrf_token"]
        assert login_body["access_token"] is None
        assert csrf_token
        assert SESSION_COOKIE_NAME in web_client.cookies
        assert CSRF_COOKIE_NAME in web_client.cookies

        # 3. GET /api/v1/auth/me restores session from HttpOnly cookie
        res_me = web_client.get("/api/v1/auth/me")
        assert res_me.status_code == 200
        me_body = res_me.json()
        assert me_body["authenticated"] is True
        assert me_body["user"]["username"] == "web_co_1"
        assert me_body["csrf_token"] == csrf_token

        # 4. Mutating cookie request WITHOUT X-CSRF-Token or with mismatch fails 403
        res_no_csrf = web_client.post("/api/v1/auth/logout")
        assert res_no_csrf.status_code == 403

        res_bad_csrf = web_client.post(
            "/api/v1/auth/logout",
            headers={"X-CSRF-Token": "wrong-csrf-token"},
        )
        assert res_bad_csrf.status_code == 403

        # Capture raw cookie value to prove revocation even if client replays stale cookie after clearing
        stale_session_cookie = web_client.cookies.get(SESSION_COOKIE_NAME)

        # 5. Mutating cookie request WITH matching X-CSRF-Token succeeds
        res_logout = web_client.post(
            "/api/v1/auth/logout",
            headers={"X-CSRF-Token": csrf_token},
        )
        assert res_logout.status_code == 200
        assert res_logout.json()["success"] is True

        # 6. Stale cookie replay after logout fails with 401
        stale_client = TestClient(app)
        stale_client.cookies.set(SESSION_COOKIE_NAME, stale_session_cookie)
        res_stale = stale_client.get("/api/v1/auth/me")
        assert res_stale.status_code == 401

        # 7. Bearer-authenticated POST (mobile APK / API) works without CSRF header
        mobile_client = TestClient(app)
        res_mobile_login = mobile_client.post(
            "/api/v1/auth/login",
            json={"username": "web_co_1", "password": "WebPass123!"},
        )
        assert res_mobile_login.status_code == 200
        mobile_token = res_mobile_login.json()["access_token"]
        assert mobile_token is not None

        res_mobile_logout = mobile_client.post(
            "/api/v1/auth/logout",
            headers={"Authorization": f"Bearer {mobile_token}"},
        )
        assert res_mobile_logout.status_code == 200
