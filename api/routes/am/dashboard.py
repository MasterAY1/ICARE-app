"""
api/routes/am/dashboard.py
Area Manager Dashboard & Regional Governance Route Adapter.
Full parity with ICARE Governance Invariants:
1. Strict Account 1000 vault cash integrity.
2. Two-tier End-of-Day (EOD) daily reconciliation sign-off.
3. High-Value Loan Confirmation (> ₦300,000).
4. Inter-Branch Transfer Sign-off.
5. Branch Supervisory Drill-down and Read-Only Handover Download Suite.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime
from fastapi import APIRouter, Depends, Query, HTTPException, status
from fastapi.responses import StreamingResponse

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role, check_branch_access
from models.user import CurrentUser
from services.area_manager_service import AreaManagerService
from services.loan_service import LoanService
from services.client_service import ClientService
from api.schemas.am_dashboard import (
    AmDashboardResponse,
    RegionalSummary,
    BranchPerformanceItem,
    AreaApprovalsHub,
    PendingHighValueLoanItem,
    PendingBranchTransferItem,
    PendingBranchEodItem,
    PendingBranchReversalItem,
    BranchHandoverSummary,
    ConfirmBranchEodRequest,
    RejectBranchEodRequest,
    ConfirmAreaClosureRequest,
    ApproveLoanRequest,
    RejectLoanRequest,
    SignOffTransferRequest,
    RejectTransferRequest,
    ApproveBranchReversalRequest,
    RejectBranchReversalRequest,
    AmActionResponse,
    OfficerProductivityItem,
    BranchOfficerProductivityResponse
)

router = APIRouter(prefix="/api/v1/am", tags=["Area Manager Dashboard & Governance"])


def _check_am_permissions(current_user: CurrentUser):
    role = (current_user.role or "").strip().lower()
    if role not in ["am", "area manager", "admin", "super admin", "director"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Area Manager or Executive privileges required."
        )


@router.get("/dashboard", response_model=AmDashboardResponse)
def get_am_dashboard(
    business_date: Optional[str] = Query(None, description="ISO format operational date (YYYY-MM-DD)"),
    start_date: Optional[str] = Query(None, description="Period start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="Period end date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns the comprehensive Area Manager dashboard:
    1. Regional Executive Summary & KPIs.
    2. Branch Comparative Performance Matrix (including capital deployment & active loan progress).
    3. Area Approvals Hub (High-value loans, transfers, EODs).
    """
    _check_am_permissions(current_user)

    target_d = date.today()
    if business_date:
        try:
            target_d = date.fromisoformat(business_date)
        except Exception:
            target_d = date.today()

    s_d = None
    e_d = None
    if start_date:
        try: s_d = date.fromisoformat(start_date)
        except Exception: pass
    if end_date:
        try: e_d = date.fromisoformat(end_date)
        except Exception: pass

    try:
        reg_dict = AreaManagerService.get_regional_summary(uow, current_user.id, target_d)
        perf_list = AreaManagerService.get_branch_performance_matrix(
            uow, current_user.id, target_date=target_d, start_date=s_d, end_date=e_d
        )
        appr_dict = AreaManagerService.get_pending_area_approvals(uow, current_user.id, target_d)

        regional_summary = RegionalSummary(**reg_dict)
        branch_performance = [BranchPerformanceItem(**b) for b in perf_list]
        approvals_hub = AreaApprovalsHub(
            pending_high_value_loans=[PendingHighValueLoanItem(**l) for l in appr_dict["pending_high_value_loans"]],
            pending_branch_transfers=[PendingBranchTransferItem(**t) for t in appr_dict["pending_branch_transfers"]],
            pending_branch_eods=[PendingBranchEodItem(**e) for e in appr_dict["pending_branch_eods"]],
            pending_branch_reversals=[PendingBranchReversalItem(**r) for r in appr_dict.get("pending_branch_reversals", [])],
            can_lock_area=appr_dict.get("can_lock_area", False)
        )

        return AmDashboardResponse(
            regional_summary=regional_summary,
            branch_performance=branch_performance,
            approvals_hub=approvals_hub
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load Area Manager dashboard: {str(e)}"
        )


