"""
ICARE Core Banking - Multi-Factor Authentication (MFA / TOTP)
Implements standard RFC 6238 Time-Based One-Time Password (TOTP) and RFC 4226 HMAC-based OTP.
Pure standard-library implementation with zero external supply-chain dependencies.

Complies with:
- RFC 6238: TOTP Time-Based One-Time Password Algorithm (SHA-1, 30s step, 6 digits)
- RFC 4226: HOTP An HMAC-Based One-Time Password Algorithm
- Strict Zero-Emoji Governance
- Cryptographic replay protection with thread-safe sliding window cache
"""
import base64
import hashlib
import hmac
import logging
import os
import secrets
import struct
import threading
import time
from datetime import datetime
from typing import Any, Callable, Dict, List, Optional, Tuple
from urllib.parse import quote

from auth.session import get_auth_secret

logger = logging.getLogger("icare.auth.mfa")


class MFAReplayStore:
    """
    Thread-safe distributed TOTP replay protection store.
    Uses PostgreSQL atomic nonce insertion (`consume_mfa_totp_nonce` RPC) when
    persistence is enabled, fronted by an L1 cache. Fails closed on DB failure.
    """

    def __init__(self, client_provider: Optional[Callable[[], Any]] = None):
        self._client_provider = client_provider
        self._lock = threading.Lock()
        self._cache: Dict[str, float] = {}

    def _is_persistence_enabled(self) -> bool:
        if self._client_provider is not None:
            return True
        return os.getenv("ENVIRONMENT", "").strip().lower() != "test"

    def _get_client(self) -> Any:
        if self._client_provider is not None:
            return self._client_provider()
        from database.connection import get_supabase_client
        return get_supabase_client()

    def check_and_record(
        self,
        user_id: str,
        counter: int,
        now: float,
        ttl_seconds: int = 90,
    ) -> bool:
        """
        Checks if a (user_id, counter) TOTP step was already consumed.
        Returns True if already replayed (reject), False if fresh (recorded).
        """
        clean_uid = str(user_id).strip().lower()
        key = f"{clean_uid}:{counter}"
        with self._lock:
            expired_keys = [k for k, exp in self._cache.items() if exp < now]
            for k in expired_keys:
                del self._cache[k]
            if key in self._cache:
                return True

        if self._is_persistence_enabled():
            try:
                client = self._get_client()
                res = client.rpc(
                    "consume_mfa_totp_nonce",
                    {
                        "p_replay_key": key,
                        "p_user_id": clean_uid,
                        "p_ttl_seconds": int(ttl_seconds),
                    },
                ).execute()
                data = getattr(res, "data", None)
                if data is True:
                    with self._lock:
                        self._cache[key] = now + float(ttl_seconds)
                    return False
                if data is False:
                    with self._lock:
                        self._cache[key] = now + float(ttl_seconds)
                    return True
                logger.error("Unexpected consume_mfa_totp_nonce response %r (failing closed).", data)
                return True
            except Exception as exc:
                logger.error("Distributed MFA replay verification failed (failing closed): %s", exc)
                return True

        with self._lock:
            self._cache[key] = now + float(ttl_seconds)
            return False

    def clear_all(self) -> None:
        with self._lock:
            self._cache.clear()


_GLOBAL_MFA_REPLAY_STORE = MFAReplayStore()


def get_mfa_replay_store() -> MFAReplayStore:
    return _GLOBAL_MFA_REPLAY_STORE


def generate_totp_secret() -> str:
    """
    Generates a cryptographically secure 160-bit (20-byte) Base32 secret string.
    Compatible with Google Authenticator, Microsoft Authenticator, and 1Password.
    """
    random_bytes = secrets.token_bytes(20)
    return base64.b32encode(random_bytes).decode("utf-8").rstrip("=")


def _decode_b32_secret(secret_b32: str) -> bytes:
    """Safely decodes a Base32 secret with casefolding and missing padding correction."""
    cleaned = secret_b32.strip().upper().replace(" ", "")
    missing_padding = len(cleaned) % 8
    if missing_padding != 0:
        cleaned += "=" * (8 - missing_padding)
    return base64.b32decode(cleaned, casefold=True)


