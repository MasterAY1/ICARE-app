"""
Authentication and MFA Route Adapter for ICARE Core Banking.
Reuses SupabaseUnitOfWork, RBACScopeService, and RFC 6238 MFA Service.
Complies with Strict Zero-Emoji Governance.
"""
from datetime import datetime
import io
import re
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Depends, File, HTTPException, Header, Request, Response, UploadFile, status
from PIL import Image, ImageOps

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, CurrentUser
from api.schemas.auth import (
    LoginRequest,
    LoginResponse,
    SessionMeResponse,
    UserInfo,
    MFASetupResponse,
    MFAActivateRequest,
    MFAChallengeRequest,
    MFADisableRequest,
    MFAResetUserRequest,
    MFAStatusResponse,
    GenericMFAActionResponse,
    ChangeInitialPasswordRequest,
    ProfileUpdateRequest,
    ProfileLoginActivityItem,
    ProfileResponse,
    ProfileUpdateResponse,
    AvatarUploadResponse,
    ChangeOwnPasswordRequest,
    ChangeOwnPasswordResponse,
)
from auth.cookies import (
    SESSION_COOKIE_NAME,
    is_cookie_auth_mode,
    set_auth_cookies,
    ensure_csrf_cookie,
    clear_auth_cookies,
)
from auth.password import verify_password, hash_password
from auth.session import (
    generate_session_token,
    generate_password_change_token,
    validate_password_change_token,
)
from auth.session_cache import invalidate_user_session_cache
from auth.token_store import get_revocation_store
from services.rate_limiter import get_auth_rate_limiter, extract_client_ip
from services.rbac_scope_service import RBACScopeService, UnknownRoleError
from auth.mfa import (
    generate_totp_secret,
    verify_totp_code,
    generate_backup_codes,
    hash_backup_code,
    verify_and_consume_backup_code,
    generate_otpauth_uri,
    generate_mfa_challenge_token,
    validate_mfa_challenge_token,
)
from config.roles import ROLE_SUPER_ADMIN, ROLE_ADMIN
from services.audit_log_service import AuditLogService

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])


