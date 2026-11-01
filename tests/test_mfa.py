"""
Automated Test Suite for RFC 6238 Multi-Factor Authentication (MFA) & API Endpoints.
Complies with Strict Zero-Emoji Governance.
"""
import base64
import os
import uuid
import time
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from api.main import app
from api.dependencies import get_uow, get_current_user
from auth.mfa import (
    generate_totp_secret,
    generate_totp_code,
    verify_totp_code,
    generate_backup_codes,
    hash_backup_code,
    verify_and_consume_backup_code,
    generate_otpauth_uri,
    generate_mfa_challenge_token,
    validate_mfa_challenge_token,
    clear_replay_cache,
)
from auth.password import hash_password
from domain.entities.user import User
from models.user import CurrentUser


client = TestClient(app)


@pytest.fixture(autouse=True)
def cleanup_mfa_state():
    """Ensures clean dependency overrides and replay cache for each test."""
    app.dependency_overrides.clear()
    clear_replay_cache()
    yield
    app.dependency_overrides.clear()
    clear_replay_cache()


# -----------------------------------------------------------------------------
# 1. Pure RFC 6238 Algorithmic Tests (Standard Appendix B Test Vectors)
# -----------------------------------------------------------------------------

def test_rfc6238_standard_test_vectors():
    """Verifies TOTP computation matches exact RFC 6238 Appendix B test vectors."""
    # RFC 6238 Appendix B secret: "12345678901234567890" in Base32
    secret_bytes = b"12345678901234567890"
    secret_b32 = base64.b32encode(secret_bytes).decode("utf-8")

    assert generate_totp_code(secret_b32, timestamp=59) == "287082"
    assert generate_totp_code(secret_b32, timestamp=1111111109) == "081804"
    assert generate_totp_code(secret_b32, timestamp=1111111111) == "050471"
    assert generate_totp_code(secret_b32, timestamp=1234567890) == "005924"
    assert generate_totp_code(secret_b32, timestamp=2000000000) == "279037"


def test_secret_generation_and_uri():
    """Verifies cryptographically secure secret generation and otpauth URI formatting."""
    secret = generate_totp_secret()
    assert len(secret) >= 32
    # Verify it is valid Base32
    raw = base64.b32decode(secret + "=" * ((8 - len(secret) % 8) % 8), casefold=True)
    assert len(raw) == 20

    uri = generate_otpauth_uri("test.user", secret, issuer="ICARE Core Banking")
    assert uri.startswith("otpauth://totp/ICARE%20Core%20Banking%3Atest.user")
    assert f"secret={secret}" in uri
    assert "algorithm=SHA1" in uri
    assert "digits=6" in uri
    assert "period=30" in uri


def test_totp_verification_window_and_drift():
    """Verifies verification window handles +/- 30s clock drift and rejects beyond."""
    secret = generate_totp_secret()
    now = 1700000000.0

    current_code = generate_totp_code(secret, timestamp=now)
    past_code = generate_totp_code(secret, timestamp=now - 30.0)
    future_code = generate_totp_code(secret, timestamp=now + 30.0)
    far_past_code = generate_totp_code(secret, timestamp=now - 90.0)

    # Current, past (-30s), and future (+30s) are valid under window=1
    assert verify_totp_code(secret, current_code, window=1, timestamp=now) is True
    assert verify_totp_code(secret, past_code, window=1, timestamp=now) is True
    assert verify_totp_code(secret, future_code, window=1, timestamp=now) is True

    # Far past (-90s) is outside window=1
    assert verify_totp_code(secret, far_past_code, window=1, timestamp=now) is False

    # Invalid formats
    assert verify_totp_code(secret, "abc123", window=1, timestamp=now) is False
    assert verify_totp_code(secret, "12345", window=1, timestamp=now) is False
    assert verify_totp_code(secret, "1234567", window=1, timestamp=now) is False
    assert verify_totp_code(secret, "", window=1, timestamp=now) is False


def test_replay_protection():
    """Verifies that an authentic TOTP code cannot be replayed within the same time window."""
    clear_replay_cache()
    secret = generate_totp_secret()
    user_id = str(uuid.uuid4())
    now = 1700000050.0
    code = generate_totp_code(secret, timestamp=now)

    # First consumption succeeds
    assert verify_totp_code(secret, code, window=1, timestamp=now, user_id=user_id) is True

    # Immediate replay with same user_id fails
    assert verify_totp_code(secret, code, window=1, timestamp=now, user_id=user_id) is False

    # Another user is not blocked
    other_user_id = str(uuid.uuid4())
    assert verify_totp_code(secret, code, window=1, timestamp=now, user_id=other_user_id) is True


# -----------------------------------------------------------------------------
# 2. Backup Recovery Codes Tests
# -----------------------------------------------------------------------------

