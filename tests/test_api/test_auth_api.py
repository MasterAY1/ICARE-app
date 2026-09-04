"""
Tests for Auth API endpoint using FastAPI dependency overrides.
"""
import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

import pytest
from fastapi.testclient import TestClient
from unittest.mock import MagicMock, patch
from api.main import app
from api.dependencies import get_uow

client = TestClient(app)


def test_login_invalid_user():
    mock_uow = MagicMock()
    mock_uow.users.find_by_username.return_value = None
    app.dependency_overrides[get_uow] = lambda: mock_uow

    res = client.post("/api/v1/auth/login", json={"username": "fakeuser", "password": "password"})
    assert res.status_code == 401
    assert "Invalid credentials" in res.json()["detail"]
    app.dependency_overrides.clear()


def test_login_success():
    mock_uow = MagicMock()
    mock_user = MagicMock()
    mock_user.id = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
    mock_user.username = "co_ayomide"
    mock_user.full_name = "Mr. Ayomide"
    mock_user.role = "Credit Officer"
    mock_user.branch_name = "Ogijo"
    mock_user.branch_id = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"
    mock_user.is_active = True
    mock_user.password_hash = "hashed"

    mock_uow.users.find_by_username.return_value = mock_user
    app.dependency_overrides[get_uow] = lambda: mock_uow

    with patch("api.routes.auth.verify_password", return_value=True):
        res = client.post("/api/v1/auth/login", json={"username": "co_ayomide", "password": "valid_pass"})
        assert res.status_code == 200
        data = res.json()
        assert "access_token" in data
        assert data["user"]["username"] == "co_ayomide"
        assert data["user"]["branch"] == "Ogijo"
        assert data["user"]["role"] == "Credit Officer"

    app.dependency_overrides.clear()
