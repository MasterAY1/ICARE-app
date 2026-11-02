"""
services/rate_limiter.py
Thread-safe sliding-window authentication rate limiter for ICARE Core Banking.
Protects login and MFA challenge endpoints against credential stuffing and brute-force attacks.
Complies with Strict Zero-Emoji Governance.
"""
import threading
import time
from typing import Dict, List, Tuple, Optional
from fastapi import Request


class AuthenticationRateLimiter:
    """
    In-memory sliding-window rate limiter with lockout period.
    Tracks failed authentication timestamps per key (IP address and normalized username).
    """
    def __init__(
        self,
        max_attempts: int = 5,
        window_seconds: int = 300,       # 5-minute sliding window
        lockout_seconds: int = 900       # 15-minute lockout period
    ):
        self.max_attempts = max_attempts
        self.window_seconds = window_seconds
        self.lockout_seconds = lockout_seconds
        self._lock = threading.Lock()
        # key -> list of failed timestamps
        self._failures: Dict[str, List[float]] = {}
        # key -> lockout expiration timestamp
        self._lockouts: Dict[str, float] = {}

    def is_locked_out(self, key: Optional[str]) -> Tuple[bool, int]:
        """
        Checks whether the specified key is currently locked out.
        Returns: (is_locked, retry_after_seconds)
        """
        if not key:
            return False, 0
        norm_key = str(key).strip().lower()
        now = time.monotonic()

        with self._lock:
            # 1. Check existing lockout
            lockout_until = self._lockouts.get(norm_key)
            if lockout_until is not None:
                if now < lockout_until:
                    retry_after = int(lockout_until - now) + 1
                    return True, retry_after
                else:
                    # Lockout expired
                    del self._lockouts[norm_key]
                    self._failures.pop(norm_key, None)

            # 2. Prune old failures outside window
            timestamps = self._failures.get(norm_key, [])
            cutoff = now - self.window_seconds
            valid_timestamps = [ts for ts in timestamps if ts > cutoff]
            self._failures[norm_key] = valid_timestamps

            if len(valid_timestamps) >= self.max_attempts:
                # Trigger lockout
                self._lockouts[norm_key] = now + self.lockout_seconds
                return True, self.lockout_seconds

            return False, 0

    def record_failure(self, key: Optional[str]) -> Tuple[bool, int]:
        """
        Records a failed authentication attempt.
        Returns: (is_locked, retry_after_seconds)
        """
        if not key:
            return False, 0
        norm_key = str(key).strip().lower()
        now = time.monotonic()

        with self._lock:
            timestamps = self._failures.get(norm_key, [])
            cutoff = now - self.window_seconds
            valid_timestamps = [ts for ts in timestamps if ts > cutoff]
            valid_timestamps.append(now)
            self._failures[norm_key] = valid_timestamps

            if len(valid_timestamps) >= self.max_attempts:
                self._lockouts[norm_key] = now + self.lockout_seconds
                return True, self.lockout_seconds

            return False, 0

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

    def clear_all(self) -> None:
        """Resets all rate limits and lockouts (primarily for testing)."""
        with self._lock:
            self._failures.clear()
            self._lockouts.clear()


# Global Singleton Rate Limiter
_GLOBAL_AUTH_RATE_LIMITER = AuthenticationRateLimiter()


def get_auth_rate_limiter() -> AuthenticationRateLimiter:
    return _GLOBAL_AUTH_RATE_LIMITER


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