def test_backup_codes_generation_and_consumption():
    """Verifies generation, hashing, and single-use consumption of recovery backup codes."""
    codes = generate_backup_codes(count=8)
    assert len(codes) == 8
    for c in codes:
        assert len(c) == 9  # XXXX-XXXX
        assert "-" in c

    hashed_codes = [hash_backup_code(c) for c in codes]
    first_code = codes[0]

    # Valid consumption
    matched, remaining = verify_and_consume_backup_code(first_code, hashed_codes)
    assert matched is True
    assert len(remaining) == 7

    # Attempt to consume the same code again fails
    matched_again, remaining_again = verify_and_consume_backup_code(first_code, remaining)
    assert matched_again is False
    assert len(remaining_again) == 7

    # Invalid code fails
    invalid_match, _ = verify_and_consume_backup_code("XXXX-YYYY", remaining)
    assert invalid_match is False


# -----------------------------------------------------------------------------
# 3. MFA Challenge Token Tests
# -----------------------------------------------------------------------------

def test_mfa_challenge_tokens():
    """Verifies creation and validation of temporary MFA challenge tokens."""
    user_id = str(uuid.uuid4())
    username = "supervisor.mfa"

    token = generate_mfa_challenge_token(user_id, username, expires_in_seconds=300)
    assert token is not None

    validated = validate_mfa_challenge_token(token)
    assert validated is not None
    assert validated["user_id"] == user_id
    assert validated["username"] == username

    # Expired token rejected
    expired_token = generate_mfa_challenge_token(user_id, username, expires_in_seconds=-10)
    assert validate_mfa_challenge_token(expired_token) is None

    # Tampered token rejected
    tampered = token[:-4] + "AAAA"
    assert validate_mfa_challenge_token(tampered) is None


# -----------------------------------------------------------------------------
# 4. MFA API Endpoints Integration Tests
# -----------------------------------------------------------------------------

def _make_mock_user(
    username="test_supervisor",
    role="Branch Manager",
    mfa_enabled=False,
    mfa_secret="",
    mfa_backup_codes=None,
    mfa_pending=None
):
    extra = {}
    if mfa_enabled:
        extra["mfa_enabled"] = True
        extra["mfa_secret"] = mfa_secret
        extra["mfa_backup_codes"] = mfa_backup_codes or []
        extra["mfa_enrolled_at"] = "2026-11-01T12:00:00"
    if mfa_pending:
        extra["mfa_pending"] = mfa_pending

    return User(
        id=str(uuid.uuid4()),
        username=username,
        full_name="Test Supervisor",
        role=role,
        branch_name="Main Branch",
        branch_id=str(uuid.uuid4()),
        password_hash=hash_password("SuperSecretPass123"),
        created_at=None,
        is_active=True,
        extra_fields=extra,
    )


