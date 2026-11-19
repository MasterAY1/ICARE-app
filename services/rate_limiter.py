"""
services/rate_limiter.py
Thread-safe distributed sliding-window rate limiters for ICARE Core Banking.
Protects login and MFA challenge endpoints across processes and restarts using
PostgreSQL (`auth_rate_limit_state`) backed by a fast L1 cache.
Complies with Strict Zero-Emoji Governance.
"""
from datetime import datetime, timezone
import logging
import os
import threading
import time
from typing import Any, Callable, Dict, List, Optional, Tuple
from fastapi import Request

logger = logging.getLogger("icare.rate_limiter")


class AuthenticationRateLimiter:
    """
    Distributed sliding-window rate limiter with lockout period.
    Tracks failed authentication timestamps per key (IP address and normalized username).
    Uses PostgreSQL (`auth_rate_limit_state`) as shared backing store outside `ENVIRONMENT=test`
    (or when an explicit client_provider is injected).
    """

    def __init__(
        self,
        max_attempts: int = 5,
        window_seconds: int = 300,       # 5-minute sliding window
        lockout_seconds: int = 900,      # 15-minute lockout period
        client_provider: Optional[Callable[[], Any]] = None,
    ):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self.lockout_seconds = lockout_seconds
        self._client_provider = client_provider
        self._lock = threading.Lock()
        # key -> list of UTC epoch failure timestamps
        self._failures: Dict[str, List[float]] = {}
        # key -> lockout expiration UTC epoch timestamp
        self._lockouts: Dict[str, float] = {}

    def _is_persistence_enabled(self) -> bool:
        if self._client_provider is not None:
            return True
        return os.getenv("ENVIRONMENT", "").strip().lower() != "test"

    def _get_client(self) -> Any:
        if self._client_provider is not None:
            return self._client_provider()
        from database.connection import get_supabase_client
        return get_supabase_client()

    @staticmethod
    def _parse_iso_epoch(value: Any) -> Optional[float]:
        if value is None:
            return None
        try:
            if isinstance(value, (int, float)):
                return float(value)
            raw = str(value).strip()
            if not raw:
                return None
            if raw.endswith("Z"):
                raw = raw[:-1] + "+00:00"
            dt = datetime.fromisoformat(raw)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc).timestamp()
        except Exception:
            return None

    def _read_shared_state(self, norm_key: str, now: float) -> Optional[Tuple[List[float], Optional[float]]]:
        if not self._is_persistence_enabled():
            return None
        try:
            client = self._get_client()
            res = (
                client.table("auth_rate_limit_state")
                .select("failure_timestamps, locked_until")
                .eq("limit_key", norm_key)
                .limit(1)
                .execute()
            )
            rows = getattr(res, "data", None) or []
            if not rows:
                return ([], None)
            row = rows[0] if isinstance(rows[0], dict) else {}
            cutoff = now - self.window_seconds
            raw_ts = row.get("failure_timestamps") or []
            db_timestamps: List[float] = []
            if isinstance(raw_ts, list):
                for item in raw_ts:
                    try:
                        ts = float(item)
                        if ts > cutoff:
                            db_timestamps.append(ts)
                    except (TypeError, ValueError):
                        continue
            db_lockout = self._parse_iso_epoch(row.get("locked_until"))
            if db_lockout is not None and db_lockout <= now:
                db_lockout = None
            return (db_timestamps, db_lockout)
        except Exception as exc:
            logger.warning("Failed to load shared auth rate limit state for %s: %s", norm_key, exc)
            return None

    def _write_shared_state(
        self,
        norm_key: str,
        timestamps: List[float],
        locked_until: Optional[float],
        now: float,
    ) -> None:
        if not self._is_persistence_enabled():
            return
        try:
            client = self._get_client()
            now_iso = datetime.fromtimestamp(now, tz=timezone.utc).isoformat()
            locked_iso = (
                datetime.fromtimestamp(locked_until, tz=timezone.utc).isoformat()
                if locked_until is not None
                else None
            )
            client.table("auth_rate_limit_state").upsert(
                {
                    "limit_key": norm_key,
                    "failure_timestamps": timestamps,
                    "locked_until": locked_iso,
                    "updated_at": now_iso,
                },
                on_conflict="limit_key",
            ).execute()
        except Exception as exc:
            logger.warning("Failed to persist auth rate limit state for %s: %s", norm_key, exc)

    def _delete_shared_state(self, norm_key: str) -> None:
        if not self._is_persistence_enabled():
            return
        try:
            client = self._get_client()
            client.table("auth_rate_limit_state").delete().eq("limit_key", norm_key).execute()
        except Exception as exc:
            logger.warning("Failed to clear shared auth rate limit state for %s: %s", norm_key, exc)

    def is_locked_out(self, key: Optional[str]) -> Tuple[bool, int]:
        """
        Checks whether the specified key is currently locked out.
        Returns: (is_locked, retry_after_seconds)
        """
        if not key:
            return False, 0
        norm_key = str(key).strip().lower()
        now = time.time()
        shared = self._read_shared_state(norm_key, now)

        with self._lock:
            cutoff = now - self.window_seconds
            local_ts = [ts for ts in self._failures.get(norm_key, []) if ts > cutoff]
            local_lock = self._lockouts.get(norm_key)
            if local_lock is not None and local_lock <= now:
                del self._lockouts[norm_key]
                self._failures.pop(norm_key, None)
                local_lock = None
                local_ts = []

            if shared is not None:
                db_ts, db_lock = shared
                valid_timestamps = sorted(db_ts)
                lockout_until = db_lock
                self._failures[norm_key] = valid_timestamps
                if lockout_until is not None:
                    self._lockouts[norm_key] = lockout_until
                else:
                    self._lockouts.pop(norm_key, None)
            else:
                valid_timestamps = local_ts
                lockout_until = local_lock
                self._failures[norm_key] = valid_timestamps

            if lockout_until is not None and now < lockout_until:
                retry_after = int(lockout_until - now) + 1
                return True, retry_after

            if len(valid_timestamps) >= self.max_attempts:
                new_lock = now + self.lockout_seconds
                self._lockouts[norm_key] = new_lock
                return True, self.lockout_seconds

            return False, 0

    def record_failure(self, key: Optional[str]) -> Tuple[bool, int]:
        """
        Records a failed authentication attempt across L1 and shared store.
        Returns: (is_locked, retry_after_seconds)
        """
        if not key:
            return False, 0
        norm_key = str(key).strip().lower()
        now = time.time()
        shared = self._read_shared_state(norm_key, now)

        with self._lock:
            cutoff = now - self.window_seconds
            if shared is not None:
                base_ts, base_lock = shared
                valid_timestamps = [ts for ts in base_ts if ts > cutoff]
                lockout_until = base_lock if (base_lock is not None and base_lock > now) else None
            else:
                valid_timestamps = [ts for ts in self._failures.get(norm_key, []) if ts > cutoff]
                existing_lock = self._lockouts.get(norm_key)
                lockout_until = existing_lock if (existing_lock is not None and existing_lock > now) else None

            valid_timestamps.append(now)
            self._failures[norm_key] = valid_timestamps

            is_locked = False
            retry_after = 0
            if len(valid_timestamps) >= self.max_attempts:
                if lockout_until is None or lockout_until <= now:
                    lockout_until = now + self.lockout_seconds
                self._lockouts[norm_key] = lockout_until
                is_locked = True
                retry_after = max(1, int(lockout_until - now) + 1)
            elif lockout_until is not None:
                self._lockouts[norm_key] = lockout_until
                is_locked = True
                retry_after = max(1, int(lockout_until - now) + 1)

            persisted_ts = list(valid_timestamps)

        self._write_shared_state(norm_key, persisted_ts, lockout_until, now)
        return is_locked, retry_after

    def reset(self, key: Optional[str]) -> None:
        """
        Clears failure counts and active lockout for a key (called on successful authentication).
        """
        if not key:
            return
        norm_key = str(key).strip().lower()
        with self._lock:
            self._failures.pop(norm_key, None)
            self._lockouts.pop(norm_key, None)
        self._delete_shared_state(norm_key)

    def clear_all(self) -> None:
        """Resets all L1 rate limits and lockouts (primarily for testing)."""
        with self._lock:
            self._failures.clear()
            self._lockouts.clear()


