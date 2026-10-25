"""
tests/test_auth_remediation.py
Verification test suite for Phase 1 Authentication and Onboarding Security Remediation.

Covers:
1. HMAC secret resolution (valid, missing, empty, whitespace-only, whitespace-stripping).
2. Module-level dynamic SECRET_KEY resolution without hardcoded fallback.
3. Token generation, HMAC signature validation, and tamper resistance.
4. Token rejection with signature from different secret.
5. Token rejection when payload is tampered with.
6. Token rejection when expired (> 7 days sliding window).
7. Token rejection on malformed inputs.
8. Application startup verification fails closed when secret is missing.
9. Onboarding /am-review unauthenticated rejection (401).
10. Onboarding /am-review invalid or forged token rejection (401).
11. Onboarding /am-review unauthorized role rejection (403 for CO, BM).
12. Onboarding /am-review Area Manager unassigned branch rejection (403).
13. Onboarding /am-review Area Manager assigned branch allowed (200).
14. Onboarding /am-review Admin allowed across all branches (200).
15. Onboarding /am-approve unauthenticated rejection (401).
16. Onboarding /am-approve unauthorized role rejection (403 for CO, BM).
17. Onboarding /am-approve Area Manager unassigned branch rejection (403).
18. Legitimate Credit Officer workflow preservation (non-regression).
"""
import os
import hmac
import hashlib
import base64
from datetime import datetime, timedelta
import pytest
from fastapi.testclient import TestClient

import auth.session as auth_session
from auth.session import (
    get_auth_secret,
    generate_session_token,
    validate_session_token,
    SESSION_TIMEOUT_MINUTES
)
from api.main import app, verify_security_configuration
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.onboarding_service import OnboardingService


@pytest.fixture(scope="module")
def client():
    return TestClient(app)


@pytest.fixture
def uow():
    with SupabaseUnitOfWork() as unit:
        yield unit


@pytest.fixture
def test_secrets():
    return {
        "primary": "test-primary-secret-key-32bytes-secure-hash",
        "secondary": "test-secondary-secret-key-32bytes-alt-hash"
    }


# ============================================================================
# 1. HMAC SECRET RESOLUTION AND CONFIGURATION TESTS
# ============================================================================

def test_get_auth_secret_valid(monkeypatch, test_secrets):
    """Verifies that a valid secret string is returned exactly."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["primary"])
    assert get_auth_secret() == test_secrets["primary"]


def test_get_auth_secret_strips_surrounding_whitespace(monkeypatch, test_secrets):
    """Verifies that surrounding whitespace is stripped from configured secret."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", f"   {test_secrets['primary']}   \n")
    assert get_auth_secret() == test_secrets["primary"]


def test_get_auth_secret_fails_closed_when_missing(monkeypatch):
    """Verifies that get_auth_secret raises RuntimeError when environment variable is missing."""
    monkeypatch.delenv("ICARE_AUTH_SECRET", raising=False)
    with pytest.raises(RuntimeError) as exc_info:
        get_auth_secret()
    assert "CRITICAL SECURITY CONFIGURATION ERROR" in str(exc_info.value)
    assert "'ICARE_AUTH_SECRET'" in str(exc_info.value)


def test_get_auth_secret_fails_closed_when_empty(monkeypatch):
    """Verifies that get_auth_secret raises RuntimeError when empty."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", "")
    with pytest.raises(RuntimeError) as exc_info:
        get_auth_secret()
    assert "CRITICAL SECURITY CONFIGURATION ERROR" in str(exc_info.value)


def test_get_auth_secret_fails_closed_when_whitespace_only(monkeypatch):
    """Verifies that get_auth_secret raises RuntimeError when whitespace only."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", "   \t\n  ")
    with pytest.raises(RuntimeError) as exc_info:
        get_auth_secret()
    assert "CRITICAL SECURITY CONFIGURATION ERROR" in str(exc_info.value)


