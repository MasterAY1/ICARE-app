"""
Automated Tests for Self-Service User Profile, Avatar Upload, Appearance Preferences,
and Role-Scoped Password Rotation Endpoints (/api/v1/auth/profile, /change-password).
Complies with Strict Zero-Emoji Governance.
"""
import io
import os
import uuid
from unittest.mock import MagicMock, patch

os.environ["ENVIRONMENT"] = "test"

from PIL import Image
import pytest
from fastapi.testclient import TestClient

from api.main import app
from api.dependencies import get_uow, get_current_user
from auth.password import hash_password, verify_password
from auth.session import validate_session_token
from auth.session_cache import invalidate_user_session_cache
from domain.entities.user import User
from models.user import CurrentUser

client = TestClient(app)


@pytest.fixture(autouse=True)
def reset_overrides():
    app.dependency_overrides.clear()
    invalidate_user_session_cache()
    yield
    app.dependency_overrides.clear()
    invalidate_user_session_cache()


def _make_domain_user(role="Branch Manager", extra_fields=None):
    return User(
        id=str(uuid.uuid4()),
        username=f"user_{role.lower().replace(' ', '_')}",
        full_name="Adaeze Okonkwo",
        role=role,
        branch_name="Ibadan",
        branch_id=str(uuid.uuid4()),
        password_hash=hash_password("OldPassword123!"),
        created_at=None,
        is_active=True,
        extra_fields=extra_fields if extra_fields is not None else {},
    )


def _current_from_domain(u: User) -> CurrentUser:
    return CurrentUser(
        id=u.id,
        username=u.username,
        role=u.role,
        branch=u.branch_name,
        branch_id=u.branch_id,
        full_name=u.full_name,
        phone=str((u.extra_fields or {}).get("phone") or ""),
        email=str((u.extra_fields or {}).get("email") or ""),
        avatar_url=str((u.extra_fields or {}).get("avatar_url") or ""),
        bio=str((u.extra_fields or {}).get("bio") or ""),
        mfa_enabled=bool((u.extra_fields or {}).get("mfa_enabled", False)),
        preferences=dict((u.extra_fields or {}).get("preferences") or {}),
    )


def _build_mock_uow(domain_user: User, login_rows=None):
    mock_uow = MagicMock()
    mock_uow.users.find_by_id.return_value = domain_user
    mock_uow.login_history.find_by_user.return_value = login_rows or []

    def _update_extra(uid, new_extra):
        domain_user.extra_fields = dict(new_extra)
        return True

    mock_uow.users.update_extra_fields.side_effect = _update_extra
    return mock_uow


@patch("api.routes.auth.AuditLogService")
def test_get_profile_for_credit_officer_and_manager(mock_audit):
    co_user = _make_domain_user(
        role="Credit Officer",
        extra_fields={
            "phone": "08012345678",
            "email": "co.adaeze@icare.ng",
            "bio": "Ibadan South field desk",
            "allowed_products": ["Daily 60 Days", "Weekly 12W"],
            "preferences": {"theme_mode": "dark", "accent_preset": "emerald"},
        },
    )
    mock_uow = _build_mock_uow(
        co_user,
        login_rows=[
            {
                "login_time": "2026-11-20T09:00:00",
                "status": "SUCCESS",
                "device_name": "Chrome Web",
                "browser": "Chrome",
                "operating_system": "Windows",
            }
        ],
    )
    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: _current_from_domain(co_user)

    resp = client.get("/api/v1/auth/profile")
    assert resp.status_code == 200
    data = resp.json()
    assert data["user"]["username"] == co_user.username
    assert data["user"]["phone"] == "08012345678"
    assert data["user"]["allowed_products"] == ["Daily 60 Days", "Weekly 12W"]
    assert data["user"]["preferences"]["theme_mode"] == "dark"
    assert data["can_self_change_password"] is False
    assert len(data["recent_activity"]) == 1

    # Branch Manager gets can_self_change_password=True
    bm_user = _make_domain_user(role="Branch Manager")
    app.dependency_overrides[get_uow] = lambda: _build_mock_uow(bm_user)
    app.dependency_overrides[get_current_user] = lambda: _current_from_domain(bm_user)
    bm_resp = client.get("/api/v1/auth/profile")
    assert bm_resp.status_code == 200
    assert bm_resp.json()["can_self_change_password"] is True