def _build_user_info(user, uow: SupabaseUnitOfWork) -> UserInfo:
    """Extracts authoritative UserInfo with AM branch assignments, allowed products, and personal profile fields."""
    assigned_branches = []
    assigned_branch_ids = []
    if user.role in ["Area Manager", "AM", "AREA_MANAGER"]:
        try:
            assignments = uow.users.load_am_assignments(user.id)
            assigned_branches = [a["name"] for a in assignments if a.get("name")]
            assigned_branch_ids = [a["branch_id"] for a in assignments if a.get("branch_id")]
        except Exception:
            assigned_branches = []
            assigned_branch_ids = []

    extra = getattr(user, "extra_fields", None)
    if not isinstance(extra, dict):
        extra = {}

    allowed_prods = extra.get("allowed_products", []) or []
    prefs = extra.get("preferences")
    if not isinstance(prefs, dict):
        prefs = {}

    return UserInfo(
        id=user.id,
        username=user.username,
        full_name=user.full_name or user.username,
        role=user.role,
        branch=user.branch_name or "Unknown",
        branch_id=user.branch_id or "",
        assigned_branches=assigned_branches,
        assigned_branch_ids=assigned_branch_ids,
        allowed_products=allowed_prods,
        phone=str(extra.get("phone") or ""),
        email=str(extra.get("email") or ""),
        avatar_url=str(extra.get("avatar_url") or ""),
        bio=str(extra.get("bio") or ""),
        mfa_enabled=bool(extra.get("mfa_enabled", False)),
        is_misc_savings_manager=bool(extra.get("is_misc_savings_manager", False)),
        created_at=user.created_at.isoformat() if getattr(user, "created_at", None) else None,
        last_login=user.last_login.isoformat() if getattr(user, "last_login", None) else None,
        preferences=prefs,
    )


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, request: Request, response: Response, uow: SupabaseUnitOfWork = Depends(get_uow)):
    """
    Authenticates user against app_users.
    If MFA is enabled for the user, issues a short-lived MFA challenge token.
    Otherwise, returns authoritative session token and user profile.
    Protected by IP and username-level sliding window rate limiting.
    """
    username = payload.username.strip()
    password = payload.password
    client_ip = extract_client_ip(request)
    limiter = get_auth_rate_limiter()

    # 1. Enforce rate limiting lockout check
    is_ip_locked, ip_retry = limiter.is_locked_out(client_ip)
    is_user_locked, user_retry = limiter.is_locked_out(username)
    if is_ip_locked or is_user_locked:
        retry_after = max(ip_retry, user_retry)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many failed login attempts. Access temporarily locked. Try again in {retry_after} seconds.",
            headers={"Retry-After": str(retry_after)}
        )

    user = uow.users.find_by_username(username)
    if not user:
        limiter.record_failure(client_ip)
        limiter.record_failure(username)
        AuditLogService.log_login(username, "FAILURE", "User not found")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please try again."
        )

    if not user.is_active:
        AuditLogService.log_login(username, "FAILURE", "Account deactivated")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account is deactivated. Contact administrator."
        )

    if not verify_password(password, user.password_hash):
        limiter.record_failure(client_ip)
        limiter.record_failure(username)
        AuditLogService.log_login(username, "FAILURE", "Invalid password")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please try again."
        )

    # Authentication succeeded: reset rate limit counters
    limiter.reset(client_ip)
    limiter.reset(username)

    extra = user.extra_fields if isinstance(user.extra_fields, dict) else {}

    # Check for first-time password rotation requirement for Management roles
    # (Admin, Super Admin, Area Manager, Branch Manager)
    try:
        normalized_role = RBACScopeService.normalize_role(user.role)
    except UnknownRoleError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account role is unrecognized. Contact administrator."
        )
    is_management = normalized_role in ["Admin", "Area Manager", "Branch Manager"]
    if is_management and extra.get("must_change_password") is True:
        temp_token = generate_password_change_token(user.id, user.username)
        user_info = _build_user_info(user, uow)
        AuditLogService.log_login(username, "PASSWORD_CHANGE_REQUIRED", "Default password detected. First-time rotation required.")
        return LoginResponse(
            access_token=None,
            token_type="Bearer",
            user=user_info,
            mfa_required=False,
            mfa_token=None,
            password_change_required=True,
            temp_token=temp_token,
            message="First-time login detected. You must set a password of your choice before proceeding."
        )

    if extra.get("mfa_enabled") is True:
        # User has MFA enabled: issue MFA challenge token
        mfa_token = generate_mfa_challenge_token(user.id, user.username)
        AuditLogService.log_login(username, "MFA_CHALLENGE", "Primary authentication succeeded; MFA challenge initiated")
        return LoginResponse(
            access_token=None,
            token_type="Bearer",
            user=None,
            mfa_required=True,
            mfa_token=mfa_token,
            password_change_required=False,
            temp_token=None,
        )

    # Standard non-MFA login
    try:
        uow.users.update_last_login(user.id)
    except Exception:
        pass

    AuditLogService.log_login(username, "SUCCESS", "User authenticated successfully")
    token = generate_session_token(user.id, user.username)
    csrf_token = set_auth_cookies(response, request, token)
    user_info = _build_user_info(user, uow)

    return LoginResponse(
        access_token=None if is_cookie_auth_mode(request) else token,
        token_type="Bearer",
        user=user_info,
        mfa_required=False,
        mfa_token=None,
        csrf_token=csrf_token,
    )


