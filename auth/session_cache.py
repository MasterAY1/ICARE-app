"""
In-Memory User Session Cache.

Thread-safe TTL cache for authenticated CurrentUser profiles.
Eliminates redundant PostgREST lookups on every API request.
Provides eviction and invalidation triggers for user deactivation,
role changes, or security events.
"""
import threading
import time
from typing import Dict, Tuple, Optional
from models.user import CurrentUser


class UserSessionCache:
    """
    Thread-safe in-memory cache for CurrentUser objects with sliding/fixed TTL.
    """
    def __init__(self, default_ttl_seconds: float = 90.0):
        self._cache: Dict[str, Tuple[float, CurrentUser]] = {}
        self._lock = threading.Lock()
        self._default_ttl = default_ttl_seconds

    def get(self, user_key: Optional[str]) -> Optional[CurrentUser]:
        """
        Retrieves a cached CurrentUser if present and unexpired.
        Returns None on cache miss or expiration.
        """
        if not user_key:
            return None
        key = str(user_key).strip().lower()
        now = time.monotonic()
        with self._lock:
            entry = self._cache.get(key)
            if entry is not None:
                expires_at, user = entry
                if now < expires_at:
                    return user
                # Expired: clean up
                del self._cache[key]
        return None

    def set(self, user_key: Optional[str], user: CurrentUser, ttl_seconds: Optional[float] = None) -> None:
        """
        Caches a CurrentUser instance under the specified user key.
        """
        if not user_key or user is None:
            return
        key = str(user_key).strip().lower()
        ttl = ttl_seconds if ttl_seconds is not None else self._default_ttl
        now = time.monotonic()
        with self._lock:
            self._cache[key] = (now + ttl, user)

    def invalidate(self, user_key: Optional[str] = None) -> None:
        """
        Invalidates a specific user or clears the entire cache.
        """
        with self._lock:
            if user_key:
                key = str(user_key).strip().lower()
                self._cache.pop(key, None)
            else:
                self._cache.clear()

    def __len__(self) -> int:
        now = time.monotonic()
        with self._lock:
            return sum(1 for exp, _ in self._cache.values() if now < exp)


# Global singleton instance (90-second TTL)
_GLOBAL_SESSION_CACHE = UserSessionCache(default_ttl_seconds=90.0)


def get_cached_user(user_key: Optional[str]) -> Optional[CurrentUser]:
    """Retrieves CurrentUser from global in-memory session cache."""
    return _GLOBAL_SESSION_CACHE.get(user_key)


def set_cached_user(user_key: Optional[str], user: CurrentUser, ttl_seconds: Optional[float] = None) -> None:
    """Stores CurrentUser in global in-memory session cache."""
    _GLOBAL_SESSION_CACHE.set(user_key, user, ttl_seconds)


def invalidate_user_session_cache(user_key: Optional[str] = None) -> None:
    """Invalidates the in-memory session cache for a specific user or completely."""
    _GLOBAL_SESSION_CACHE.invalidate(user_key)