# Global Singleton Rate Limiter
_GLOBAL_AUTH_RATE_LIMITER = AuthenticationRateLimiter()


def get_auth_rate_limiter() -> AuthenticationRateLimiter:
    return _GLOBAL_AUTH_RATE_LIMITER


class FinancialRateLimiter:
    """
    Sliding-window concurrency & rapid double-click protector for mission-critical
    financial mutation endpoints (repayments, disbursements, savings, adjustments).
    Complies with Strict Zero-Emoji Governance.
    """

    def __init__(self, max_requests: int = 10, window_seconds: float = 5.0):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self._lock = threading.Lock()
        self._requests: Dict[str, List[float]] = {}

    def check_rate_limit(self, key: Optional[str]) -> Tuple[bool, int]:
        """
        Checks if the caller has exceeded the allowable financial submission burst rate.
        Returns: (is_limited, retry_after_seconds)
        """
        if not key:
            return False, 0
        norm_key = str(key).strip().lower()
        now = time.monotonic()

        with self._lock:
            timestamps = self._requests.get(norm_key, [])
            cutoff = now - self.window_seconds
            valid_timestamps = [ts for ts in timestamps if ts > cutoff]

            if len(valid_timestamps) >= self.max_requests:
                oldest = valid_timestamps[0]
                retry_after = max(1, int(self.window_seconds - (now - oldest)) + 1)
                return True, retry_after

            valid_timestamps.append(now)
            self._requests[norm_key] = valid_timestamps
            return False, 0

    def clear_all(self) -> None:
        """Resets all records (for testing)."""
        with self._lock:
            self._requests.clear()


_GLOBAL_FINANCIAL_RATE_LIMITER = FinancialRateLimiter()


def get_financial_rate_limiter() -> FinancialRateLimiter:
    return _GLOBAL_FINANCIAL_RATE_LIMITER


def extract_client_ip(request: Request) -> str:
    """Extracts client IP address safely, checking proxy headers."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        # First IP in comma-separated list
        return forwarded.split(",")[0].strip()
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()
    if request.client and request.client.host:
        return request.client.host.strip()
    return "127.0.0.1"