@router.post("/mfa/challenge", response_model=LoginResponse)
def mfa_challenge(
    payload: MFAChallengeRequest,
    request: Request,
    response: Response,
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Validates a 6-digit TOTP code or backup code against a temporary MFA challenge token.
    On successful verification, completes login and returns authoritative session token.
    Protected by rate limiting.
    """
    client_ip = extract_client_ip(request)
    limiter = get_auth_rate_limiter()

    is_ip_locked, ip_retry = limiter.is_locked_out(client_ip)
    if is_ip_locked:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many failed verification attempts. Access temporarily locked. Try again in {ip_retry} seconds.",
            headers={"Retry-After": str(ip_retry)}
        )

    token_data = validate_mfa_challenge_token(payload.mfa_token)
    if not token_data:
        limiter.record_failure(client_ip)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="MFA challenge token is invalid or expired. Please log in again."
        )

    user_id = token_data.get("user_id")
    is_user_locked, user_retry = limiter.is_locked_out(user_id)
    if is_user_locked:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many failed verification attempts. Access temporarily locked. Try again in {user_retry} seconds.",
            headers={"Retry-After": str(user_retry)}
        )

    user = uow.users.find_by_id(user_id)
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is inactive or not found."
        )

    extra = dict(user.extra_fields or {})
    if not extra.get("mfa_enabled"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="MFA is not enabled for this user."
        )

    submitted_code = payload.code.strip()
    mfa_secret = extra.get("mfa_secret", "")
    authenticated = False

    # 1. Attempt TOTP verification with replay protection (+/- 30s window)
    if verify_totp_code(mfa_secret, submitted_code, window=1, user_id=user.id):
        authenticated = True
    else:
        # 2. Attempt Backup Code verification (single-use)
        hashed_codes = extra.get("mfa_backup_codes", [])
        matched, remaining_hashes = verify_and_consume_backup_code(submitted_code, hashed_codes)
        if matched:
            authenticated = True
            extra["mfa_backup_codes"] = remaining_hashes
            try:
                uow.users.update_extra_fields(user.id, extra)
                invalidate_user_session_cache(user.id)
            except Exception:
                pass
            AuditLogService.log_user_action(
                action="MFA_BACKUP_CODE_USED",
                target_user_id=user.id,
                display_name=user.username,
                new={"remaining_backup_codes": len(remaining_hashes)},
            )

    if not authenticated:
        limiter.record_failure(client_ip)
        limiter.record_failure(user_id)
        AuditLogService.log_login(user.username, "FAILURE", "Invalid MFA verification code")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid MFA verification code. Check your authenticator app or backup code."
        )

    # Success: reset limiter and consume MFA challenge token (single-use)
    limiter.reset(client_ip)
    limiter.reset(user_id)
    get_revocation_store().revoke_token(payload.mfa_token, ttl_seconds=300.0, user_id=user.id)

    try:
        uow.users.update_last_login(user.id)
    except Exception:
        pass

    AuditLogService.log_login(user.username, "SUCCESS", "User completed MFA authentication successfully")
    token = generate_session_token(user.id, user.username)
    csrf_token = set_auth_cookies(response, request, token)
    user_info = _build_user_info(user, uow)

    return LoginResponse(
        access_token=None if is_cookie_auth_mode(request) else token,
        token_type="Bearer",
        user=user_info,
        mfa_required=False,
        mfa_token=None,
        csrf_token=csrf_token,
    )


@router.get("/me", response_model=SessionMeResponse)
def get_current_session(
    request: Request,
    response: Response,
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Validates active HttpOnly session cookie (or Bearer token) and returns
    the authoritative current user profile and CSRF token for session restoration.
    """
    user_info = UserInfo(
        id=current_user.id,
        username=current_user.username,
        full_name=current_user.full_name or current_user.username,
        role=current_user.role,
        branch=current_user.branch or "Unknown",
        branch_id=current_user.branch_id or "",
        assigned_branches=list(getattr(current_user, "assigned_branches", []) or []),
        assigned_branch_ids=list(getattr(current_user, "assigned_branch_ids", []) or []),
        allowed_products=list(getattr(current_user, "allowed_products", []) or []),
        phone=str(getattr(current_user, "phone", "") or ""),
        email=str(getattr(current_user, "email", "") or ""),
        avatar_url=str(getattr(current_user, "avatar_url", "") or ""),
        bio=str(getattr(current_user, "bio", "") or ""),
        mfa_enabled=bool(getattr(current_user, "mfa_enabled", False)),
        is_misc_savings_manager=bool(getattr(current_user, "is_misc_savings_manager", False)),
        created_at=getattr(current_user, "created_at", None),
        last_login=getattr(current_user, "last_login", None),
        preferences=dict(getattr(current_user, "preferences", {}) or {}),
    )
    csrf_token = ensure_csrf_cookie(response, request)
    return SessionMeResponse(
        authenticated=True,
        user=user_info,
        csrf_token=csrf_token,
    )


@router.post("/logout")
def logout(
    request: Request,
    response: Response,
    authorization: Optional[str] = Header(None),
    current_user: CurrentUser = Depends(get_current_user),
):
    """
    Explicitly revokes the caller's active session token (Bearer or HttpOnly cookie),
    clears auth cookies, and purges the user session cache.
    Complies with Strict Zero-Emoji Governance.
    """
    token = ""
    if authorization:
        token = authorization.replace("Bearer ", "").strip()
    elif request is not None and request.cookies.get(SESSION_COOKIE_NAME):
        token = str(request.cookies.get(SESSION_COOKIE_NAME) or "").strip()

    if token:
        get_revocation_store().revoke_token(token, user_id=current_user.id)

    clear_auth_cookies(response, request)
    invalidate_user_session_cache(current_user.id)
    invalidate_user_session_cache(current_user.username)

    AuditLogService.log_user_action(
        action="USER_LOGOUT",
        target_user_id=current_user.id,
        display_name=current_user.username,
        new={"status": "revoked"}
    )
    return {"success": True, "message": "Successfully logged out and session revoked."}


@router.post("/change-initial-password", response_model=LoginResponse)
def change_initial_password(
    payload: ChangeInitialPasswordRequest,
    request: Request,
    response: Response,
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Allows Admin, AM, or BM to change their initial default password on first login.
    Officers cannot call this endpoint; their credentials are controlled by BM/AM.
    Complies with Strict Zero-Emoji Governance.
    """
    token_data = validate_password_change_token(payload.temp_token)
    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Password change token is invalid or expired. Please log in again."
        )

    user_id = token_data.get("user_id")
    user = uow.users.find_by_id(user_id)
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is inactive or not found."
        )

    # Enforce role restriction: only Admin, AM, and BM can self-service rotate initial password
    try:
        normalized_role = RBACScopeService.normalize_role(user.role)
    except UnknownRoleError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account role is unrecognized. Contact administrator."
        )
    if normalized_role not in ["Admin", "Area Manager", "Branch Manager"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Credit Officer passwords must be configured and managed by your supervising Branch Manager or Area Manager."
        )

    # Verify current default password
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current temporary/default password is incorrect."
        )

    # Complexity checks
    new_pw = payload.new_password.strip()
    if len(new_pw) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="New password must be at least 8 characters long."
        )

    if verify_password(new_pw, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password cannot be identical to the current temporary password."
        )

    # Hash and update password
    new_hash = hash_password(new_pw)
    uow.users.update_password(user.username, new_hash)

    # Clear must_change_password flag
    extra = dict(user.extra_fields or {})
    extra["must_change_password"] = False
    extra["password_changed_at"] = datetime.now().isoformat()
    try:
        uow.users.update_extra_fields(user.id, extra)
    except Exception:
        pass

    get_revocation_store().revoke_user_sessions(user.id)
    get_revocation_store().revoke_token(payload.temp_token, ttl_seconds=900.0, user_id=user.id)
    invalidate_user_session_cache(user.id)
    invalidate_user_session_cache(user.username)

    AuditLogService.log_user_action(
        action="INITIAL_PASSWORD_ROTATED",
        target_user_id=user.id,
        display_name=user.username,
        new={"must_change_password": False}
    )

    if extra.get("mfa_enabled") is True:
        mfa_token = generate_mfa_challenge_token(user.id, user.username)
        return LoginResponse(
            access_token=None,
            token_type="Bearer",
            user=None,
            mfa_required=True,
            mfa_token=mfa_token,
            password_change_required=False,
            temp_token=None,
            message="Password updated. Enter your authentication code to complete sign in."
        )

    # Issue authoritative session token
    token = generate_session_token(user.id, user.username)
    csrf_token = set_auth_cookies(response, request, token)
    user_info = _build_user_info(user, uow)

    return LoginResponse(
        access_token=None if is_cookie_auth_mode(request) else token,
        token_type="Bearer",
        user=user_info,
        mfa_required=False,
        mfa_token=None,
        password_change_required=False,
        temp_token=None,
        csrf_token=csrf_token,
        message="Password updated successfully. Session activated."
    )


@router.get("/mfa/status", response_model=MFAStatusResponse)
def get_mfa_status(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns current user's MFA enrollment status and count of remaining backup codes.
    """
    user = uow.users.find_by_id(current_user.id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    extra = user.extra_fields if isinstance(user.extra_fields, dict) else {}
    mfa_enabled = bool(extra.get("mfa_enabled", False))
    enrolled_at = extra.get("mfa_enrolled_at")
    remaining_codes = len(extra.get("mfa_backup_codes", []))

    return MFAStatusResponse(
        mfa_enabled=mfa_enabled,
        enrolled_at=enrolled_at,
        remaining_backup_codes=remaining_codes,
    )


@router.post("/mfa/setup", response_model=MFASetupResponse)
def setup_mfa(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Generates a new Base32 TOTP secret and 8 single-use recovery backup codes.
    Stores setup state as pending until confirmed via /activate.
    """
    user = uow.users.find_by_id(current_user.id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    extra = dict(user.extra_fields or {})
    if extra.get("mfa_enabled") is True:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Multi-Factor Authentication is already enabled on this account."
        )

    secret = generate_totp_secret()
    backup_codes = generate_backup_codes(count=8)
    hashed_codes = [hash_backup_code(c) for c in backup_codes]

    extra["mfa_pending"] = {
        "secret": secret,
        "backup_codes": hashed_codes,
        "created_at": datetime.now().isoformat(),
    }

    uow.users.update_extra_fields(user.id, extra)
    invalidate_user_session_cache(user.id)

    otpauth_uri = generate_otpauth_uri(user.username, secret)

    return MFASetupResponse(
        secret=secret,
        otpauth_uri=otpauth_uri,
        backup_codes=backup_codes,
    )


@router.post("/mfa/activate", response_model=GenericMFAActionResponse)
def activate_mfa(
    payload: MFAActivateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Verifies initial TOTP code against pending MFA setup and enables MFA on the account.
    """
    user = uow.users.find_by_id(current_user.id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    extra = dict(user.extra_fields or {})
    pending = extra.get("mfa_pending")
    if not pending or not isinstance(pending, dict):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No pending MFA setup found. Please initiate setup before activating."
        )

    pending_secret = pending.get("secret", "")
    if not verify_totp_code(pending_secret, payload.code, window=1, user_id=user.id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid verification code. Ensure your device clock is accurate and try again."
        )

    # Transition from pending to active
    extra["mfa_enabled"] = True
    extra["mfa_secret"] = pending_secret
    extra["mfa_backup_codes"] = pending.get("backup_codes", [])
    extra["mfa_enrolled_at"] = datetime.now().isoformat()
    extra.pop("mfa_pending", None)

    uow.users.update_extra_fields(user.id, extra)
    invalidate_user_session_cache(user.id)

    AuditLogService.log_user_action(
        action="MFA_ENROLLED",
        target_user_id=user.id,
        display_name=user.username,
    )

    return GenericMFAActionResponse(
        success=True,
        message="Multi-Factor Authentication activated successfully."
    )


@router.post("/mfa/disable", response_model=GenericMFAActionResponse)
def disable_mfa(
    payload: MFADisableRequest,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Disables MFA for current user after confirming account password.
    """
    user = uow.users.find_by_id(current_user.id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found.")

    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid account password. MFA could not be disabled."
        )

    extra = dict(user.extra_fields or {})
    extra.pop("mfa_enabled", None)
    extra.pop("mfa_secret", None)
    extra.pop("mfa_backup_codes", None)
    extra.pop("mfa_enrolled_at", None)
    extra.pop("mfa_pending", None)

    uow.users.update_extra_fields(user.id, extra)
    invalidate_user_session_cache(user.id)

    AuditLogService.log_user_action(
        action="MFA_DISABLED",
        target_user_id=user.id,
        display_name=user.username,
    )

    return GenericMFAActionResponse(
        success=True,
        message="Multi-Factor Authentication disabled successfully."
    )


@router.post("/mfa/reset-user", response_model=GenericMFAActionResponse)
def admin_reset_mfa(
    payload: MFAResetUserRequest,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Supervisory reset endpoint: allows Super Admin or Admin to clear MFA for a locked-out staff member.
    """
    if current_user.role not in [ROLE_SUPER_ADMIN, ROLE_ADMIN, "Super Admin", "Admin", "ADMIN"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied. Only Administrators can reset staff MFA credentials."
        )

    target_user = uow.users.find_by_id(payload.user_id)
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Target user not found."
        )

    extra = dict(target_user.extra_fields or {})
    extra.pop("mfa_enabled", None)
    extra.pop("mfa_secret", None)
    extra.pop("mfa_backup_codes", None)
    extra.pop("mfa_enrolled_at", None)
    extra.pop("mfa_pending", None)

    uow.users.update_extra_fields(target_user.id, extra)
    invalidate_user_session_cache(target_user.id)

    AuditLogService.log_user_action(
        action="MFA_ADMIN_RESET",
        target_user_id=target_user.id,
        display_name=target_user.username,
        new={"reset_by": current_user.username},
    )

    return GenericMFAActionResponse(
        success=True,
        message=f"MFA credentials reset successfully for user {target_user.username}."
    )


# -----------------------------------------------------------------------------
# Self-Service Profile, Avatar, Appearance Preferences & Password Rotation
# -----------------------------------------------------------------------------

_ALLOWED_AVATAR_EXTENSIONS = {"jpg", "jpeg", "png", "webp"}
_MAX_AVATAR_BYTES = 5 * 1024 * 1024  # 5 MB
_AVATAR_BUCKET = "user-avatars"
_ALLOWED_THEME_MODES = {"system", "light", "dark"}
_ALLOWED_ACCENT_PRESETS = {"emerald", "sapphire", "teal", "indigo"}
_EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_PHONE_REGEX = re.compile(r"^[0-9+\-\s()]{7,25}$")


def _sanitize_preferences(raw_prefs: Optional[Dict[str, Any]], existing_prefs: Dict[str, Any]) -> Dict[str, Any]:
    """Merges and validates self-service UI preferences safely."""
    merged = dict(existing_prefs or {})
    if not isinstance(raw_prefs, dict):
        return merged

    if "theme_mode" in raw_prefs and raw_prefs["theme_mode"] is not None:
        tm = str(raw_prefs["theme_mode"]).strip().lower()
        if tm not in _ALLOWED_THEME_MODES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Theme mode must be 'system', 'light', or 'dark'."
            )
        merged["theme_mode"] = tm

    if "accent_preset" in raw_prefs and raw_prefs["accent_preset"] is not None:
        ap = str(raw_prefs["accent_preset"]).strip().lower()
        if ap not in _ALLOWED_ACCENT_PRESETS:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Accent preset must be 'emerald', 'sapphire', 'teal', or 'indigo'."
            )
        merged["accent_preset"] = ap

    for bool_key in ("compact_density", "reduce_motion", "haptics_enabled"):
        if bool_key in raw_prefs and raw_prefs[bool_key] is not None:
            merged[bool_key] = bool(raw_prefs[bool_key])

    return merged


@router.get("/profile", response_model=ProfileResponse)
def get_my_profile(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow),
):
    """
    Returns complete self-service profile, security posture, preferences, and recent logins
    for the authenticated staff member across all roles.
    """
    user = uow.users.find_by_id(current_user.id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    extra = dict(user.extra_fields or {})
    user_info = _build_user_info(user, uow)

    try:
        normalized_role = RBACScopeService.normalize_role(user.role)
        can_change_pw = normalized_role != "CO"
    except UnknownRoleError:
        can_change_pw = False

    recent_items: List[ProfileLoginActivityItem] = []
    try:
        rows = uow.login_history.find_by_user(user.id, limit=5)
        for r in (rows or []):
            recent_items.append(
                ProfileLoginActivityItem(
                    login_time=str(r.get("login_time") or ""),
                    status=str(r.get("status") or "SUCCESS"),
                    device_name=r.get("device_name"),
                    browser=r.get("browser"),
                    operating_system=r.get("operating_system"),
                )
            )
    except Exception:
        recent_items = []

    return ProfileResponse(
        user=user_info,
        emergency_contact=str(extra.get("emergency_contact") or ""),
        can_self_change_password=can_change_pw,
        remaining_backup_codes=len(extra.get("mfa_backup_codes", []) or []),
        mfa_enrolled_at=extra.get("mfa_enrolled_at"),
        recent_activity=recent_items,
    )


@router.patch("/profile", response_model=ProfileUpdateResponse)
def update_my_profile(
    payload: ProfileUpdateRequest,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow),
):
    """
    Updates personal contact details and UI preferences in app_users.extra_fields.
    Role, branch scope, username, display full name, and MFA state are strictly read-only here.
    """
    user = uow.users.find_by_id(current_user.id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    extra = dict(user.extra_fields or {})

    if payload.phone is not None:
        clean_phone = payload.phone.strip()
        if clean_phone and not _PHONE_REGEX.match(clean_phone):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Enter a valid contact phone number (7-25 digits/characters)."
            )
        extra["phone"] = clean_phone

    if payload.email is not None:
        clean_email = payload.email.strip()
        if clean_email and not _EMAIL_REGEX.match(clean_email):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="Enter a valid email address."
            )
        extra["email"] = clean_email

    if payload.bio is not None:
        extra["bio"] = payload.bio.strip()[:280]

    if payload.emergency_contact is not None:
        extra["emergency_contact"] = payload.emergency_contact.strip()[:120]

    if payload.preferences is not None:
        existing_prefs = extra.get("preferences") if isinstance(extra.get("preferences"), dict) else {}
        extra["preferences"] = _sanitize_preferences(payload.preferences.model_dump(), existing_prefs)

    extra["profile_updated_at"] = datetime.now().isoformat()
    uow.users.update_extra_fields(user.id, extra)
    user.extra_fields = extra

    invalidate_user_session_cache(user.id)
    invalidate_user_session_cache(user.username)

    AuditLogService.log_user_action(
        action="USER_PROFILE_UPDATED",
        target_user_id=user.id,
        display_name=user.username,
        new={"updated_fields": [k for k, v in payload.model_dump(exclude_none=True).items()]},
    )

    return ProfileUpdateResponse(
        success=True,
        message="Profile and preferences saved.",
        user=_build_user_info(user, uow),
        emergency_contact=str(extra.get("emergency_contact") or ""),
    )


