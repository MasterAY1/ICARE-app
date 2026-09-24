"""
User Management API Route Adapter.
Reuses UserService, ScheduleService, SupabaseUnitOfWork, and RBACScopeService.
Implements 1:1 Streamlit parity for User Directory, Create User, Password Reset,
Officer Turnover, Product Assignment, AM Assignments, Branch Closures,
System Audit Logs, and Login History (app.py L13862–14316).
"""
from datetime import date
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, CurrentUser
from domain.entities.branch_closure import BranchClosure
from services.user_service import UserService
from services.schedule_service import ScheduleService
from config.roles import (
    ROLE_SUPER_ADMIN, ROLE_ADMIN, ROLE_AREA_MANAGER,
    ROLE_BRANCH_MANAGER, ROLE_CREDIT_OFFICER
)
from api.schemas.users import (
    UserListItem, UserListResponse,
    CreateUserRequest, CreateUserResponse,
    UserStatusToggleRequest, GenericActionResponse,
    PasswordResetRequest, OfficerTurnoverRequest,
    ProductAssignmentMetaResponse, CreditOfficerProductMeta,
    AssignProductsRequest,
    AMAssignmentsResponse, AMAssignmentItem, BranchOptionItem,
    SaveAMAssignmentsRequest,
    BranchClosuresResponse, BranchClosureItem,
    CreateBranchClosureRequest, CreateBranchClosureResponse,
    UserAuditLogsResponse, UserAuditLogItem,
    LoginHistoryResponse, LoginHistoryItem,
)

router = APIRouter(prefix="/api/v1/users", tags=["User Management"])


def _check_not_co(current_user: CurrentUser):
    role = (current_user.role or "").strip().lower()
    if role in ["co", "credit officer", "officer"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access User Management."
        )


def _is_admin(current_user: CurrentUser) -> bool:
    role = (current_user.role or "").strip()
    return role in [ROLE_SUPER_ADMIN, ROLE_ADMIN, "Super Admin", "Admin", "ADMIN"]


def _is_bm(current_user: CurrentUser) -> bool:
    role = (current_user.role or "").strip()
    return role in [ROLE_BRANCH_MANAGER, "BM", "Branch Manager"]


