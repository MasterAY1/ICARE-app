"""
auth/token_store.py
Thread-safe Durable Token Revocation and Session Invalidation Store for ICARE Core Banking.
Persists revocations to Supabase PostgreSQL so revocations survive backend restarts and
remain consistent across multiple backend instances, with an L1 in-memory cache and
fail-closed read semantics. Complies with Strict Zero-Emoji Governance.
"""
from datetime import datetime, timedelta, timezone
import hashlib
import logging
import os
import threading
import time
from typing import Any, Callable, Dict, Optional

logger = logging.getLogger("icare.auth.token_store")


class TokenRevocationStore:
    """
    Durable store for revoked session/challenge tokens and user-wide session revocations.
    Uses PostgreSQL (`revoked_tokens`, `user_session_revocations`) as the shared authoritative
    backing store when persistence is enabled, fronted by a bounded thread-safe L1 memory cache.
    In `ENVIRONMENT=test` without an explicit client_provider, operates in fast in-memory mode.
    """

    def __init__(self, client_provider: Optional[Callable[[], Any]] = None):
        self._lock = threading.Lock()
        self._client_provider = client_provider
        # token_hash -> expiration monotonic timestamp (L1 cache)
        self._revoked_tokens: Dict[str, float] = {}
        # user_id -> revocation epoch timestamp (tokens issued <= epoch are invalid)
        self._revoked_users: Dict[str, float] = {}

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
    def _hash_token(token: str) -> str:
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    @staticmethod
    def _parse_iso_timestamp(value: Any) -> datetime:
        if isinstance(value, datetime):
            dt = value
        else:
            raw = str(value).strip()
            if raw.endswith("Z"):
                raw = raw[:-1] + "+00:00"
            dt = datetime.fromisoformat(raw)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)

    def revoke_token(
        self,
        token: str,
        ttl_seconds: float = 604800.0,
        user_id: Optional[str] = None,
    ) -> None:
        """
        Revokes a specific session or challenge token until its maximum lifetime expires.
        """
        if not token:
            return
        thash = self._hash_token(token)
        ttl = max(float(ttl_seconds), 1.0)
        now_mono = time.monotonic()
        with self._lock:
            self._revoked_tokens[thash] = now_mono + ttl
            self._prune_expired(now_mono)

        if self._is_persistence_enabled():
            now_utc = datetime.now(timezone.utc)
            exp_utc = now_utc + timedelta(seconds=ttl)
            clean_uid = str(user_id).strip().lower() if user_id else None
            try:
                client = self._get_client()
                client.table("revoked_tokens").upsert(
                    {
                        "token_hash": thash,
                        "user_id": clean_uid,
                        "revoked_at": now_utc.isoformat(),
                        "expires_at": exp_utc.isoformat(),
                    },
                    on_conflict="token_hash",
                ).execute()
            except Exception as exc:
                logger.error("Failed to persist token revocation: %s", exc)
                raise RuntimeError("Failed to persist token revocation.") from exc

    def is_token_revoked(self, token: str) -> bool:
        """
        Returns True if the specific token has been explicitly revoked.
        Fails closed (returns True) if shared persistence lookup fails.
        """
        if not token:
            return True
        thash = self._hash_token(token)
        now_mono = time.monotonic()
        with self._lock:
            exp = self._revoked_tokens.get(thash)
            if exp is not None:
                if now_mono < exp:
                    return True
                del self._revoked_tokens[thash]

        if self._is_persistence_enabled():
            try:
                client = self._get_client()
                res = (
                    client.table("revoked_tokens")
                    .select("expires_at")
                    .eq("token_hash", thash)
                    .limit(1)
                    .execute()
                )
                rows = getattr(res, "data", None) or []
                if rows:
                    row = rows[0] if isinstance(rows[0], dict) else {}
                    exp_raw = row.get("expires_at")
                    if not exp_raw:
                        return True
                    exp_dt = self._parse_iso_timestamp(exp_raw)
                    now_utc = datetime.now(timezone.utc)
                    remaining = (exp_dt - now_utc).total_seconds()
                    if remaining > 0:
                        with self._lock:
                            self._revoked_tokens[thash] = time.monotonic() + remaining
                        return True
            except Exception as exc:
                logger.error("Failed to verify durable token revocation (failing closed): %s", exc)
                return True

        return False

    def revoke_user_sessions(self, user_id: str) -> float:
        """
        Revokes all active sessions for a user issued at or before the returned epoch timestamp.
        """
        if not user_id:
            return 0.0
        uid = str(user_id).strip().lower()
        now_utc = datetime.now(timezone.utc)
        now_epoch = now_utc.timestamp()
        with self._lock:
            existing = self._revoked_users.get(uid)
            if existing is not None and existing > now_epoch:
                now_epoch = existing
                now_utc = datetime.fromtimestamp(now_epoch, tz=timezone.utc)
            self._revoked_users[uid] = now_epoch

        if self._is_persistence_enabled():
            try:
                client = self._get_client()
                client.table("user_session_revocations").upsert(
                    {
                        "user_id": uid,
                        "revoked_before": now_utc.isoformat(),
                        "updated_at": now_utc.isoformat(),
                    },
                    on_conflict="user_id",
                ).execute()
            except Exception as exc:
                logger.error("Failed to persist user session revocation for %s: %s", uid, exc)
                raise RuntimeError("Failed to persist user session revocation.") from exc

        return now_epoch

    def get_user_revocation_epoch(self, user_id: str) -> Optional[float]:
        """
        Returns the highest recorded user-level revocation epoch timestamp, or None.
        Raises on persistence query error so verification callers can fail closed.
        """
        if not user_id:
            return None
        uid = str(user_id).strip().lower()
        with self._lock:
            local_epoch = self._revoked_users.get(uid)

        if self._is_persistence_enabled():
            client = self._get_client()
            res = (
                client.table("user_session_revocations")
                .select("revoked_before")
                .eq("user_id", uid)
                .limit(1)
                .execute()
            )
            rows = getattr(res, "data", None) or []
            if rows:
                row = rows[0] if isinstance(rows[0], dict) else {}
                rev_raw = row.get("revoked_before")
                if rev_raw:
                    db_epoch = self._parse_iso_timestamp(rev_raw).timestamp()
                    effective = max(local_epoch, db_epoch) if local_epoch is not None else db_epoch
                    with self._lock:
                        prev = self._revoked_users.get(uid)
                        if prev is None or effective > prev:
                            self._revoked_users[uid] = effective
                    return effective

        return local_epoch

    def is_user_revoked(self, user_id: str, token_timestamp: float) -> bool:
        """
        Returns True if a user-level revocation was issued at or after the token was generated.
        Fails closed (returns True) if shared persistence lookup fails.
        """
        if not user_id:
            return False
        uid = str(user_id).strip().lower()
        with self._lock:
            local_epoch = self._revoked_users.get(uid)
            if local_epoch is not None and token_timestamp <= local_epoch:
                return True

        if self._is_persistence_enabled():
            try:
                effective_epoch = self.get_user_revocation_epoch(uid)
                if effective_epoch is not None:
                    return token_timestamp <= effective_epoch
            except Exception as exc:
                logger.error("Failed to verify durable user revocation for %s (failing closed): %s", uid, exc)
                return True

        return False

    def _prune_expired(self, now: float) -> None:
        expired_keys = [k for k, exp in self._revoked_tokens.items() if now >= exp]
        for k in expired_keys:
            del self._revoked_tokens[k]

    def clear_all(self) -> None:
        """Resets L1 in-memory revocations (used in tests)."""
        with self._lock:
            self._revoked_tokens.clear()
            self._revoked_users.clear()


# Global Singleton Store
_GLOBAL_REVOCATION_STORE = TokenRevocationStore()


def get_revocation_store() -> TokenRevocationStore:
    return _GLOBAL_REVOCATION_STORE