@router.post("/profile/avatar", response_model=AvatarUploadResponse)
async def upload_profile_avatar(
    file: UploadFile = File(...),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow),
):
    """
    Uploads, EXIF-strips, downscales (max 512px), and stores the authenticated user's
    profile photograph in Supabase Storage (`user-avatars`).
    """
    user = uow.users.find_by_id(current_user.id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    raw_bytes = await file.read()
    if not raw_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Selected image file is empty.")
    if len(raw_bytes) > _MAX_AVATAR_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Profile photo exceeds the 5 MB maximum upload limit."
        )

    filename = file.filename or "avatar.jpg"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext and ext not in _ALLOWED_AVATAR_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported image format. Allowed formats: JPG, JPEG, PNG, WEBP."
        )

    try:
        img = Image.open(io.BytesIO(raw_bytes))
        try:
            img = ImageOps.exif_transpose(img)
        except Exception:
            pass
        if img.mode in ("RGBA", "P", "LA"):
            bg = Image.new("RGB", img.size, (255, 255, 255))
            if img.mode == "RGBA":
                bg.paste(img, mask=img.split()[3])
            else:
                bg.paste(img)
            img = bg
        elif img.mode != "RGB":
            img = img.convert("RGB")

        img.thumbnail((512, 512), Image.Resampling.LANCZOS)
        out_buf = io.BytesIO()
        # Re-saving via Pillow strips GPS/EXIF metadata while optimizing size
        img.save(out_buf, format="JPEG", quality=82, optimize=True)
        target_bytes = out_buf.getvalue()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not decode image file. Please select a valid JPG, PNG, or WEBP photo."
        )

    try:
        buckets = uow.client.storage.list_buckets()
        bucket_names = [b.name for b in (buckets or [])]
        if _AVATAR_BUCKET not in bucket_names:
            uow.client.storage.create_bucket(_AVATAR_BUCKET, options={"public": True})
    except Exception:
        pass

    extra = dict(user.extra_fields or {})
    old_path = extra.get("avatar_storage_path")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    storage_path = f"{user.id}/avatar_{timestamp}.jpg"

    try:
        uow.client.storage.from_(_AVATAR_BUCKET).upload(
            path=storage_path,
            file=target_bytes,
            file_options={"content-type": "image/jpeg"}
        )
    except Exception as upload_err:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to store profile photograph: {upload_err}"
        )

    if old_path and old_path != storage_path:
        try:
            uow.client.storage.from_(_AVATAR_BUCKET).remove([old_path])
        except Exception:
            pass

    public_url = uow.client.storage.from_(_AVATAR_BUCKET).get_public_url(storage_path)
    extra["avatar_url"] = public_url
    extra["avatar_storage_path"] = storage_path
    extra["avatar_updated_at"] = datetime.now().isoformat()

    uow.users.update_extra_fields(user.id, extra)
    invalidate_user_session_cache(user.id)
    invalidate_user_session_cache(user.username)

    AuditLogService.log_user_action(
        action="USER_AVATAR_UPDATED",
        target_user_id=user.id,
        display_name=user.username,
    )

    return AvatarUploadResponse(
        success=True,
        message="Profile photograph updated successfully.",
        avatar_url=public_url,
        size_kb=round(len(target_bytes) / 1024.0, 1),
    )