@patch("api.routes.auth.AuditLogService")
def test_patch_profile_preserves_existing_extra_fields_and_validates(mock_audit):
    co_user = _make_domain_user(
        role="Credit Officer",
        extra_fields={
            "allowed_products": ["Daily 60 Days"],
            "mfa_enabled": True,
            "is_misc_savings_manager": True,
        },
    )
    mock_uow = _build_mock_uow(co_user)
    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: _current_from_domain(co_user)

    # Reject invalid email
    bad_resp = client.patch("/api/v1/auth/profile", json={"email": "not-an-email"})
    assert bad_resp.status_code == 422

    # Valid update saves phone, email, bio, emergency contact, preferences without clobbering MFA or products
    ok_resp = client.patch(
        "/api/v1/auth/profile",
        json={
            "phone": "+234 801 555 0199",
            "email": "adaeze@icare.ng",
            "bio": "Lead Field Officer",
            "emergency_contact": "Tunde Okonkwo - 08090001111",
            "preferences": {
                "theme_mode": "dark",
                "accent_preset": "sapphire",
                "compact_density": True,
                "reduce_motion": True,
                "haptics_enabled": False,
            },
        },
    )
    assert ok_resp.status_code == 200
    body = ok_resp.json()
    assert body["success"] is True
    assert body["user"]["phone"] == "+234 801 555 0199"
    assert body["user"]["email"] == "adaeze@icare.ng"
    assert body["user"]["allowed_products"] == ["Daily 60 Days"]
    assert body["user"]["mfa_enabled"] is True
    assert body["user"]["is_misc_savings_manager"] is True
    assert body["user"]["preferences"]["theme_mode"] == "dark"
    assert body["user"]["preferences"]["accent_preset"] == "sapphire"
    assert body["emergency_contact"] == "Tunde Okonkwo - 08090001111"


@patch("api.routes.auth.AuditLogService")
def test_avatar_upload_and_removal(mock_audit):
    user = _make_domain_user(role="Area Manager")
    mock_uow = _build_mock_uow(user)
    bucket_mock = MagicMock()
    bucket_mock.get_public_url.return_value = "https://cdn.example.com/user-avatars/avatar.jpg"
    mock_uow.client.storage.list_buckets.return_value = [MagicMock(name="user-avatars")]
    mock_uow.client.storage.from_.return_value = bucket_mock

    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: _current_from_domain(user)

    # Create valid in-memory PNG image
    buf = io.BytesIO()
    Image.new("RGBA", (600, 600), (6, 78, 59, 255)).save(buf, format="PNG")
    buf.seek(0)

    up_resp = client.post(
        "/api/v1/auth/profile/avatar",
        files={"file": ("headshot.png", buf.getvalue(), "image/png")},
    )
    assert up_resp.status_code == 200
    up_data = up_resp.json()
    assert up_data["success"] is True
    assert up_data["avatar_url"] == "https://cdn.example.com/user-avatars/avatar.jpg"
    assert user.extra_fields["avatar_url"] == "https://cdn.example.com/user-avatars/avatar.jpg"
    bucket_mock.upload.assert_called_once()

    # Delete avatar clears storage and extra_fields
    del_resp = client.delete("/api/v1/auth/profile/avatar")
    assert del_resp.status_code == 200
    assert del_resp.json()["success"] is True
    assert del_resp.json()["user"]["avatar_url"] == ""
    assert "avatar_url" not in user.extra_fields


@patch("api.routes.auth.AuditLogService")
def test_change_password_enforces_co_restriction_and_rotates_manager(mock_audit):
    # 1. CO rejected with 403
    co_user = _make_domain_user(role="Credit Officer")
    mock_uow_co = _build_mock_uow(co_user)
    app.dependency_overrides[get_uow] = lambda: mock_uow_co
    app.dependency_overrides[get_current_user] = lambda: _current_from_domain(co_user)

    co_resp = client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "OldPassword123!", "new_password": "NewStrongPass99!"},
    )
    assert co_resp.status_code == 403
    assert "Branch Manager" in co_resp.json()["detail"]

    # 2. Branch Manager succeeds and receives fresh session token
    bm_user = _make_domain_user(role="Branch Manager")
    mock_uow_bm = _build_mock_uow(bm_user)
    app.dependency_overrides[get_uow] = lambda: mock_uow_bm
    app.dependency_overrides[get_current_user] = lambda: _current_from_domain(bm_user)

    # Wrong current password rejected
    wrong_resp = client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "WrongPassword", "new_password": "NewStrongPass99!"},
    )
    assert wrong_resp.status_code == 400

    # Correct rotation succeeds
    ok_resp = client.post(
        "/api/v1/auth/change-password",
        json={"current_password": "OldPassword123!", "new_password": "NewStrongPass99!"},
    )
    assert ok_resp.status_code == 200
    data = ok_resp.json()
    assert data["success"] is True
    assert data["access_token"] is not None
    assert validate_session_token(data["access_token"]) is not None
    mock_uow_bm.users.update_password.assert_called_once()
    saved_hash = mock_uow_bm.users.update_password.call_args[0][1]
    assert verify_password("NewStrongPass99!", saved_hash) is True
