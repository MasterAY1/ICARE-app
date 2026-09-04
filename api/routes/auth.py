"""
Authentication route adapter.
Reuses AuthService, SupabaseUnitOfWork, and RBACScopeService.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow
from api.schemas.auth import LoginRequest, LoginResponse, UserInfo
from auth.password import verify_password
from auth.session import generate_session_token
from services.audit_log_service import AuditLogService

router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest, uow: SupabaseUnitOfWork = Depends(get_uow)):
    """
    Authenticates user against app_users and returns authoritative JWT token and scope.
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

    # Load Area Manager assigned branches if applicable
    assigned_branches = []
    if user.role == "Area Manager":
        try:
            assignments = uow.users.load_am_assignments(user.id)
            assigned_branches = [a["name"] for a in assignments]
        except Exception:
            assigned_branches = []

    # Update last login
    try:
        uow.users.update_last_login(user.id)
    except Exception:
        pass

    # Record login audit
    AuditLogService.log_login(username, "SUCCESS", "User authenticated successfully")

    # Generate token
    token = generate_session_token(user.id, user.username)

    user_info = UserInfo(
        id=user.id,
        username=user.username,
        full_name=user.full_name or user.username,
        role=user.role,
        branch=user.branch_name or 'Unknown',
        branch_id=user.branch_id or '',
        assigned_branches=assigned_branches
    )

    return LoginResponse(
        access_token=token,
        token_type="Bearer",
        user=user_info
    )