@router.delete("/profile/avatar", response_model=ProfileUpdateResponse)
def remove_profile_avatar(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow),
):
    """Removes the authenticated user's profile photograph and clears avatar metadata."""
    user = uow.users.find_by_id(current_user.id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    extra = dict(user.extra_fields or {})
    old_path = extra.pop("avatar_storage_path", None)
    extra.pop("avatar_url", None)
    extra["avatar_updated_at"] = datetime.now().isoformat()

    if old_path:
        try:
            uow.client.storage.from_(_AVATAR_BUCKET).remove([old_path])
        except Exception:
            pass

    uow.users.update_extra_fields(user.id, extra)
    user.extra_fields = extra
    invalidate_user_session_cache(user.id)
    invalidate_user_session_cache(user.username)

    AuditLogService.log_user_action(
        action="USER_AVATAR_REMOVED",
        target_user_id=user.id,
        display_name=user.username,
    )

    return ProfileUpdateResponse(
        success=True,
        message="Profile photograph removed.",
        user=_build_user_info(user, uow),
        emergency_contact=str(extra.get("emergency_contact") or ""),
    )


@router.post("/change-password", response_model=ChangeOwnPasswordResponse)
def change_own_password(
    payload: ChangeOwnPasswordRequest,
    request: Request,
    response: Response,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow),
):
    """
    Allows authenticated management & administrative roles to rotate their own password.
    Credit Officer credentials remain centrally managed by Branch/Area Managers.
    Issues a fresh session token so the active session remains uninterrupted.
    """
    user = uow.users.find_by_id(current_user.id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User account not found.")

    try:
        normalized_role = RBACScopeService.normalize_role(user.role)
    except UnknownRoleError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account role is unrecognized. Contact administrator."
        )

    if normalized_role == "CO":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Credit Officer passwords must be configured and managed by your supervising Branch Manager or Area Manager."
        )

    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect."
        )

    new_pw = payload.new_password.strip()
    if len(new_pw) < 8:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="New password must be at least 8 characters long."
        )

    if verify_password(new_pw, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be different from your current password."
        )

    new_hash = hash_password(new_pw)
    uow.users.update_password(user.username, new_hash)

    extra = dict(user.extra_fields or {})
    extra["must_change_password"] = False
    extra["password_changed_at"] = datetime.now().isoformat()
    try:
        uow.users.update_extra_fields(user.id, extra)
    except Exception:
        pass

    get_revocation_store().revoke_user_sessions(user.id)
    invalidate_user_session_cache(user.id)
    invalidate_user_session_cache(user.username)

    AuditLogService.log_user_action(
        action="USER_PASSWORD_CHANGED",
        target_user_id=user.id,
        display_name=user.username,
    )

    # Issue a fresh replacement session token for the active caller after revoking prior sessions
    new_token = generate_session_token(user.id, user.username)
    csrf_token = set_auth_cookies(response, request, new_token)

    return ChangeOwnPasswordResponse(
        success=True,
        message="Password updated successfully. Active session refreshed.",
        access_token=None if is_cookie_auth_mode(request) else new_token,
        csrf_token=csrf_token,
    )
