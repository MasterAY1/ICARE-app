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
        or SUPABASE_URL
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
        or SUPABASE_SERVICE_ROLE_KEY
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
            or SUPABASE_KEY
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
    def handle_request(self, request: httpx.Request) -> httpx.Response:
        max_retries = 3
        for attempt in range(max_retries):
            try:
                return super().handle_request(request)
            except (httpx.ConnectError, httpx.TimeoutException, httpx.RemoteProtocolError):
                if attempt == max_retries - 1:
                    raise
                time.sleep(0.5 * (attempt + 1))


def get_supabase_client() -> Client:
    """
    Instantiates an authenticated Supabase client using authoritatively resolved credentials.
    """
    url, key, _ = resolve_supabase_credentials()
    transport = RetryingHTTPTransport(retries=3)
    http_client = httpx.Client(http2=False, timeout=60.0, transport=transport)
    opts = SyncClientOptions(httpx_client=http_client)
    return create_client(url, key, options=opts)


if st and hasattr(st, "cache_resource"):
    get_supabase_client = st.cache_resource(get_supabase_client)

supabase = get_supabase_client()