@router.get("/branch-officer-productivity/{branch_id}", response_model=BranchOfficerProductivityResponse)
def get_branch_officer_productivity(
    branch_id: str,
    start_date: Optional[str] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[str] = Query(None, description="End date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Retrieves officer productivity metrics for Credit Officers within an assigned branch.
    """
    _check_am_permissions(current_user)

    s_d = None
    e_d = None
    if start_date:
        try: s_d = date.fromisoformat(start_date)
        except Exception: pass
    if end_date:
        try: e_d = date.fromisoformat(end_date)
        except Exception: pass

    try:
        data = AreaManagerService.get_branch_officer_productivity(
            uow, current_user.id, branch_id, start_date=s_d, end_date=e_d
        )
        return BranchOfficerProductivityResponse(**data)
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(ve))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch branch officer productivity: {str(e)}"
        )


@router.get("/approvals", response_model=AreaApprovalsHub)
def get_am_approvals_hub(
    business_date: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns all pending Area-level approvals.
    """
    _check_am_permissions(current_user)
    target_d = date.today()
    if business_date:
        try:
            target_d = date.fromisoformat(business_date)
        except Exception:
            pass

    try:
        appr_dict = AreaManagerService.get_pending_area_approvals(uow, current_user.id, target_d)
        return AreaApprovalsHub(
            pending_high_value_loans=[PendingHighValueLoanItem(**l) for l in appr_dict["pending_high_value_loans"]],
            pending_branch_transfers=[PendingBranchTransferItem(**t) for t in appr_dict["pending_branch_transfers"]],
            pending_branch_eods=[PendingBranchEodItem(**e) for e in appr_dict["pending_branch_eods"]],
            pending_branch_reversals=[PendingBranchReversalItem(**r) for r in appr_dict.get("pending_branch_reversals", [])],
            can_lock_area=appr_dict.get("can_lock_area", False)
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load Area approvals: {str(e)}"
        )


@router.post("/confirm-branch-eod", response_model=AmActionResponse)
def confirm_branch_eod(
    payload: ConfirmBranchEodRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager confirms an individual branch's EOD daily reconciliation.
    """
    _check_am_permissions(current_user)
    try:
        closure_d = date.fromisoformat(payload.closure_date)
        res = AreaManagerService.confirm_branch_eod(
            uow=uow,
            am_user_id=current_user.id,
            branch_id=payload.branch_id,
            closure_date=closure_d,
            notes=payload.notes
        )
        return AmActionResponse(
            success=True,
            message=res["message"],
            details=res
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/reject-branch-eod", response_model=AmActionResponse)
def reject_branch_eod(
    payload: RejectBranchEodRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager returns an individual branch's EOD submission to Branch Manager with notes for correction.
    """
    _check_am_permissions(current_user)
    try:
        closure_d = date.fromisoformat(payload.closure_date)
        res = AreaManagerService.reject_branch_eod(
            uow=uow,
            am_user_id=current_user.id,
            branch_id=payload.branch_id,
            closure_date=closure_d,
            reason=payload.reason
        )
        return AmActionResponse(
            success=True,
            message=res["message"],
            details=res
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/confirm-area-closure", response_model=AmActionResponse)
def confirm_area_closure(
    payload: ConfirmAreaClosureRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager locks and seals daily operations for the entire Area once all branches are confirmed.
    """
    _check_am_permissions(current_user)
    try:
        closure_d = date.fromisoformat(payload.closure_date)
        res = AreaManagerService.confirm_area_closure(
            uow=uow,
            am_user_id=current_user.id,
            area_name=payload.area_name,
            closure_date=closure_d
        )
        return AmActionResponse(
            success=True,
            message=res["message"],
            details=res
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/approve-loan", response_model=AmActionResponse)
def approve_high_value_loan(
    payload: ApproveLoanRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager approves an escalated or high-value loan (> ₦300,000).
    """
    _check_am_permissions(current_user)
    res_l = uow.client.table("loans").select("branch_id, loan_amount").eq("loan_id", payload.loan_id).execute()
    if not res_l.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan not found.")
    loan_row = res_l.data[0]
    check_branch_access(current_user, loan_row.get("branch_id"), "approve high-value loans")

    try:
        d_date = date.fromisoformat(payload.disbursement_date)
        res = LoanService.approve_and_disburse_loan(
            uow=uow,
            loan_id=payload.loan_id,
            approved_by=current_user.username,
            disbursement_date=d_date
        )
        return AmActionResponse(
            success=True,
            message=f"High-Value Loan #{payload.loan_id[:8]} confirmed and disbursed for {d_date.isoformat()}."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-loan", response_model=AmActionResponse)
def reject_high_value_loan(
    payload: RejectLoanRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager rejects an escalated loan.
    """
    _check_am_permissions(current_user)
    res_l = uow.client.table("loans").select("branch_id").eq("loan_id", payload.loan_id).execute()
    if not res_l.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan not found.")
    check_branch_access(current_user, res_l.data[0].get("branch_id"), "reject high-value loans")

    try:
        LoanService.reject_loan(
            uow=uow,
            loan_id=payload.loan_id,
            rejected_by=current_user.username,
            reason=payload.reason or "Rejected by Area Manager"
        )
        return AmActionResponse(
            success=True,
            message=f"Loan #{payload.loan_id[:8]} rejected by Area Manager."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/sign-off-transfer", response_model=AmActionResponse)
def sign_off_client_transfer(
    payload: SignOffTransferRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager signs off on an inter-branch client transfer.
    Transitions status to PENDING_RECEIVING_BM so the destination Branch Manager
    can accept and assign a local Credit Officer and Solidarity Group.
    """
    _check_am_permissions(current_user)
    res_t = uow.client.table("client_transfers").select("transfer_id, client_id, from_branch_id, to_branch_id").eq("transfer_id", payload.transfer_id).execute()
    if not res_t.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer request not found.")
    t_row = res_t.data[0]
    check_branch_access(current_user, t_row.get("from_branch_id") or t_row.get("to_branch_id"), "sign off client transfer")

    try:
        now_iso = datetime.now().isoformat()
        user_uuid = current_user.id if current_user.id else None

        uow.client.table("client_transfers").update({
            "status": "PENDING_RECEIVING_BM",
            "approved_by": user_uuid,
            "approved_at": now_iso,
            "notes": payload.notes or f"Signed off by AM {current_user.username}"
        }).eq("transfer_id", payload.transfer_id).execute()

        # Audit Log
        uow.client.table("audit_logs").insert({
            "action": "CLIENT_TRANSFER_AM_APPROVED",
            "entity": "client_transfers",
            "entity_id": payload.transfer_id,
            "user_id": user_uuid,
            "details": f"Area Manager {current_user.username} approved inter-branch transfer #{payload.transfer_id[:8]} (Awaiting Receiving BM Assignment)"
        }).execute()

        return AmActionResponse(
            success=True,
            message="Inter-branch transfer approved by Area Manager and forwarded to destination branch."
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-transfer", response_model=AmActionResponse)
def reject_client_transfer(
    payload: RejectTransferRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager rejects an inter-branch client transfer.
    """
    _check_am_permissions(current_user)
    try:
        now_iso = datetime.now().isoformat()
        user_uuid = current_user.id if current_user.id else None

        res_t = uow.client.table("client_transfers").select("transfer_id, client_id, from_branch_id, to_branch_id").eq("transfer_id", payload.transfer_id).execute()
        if not res_t.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transfer request not found.")
        t_row = res_t.data[0]
        check_branch_access(current_user, t_row.get("from_branch_id") or t_row.get("to_branch_id"), "reject client transfer")

        uow.client.table("client_transfers").update({
            "status": "REJECTED",
            "rejected_by": user_uuid,
            "rejected_at": now_iso,
            "rejection_reason": payload.reason,
            "notes": payload.reason
        }).eq("transfer_id", payload.transfer_id).execute()

        uow.client.table("audit_logs").insert({
            "action": "CLIENT_TRANSFER_AM_REJECTED",
            "entity": "client_transfers",
            "entity_id": payload.transfer_id,
            "user_id": user_uuid,
            "details": f"Area Manager {current_user.username} rejected inter-branch transfer #{payload.transfer_id[:8]}. Reason: {payload.reason}"
        }).execute()

        return AmActionResponse(
            success=True,
            message=f"Inter-branch transfer #{payload.transfer_id[:8]} rejected."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get("/branch-handover/{branch_id}", response_model=BranchHandoverSummary)
def get_branch_handover(
    branch_id: str,
    business_date: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns available reports and handover summary for a supervised branch in read-only mode.
    """
    _check_am_permissions(current_user)
    target_d = date.today()
    if business_date:
        try:
            target_d = date.fromisoformat(business_date)
        except Exception:
            pass

    try:
        res = AreaManagerService.get_branch_handover_summary(uow, current_user.id, branch_id, target_d)
        return BranchHandoverSummary(**res)
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/branch-inspection/{branch_id}")
def get_branch_inspection(
    branch_id: str,
    business_date: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns full supervisory drill-down details for an individual branch (equivalent to BM console).
    """
    _check_am_permissions(current_user)
    target_d = date.today()
    if business_date:
        try:
            target_d = date.fromisoformat(business_date)
        except Exception:
            pass

    try:
        return AreaManagerService.get_branch_inspection_data(uow, current_user.id, branch_id, target_d)
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/approve-branch-reversal", response_model=AmActionResponse)
def approve_branch_reversal(
    payload: ApproveBranchReversalRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager signs off on a branch-level correction / treasury reversal (BR-ERR-001).
    """
    _check_am_permissions(current_user)
    try:
        res = AreaManagerService.approve_branch_reversal(
            uow=uow,
            am_user_id=current_user.id,
            request_id=payload.request_id
        )
        return AmActionResponse(
            success=True,
            message=res["message"],
            details=res
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/reject-branch-reversal", response_model=AmActionResponse)
def reject_branch_reversal(
    payload: RejectBranchReversalRequest,
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Area Manager rejects a branch-level correction / treasury reversal.
    """
    _check_am_permissions(current_user)
    try:
        res = AreaManagerService.reject_branch_reversal(
            uow=uow,
            am_user_id=current_user.id,
            request_id=payload.request_id,
            reason=payload.reason
        )
        return AmActionResponse(
            success=True,
            message=res["message"],
            details=res
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/reports/excel")
def download_area_excel_workbook(
    business_date: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(require_role(["AM", "Area Manager", "Admin", "Super Admin", "Director"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Downloads multi-tab regional Excel workbook for Area 1.
    """
    _check_am_permissions(current_user)
    target_d = date.today()
    if business_date:
        try:
            target_d = date.fromisoformat(business_date)
        except Exception:
            pass

    try:
        stream = AreaManagerService.generate_area_excel_workbook(uow, current_user.id, target_d)
        filename = f"Area_1_Regional_Report_{target_d.isoformat()}.xlsx"
        return StreamingResponse(
            stream,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'}
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate Area Excel workbook: {str(e)}"
        )
