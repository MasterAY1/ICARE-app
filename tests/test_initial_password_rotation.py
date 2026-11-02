"""
tests/test_initial_password_rotation.py
Automated test suite for First-Time Password Rotation (Management Tier) & Officer Credential Custody.
Verifies:
1. Management user (BM/AM/Admin) with must_change_password=True receives password_change_required=True and temp_token.
2. Standard test user without flag logs in normally (100% unaffected testing phase).
3. Successful initial password change clears flag, updates password hash, and issues permanent session token.
4. Incorrect current password rejected with HTTP 400.
5. Weak (< 8 chars) or identical password rejected.
6. Credit Officer blocked from self-service password rotation (controlled by BM/AM).
Complies with Strict Zero-Emoji Governance.
"""
from datetime import datetime
from unittest.mock import MagicMock
from fastapi.testclient import TestClient

from api.main import app
from auth.password import hash_password
from auth.session import generate_password_change_token
from domain.entities.user import User
from api.dependencies import get_uow


client = TestClient(app)


class TestInitialPasswordRotation:

    def setup_method(self):
        app.dependency_overrides.clear()

    def teardown_method(self):
        app.dependency_overrides.clear()

    def test_management_user_with_must_change_password_receives_temp_token_and_flag(self):
        """
        Verify that a Branch Manager with must_change_password=True is intercepted
        and required to rotate their initial password.
        """
        mock_uow = MagicMock()
        hashed = hash_password("DefaultAdmin2026!")
        bm_user = User(
            id="usr-bm-01",
            username="bm_ikeja",
            full_name="Branch Manager Ikeja",
            role="Branch Manager",
            branch_name="Ikeja",
            password_hash=hashed,
            created_at=datetime.now(),
            branch_id="b-ikeja-uuid",
            is_active=True,
            extra_fields={"must_change_password": True}
        )
        mock_uow.users.find_by_username.return_value = bm_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        res = client.post("/api/v1/auth/login", json={"username": "bm_ikeja", "password": "DefaultAdmin2026!"})
        assert res.status_code == 200
        data = res.json()
        assert data["password_change_required"] is True
        assert data["access_token"] is None
        assert data["temp_token"] is not None
        assert "First-time login detected" in data["message"]

    def test_normal_test_user_without_flag_unaffected(self):
        """
        Verify that test users without must_change_password=True are completely unaffected
        and receive a full session access token immediately.
        """
        mock_uow = MagicMock()
        hashed = hash_password("TestPassword123!")
        test_user = User(
            id="usr-test-01",
            username="test_admin",
            full_name="Test Administrator",
            role="Admin",
            branch_name="Head Office",
            password_hash=hashed,
            created_at=datetime.now(),
            branch_id="b-hq-uuid",
            is_active=True,
            extra_fields={}  # No flag
        )
        mock_uow.users.find_by_username.return_value = test_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        res = client.post("/api/v1/auth/login", json={"username": "test_admin", "password": "TestPassword123!"})
        assert res.status_code == 200
        data = res.json()
        assert data["password_change_required"] is False
        assert data["access_token"] is not None

    def test_change_initial_password_success(self):
        """
        Verify that a management user submitting valid current and new passwords
        successfully updates their password, clears must_change_password, and gets a permanent token.
        """
        mock_uow = MagicMock()
        old_hashed = hash_password("DefaultBM2026!")
        bm_user = User(
            id="usr-bm-02",
            username="bm_yaba",
            full_name="Branch Manager Yaba",
            role="Branch Manager",
            branch_name="Yaba",
            password_hash=old_hashed,
            created_at=datetime.now(),
            branch_id="b-yaba-uuid",
            is_active=True,
            extra_fields={"must_change_password": True}
        )
        mock_uow.users.find_by_id.return_value = bm_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        temp_token = generate_password_change_token(bm_user.id, bm_user.username)

        res = client.post("/api/v1/auth/change-initial-password", json={
            "temp_token": temp_token,
            "current_password": "DefaultBM2026!",
            "new_password": "NewSecurePass2026!"
        })
        assert res.status_code == 200
        data = res.json()
        assert data["password_change_required"] is False
        assert data["access_token"] is not None
        assert "Password updated successfully" in data["message"]

        # Verify DB update calls
        assert mock_uow.users.update_password.call_count == 1
        assert mock_uow.users.update_extra_fields.call_count == 1
        updated_extra = mock_uow.users.update_extra_fields.call_args[0][1]
        assert updated_extra["must_change_password"] is False
        assert "password_changed_at" in updated_extra

    def test_change_initial_password_invalid_current_password_fails(self):
        """
        Verify that incorrect current password is rejected with HTTP 400 Bad Request.
        """
        mock_uow = MagicMock()
        old_hashed = hash_password("ActualPassword123!")
        bm_user = User(
            id="usr-bm-03",
            username="bm_ikeja",
            full_name="Branch Manager Ikeja",
            role="Branch Manager",
            branch_name="Ikeja",
            password_hash=old_hashed,
            created_at=datetime.now(),
            branch_id="b-ikeja-uuid",
            is_active=True,
            extra_fields={"must_change_password": True}
        )
        mock_uow.users.find_by_id.return_value = bm_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        temp_token = generate_password_change_token(bm_user.id, bm_user.username)

        res = client.post("/api/v1/auth/change-initial-password", json={
            "temp_token": temp_token,
            "current_password": "WrongPassword!",
            "new_password": "NewSecurePass2026!"
        })
        assert res.status_code == 400
        assert "Current temporary/default password is incorrect" in res.json().get("detail", "")

    def test_change_initial_password_weak_or_identical_password_fails(self):
        """
        Verify that weak (<8 chars) or identical passwords are rejected.
        """
        mock_uow = MagicMock()
        old_hashed = hash_password("DefaultPass123!")
        bm_user = User(
            id="usr-bm-04",
            username="bm_ikeja",
            full_name="Branch Manager Ikeja",
            role="Branch Manager",
            branch_name="Ikeja",
            password_hash=old_hashed,
            created_at=datetime.now(),
            branch_id="b-ikeja-uuid",
            is_active=True,
            extra_fields={"must_change_password": True}
        )
        mock_uow.users.find_by_id.return_value = bm_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        temp_token = generate_password_change_token(bm_user.id, bm_user.username)

        # 1. Too short (< 8 chars)
        res_short = client.post("/api/v1/auth/change-initial-password", json={
            "temp_token": temp_token,
            "current_password": "DefaultPass123!",
            "new_password": "short"
        })
        assert res_short.status_code == 422

        # 2. Identical to current password
        res_same = client.post("/api/v1/auth/change-initial-password", json={
            "temp_token": temp_token,
            "current_password": "DefaultPass123!",
            "new_password": "DefaultPass123!"
        })
        assert res_same.status_code == 400
        assert "cannot be identical" in res_same.json().get("detail", "")

    def test_credit_officer_cannot_self_service_rotate_initial_password(self):
        """
        Verify that Credit Officers are blocked from self-service initial password rotation.
        Field officer passwords must be controlled and managed by BM/AM.
        """
        mock_uow = MagicMock()
        hashed = hash_password("OfficerPass123!")
        co_user = User(
            id="usr-co-01",
            username="co_sarah",
            full_name="Sarah Officer",
            role="Credit Officer",
            branch_name="Ikeja",
            password_hash=hashed,
            created_at=datetime.now(),
            branch_id="b-ikeja-uuid",
            is_active=True,
            extra_fields={"must_change_password": True}
        )
        mock_uow.users.find_by_id.return_value = co_user
        app.dependency_overrides[get_uow] = lambda: mock_uow

        temp_token = generate_password_change_token(co_user.id, co_user.username)

        res = client.post("/api/v1/auth/change-initial-password", json={
            "temp_token": temp_token,
            "current_password": "OfficerPass123!",
            "new_password": "NewSecretPass2026!"
        })
        assert res.status_code == 403
        data = res.json()
        assert "Credit Officer passwords must be configured and managed" in (data.get("message") or data.get("detail", ""))