@patch("api.routes.auth.AuditLogService")
def test_login_flow_without_mfa(mock_audit):
    """Verifies regular login without MFA returns full session token immediately."""
    mock_uow = MagicMock()
    mock_user = _make_mock_user(mfa_enabled=False)
    mock_uow.users.find_by_username.return_value = mock_user
    app.dependency_overrides[get_uow] = lambda: mock_uow

    resp = client.post(
        "/api/v1/auth/login",
        json={"username": "test_supervisor", "password": "SuperSecretPass123"}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["mfa_required"] is False
    assert data["access_token"] is not None
    assert data["user"]["username"] == "test_supervisor"


@patch("api.routes.auth.AuditLogService")
def test_login_flow_with_mfa_challenge(mock_audit):
    """Verifies login for MFA-enabled user returns mfa_required=True and mfa_token."""
    secret = generate_totp_secret()
    mock_uow = MagicMock()
    mock_user = _make_mock_user(mfa_enabled=True, mfa_secret=secret)
    mock_uow.users.find_by_username.return_value = mock_user
    app.dependency_overrides[get_uow] = lambda: mock_uow

    resp = client.post(
        "/api/v1/auth/login",
        json={"username": "test_supervisor", "password": "SuperSecretPass123"}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["mfa_required"] is True
    assert data["access_token"] is None
    assert data["user"] is None
    assert data["mfa_token"] is not None


@patch("api.routes.auth.AuditLogService")
def test_mfa_challenge_totp_success(mock_audit):
    """Verifies completing MFA challenge with valid TOTP code returns session token."""
    secret = generate_totp_secret()
    mock_uow = MagicMock()
    mock_user = _make_mock_user(mfa_enabled=True, mfa_secret=secret)
    mock_uow.users.find_by_id.return_value = mock_user
    app.dependency_overrides[get_uow] = lambda: mock_uow

    mfa_token = generate_mfa_challenge_token(mock_user.id, mock_user.username)
    valid_code = generate_totp_code(secret)

    resp = client.post(
        "/api/v1/auth/mfa/challenge",
        json={"mfa_token": mfa_token, "code": valid_code}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["mfa_required"] is False
    assert data["access_token"] is not None
    assert data["user"]["username"] == mock_user.username


@patch("api.routes.auth.AuditLogService")
def test_mfa_challenge_backup_code_consumption(mock_audit):
    """Verifies completing MFA challenge with single-use backup code consumes code."""
    secret = generate_totp_secret()
    backup_codes = generate_backup_codes(4)
    hashed_codes = [hash_backup_code(c) for c in backup_codes]

    mock_uow = MagicMock()
    mock_user = _make_mock_user(
        mfa_enabled=True,
        mfa_secret=secret,
        mfa_backup_codes=hashed_codes
    )
    mock_uow.users.find_by_id.return_value = mock_user
    app.dependency_overrides[get_uow] = lambda: mock_uow

    mfa_token = generate_mfa_challenge_token(mock_user.id, mock_user.username)
    chosen_backup_code = backup_codes[0]

    resp = client.post(
        "/api/v1/auth/mfa/challenge",
        json={"mfa_token": mfa_token, "code": chosen_backup_code}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["access_token"] is not None
    assert data["mfa_required"] is False

    # Verify backup code was consumed and DB updated
    mock_uow.users.update_extra_fields.assert_called_once()
    saved_extra = mock_uow.users.update_extra_fields.call_args[0][1]
    assert len(saved_extra["mfa_backup_codes"]) == 3


@patch("api.routes.auth.AuditLogService")
def test_mfa_challenge_invalid_code_rejection(mock_audit):
    """Verifies that an invalid MFA code is rejected with HTTP 401."""
    secret = generate_totp_secret()
    mock_uow = MagicMock()
    mock_user = _make_mock_user(mfa_enabled=True, mfa_secret=secret)
    mock_uow.users.find_by_id.return_value = mock_user
    app.dependency_overrides[get_uow] = lambda: mock_uow

    mfa_token = generate_mfa_challenge_token(mock_user.id, mock_user.username)

    resp = client.post(
        "/api/v1/auth/mfa/challenge",
        json={"mfa_token": mfa_token, "code": "000000"}
    )
    assert resp.status_code == 401
    assert "Invalid MFA verification code" in resp.json()["detail"]


@patch("api.routes.auth.AuditLogService")
def test_mfa_setup_and_activate_lifecycle(mock_audit):
    """Verifies setup initiation, status check, activation, and disable."""
    mock_uow = MagicMock()
    mock_user = _make_mock_user(mfa_enabled=False)
    mock_uow.users.find_by_id.return_value = mock_user

    current_user = CurrentUser(
        id=mock_user.id,
        username=mock_user.username,
        role=mock_user.role,
        branch=mock_user.branch_name,
        branch_id=mock_user.branch_id,
        full_name=mock_user.full_name,
    )

    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: current_user

    # 1. Setup MFA
    setup_resp = client.post("/api/v1/auth/mfa/setup")
    assert setup_resp.status_code == 200
    setup_data = setup_resp.json()
    secret = setup_data["secret"]
    assert len(setup_data["backup_codes"]) == 8
    assert "otpauth://" in setup_data["otpauth_uri"]

    # 2. Simulate pending saved in user extra_fields
    mock_user.extra_fields["mfa_pending"] = {
        "secret": secret,
        "backup_codes": [hash_backup_code(c) for c in setup_data["backup_codes"]],
    }

    # 3. Activate MFA with valid TOTP code
    code = generate_totp_code(secret)
    act_resp = client.post("/api/v1/auth/mfa/activate", json={"code": code})
    assert act_resp.status_code == 200
    assert act_resp.json()["success"] is True

    # 4. Check status
    mock_user.extra_fields["mfa_enabled"] = True
    mock_user.extra_fields["mfa_backup_codes"] = ["hash1", "hash2"]
    status_resp = client.get("/api/v1/auth/mfa/status")
    assert status_resp.status_code == 200
    assert status_resp.json()["mfa_enabled"] is True
    assert status_resp.json()["remaining_backup_codes"] == 2

    # 5. Disable MFA with correct password
    dis_resp = client.post("/api/v1/auth/mfa/disable", json={"password": "SuperSecretPass123"})
    assert dis_resp.status_code == 200
    assert dis_resp.json()["success"] is True


@patch("api.routes.auth.AuditLogService")
def test_admin_reset_user_mfa(mock_audit):
    """Verifies that an Admin can reset MFA for a locked-out user."""
    mock_uow = MagicMock()
    target_user = _make_mock_user(
        username="locked_out_officer",
        role="Credit Officer",
        mfa_enabled=True,
        mfa_secret=generate_totp_secret(),
        mfa_backup_codes=["hash1"]
    )
    mock_uow.users.find_by_id.return_value = target_user

    admin_user = CurrentUser(
        id=str(uuid.uuid4()),
        username="head_admin",
        role="Admin",
        branch="Head Office",
        branch_id=str(uuid.uuid4()),
        full_name="Head Administrator",
    )

    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: admin_user

    resp = client.post("/api/v1/auth/mfa/reset-user", json={"user_id": target_user.id})
    assert resp.status_code == 200
    assert resp.json()["success"] is True

    # Verify target user MFA fields were cleared
    mock_uow.users.update_extra_fields.assert_called_once()
    cleared_extra = mock_uow.users.update_extra_fields.call_args[0][1]
    assert "mfa_enabled" not in cleared_extra
    assert "mfa_secret" not in cleared_extra