def test_module_getattr_secret_key_dynamic_resolution(monkeypatch, test_secrets):
    """Verifies that accessing auth_session.SECRET_KEY dynamically resolves without fallback."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["primary"])
    assert auth_session.SECRET_KEY == test_secrets["primary"]

    monkeypatch.delenv("ICARE_AUTH_SECRET", raising=False)
    with pytest.raises(RuntimeError):
        _ = auth_session.SECRET_KEY


# ============================================================================
# 2. TOKEN GENERATION, VALIDATION, AND TAMPER RESISTANCE TESTS
# ============================================================================

def test_token_generation_and_validation_roundtrip(monkeypatch, test_secrets):
    """Verifies valid token issuance and payload extraction."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["primary"])
    user_id = "u-001"
    username = "teller_one"

    token = generate_session_token(user_id, username)
    assert isinstance(token, str) and len(token) > 0

    token_data = validate_session_token(token)
    assert token_data is not None
    assert token_data["user_id"] == user_id
    assert token_data["username"] == username
    assert isinstance(token_data["timestamp"], int)


def test_token_rejection_different_signing_secret(monkeypatch, test_secrets):
    """Verifies that a token signed with Secret A is rejected when evaluated with Secret B."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["primary"])
    token = generate_session_token("u-002", "branch_mgr")

    # Switch to different secret
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["secondary"])
    assert validate_session_token(token) is None


def test_token_rejection_tampered_payload(monkeypatch, test_secrets):
    """Verifies that tampering with payload parameters invalidates HMAC signature."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["primary"])
    token = generate_session_token("u-003", "regular_user")

    raw_bytes = base64.urlsafe_b64decode(token.encode("utf-8"))
    raw_str = raw_bytes.decode("utf-8")
    parts = raw_str.split(":")
    assert len(parts) == 4

    # Tamper with username
    tampered_str = f"{parts[0]}:admin_super:{parts[2]}:{parts[3]}"
    tampered_token = base64.urlsafe_b64encode(tampered_str.encode("utf-8")).decode("utf-8")

    assert validate_session_token(tampered_token) is None


def test_token_rejection_expired_window(monkeypatch, test_secrets):
    """Verifies that tokens older than 7 days (SESSION_TIMEOUT_MINUTES) are rejected."""
    secret = test_secrets["primary"]
    monkeypatch.setenv("ICARE_AUTH_SECRET", secret)

    expired_ts = int(datetime.now().timestamp()) - (SESSION_TIMEOUT_MINUTES * 60 + 600)
    payload_str = f"u-004:old_session:{expired_ts}"
    sig = hmac.new(secret.encode("utf-8"), payload_str.encode("utf-8"), hashlib.sha256).hexdigest()
    raw_token = f"{payload_str}:{sig}"
    expired_token = base64.urlsafe_b64encode(raw_token.encode("utf-8")).decode("utf-8")

    assert validate_session_token(expired_token) is None


def test_token_rejection_future_clock_skew(monkeypatch, test_secrets):
    """Verifies that tokens with excessive future timestamps (> 300 seconds) are rejected."""
    secret = test_secrets["primary"]
    monkeypatch.setenv("ICARE_AUTH_SECRET", secret)

    future_ts = int(datetime.now().timestamp()) + 600
    payload_str = f"u-005:future_user:{future_ts}"
    sig = hmac.new(secret.encode("utf-8"), payload_str.encode("utf-8"), hashlib.sha256).hexdigest()
    raw_token = f"{payload_str}:{sig}"
    future_token = base64.urlsafe_b64encode(raw_token.encode("utf-8")).decode("utf-8")

    assert validate_session_token(future_token) is None


