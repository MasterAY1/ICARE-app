"""
api/routes/bm/approvals.py
Branch Manager Four-Eyes Approval and Automated Operations Router.
Handles:
1. Client Profile Update Review (Approve / Reject).
2. Automated 3-Month LAPS Sweep (Preview / Execute).
3. Automated 3-Default Loan & Client Defaulter Evaluation.
"""
from typing import Optional, List, Dict, Any
from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException, status

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role, check_branch_access
from models.user import CurrentUser
from services.client_service import ClientService
from services.savings_service import SavingsService
from services.schedule_service import ScheduleService
from api.schemas.approvals import (
    PendingClientUpdateItem,
    RejectClientUpdateRequest,
    ApprovalActionResponse,
    LapsSweepPreviewItem,
    LapsSweepResponse,
    DefaulterEvaluationResponse
)

router = APIRouter(prefix="/api/v1/bm", tags=["BM Approvals & Operations"])


# =========================================================================
# 1. CLIENT PROFILE UPDATE FOUR-EYES APPROVALS
# =========================================================================

@router.get("/approvals/client-updates/pending", response_model=List[PendingClientUpdateItem])
def get_pending_client_update_requests(
    branch_id: Optional[str] = Query(None, description="Optional branch filter for supervising roles"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns pending client profile modifications awaiting Branch Manager approval.
    """
    # Enforce branch scope for Branch Managers
    target_branch = branch_id
    if current_user.role in ["BM", "Branch Manager"]:
        target_branch = current_user.branch_id
    elif not target_branch and current_user.branch_id:
        target_branch = current_user.branch_id

    records = ClientService.get_pending_profile_update_requests(uow, branch_id=target_branch)

    items = []
    for r in records:
        items.append(PendingClientUpdateItem(
            request_id=r["request_id"],
            client_id=r["client_id"],
            client_name=r.get("client_name", "Unknown"),
            client_code=r.get("client_code", ""),
            branch_id=r["branch_id"],
            branch_name=r.get("branch_name", ""),
            requested_by_name=r.get("requested_by_name", ""),
            proposed_changes=r.get("proposed_changes", {}),
            previous_values=r.get("previous_values", {}),
            created_at=r.get("created_at")
        ))
    return items


@router.post("/approvals/client-updates/{request_id}/approve", response_model=ApprovalActionResponse)
def approve_client_update_request(
    request_id: str,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Branch Manager approves client profile update and applies changes atomically.
    """
    res = ClientService.approve_profile_update_request(
        uow=uow,
        request_id=request_id,
        approved_by=current_user.id or current_user.username
    )
    return ApprovalActionResponse(
        success=True,
        status="APPROVED",
        message=res["message"],
        request_id=request_id
    )


@router.post("/approvals/client-updates/{request_id}/reject", response_model=ApprovalActionResponse)
def reject_client_update_request(
    request_id: str,
    payload: RejectClientUpdateRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Branch Manager rejects client profile update with required justification reason.
    """
    res = ClientService.reject_profile_update_request(
        uow=uow,
        request_id=request_id,
        rejected_by=current_user.id or current_user.username,
        reason=payload.reason
    )
    return ApprovalActionResponse(
        success=True,
        status="REJECTED",
        message=res["message"],
        request_id=request_id
    )


# =========================================================================
# 2. AUTOMATIC 3-MONTH LAPS SAVINGS SWEEP
# =========================================================================

@router.get("/savings/sweep-laps-preview", response_model=List[LapsSweepPreviewItem])
def preview_laps_savings_sweep(
    branch_id: Optional[str] = Query(None, description="Optional branch ID"),
    threshold_days: int = Query(90, ge=1, description="Threshold days of inactivity (default 90 days = 3 months)"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Previews eligible clients with status 'Inactive (Savings Only)', 'Dormant', or 'Suspended'
    for >= 3 months (90 days) who have positive individual savings balances.
    """
    target_branch = branch_id
    if current_user.role in ["BM", "Branch Manager"]:
        target_branch = current_user.branch_id
    elif not target_branch and current_user.branch_id:
        target_branch = current_user.branch_id

    candidates = SavingsService.preview_automatic_laps_sweep(
        uow=uow,
        branch_id=target_branch,
        threshold_days=threshold_days
    )

    items = []
    for c in candidates:
        items.append(LapsSweepPreviewItem(
            client_id=c["client_id"],
            client_name=c["client_name"],
            client_code=c["client_code"],
            branch_name=c["branch_name"],
            officer_name=c["officer_name"],
            status=c["status"],
            days_in_status=c["days_in_status"],
            savings_balance=c["savings_balance"]
        ))
    return items


@router.post("/savings/sweep-laps", response_model=LapsSweepResponse)
def execute_laps_savings_sweep(
    branch_id: Optional[str] = Query(None, description="Optional branch ID"),
    threshold_days: int = Query(90, ge=1, description="Threshold days of inactivity (default 90 days = 3 months)"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Executes automated sweep to LAPS for clients inactive >= 3 months.
    Non-cash internal transfer (zero impact on physical Account 1000 vault cash).
    """
    target_branch = branch_id
    if current_user.role in ["BM", "Branch Manager"]:
        target_branch = current_user.branch_id
    elif not target_branch and current_user.branch_id:
        target_branch = current_user.branch_id

    result = SavingsService.process_automatic_laps_sweep(
        uow=uow,
        branch_id=target_branch,
        threshold_days=threshold_days
    )

    return LapsSweepResponse(
        success=result["success"],
        swept_count=result["swept_count"],
        total_amount=result["total_amount"],
        details=result["details"],
        message=result["message"]
    )


# =========================================================================
# 3. AUTOMATIC 3-DEFAULT LOAN & CLIENT EVALUATION
# =========================================================================

@router.post("/loans/evaluate-defaulters", response_model=DefaulterEvaluationResponse)
def evaluate_loan_defaulters(
    branch_id: Optional[str] = Query(None, description="Optional branch ID"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Evaluates active loans against the 3-default rule.
    Any loan with 3 or more missed installments is automatically transitioned
    to 'Defaulter', and the client's lifecycle status is updated to 'Defaulter'.
    """
    target_branch = branch_id
    if current_user.role in ["BM", "Branch Manager"]:
        target_branch = current_user.branch_id
    elif not target_branch and current_user.branch_id:
        target_branch = current_user.branch_id

    result = ScheduleService.evaluate_branch_defaults(
        uow=uow,
        branch_id=target_branch,
        actor_id=current_user.id or current_user.username
    )

    return DefaulterEvaluationResponse(
        success=result["success"],
        evaluated_count=result["evaluated_count"],
        new_defaulters_count=result["new_defaulters_count"],
        defaulters=result["defaulters"],
        message=result["message"]
    )
