"""
Authentication and MFA Route Adapter for ICARE Core Banking.
Reuses SupabaseUnitOfWork, RBACScopeService, and RFC 6238 MFA Service.
Complies with Strict Zero-Emoji Governance.
"""
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, CurrentUser
from api.schemas.auth import (
    LoginRequest,
    LoginResponse,
    UserInfo,
    MFASetupResponse,
    MFAActivateRequest,
    MFAChallengeRequest,
    MFADisableRequest,
    MFAResetUserRequest,
    MFAStatusResponse,
    GenericMFAActionResponse,
)
from auth.password import verify_password
from auth.session import generate_session_token
from auth.session_cache import invalidate_user_session_cache
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
    """Extracts authoritative UserInfo with AM branch assignments and allowed products."""
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

    allowed_prods = []
    if getattr(user, "extra_fields", None) and isinstance(user.extra_fields, dict):
        allowed_prods = user.extra_fields.get("allowed_products", []) or []

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
    )


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, uow: SupabaseUnitOfWork = Depends(get_uow)):
    """
    Authenticates user against app_users.
    If MFA is enabled for the user, issues a short-lived MFA challenge token.
    Otherwise, returns authoritative session token and user profile.
    """
    username = payload.username.strip()
    password = payload.password

    user = uow.users.find_by_username(username)
    if not user:
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
        AuditLogService.log_login(username, "FAILURE", "Invalid password")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials. Please try again."
        )

    extra = user.extra_fields if isinstance(user.extra_fields, dict) else {}
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
        )

    # Standard non-MFA login
    try:
        uow.users.update_last_login(user.id)
    except Exception:
        pass

    AuditLogService.log_login(username, "SUCCESS", "User authenticated successfully")
    token = generate_session_token(user.id, user.username)
    user_info = _build_user_info(user, uow)

    return LoginResponse(
        access_token=token,
        token_type="Bearer",
        user=user_info,
        mfa_required=False,
        mfa_token=None,
    )


@router.post("/mfa/challenge", response_model=LoginResponse)
def mfa_challenge(
    payload: MFAChallengeRequest,
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Validates a 6-digit TOTP code or backup code against a temporary MFA challenge token.
    On successful verification, completes login and returns authoritative session token.
    """
    token_data = validate_mfa_challenge_token(payload.mfa_token)
    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="MFA challenge token is invalid or expired. Please log in again."
        )

    user_id = token_data.get("user_id")
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
        AuditLogService.log_login(user.username, "FAILURE", "Invalid MFA verification code")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid MFA verification code. Check your authenticator app or backup code."
        )

    try:
        uow.users.update_last_login(user.id)
    except Exception:
        pass

    AuditLogService.log_login(user.username, "SUCCESS", "User completed MFA authentication successfully")
    token = generate_session_token(user.id, user.username)
    user_info = _build_user_info(user, uow)

    return LoginResponse(
        access_token=token,
        token_type="Bearer",
        user=user_info,
        mfa_required=False,
        mfa_token=None,
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