def test_token_rejection_malformed_inputs(monkeypatch, test_secrets):
    """Verifies that malformed, corrupted, or non-base64 tokens fail safely with None."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["primary"])
    assert validate_session_token("") is None
    assert validate_session_token(None) is None
    assert validate_session_token("not-valid-base64!@#$") is None
    assert validate_session_token(base64.urlsafe_b64encode(b"invalid:parts:only").decode("utf-8")) is None
    assert validate_session_token(base64.urlsafe_b64encode(b"u:user:non_int_ts:sig").decode("utf-8")) is None


# ============================================================================
# 3. FASTAPI STARTUP HOOK VERIFICATION
# ============================================================================

def test_startup_verification_fails_closed_when_secret_unset(monkeypatch):
    """Verifies FastAPI startup event handler aborts startup if secret is not configured."""
    monkeypatch.delenv("ICARE_AUTH_SECRET", raising=False)
    with pytest.raises(RuntimeError) as exc_info:
        verify_security_configuration()
    assert "CRITICAL SECURITY CONFIGURATION ERROR" in str(exc_info.value)


def test_startup_verification_succeeds_when_secret_configured(monkeypatch, test_secrets):
    """Verifies FastAPI startup event handler passes cleanly when secret is configured."""
    monkeypatch.setenv("ICARE_AUTH_SECRET", test_secrets["primary"])
    verify_security_configuration()


# ============================================================================
# 4. ONBOARDING AUTHORIZATION AND MULTI-BRANCH ACCESS TESTS
# ============================================================================

@pytest.fixture
def onboarding_test_sessions(uow):
    """
    Creates temporary onboarding sessions for test verification:
    1. Assigned branch session (Ogijo - within Area 1)
    2. Unassigned branch session (Ibadan - outside Area 1)
    """
    clean_code_assigned = f"TOG{int(datetime.now().timestamp()) % 10000}"
    clean_code_unassigned = f"TIB{int(datetime.now().timestamp()) % 10000}"

    sess_assigned = OnboardingService.create_session(
        uow=uow,
        branch_name="Ogijo",
        branch_code=clean_code_assigned,
        contact_person="Ogijo Tester"
    )
    sess_unassigned = OnboardingService.create_session(
        uow=uow,
        branch_name="Ibadan",
        branch_code=clean_code_unassigned,
        contact_person="Ibadan Tester"
    )

    yield {
        "assigned": sess_assigned,
        "unassigned": sess_unassigned
    }

    # Cleanup
    try:
        uow.client.table("branch_onboarding_sessions").delete().eq("token", sess_assigned["token"]).execute()
        uow.client.table("branch_onboarding_sessions").delete().eq("token", sess_unassigned["token"]).execute()
    except Exception:
        pass


def test_onboarding_am_review_unauthenticated_rejected(client, onboarding_test_sessions):
    """Verifies GET /am-review rejects unauthenticated requests with HTTP 401."""
    token = onboarding_test_sessions["assigned"]["token"]
    res = client.get(f"/api/v1/onboarding/session/{token}/am-review")
    assert res.status_code == 401
    assert "Authentication token required" in res.text or "401" in str(res.status_code)


def test_onboarding_am_review_invalid_token_rejected(client, onboarding_test_sessions):
    """Verifies GET /am-review rejects invalid tokens with HTTP 401."""
    token = onboarding_test_sessions["assigned"]["token"]
    res = client.get(
        f"/api/v1/onboarding/session/{token}/am-review",
        headers={"Authorization": "Bearer invalid_garbled_token_string"}
    )
    assert res.status_code == 401


def test_onboarding_am_review_unauthorized_role_rejected(client, uow, onboarding_test_sessions):
    """Verifies GET /am-review rejects Credit Officer and Branch Manager with HTTP 403."""
    co_user = uow.users.find_by_username("OGI_CO1")
    assert co_user is not None
    co_token = generate_session_token(co_user.id, co_user.username)

    bm_user = uow.users.find_by_username("BM_Ogijo")
    assert bm_user is not None
    bm_token = generate_session_token(bm_user.id, bm_user.username)

    token = onboarding_test_sessions["assigned"]["token"]

    # Credit Officer rejected
    res_co = client.get(
        f"/api/v1/onboarding/session/{token}/am-review",
        headers={"Authorization": f"Bearer {co_token}"}
    )
    assert res_co.status_code == 403
    assert "is not authorized" in res_co.text or "Access forbidden" in res_co.text

    # Branch Manager rejected
    res_bm = client.get(
        f"/api/v1/onboarding/session/{token}/am-review",
        headers={"Authorization": f"Bearer {bm_token}"}
    )
    assert res_bm.status_code == 403
    assert "is not authorized" in res_bm.text or "Access forbidden" in res_bm.text


def test_onboarding_am_review_am_unassigned_branch_forbidden(client, uow, onboarding_test_sessions):
    """Verifies Area Manager cannot review onboarding for branch outside supervisory scope."""
    am_user = uow.users.find_by_username("AM_Area_1")
    assert am_user is not None
    am_token = generate_session_token(am_user.id, am_user.username)

    unassigned_token = onboarding_test_sessions["unassigned"]["token"]

    res = client.get(
        f"/api/v1/onboarding/session/{unassigned_token}/am-review",
        headers={"Authorization": f"Bearer {am_token}"}
    )
    assert res.status_code == 403
    assert "outside your supervisory area" in res.text


def test_onboarding_am_review_am_assigned_branch_allowed(client, uow, onboarding_test_sessions):
    """Verifies Area Manager can inspect onboarding for branch within supervisory scope."""
    am_user = uow.users.find_by_username("AM_Area_1")
    assert am_user is not None
    am_token = generate_session_token(am_user.id, am_user.username)

    assigned_token = onboarding_test_sessions["assigned"]["token"]

    res = client.get(
        f"/api/v1/onboarding/session/{assigned_token}/am-review",
        headers={"Authorization": f"Bearer {am_token}"}
    )
    assert res.status_code == 200
    res_data = res.json()
    assert res_data.get("session", {}).get("token") == assigned_token or res_data.get("token") == assigned_token


def test_onboarding_am_review_admin_allowed_any_branch(client, uow, onboarding_test_sessions):
    """Verifies Admin has institution-wide review access across any branch."""
    admin_user = uow.users.find_by_username("Admin") or uow.users.find_by_username("admin")
    assert admin_user is not None
    admin_token = generate_session_token(admin_user.id, admin_user.username)

    unassigned_token = onboarding_test_sessions["unassigned"]["token"]

    res = client.get(
        f"/api/v1/onboarding/session/{unassigned_token}/am-review",
        headers={"Authorization": f"Bearer {admin_token}"}
    )
    assert res.status_code == 200


def test_onboarding_am_approve_unauthenticated_rejected(client, onboarding_test_sessions):
    """Verifies POST /am-approve rejects unauthenticated requests with HTTP 401."""
    token = onboarding_test_sessions["assigned"]["token"]
    res = client.post(f"/api/v1/onboarding/session/{token}/am-approve")
    assert res.status_code == 401


def test_onboarding_am_approve_unauthorized_role_rejected(client, uow, onboarding_test_sessions):
    """Verifies POST /am-approve rejects non-AM/Admin roles with HTTP 403."""
    co_user = uow.users.find_by_username("OGI_CO1")
    assert co_user is not None
    co_token = generate_session_token(co_user.id, co_user.username)

    token = onboarding_test_sessions["assigned"]["token"]
    res = client.post(
        f"/api/v1/onboarding/session/{token}/am-approve",
        headers={"Authorization": f"Bearer {co_token}"}
    )
    assert res.status_code == 403


def test_onboarding_am_approve_am_unassigned_branch_forbidden(client, uow, onboarding_test_sessions):
    """Verifies Area Manager cannot approve onboarding for branch outside supervisory scope."""
    am_user = uow.users.find_by_username("AM_Area_1")
    assert am_user is not None
    am_token = generate_session_token(am_user.id, am_user.username)

    unassigned_token = onboarding_test_sessions["unassigned"]["token"]

    res = client.post(
        f"/api/v1/onboarding/session/{unassigned_token}/am-approve",
        headers={"Authorization": f"Bearer {am_token}"}
    )
    assert res.status_code == 403
    assert "outside your supervisory area" in res.text


# ============================================================================
# 5. LEGITIMATE CREDIT OFFICER WORKFLOW PRESERVATION
# ============================================================================

def test_legitimate_credit_officer_flow_preserved(client, uow):
    """Verifies that legitimate Credit Officer authentication and endpoint access remains fully functional."""
    co_user = uow.users.find_by_username("OGI_CO1")
    assert co_user is not None

    token = generate_session_token(co_user.id, co_user.username)
    res = client.get("/api/v1/co/dashboard", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 200
    data = res.json()
    assert "welcome" in data
    assert data["welcome"]["officer_name"] == "OGI_CO1"
