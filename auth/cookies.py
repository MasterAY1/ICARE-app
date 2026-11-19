"""
auth/cookies.py
HttpOnly Session Cookie and Double-Submit CSRF Token Helpers for ICARE Core Banking Web Client.
Complies with Strict Zero-Emoji Governance.
"""
import os
import secrets
from typing import Optional
from fastapi import Request, Response

SESSION_COOKIE_NAME = "icare_session"
CSRF_COOKIE_NAME = "icare_csrf"
CSRF_HEADER_NAME = "X-CSRF-Token"
AUTH_MODE_HEADER = "X-Auth-Mode"
SESSION_COOKIE_MAX_AGE = 7 * 24 * 60 * 60


def is_https_request(request: Optional[Request]) -> bool:
    """
    Determines whether the incoming request arrived over HTTPS (directly or via proxy)
    or is running in production mode.
    """
    if request is not None:
        forwarded_proto = (request.headers.get("x-forwarded-proto") or "").split(",")[0].strip().lower()
        if forwarded_proto == "https":
            return True
        try:
            if request.url.scheme.lower() == "https":
                return True
        except Exception:
            pass
    return os.getenv("ENVIRONMENT", "").strip().lower() == "production"


def is_cookie_auth_mode(request: Optional[Request]) -> bool:
    """
    Returns True when the caller explicitly requests HttpOnly cookie session mode (Flutter Web).
    Mobile/CLI callers omit this header and receive the Bearer token in JSON.
    """
    if request is None:
        return False
    return (request.headers.get("x-auth-mode") or "").strip().lower() == "cookie"


def _cookie_security_attrs(request: Optional[Request]) -> dict:
    secure = is_https_request(request)
    samesite = "none" if secure else "lax"
    return {"secure": secure, "samesite": samesite}


def set_auth_cookies(response: Response, request: Optional[Request], session_token: str) -> str:
    """
    Sets HttpOnly session cookie (`icare_session`) and readable double-submit CSRF cookie (`icare_csrf`).
    Returns the issued CSRF token string.
    """
    csrf_token = secrets.token_urlsafe(32)
    attrs = _cookie_security_attrs(request)

    response.set_cookie(
        key=SESSION_COOKIE_NAME,
        value=session_token,
        max_age=SESSION_COOKIE_MAX_AGE,
        path="/",
        httponly=True,
        secure=attrs["secure"],
        samesite=attrs["samesite"],
    )
    response.set_cookie(
        key=CSRF_COOKIE_NAME,
        value=csrf_token,
        max_age=SESSION_COOKIE_MAX_AGE,
        path="/",
        httponly=False,
        secure=attrs["secure"],
        samesite=attrs["samesite"],
    )
    return csrf_token


def ensure_csrf_cookie(response: Response, request: Optional[Request]) -> str:
    """
    Reuses existing non-empty CSRF cookie if present, otherwise issues a new one.
    """
    if request is not None:
        existing = (request.cookies.get(CSRF_COOKIE_NAME) or "").strip()
        if existing:
            return existing

    csrf_token = secrets.token_urlsafe(32)
    attrs = _cookie_security_attrs(request)
    response.set_cookie(
        key=CSRF_COOKIE_NAME,
        value=csrf_token,
        max_age=SESSION_COOKIE_MAX_AGE,
        path="/",
        httponly=False,
        secure=attrs["secure"],
        samesite=attrs["samesite"],
    )
    return csrf_token


def clear_auth_cookies(response: Response, request: Optional[Request]) -> None:
    """
    Clears HttpOnly session and CSRF cookies from the browser.
    """
    attrs = _cookie_security_attrs(request)
    response.delete_cookie(
        key=SESSION_COOKIE_NAME,
        path="/",
        secure=attrs["secure"],
        samesite=attrs["samesite"],
    )
    response.delete_cookie(
        key=CSRF_COOKIE_NAME,
        path="/",
        secure=attrs["secure"],
        samesite=attrs["samesite"],
    )
