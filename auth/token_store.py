"""
auth/token_store.py
Thread-safe Token Revocation and Session Invalidation Store for ICARE Core Banking.
Complies with Strict Zero-Emoji Governance.
"""
import hashlib
import threading
import time
from typing import Dict, Optional


class TokenRevocationStore:
    """
    In-memory store for revoked session tokens and administrative user session revocations.
    """
    def __init__(self):
        self._lock = threading.Lock()
        # token_hash -> expiration monotonic timestamp
        self._revoked_tokens: Dict[str, float] = {}
        # user_id -> revocation epoch timestamp (tokens issued prior to this epoch are invalid)
        self._revoked_users: Dict[str, float] = {}

    @staticmethod
    def _hash_token(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    def revoke_token(self, token: str, ttl_seconds: float = 604800.0) -> None:
        """
        Revokes a specific session token until its maximum lifetime expires.
        """
        if not token:
            return
        thash = self._hash_token(token)
        now = time.monotonic()
        with self._lock:
            self._revoked_tokens[thash] = now + ttl_seconds
            self._prune_expired(now)

    def is_token_revoked(self, token: str) -> bool:
        """
        Returns True if the specific token has been explicitly revoked.
        """
        if not token:
            return True
        thash = self._hash_token(token)
        now = time.monotonic()
        with self._lock:
            exp = self._revoked_tokens.get(thash)
            if exp is not None:
                if now < exp:
                    return True
                del self._revoked_tokens[thash]
        return False

    def revoke_user_sessions(self, user_id: str) -> None:
        """
        Revokes all active sessions for a user issued before the current timestamp.
        """
        if not user_id:
            return
        uid = str(user_id).strip().lower()
        now_epoch = time.time()
        with self._lock:
            self._revoked_users[uid] = now_epoch

    def is_user_revoked(self, user_id: str, token_timestamp: float) -> bool:
        """
        Returns True if a user-level revocation was issued after the token was generated.
        """
        if not user_id:
            return False
        uid = str(user_id).strip().lower()
        with self._lock:
            revocation_epoch = self._revoked_users.get(uid)
            if revocation_epoch is not None:
                return token_timestamp <= revocation_epoch
        return False

    def _prune_expired(self, now: float) -> None:
        expired_keys = [k for k, exp in self._revoked_tokens.items() if now >= exp]
        for k in expired_keys:
            del self._revoked_tokens[k]

    def clear_all(self) -> None:
        """Resets all revocations (used in tests)."""
        with self._lock:
            self._revoked_tokens.clear()
            self._revoked_users.clear()


# Global Singleton Store
_GLOBAL_REVOCATION_STORE = TokenRevocationStore()


def get_revocation_store() -> TokenRevocationStore:
    return _GLOBAL_REVOCATION_STORE
