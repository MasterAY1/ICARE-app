"""
FastAPI dependencies for authentication, database Unit of Work, and RBAC scope resolution.
"""
from typing import Generator, Optional, List
from fastapi import Header, HTTPException, Depends, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from auth.session import validate_session_token
from services.rbac_scope_service import RBACScopeService, RBACScope
from models.user import CurrentUser
from auth.authorization import PERMISSIONS


def get_uow() -> Generator[SupabaseUnitOfWork, None, None]:
    """Provides a transactional UnitOfWork session."""
    with SupabaseUnitOfWork() as uow:
        yield uow


def get_current_user(
    authorization: Optional[str] = Header(None),
    uow: SupabaseUnitOfWork = Depends(get_uow)
) -> CurrentUser:
    """
    Extracts Bearer token from Authorization header, validates signature and session age,
    and returns authoritative CurrentUser object directly from database.
    Fails closed with HTTP 401 on any error.
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required. Missing Authorization header."
        )

    token = authorization.replace("Bearer ", "").strip()
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Malformed Authorization header."
        )

    token_data = validate_session_token(token)
    if not token_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token. Please log in again."
        )

    user_id = token_data.get("user_id")
    username = token_data.get("username")

    user_record = uow.users.find_by_id(user_id) if user_id else uow.users.find_by_username(username)
    if not user_record or not user_record.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User account is deactivated or no longer exists."
        )

    role = user_record.role
    user_permissions = PERMISSIONS.get(role, set())

    current_user = CurrentUser(
        id=user_record.id,
        username=user_record.username,
        role=role,
        branch=user_record.branch_name or 'Unknown',
        branch_id=user_record.branch_id or '',
        full_name=user_record.full_name or '',
        permissions=user_permissions,
    )

    if role == "Area Manager":
        try:
            assignments = uow.users.load_am_assignments(user_record.id)
            current_user.assigned_branch_ids = [a["branch_id"] for a in assignments]
            current_user.assigned_branches = [a["name"] for a in assignments]
        except Exception:
            current_user.assigned_branch_ids = []
            current_user.assigned_branches = []

    return current_user


def get_current_scope(current_user: CurrentUser = Depends(get_current_user)) -> RBACScope:
    """Resolves authoritative RBACScope from authenticated CurrentUser."""
    user_dict = {
        "id": current_user.id,
        "username": current_user.username,
        "role": current_user.role,
        "branch": current_user.branch,
        "branch_id": current_user.branch_id,
        "assigned_branches": getattr(current_user, "assigned_branch_ids", [])
    }
    return RBACScopeService.resolve_scope(user_dict)


def require_role(allowed_roles: List[str]):
    """Enforces that the authenticated user's role is in allowed_roles."""
    def role_checker(current_user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        normalized_role = RBACScopeService.normalize_role(current_user.role)
        normalized_allowed = [RBACScopeService.normalize_role(r) for r in allowed_roles]
        if normalized_role not in normalized_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access forbidden: Role '{current_user.role}' is not authorized for this operation."
            )
        return current_user
    return role_checker
