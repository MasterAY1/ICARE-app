import os
import json
import base64
from typing import Optional, Tuple

try:
    import streamlit as st
except ImportError:
    st = None

from supabase import create_client, Client
from config.settings import (
    SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY,
    SUPABASE_KEY,
    ENVIRONMENT,
    IS_PRODUCTION
)

import httpx
import time
from supabase.lib.client_options import SyncClientOptions


def is_production() -> bool:
    """
    Returns True if the backend is operating in a production environment
    (e.g. deployed on Render or explicit ENVIRONMENT/APP_ENV set to production/prod).
    """
    env = (os.getenv("ENVIRONMENT") or os.getenv("APP_ENV") or ENVIRONMENT or "").strip().lower()
    if env in ("production", "prod"):
        return True
    if os.getenv("RENDER") or os.getenv("RENDER_SERVICE_ID"):
        return True
    return False


def get_jwt_role(token: str) -> Optional[str]:
    """
    Safely inspects the 'role' claim in a Supabase JWT without verifying signatures or logging secrets.
    Returns the role string (e.g. 'anon', 'service_role') or None if unparseable/non-JWT.
    """
    if not token or not isinstance(token, str):
        return None
    try:
        parts = token.strip().split(".")
        if len(parts) >= 2:
            payload_b64 = parts[1]
            payload_b64 += "=" * ((4 - len(payload_b64) % 4) % 4)
            claims = json.loads(base64.urlsafe_b64decode(payload_b64))
            return claims.get("role")
    except Exception:
        pass
    return None


def _get_st_secret(key_name: str) -> Optional[str]:
    """Safely retrieves a Streamlit secret without throwing if the secrets file is missing."""
    if st and hasattr(st, "secrets"):
        try:
            val = st.secrets.get(key_name)
            if val is not None and str(val).strip():
                return str(val).strip()
        except Exception:
            return None
    return None


def resolve_supabase_credentials() -> Tuple[str, str, str]:
    """
    Authoritatively resolves the Supabase URL and backend database credential.
    
    Security Invariants:
    1. In PRODUCTION:
       - SUPABASE_SERVICE_ROLE_KEY is mandatory.
       - Accidental or silent fallback to the public anon key (SUPABASE_KEY) is strictly prohibited.
       - If SUPABASE_SERVICE_ROLE_KEY is missing, empty, or carries an 'anon' JWT role,
         this function fails closed with a clear, non-sensitive RuntimeError.
    2. In DEVELOPMENT / TESTING:
       - Prefers SUPABASE_SERVICE_ROLE_KEY if configured.
       - If SUPABASE_SERVICE_ROLE_KEY is absent, permits fallback to SUPABASE_KEY to preserve
         backward compatibility with local developer test fixtures and Streamlit secrets.
         
    Returns:
        (url, resolved_key, key_source_identifier)
    """
    # 1. Resolve URL
    url = (
        os.getenv("SUPABASE_URL", "").strip()
        or _get_st_secret("SUPABASE_URL")
    )
    if not url:
        if is_production():
            raise RuntimeError(
                "CRITICAL SECURITY CONFIGURATION ERROR: SUPABASE_URL is missing or empty. "
                "Backend cannot establish database connection in production."
            )
        else:
            raise ValueError("Database configuration is missing: SUPABASE_URL is not set.")

    in_prod = is_production()

    # 2. Check for explicit SUPABASE_SERVICE_ROLE_KEY
    srv_key = (
        os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        or _get_st_secret("SUPABASE_SERVICE_ROLE_KEY")
    )

    if in_prod:
        # PRODUCTION ENFORCEMENT
        if not srv_key:
            raise RuntimeError(
                "CRITICAL SECURITY CONFIGURATION ERROR: SUPABASE_SERVICE_ROLE_KEY is required in "
                "production but is not configured. Falling back to the public anon key (SUPABASE_KEY) "
                "is strictly prohibited in production to prevent RLS bypass failures and service outages."
            )

        srv_role = get_jwt_role(srv_key)
        if srv_role == "anon":
            raise RuntimeError(
                "CRITICAL SECURITY CONFIGURATION ERROR: SUPABASE_SERVICE_ROLE_KEY was configured with "
                "a public 'anon' key instead of a privileged service_role key. "
                "Backend cannot operate with a public anon key in production."
            )

        return url, srv_key, "SUPABASE_SERVICE_ROLE_KEY"

    else:
        # DEVELOPMENT / TESTING ENVIRONMENT
        if srv_key:
            srv_role = get_jwt_role(srv_key)
            if srv_role != "anon":
                return url, srv_key, "SUPABASE_SERVICE_ROLE_KEY"

        # Safe backward compatibility fallback in non-production environments only
        dev_key = (
            os.getenv("SUPABASE_KEY", "").strip()
            or _get_st_secret("SUPABASE_KEY")
        )
        if dev_key:
            return url, dev_key, "SUPABASE_KEY"

        raise ValueError(
            "Database configuration is missing. Set SUPABASE_SERVICE_ROLE_KEY or SUPABASE_KEY "
            "in your environment or secrets."
        )


