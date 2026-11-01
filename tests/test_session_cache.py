"""
Unit Tests for In-Memory User Session Caching.

Verifies:
1. Cache storage and retrieval.
2. TTL expiration and eviction.
3. User-specific and global cache invalidation.
4. `get_current_user` fast-path cache hit bypassing database lookups.
5. Deactivated user handling and immediate 401 fail-closed.
"""
import time
import uuid
import pytest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException

from auth.session_cache import (
    UserSessionCache,
    get_cached_user,
    set_cached_user,
    invalidate_user_session_cache,
)
from models.user import CurrentUser
from api.dependencies import get_current_user


def test_session_cache_set_and_get():
    cache = UserSessionCache(default_ttl_seconds=60.0)
    user = CurrentUser(
        id=str(uuid.uuid4()),
        username="officer_john",
        role="Credit Officer",
        branch="Ikeja",
        branch_id=str(uuid.uuid4()),
        full_name="John Doe",
        permissions={"client.view"}
    )
    cache.set("officer_john", user)
    cached = cache.get("officer_john")

    assert cached is not None
    assert cached.username == "officer_john"
    assert cached.branch == "Ikeja"
    # Case insensitive key
    assert cache.get("OFFICER_JOHN") is not None


def test_session_cache_ttl_expiration():
    cache = UserSessionCache(default_ttl_seconds=0.1)  # 100ms TTL
    user = CurrentUser(
        id=str(uuid.uuid4()),
        username="officer_temp",
        role="Credit Officer",
        branch="Main",
        branch_id=str(uuid.uuid4()),
        full_name="Temp Officer",
        permissions=set()
    )
    cache.set("officer_temp", user, ttl_seconds=0.03)
    assert cache.get("officer_temp") is not None

    time.sleep(0.1)
    # Expired
    assert cache.get("officer_temp") is None
    assert len(cache) == 0


def test_session_cache_invalidation():
    cache = UserSessionCache(default_ttl_seconds=60.0)
    u1 = CurrentUser(id="u1", username="user1", role="CO", branch="B1", branch_id="b1", full_name="User 1", permissions=set())
    u2 = CurrentUser(id="u2", username="user2", role="BM", branch="B2", branch_id="b2", full_name="User 2", permissions=set())

    cache.set("user1", u1)
    cache.set("user2", u2)
    assert len(cache) == 2

    # Invalidate single
    cache.invalidate("user1")
    assert cache.get("user1") is None
    assert cache.get("user2") is not None
    assert len(cache) == 1

    # Invalidate all
    cache.invalidate()
    assert cache.get("user2") is None
    assert len(cache) == 0


def test_get_current_user_bypasses_db_on_cache_hit():
    invalidate_user_session_cache()

    user_id = str(uuid.uuid4())
    username = "sarah_bm"
    mock_user_record = MagicMock()
    mock_user_record.id = user_id
    mock_user_record.username = username
    mock_user_record.role = "Branch Manager"
    mock_user_record.branch_name = "Ikeja"
    mock_user_record.branch_id = str(uuid.uuid4())
    mock_user_record.full_name = "Sarah Connor"
    mock_user_record.is_active = True
    mock_user_record.extra_fields = {}

    mock_uow = MagicMock()
    mock_uow.users.find_by_id.return_value = mock_user_record

    token_data = {"user_id": user_id, "username": username, "timestamp": int(time.time())}

    with patch("api.dependencies.validate_session_token", return_value=token_data):
        # 1. First call: Cache miss -> queries database
        user1 = get_current_user(authorization="Bearer valid-token-123", uow=mock_uow)
        assert user1.username == username
        assert mock_uow.users.find_by_id.call_count == 1

        # 2. Second call with same token: Cache hit -> does NOT query database
        user2 = get_current_user(authorization="Bearer valid-token-123", uow=mock_uow)
        assert user2.username == username
        # DB lookup count remains 1!
        assert mock_uow.users.find_by_id.call_count == 1

    invalidate_user_session_cache()


def test_get_current_user_deactivated_fails_and_evicts_cache():
    invalidate_user_session_cache()

    user_id = str(uuid.uuid4())
    username = "deactivated_user"

    mock_user_record = MagicMock()
    mock_user_record.id = user_id
    mock_user_record.username = username
    mock_user_record.is_active = False

    mock_uow = MagicMock()
    mock_uow.users.find_by_id.return_value = mock_user_record

    token_data = {"user_id": user_id, "username": username, "timestamp": int(time.time())}

    with patch("api.dependencies.validate_session_token", return_value=token_data):
        with pytest.raises(HTTPException) as exc_info:
            get_current_user(authorization="Bearer deactivated-token", uow=mock_uow)

        assert exc_info.value.status_code == 401
        assert "deactivated" in exc_info.value.detail.lower()

    # Ensure nothing was cached
    assert get_cached_user(user_id) is None
    assert get_cached_user(username) is None
    invalidate_user_session_cache()