def _compute_totp_for_counter(secret_bytes: bytes, counter: int, digits: int = 6) -> str:
    """Calculates RFC 4226 HOTP code for a given 64-bit integer counter."""
    msg = struct.pack(">Q", counter)
    digest = hmac.new(secret_bytes, msg, hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    binary_code = struct.unpack(">I", digest[offset:offset + 4])[0] & 0x7FFFFFFF
    otp = binary_code % (10 ** digits)
    return f"{otp:0{digits}d}"


def generate_totp_code(
    secret_b32: str,
    timestamp: Optional[float] = None,
    step: int = 30,
    digits: int = 6
) -> str:
    """
    Generates the current RFC 6238 TOTP code for the specified secret and timestamp.
    Defaults to current system wall-clock time, 30-second step, and 6 digits.
    """
    secret_bytes = _decode_b32_secret(secret_b32)
    ts = time.time() if timestamp is None else float(timestamp)
    counter = int(ts // step)
    return _compute_totp_for_counter(secret_bytes, counter, digits=digits)


def _check_and_record_replay(user_id: str, counter: int, now: float) -> bool:
    """
    Checks if a (user_id, counter) pair was already consumed.
    Returns True if already replayed (consumption rejected), False if fresh (consumption recorded).
    """
    return _GLOBAL_MFA_REPLAY_STORE.check_and_record(user_id, counter, now, ttl_seconds=90)


def clear_replay_cache() -> None:
    """Clears the L1 in-memory replay cache (primarily for automated test teardown)."""
    _GLOBAL_MFA_REPLAY_STORE.clear_all()


def verify_totp_code(
    secret_b32: str,
    code: str,
    window: int = 1,
    timestamp: Optional[float] = None,
    user_id: Optional[str] = None
) -> bool:
    """
    Verifies a user-supplied 6-digit TOTP code against the secret within +/- window steps.
    Window of 1 covers [-30s, +30s] clock drift.
    Includes replay protection when user_id is provided.
    """
    if not code:
        return False

    clean_code = str(code).strip().replace(" ", "").replace("-", "")
    if not (clean_code.isdigit() and len(clean_code) == 6):
        return False

    try:
        secret_bytes = _decode_b32_secret(secret_b32)
    except Exception:
        return False

    ts = time.time() if timestamp is None else float(timestamp)
    current_counter = int(ts // 30)

    for offset in range(-window, window + 1):
        counter = current_counter + offset
        expected_code = _compute_totp_for_counter(secret_bytes, counter, digits=6)
        if hmac.compare_digest(clean_code, expected_code):
            if user_id:
                if _check_and_record_replay(user_id, counter, ts):
                    # Code was already consumed in this time window
                    return False
            return True

    return False


def generate_backup_codes(count: int = 8) -> List[str]:
    """
    Generates cryptographically random backup recovery codes formatted as 'XXXX-XXXX'.
    """
    codes: List[str] = []
    for _ in range(count):
        hex_val = secrets.token_hex(4).upper()
        codes.append(f"{hex_val[:4]}-{hex_val[4:]}")
    return codes


def hash_backup_code(code: str) -> str:
    """Computes a SHA-256 hash of a normalized backup code."""
    normalized = code.replace("-", "").strip().upper()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def verify_and_consume_backup_code(
    code: str,
    hashed_codes: List[str]
) -> Tuple[bool, List[str]]:
    """
    Verifies whether a backup code matches one of the stored hashes.
    If matched, returns (True, remaining_hashed_codes) with the matched code consumed.
    If not matched, returns (False, unchanged_hashed_codes).
    """
    if not code or not hashed_codes:
        return False, hashed_codes

    candidate_hash = hash_backup_code(code)
    for idx, stored_hash in enumerate(hashed_codes):
        if hmac.compare_digest(candidate_hash, stored_hash):
            remaining = [h for j, h in enumerate(hashed_codes) if j != idx]
            return True, remaining

    return False, hashed_codes


def generate_otpauth_uri(
    username: str,
    secret_b32: str,
    issuer: str = "ICARE Core Banking"
) -> str:
    """
    Generates a standard RFC 6238 otpauth:// URI for scanning with authenticator apps.
    """
    cleaned_secret = secret_b32.strip().upper().replace(" ", "").rstrip("=")
    label = quote(f"{issuer}:{username}")
    issuer_param = quote(issuer)
    return (
        f"otpauth://totp/{label}"
        f"?secret={cleaned_secret}&issuer={issuer_param}&algorithm=SHA1&digits=6&period=30"
    )


def generate_mfa_challenge_token(
    user_id: str,
    username: str,
    expires_in_seconds: int = 300
) -> str:
    """
    Generates an HMAC-SHA256 signed temporary MFA challenge token.
    Valid for expires_in_seconds (default 5 minutes).
    Cannot be used as an Authorization Bearer token.
    """
    secret = get_auth_secret()
    timestamp = int(datetime.now().timestamp())
    payload_str = f"mfa:{user_id}:{username}:{timestamp}:{expires_in_seconds}"
    signature = hmac.new(
        secret.encode("utf-8"),
        payload_str.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()
    raw_token = f"{payload_str}:{signature}"
    return base64.urlsafe_b64encode(raw_token.encode("utf-8")).decode("utf-8")


def validate_mfa_challenge_token(token_str: str) -> Optional[dict]:
    """
    Validates an MFA challenge token signature and expiry.
    Returns dict with user_id, username, timestamp if valid, else None.
    """
    if not token_str:
        return None

    secret = get_auth_secret()
    try:
        raw_token = base64.urlsafe_b64decode(token_str.encode("utf-8")).decode("utf-8")
        parts = raw_token.split(":")
        if len(parts) != 6:
            return None

        tag, user_id, username, ts_str, exp_str, sig = parts
        if tag != "mfa":
            return None

        payload_str = f"mfa:{user_id}:{username}:{ts_str}:{exp_str}"
        expected_sig = hmac.new(
            secret.encode("utf-8"),
            payload_str.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(sig, expected_sig):
            return None

        ts = int(ts_str)
        exp = int(exp_str)
        now = datetime.now().timestamp()
        if now - ts > exp or now - ts < -30:
            return None

        from auth.token_store import get_revocation_store
        if get_revocation_store().is_token_revoked(token_str):
            return None

        return {
            "user_id": user_id,
            "username": username,
            "timestamp": ts,
        }
    except Exception:
        return None
