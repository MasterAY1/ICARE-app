"""
FastAPI dependencies for authentication, database Unit of Work, and RBAC scope resolution.
"""
import hmac
from typing import Generator, Optional, List
from fastapi import Header, HTTPException, Depends, Request, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from auth.cookies import SESSION_COOKIE_NAME, CSRF_COOKIE_NAME
from auth.session import validate_session_token
from auth.session_cache import (
    get_cached_user,
    set_cached_user,
    invalidate_user_session_cache,
)
from services.rbac_scope_service import RBACScopeService, RBACScope, UnknownRoleError
from models.user import CurrentUser
from auth.authorization import PERMISSIONS


def get_uow() -> Generator[SupabaseUnitOfWork, None, None]:
    """Provides a transactional UnitOfWork session."""
    with SupabaseUnitOfWork() as uow:
        yield uow


def get_current_user(
    request: Request = None,
    authorization: Optional[str] = Header(None),
    uow: SupabaseUnitOfWork = Depends(get_uow)
) -> CurrentUser:
    """
    Extracts session token from Authorization Bearer header (mobile/CLI) or
    HttpOnly session cookie (web), enforces CSRF double-submit verification on
    cookie-authenticated mutating requests, validates signature and revocation,
    and returns authoritative CurrentUser object from cache/database.
    Fails closed with HTTP 401/403 on any error.
    """
    auth_source = "bearer"
    if authorization is not None and authorization != "":
        token = authorization.replace("Bearer ", "").strip()
        if not token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Malformed Authorization header."
            )
    elif authorization == "":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required. Missing Authorization header."
        )
    elif request is not None and request.cookies.get(SESSION_COOKIE_NAME):
        token = str(request.cookies.get(SESSION_COOKIE_NAME) or "").strip()
        if not token:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication token required. Missing credentials."
            )
        auth_source = "cookie"
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required. Missing Authorization header."
        )

    if (
        auth_source == "cookie"
        and request is not None
        and request.method.upper() in ("POST", "PUT", "PATCH", "DELETE")
    ):
        csrf_cookie = (request.cookies.get(CSRF_COOKIE_NAME) or "").strip()
        csrf_header = (request.headers.get("x-csrf-token") or "").strip()
        if not csrf_cookie or not csrf_header or not hmac.compare_digest(csrf_cookie, csrf_header):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="CSRF validation failed. Please refresh your session and retry."
            )

    token_data = validate_session_token(token)
    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token. Please log in again."
        )

    user_id = token_data.get("user_id")
    username = token_data.get("username")

    # Fast-path: Check in-memory session cache (eliminates PostgREST roundtrip)
    cached_user = get_cached_user(user_id) or get_cached_user(username)
    if cached_user is not None:
        return cached_user

    # Cache miss: fetch authoritative user record from database
    user_record = uow.users.find_by_id(user_id) if user_id else uow.users.find_by_username(username)
    if not user_record or not user_record.is_active:
        invalidate_user_session_cache(user_id)
        invalidate_user_session_cache(username)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is deactivated or no longer exists."
        )

    role = user_record.role
    user_permissions = PERMISSIONS.get(role, set())

    extra_fields = getattr(user_record, "extra_fields", None)
    if not isinstance(extra_fields, dict):
        extra_fields = {}

    allowed_prods = extra_fields.get("allowed_products", []) or []
    prefs = extra_fields.get("preferences")
    if not isinstance(prefs, dict):
        prefs = {}

    current_user = CurrentUser(
        id=user_record.id,
        username=user_record.username,
        role=role,
        branch=user_record.branch_name or 'Unknown',
        branch_id=user_record.branch_id or '',
        full_name=user_record.full_name or '',
        permissions=user_permissions,
        allowed_products=allowed_prods,
        phone=str(extra_fields.get("phone") or ""),
        email=str(extra_fields.get("email") or ""),
        avatar_url=str(extra_fields.get("avatar_url") or ""),
        bio=str(extra_fields.get("bio") or ""),
        mfa_enabled=bool(extra_fields.get("mfa_enabled", False)),
        is_misc_savings_manager=bool(extra_fields.get("is_misc_savings_manager", False)),
        preferences=prefs,
        created_at=user_record.created_at.isoformat() if getattr(user_record, "created_at", None) else None,
        last_login=user_record.last_login.isoformat() if getattr(user_record, "last_login", None) else None,
    )

    if role in ["Area Manager", "AM", "AREA_MANAGER"]:
        try:
            assignments = uow.users.load_am_assignments(user_record.id)
            current_user.assigned_branch_ids = [a["branch_id"] for a in assignments if a.get("branch_id")]
            current_user.assigned_branches = [a["name"] for a in assignments if a.get("name")]
            if user_record.branch_id and user_record.branch_id not in current_user.assigned_branch_ids:
                current_user.assigned_branch_ids.append(user_record.branch_id)
            if user_record.branch_name and user_record.branch_name not in current_user.assigned_branches:
                current_user.assigned_branches.append(user_record.branch_name)
        except Exception:
            current_user.assigned_branch_ids = [user_record.branch_id] if user_record.branch_id else []
            current_user.assigned_branches = [user_record.branch_name] if user_record.branch_name else []

    # Cache resolved user profile
    if user_id:
        set_cached_user(user_id, current_user)
    if username:
        set_cached_user(username, current_user)

    return current_user