# -----------------------------------------------------------------------------
# 1. User Directory & Listing
# -----------------------------------------------------------------------------
@router.get("", response_model=UserListResponse)
def get_users(
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Fetch users scoped to caller's role (app.py L13886)."""
    _check_not_co(current_user)

    user_dicts = UserService.list_users(current_user)

    # Fetch extra_fields for rich client data
    try:
        res_raw = uow.client.table("app_users").select("id, extra_fields").execute()
        extra_map = {r["id"]: r.get("extra_fields") for r in (res_raw.data or []) if r.get("id")}
    except Exception:
        extra_map = {}

    items: List[UserListItem] = []
    for u in user_dicts:
        uid = str(u.get("id") or "")
        items.append(UserListItem(
            id=uid,
            username=u.get("username", ""),
            full_name=u.get("full_name", ""),
            role=u.get("role", ""),
            branch_name=u.get("branch_name"),
            branch_id=u.get("branch_id"),
            is_active=bool(u.get("is_active", True)),
            created_at=str(u.get("created_at") or ""),
            last_login=str(u.get("last_login") or "Never"),
            extra_fields=extra_map.get(uid),
        ))

    return UserListResponse(users=items, total_count=len(items))


# -----------------------------------------------------------------------------
# 2. Create User (Admin Only)
# -----------------------------------------------------------------------------
@router.post("", response_model=CreateUserResponse)
def create_user(
    payload: CreateUserRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Create a new user (Admin only, app.py L13977–14004)."""
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Head Office administrators can create new users."
        )

    res = UserService.create_user(
        username=payload.username.strip(),
        full_name=payload.full_name.strip(),
        password=payload.password,
        role=payload.role.strip(),
        branch_name=payload.branch_name.strip() if payload.branch_name else "",
        requesting_user=current_user,
    )

    if not res.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.get("message", "Failed to create user.")
        )

    created_user = res.get("user")
    user_item = None
    if created_user:
        user_item = UserListItem(
            id=str(created_user.id or ""),
            username=created_user.username,
            full_name=created_user.full_name,
            role=created_user.role,
            branch_name=created_user.branch_name,
            branch_id=created_user.branch_id,
            is_active=created_user.is_active,
            created_at=str(created_user.created_at) if created_user.created_at else None,
            last_login="Never"
        )

    return CreateUserResponse(
        success=True,
        message=res.get("message", "User created successfully."),
        user=user_item
    )


# -----------------------------------------------------------------------------
# 3. Activate / Deactivate User
# -----------------------------------------------------------------------------
@router.post("/{user_id}/status", response_model=GenericActionResponse)
def toggle_user_status(
    user_id: str,
    payload: UserStatusToggleRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Toggle user active status (app.py L13929–13959)."""
    _check_not_co(current_user)

    if payload.activate:
        res = UserService.activate_user(user_id, requesting_user=current_user)
    else:
        res = UserService.deactivate_user(user_id, requesting_user=current_user)

    if not res.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.get("message", "Failed to update user status.")
        )

    return GenericActionResponse(success=True, message=res["message"])


# -----------------------------------------------------------------------------
# 4. Permanently Delete User (Admin Only)
# -----------------------------------------------------------------------------
@router.delete("/{user_id}", response_model=GenericActionResponse)
def delete_user(
    user_id: str,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Permanently delete user from system (Admin only, app.py L13960–13972)."""
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthorized. Only Administrators can delete users."
        )

    res = UserService.remove_user_permanently(user_id, requesting_user=current_user)
    if not res.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.get("message", "Failed to delete user.")
        )

    return GenericActionResponse(success=True, message=res["message"])


# -----------------------------------------------------------------------------
# 5. Password Reset
# -----------------------------------------------------------------------------
@router.post("/password-reset", response_model=GenericActionResponse)
def reset_password(
    payload: PasswordResetRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Reset user password (app.py L14006–14024)."""
    _check_not_co(current_user)

    res = UserService.reset_password(
        username=payload.username.strip(),
        new_password=payload.new_password,
        requesting_user=current_user,
    )
    if not res.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.get("message", "Failed to reset password.")
        )

    return GenericActionResponse(success=True, message=res["message"])


# -----------------------------------------------------------------------------
# 6. Officer Turnover (Admin Only)
# -----------------------------------------------------------------------------
@router.post("/officer-turnover", response_model=GenericActionResponse)
def update_officer_turnover(
    payload: OfficerTurnoverRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Update officer display name preserving historical username (Admin only, app.py L14026–14055)."""
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can update officer names."
        )

    res = UserService.update_officer_name(
        username=payload.username.strip(),
        new_name=payload.new_name.strip(),
        requesting_user=current_user,
    )
    if not res.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.get("message", "Failed to update officer name.")
        )

    return GenericActionResponse(success=True, message=res["message"])


# -----------------------------------------------------------------------------
# 7. Product Assignment (Admin & BM)
# -----------------------------------------------------------------------------
@router.get("/products/meta", response_model=ProductAssignmentMetaResponse)
def get_product_assignment_meta(
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Fetch loan products and Credit Officers with current allowed products (app.py L14060–14095)."""
    _check_not_co(current_user)

    # Available products
    try:
        res_prods = uow.client.table("loan_products").select("name").execute()
        available_products = [p["name"] for p in (res_prods.data or []) if p.get("name")]
    except Exception:
        available_products = []

    if not available_products:
        available_products = [
            "Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W",
            "Monthly 3M", "Monthly 6M", "60-Day Asset", "120-Day Asset",
            "Weekly 12W Asset", "Weekly 24W Asset", "Monthly 3M Asset",
            "Monthly 6M Asset", "Cash and Carry"
        ]

    # Scoped CO users
    all_users = UserService.list_users(current_user)
    co_users = [u for u in all_users if u.get("role") in [ROLE_CREDIT_OFFICER, "Credit Officer", "CO", "Officer"]]

    # Fetch extra_fields
    co_meta: List[CreditOfficerProductMeta] = []
    for co in co_users:
        uid = str(co.get("id"))
        uname = co.get("username", "")
        fname = co.get("full_name") or uname

        try:
            res_u = uow.client.table("app_users").select("extra_fields").eq("id", uid).execute()
            extra = (res_u.data[0].get("extra_fields") or {}) if res_u.data else {}
            allowed = extra.get("allowed_products", [])
            if not isinstance(allowed, list):
                allowed = []
        except Exception:
            allowed = []

        co_meta.append(CreditOfficerProductMeta(
            id=uid,
            username=uname,
            full_name=fname,
            allowed_products=allowed,
        ))

    return ProductAssignmentMetaResponse(
        available_products=available_products,
        credit_officers=co_meta
    )


@router.post("/products/assign", response_model=GenericActionResponse)
def assign_products_to_officer(
    payload: AssignProductsRequest,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Save allowed products for a Credit Officer (app.py L14098–14112)."""
    _check_not_co(current_user)

    target_uname = payload.username.strip()
    target_user = uow.users.find_by_username(target_uname)
    if not target_user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Credit Officer '{target_uname}' not found."
        )

    # BM Scope Check
    if _is_bm(current_user) and target_user.branch_id != current_user.branch_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only manage Credit Officers in your own branch."
        )

    try:
        res_raw = uow.client.table("app_users").select("extra_fields").eq("id", target_user.id).execute()
        extra_fields = dict((res_raw.data[0].get("extra_fields") or {}) if res_raw.data else {})
        extra_fields["allowed_products"] = payload.allowed_products

        uow.client.table("app_users").update({"extra_fields": extra_fields}).eq("id", target_user.id).execute()
        return GenericActionResponse(
            success=True,
            message=f"Successfully updated allowed products for {target_uname}."
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Error updating products: {str(e)}"
        )


# -----------------------------------------------------------------------------
# 8. AM Branch Assignments (Admin Only)
# -----------------------------------------------------------------------------
@router.get("/am-assignments", response_model=AMAssignmentsResponse)
def get_am_assignments(
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Fetch Area Managers and their current assigned branches (Admin only, app.py L14117–14145)."""
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can view Area Manager branch assignments."
        )

    # 1. Fetch active branches
    try:
        res_b = uow.client.table("branches").select("branch_id, name").eq("is_active", True).execute()
        all_branches = [BranchOptionItem(branch_id=str(b["branch_id"]), name=b["name"]) for b in (res_b.data or [])]
    except Exception:
        all_branches = []

    # 2. Fetch Area Managers
    all_users = UserService.list_users(current_user)
    am_users = [u for u in all_users if u.get("role") in [ROLE_AREA_MANAGER, "Area Manager", "AM"]]

    am_items: List[AMAssignmentItem] = []
    for am in am_users:
        am_id = str(am["id"])
        assignments = UserService.get_am_assignments(am_id)
        assigned_ids = [str(a["branch_id"]) for a in assignments if a.get("branch_id")]
        assigned_names = [str(a["name"]) for a in assignments if a.get("name")]

        am_items.append(AMAssignmentItem(
            user_id=am_id,
            username=am.get("username", ""),
            full_name=am.get("full_name") or am.get("username", ""),
            assigned_branch_ids=assigned_ids,
            assigned_branch_names=assigned_names,
        ))

    return AMAssignmentsResponse(
        area_managers=am_items,
        all_branches=all_branches
    )


@router.post("/am-assignments", response_model=GenericActionResponse)
def save_am_assignments(
    payload: SaveAMAssignmentsRequest,
    current_user: CurrentUser = Depends(get_current_user),
):
    """Save 5-7 branch assignments for an Area Manager (Admin only, app.py L14146–14163)."""
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can assign branches to Area Managers."
        )

    res = UserService.save_am_assignments(
        am_id=payload.am_id,
        branch_ids=payload.branch_ids,
        requesting_user=current_user,
    )
    if not res.get("success"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=res.get("message", "Failed to assign branches.")
        )

    return GenericActionResponse(success=True, message=res["message"])


# -----------------------------------------------------------------------------
# 9. Branch Closures & Settings
# -----------------------------------------------------------------------------
@router.get("/closures", response_model=BranchClosuresResponse)
def get_branch_closures(
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Fetch custom branch closures (app.py L14231–14252)."""
    _check_not_co(current_user)

    try:
        # Branch map
        res_b = uow.client.table("branches").select("branch_id, name").execute()
        b_map = {str(b["branch_id"]): b["name"] for b in (res_b.data or [])}

        closures = uow.branch_closures.find_all()
        # Filter for BM
        if _is_bm(current_user):
            closures = [c for c in closures if c.branch_id is None or str(c.branch_id) == str(current_user.branch_id)]

        items: List[BranchClosureItem] = []
        for c in closures:
            b_name = b_map.get(str(c.branch_id), "Global") if c.branch_id else "Global"
            items.append(BranchClosureItem(
                id=str(c.id or ""),
                start_date=c.start_date.isoformat(),
                end_date=c.end_date.isoformat(),
                reason=c.reason or "",
                branch_id=str(c.branch_id) if c.branch_id else None,
                branch_name=b_name,
            ))
        return BranchClosuresResponse(closures=items)
    except Exception as e:
        return BranchClosuresResponse(closures=[])


@router.post("/closures", response_model=CreateBranchClosureResponse)
def create_branch_closure(
    payload: CreateBranchClosureRequest,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Add new branch closure and reschedule loan installments (app.py L14177–14227)."""
    _check_not_co(current_user)

    target_branch_id = payload.branch_id
    if _is_bm(current_user):
        target_branch_id = current_user.branch_id

    try:
        s_date = date.fromisoformat(payload.start_date[:10])
        e_date = date.fromisoformat(payload.end_date[:10])
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid date format. Expected YYYY-MM-DD."
        )

    if s_date > e_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Start date cannot be after end date."
        )

    try:
        closure = BranchClosure(
            id=None,
            start_date=s_date,
            end_date=e_date,
            reason=payload.reason.strip(),
            branch_id=target_branch_id
        )
        created = uow.branch_closures.create(closure)

        # Reschedule active loan schedules
        rescheduled_count = ScheduleService.reschedule_branch_loans_on_closure(
            uow=uow,
            branch_id=target_branch_id or "",
            start_date=s_date,
            end_date=e_date
        )

        return CreateBranchClosureResponse(
            success=True,
            message="Branch closure added and loan schedules rescheduled successfully!",
            rescheduled_loans=rescheduled_count
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to add closure: {str(e)}"
        )