def verify_supabase_credentials() -> None:
    """
    FastAPI startup validation gate. Fails closed immediately if database credentials
    are invalid, missing, or misconfigured for the current environment.
    """
    resolve_supabase_credentials()


class RetryingHTTPTransport(httpx.HTTPTransport):
    """
    Idempotency-safe HTTP transport with connection pooling and circuit breaker protection.
    Prevents duplicate database mutations on server timeouts.
    """
    def __init__(self, retries: int = 3, **kwargs):
        super().__init__(**kwargs)
        self.max_retries = retries

    def handle_request(self, request: httpx.Request) -> httpx.Response:
        from services.circuit_breaker import get_circuit_breaker
        cb = get_circuit_breaker("database")

        is_idempotent = request.method.upper() in ("GET", "HEAD", "OPTIONS")

        for attempt in range(self.max_retries):
            # Check circuit breaker before attempting request
            from services.circuit_breaker import CircuitState, CircuitBreakerOpenException
            if cb.state == CircuitState.OPEN:
                status_dict = cb.get_status()
                raise CircuitBreakerOpenException("database", status_dict.get("remaining_cooldown_seconds", 15.0))

            try:
                response = super().handle_request(request)
                if response.status_code < 500:
                    cb.record_success()
                elif response.status_code in (502, 503, 504):
                    cb.record_failure()
                return response
            except httpx.ConnectError:
                cb.record_failure()
                if attempt == self.max_retries - 1:
                    raise
                time.sleep(0.5 * (2 ** attempt))
            except (httpx.TimeoutException, httpx.RemoteProtocolError):
                cb.record_failure()
                # MUTATION SAFETY INVARIANT: Never blindly retry mutating requests (POST, PUT, DELETE, PATCH)
                # on timeout because the database may have already executed the transaction.
                if not is_idempotent or attempt == self.max_retries - 1:
                    raise
                time.sleep(0.5 * (2 ** attempt))


def get_supabase_client() -> Client:
    """
    Instantiates an authenticated Supabase client using authoritatively resolved credentials,
    strict connection pooling, and circuit breaker-protected HTTP transport.
    """
    url, key, _ = resolve_supabase_credentials()
    pool_limits = httpx.Limits(
        max_keepalive_connections=50,
        max_connections=100,
        keepalive_expiry=60.0
    )
    transport = RetryingHTTPTransport(retries=3, limits=pool_limits)
    http_client = httpx.Client(
        http2=False,
        timeout=60.0,
        transport=transport,
        limits=pool_limits
    )
    opts = SyncClientOptions(httpx_client=http_client)
    return create_client(url, key, options=opts)


if st and hasattr(st, "runtime") and st.runtime.exists() and hasattr(st, "cache_resource"):
    get_supabase_client = st.cache_resource(get_supabase_client)

supabase = get_supabase_client()