def get_current_user_optional(
    request: Request = None,
    authorization: Optional[str] = Header(None),
    uow: SupabaseUnitOfWork = Depends(get_uow)
) -> Optional[CurrentUser]:
    """
    Extracts CurrentUser if Authorization header or session cookie is present and valid; returns None otherwise.
    """
    has_cookie = bool(request is not None and request.cookies.get(SESSION_COOKIE_NAME))
    if not authorization and not has_cookie:
        return None
    try:
        return get_current_user(request=request, authorization=authorization, uow=uow)
    except Exception:
        return None


def get_current_scope(current_user: CurrentUser = Depends(get_current_user)) -> RBACScope:
    """Resolves authoritative RBACScope from authenticated CurrentUser."""
    user_dict = {
        "id": current_user.id,
        "username": current_user.username,
        "role": current_user.role,
        "branch": current_user.branch,
        "branch_id": current_user.branch_id,
        "assigned_branches": getattr(current_user, "assigned_branches", []),
        "assigned_branch_ids": getattr(current_user, "assigned_branch_ids", [])
    }
    try:
        return RBACScopeService.resolve_scope(user_dict)
    except UnknownRoleError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Access forbidden: {exc}"
        )


def require_role(allowed_roles: List[str]):
    """Enforces that the authenticated user's role is in allowed_roles."""
    def role_checker(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        try:
            normalized_role = RBACScopeService.normalize_role(current_user.role)
        except UnknownRoleError:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access forbidden: Role '{current_user.role}' is unrecognized."
            )
        normalized_allowed = [RBACScopeService.normalize_role(r) for r in allowed_roles]
        if normalized_role not in normalized_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access forbidden: Role '{current_user.role}' is not authorized for this operation."
            )
        return current_user
    return role_checker


def check_branch_access(current_user: CurrentUser, target_branch_id: Optional[str], action_desc: str = "manage records") -> None:
    """
    Enforces strict multi-branch authorization:
    - Admin / Super Admin / Director: allowed across all branches
    - Branch Manager / Account Manager / Credit Officer: target_branch_id must match current_user.branch_id
    - Area Manager: target_branch_id must be in current_user.assigned_branch_ids
    - Unrecognized role fails closed with 403 Forbidden
    - Missing target_branch_id fails closed with 400 Bad Request
    """
    try:
        norm_role = RBACScopeService.normalize_role(current_user.role)
    except UnknownRoleError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Unrecognized user role."
        )
    if norm_role in ["Admin", "Director"]:
        return

    if not target_branch_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Target record has no valid branch assignment; cannot {action_desc}."
        )

    if norm_role in ["Branch Manager", "Account Manager", "CO"]:
        if target_branch_id != current_user.branch_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Forbidden: You cannot {action_desc} belonging to another branch."
            )
    elif norm_role == "Area Manager":
        allowed_ids = getattr(current_user, "assigned_branch_ids", [])
        if target_branch_id not in allowed_ids:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Forbidden: You cannot {action_desc} belonging to a branch outside your supervisory area."
            )
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Forbidden: Insufficient privileges to {action_desc}."
        )