@router.delete("/closures/{closure_id}", response_model=GenericActionResponse)
def delete_branch_closure(
    closure_id: str,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Delete a branch closure entry."""
    _check_not_co(current_user)

    try:
        deleted = uow.branch_closures.delete(closure_id)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Closure not found or already deleted."
            )
        return GenericActionResponse(success=True, message="Branch closure deleted successfully.")
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to delete closure: {str(e)}"
        )


# -----------------------------------------------------------------------------
# 10. Audit Logs & Login History
# -----------------------------------------------------------------------------
@router.get("/audit-logs", response_model=UserAuditLogsResponse)
def get_user_audit_logs(
    limit: int = Query(200, ge=1, le=500),
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Fetch user audit logs, scoped to branch for BM (app.py L14255–14296)."""
    _check_not_co(current_user)

    try:
        query = uow.client.table("user_audit_logs").select("*")
        if _is_bm(current_user):
            branch_name = current_user.branch or ""
            if branch_name:
                query = query.ilike("branch", f"%{branch_name}%")
        res = query.order("timestamp", desc=True).limit(limit).execute()
        rows = res.data or []

        items = [
            UserAuditLogItem(
                id=str(r.get("id") or ""),
                timestamp=str(r.get("timestamp") or ""),
                username=r.get("username", "System"),
                role=r.get("role"),
                branch=r.get("branch"),
                action=r.get("action", ""),
                module=r.get("module"),
                entity_type=r.get("entity_type"),
                display_name=r.get("display_name"),
                status=r.get("status"),
            )
            for r in rows
        ]
        return UserAuditLogsResponse(logs=items, total_count=len(items))
    except Exception:
        return UserAuditLogsResponse(logs=[], total_count=0)


@router.get("/login-history", response_model=LoginHistoryResponse)
def get_login_history(
    limit: int = Query(200, ge=1, le=500),
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Fetch login history records (Admin only, app.py L14298–14316)."""
    if not _is_admin(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only administrators can view system login history."
        )

    try:
        rows = uow.login_history.find_recent(limit=limit)
        items = [
            LoginHistoryItem(
                id=str(r.get("id") or ""),
                login_time=str(r.get("login_time") or ""),
                username=r.get("username", ""),
                status=r.get("status", "SUCCESS"),
                session_id=r.get("session_id"),
                logout_time=str(r.get("logout_time")) if r.get("logout_time") else None,
                failed_attempts=int(r.get("failed_attempts") or 0),
            )
            for r in (rows or [])
        ]
        return LoginHistoryResponse(history=items, total_count=len(items))
    except Exception:
        return LoginHistoryResponse(history=[], total_count=0)
