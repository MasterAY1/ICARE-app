"""
Branch Manager Dashboard route adapter.
Provides presentation-ready dashboard dataset and approval endpoints for BM / Supervising roles.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime
from fastapi import APIRouter, Depends, Query, HTTPException, status
import pandas as pd

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from models.user import CurrentUser
from services.dashboard_service import DashboardService
from services.business_date_service import BusinessDateService
from services.loan_service import LoanService
from services.savings_service import SavingsService
from services.correction_service import CorrectionService

from api.schemas.bm_dashboard import (
    BmDashboardResponse,
    BranchSummary,
    BranchCashPosition,
    OfficerCollectionStatusItem,
    PendingLoanApprovalItem,
    PendingWithdrawalApprovalItem,
    PendingCorrectionApprovalItem,
    ApproveLoanRequest,
    RejectLoanRequest,
    BatchApproveLoansRequest,
    ApproveWithdrawalRequest,
    RejectWithdrawalRequest,
    BatchApproveWithdrawalsRequest,
    ApproveCorrectionRequest,
    RejectCorrectionRequest,
    BatchApproveCorrectionsRequest,
    ActionResponse
)

router = APIRouter(prefix="/api/v1/bm", tags=["Branch Manager Dashboard"])


def _execute_withdrawal_approval(uow_exec: SupabaseUnitOfWork, wr_item: dict, op_date: date, branch: str, user: str):
    w_id = wr_item["id"]
    # Idempotency check: ensure request hasn't already been approved
    chk = uow_exec.client.table("withdrawal_requests").select("status").eq("id", w_id).execute()
    if chk.data and chk.data[0].get("status") == "APPROVED":
        return

    w_type = wr_item.get("savings_type")
    w_op = wr_item.get("operation_type")
    w_amt = float(wr_item.get("amount", 0))
    w_name = wr_item.get("client_name", "")
    w_by = wr_item.get("requested_by", user)
    w_remarks = wr_item.get("remarks") or ""

    s_type = "GroupSavings" if w_type == "Group" else ("MiscSavings" if w_type == "Misc" else "IndividualSavings")
    if w_op in ["Cash Withdrawal", "Bank Transfer", "Client Bank Account (Transfer)", "Group Bank Account (Transfer)"]:
        if w_type == "Individual":
            SavingsService.post_individual_savings(
                uow=uow_exec, client_id=wr_item.get("client_id"), client_name=w_name,
                branch=branch, officer=w_by, deposit_amount=0.0, withdrawal_amount=w_amt,
                reference=wr_item.get("reference"), remarks=f"[BM APPROVED] {w_remarks}",
                posting_date=op_date
            )
        elif w_type == "Group":
            SavingsService.post_group_savings(
                uow=uow_exec, group_name=wr_item.get("group_name") or w_name, branch=branch,
                officer=w_by, deposit_amount=0.0, withdrawal_amount=w_amt,
                reference=wr_item.get("reference"), remarks=f"[BM APPROVED] {w_remarks}",
                posting_date=op_date
            )
        elif w_type == "Misc":
            SavingsService.post_misc_savings(
                uow=uow_exec, client_id=wr_item.get("client_id") or "", client_name=w_name,
                branch=branch, officer=w_by, deposit_amount=0.0, withdrawal_amount=w_amt,
                reference=wr_item.get("reference"), remarks=f"[BM APPROVED] {w_remarks}",
                posting_date=op_date
            )
    elif w_op in ["Loan Offset", "Asset Downpayment", "Loan Repayment / Asset Debt Offset"]:
        SavingsService.post_loan_offset_from_savings(
            uow=uow_exec, client_id=wr_item.get("client_id"), client_name=w_name,
            loan_id=wr_item.get("loan_id"), source_savings_type=s_type,
            branch=branch, officer=w_by, amount=w_amt,
            reference=wr_item.get("reference"), remarks=f"[BM APPROVED {w_op.upper()}] {w_remarks}",
            posting_date=op_date
        )
    elif w_op in ["Fee Offset", "Fee Payment from Savings"]:
        fee_code = "misc_fees"
        if "[FEE:" in w_remarks:
            try: fee_code = w_remarks.split("[FEE:")[1].split("]")[0].strip()
            except Exception: pass
        SavingsService.post_fee_offset_from_savings(
            uow=uow_exec, client_id=wr_item.get("client_id"), client_name=w_name,
            source_savings_type=s_type, branch=branch, officer=w_by,
            fee_type=fee_code, amount=w_amt,
            reference=wr_item.get("reference"), remarks=f"[BM APPROVED FEE OFFSET] {w_remarks}",
            posting_date=op_date
        )
    elif w_op in ["Savings Transfer", "Transfer to Another Savings", "Another Member or Group Savings"]:
        dest_id = wr_item.get("client_id")
        dest_name = w_name
        dest_type = "IndividualSavings"
        if "[DEST_ID:" in w_remarks:
            try:
                dest_id = w_remarks.split("[DEST_ID:")[1].split("]")[0].strip()
                dest_name = w_remarks.split("[DEST_NAME:")[1].split("]")[0].strip()
                dest_type = w_remarks.split("[DEST_TYPE:")[1].split("]")[0].strip()
            except Exception: pass
        SavingsService.transfer_savings(
            uow=uow_exec, source_id=wr_item.get("client_id"), source_name=w_name,
            source_type=s_type, destination_id=dest_id,
            destination_name=dest_name, destination_type=dest_type,
            branch=branch, officer=w_by, amount=w_amt,
            reference=wr_item.get("reference"), remarks=f"[BM APPROVED TRANSFER] {w_remarks}",
            posting_date=op_date
        )
    elif w_op == "LAPS Transfer":
        SavingsService.transfer_to_laps(
            uow=uow_exec, client_id=wr_item.get("client_id"), client_name=w_name,
            source_savings_type=s_type, branch=branch, officer=w_by, amount=w_amt,
            reference=wr_item.get("reference"), remarks=f"[BM APPROVED] {w_remarks}",
            posting_date=op_date
        )
    elif w_op == "LAPS Payout":
        cash_paid = (wr_item.get("payout_method") or "Cash") == "Cash"
        SavingsService.pay_laps(
            uow=uow_exec, client_id=wr_item.get("client_id"), client_name=w_name,
            branch=branch, officer=w_by, amount=w_amt, cash_paid=cash_paid,
            reference=wr_item.get("reference"), remarks=f"[BM APPROVED] {w_remarks}",
            posting_date=op_date
        )

    uow_exec.client.table("withdrawal_requests").update({
        "status": "APPROVED",
        "approved_by": user,
        "approved_at": datetime.now().isoformat()
    }).eq("id", w_id).execute()


@router.get("/dashboard", response_model=BmDashboardResponse)
def get_bm_dashboard(
    date_str: Optional[str] = Query(None, alias="date", description="Target ISO date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns presentation-ready BM Dashboard dataset for the authenticated branch manager.
    """
    branch_name = current_user.branch
    branch_id = current_user.branch_id

    target_date = BusinessDateService.get_business_date(uow, branch_name) if branch_name else date.today()
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )

    try:
        bm_data = DashboardService.get_bm_dashboard_data(
            uow=uow,
            branch_name=branch_name,
            branch_id=branch_id,
            target_date=target_date
        )

        bs = bm_data.get("branch_summary", {})
        branch_summary = BranchSummary(
            active_clients=int(bs.get("active_clients", 0)),
            active_loans=int(bs.get("active_loans", 0)),
            active_savings=float(bs.get("active_savings", 0.0)),
            collection_today=float(bs.get("collection_today", 0.0)),
            par=str(bs.get("par", "0.0%"))
        )

        bcp = bm_data.get("branch_cash_position", {})
        branch_cash_pos = BranchCashPosition(
            opening_balance=float(bcp.get("opening_balance", 0.0)),
            cash_in=float(bcp.get("cash_in", 0.0)),
            cash_out=float(bcp.get("cash_out", 0.0)),
            bank_deposit=float(bcp.get("bank_deposit", 0.0)),
            bank_withdrawal=float(bcp.get("bank_withdrawal", 0.0)),
            closing_balance=float(bcp.get("closing_balance", 0.0)),
            status=str(bcp.get("status", "Balanced")),
            difference=float(bcp.get("difference", 0.0))
        )

        # Parse officer_collection_status DataFrame
        officer_status_list: List[OfficerCollectionStatusItem] = []
        off_df = bm_data.get("officer_collection_status")
        if isinstance(off_df, pd.DataFrame) and not off_df.empty:
            for _, r in off_df.iterrows():
                comp_pct = float(r.get("Compliance %") or r.get("compliance_pct") or 0.0)
                officer_status_list.append(OfficerCollectionStatusItem(
                    officer=str(r.get("Officer") or ""),
                    officer_name=str(r.get("Officer Name") or r.get("Officer") or ""),
                    groups_scheduled=int(r.get("Groups Scheduled") or 0),
                    scheduled_groups=str(r.get("Scheduled Groups") or "None Scheduled"),
                    expected=float(r.get("Expected") or 0.0),
                    collected=float(r.get("Collected") or 0.0),
                    outstanding=float(r.get("Outstanding") or 0.0),
                    compliance_pct=comp_pct,
                    closing_balance=float(r.get("Closing Balance") or 0.0),
                    status=str(r.get("Status") or "Normal")
                ))

        # Query pending approvals
        p_loans = bm_data.get("approval_queue", [])
        pending_loan_items: List[PendingLoanApprovalItem] = []
        for pl in p_loans:
            c_dict = pl.get("clients") or {}
            c_name = c_dict.get("name") or pl.get("client_name", "Unknown Client")
            c_code = c_dict.get("client_code") or pl.get("client_id", "")[:8]
            u_dict = pl.get("app_users") or {}
            officer = (u_dict.get("username") or u_dict.get("full_name")) if isinstance(u_dict, dict) else (pl.get("officer") or "Unknown")
            p_dict = pl.get("loan_products") or {}
            prod = p_dict.get("name") if isinstance(p_dict, dict) else (pl.get("loan_product") or "Standard")
            amt = float(pl.get("loan_amount") or 0.0)

            pending_loan_items.append(PendingLoanApprovalItem(
                loan_id=str(pl.get("loan_id")),
                client_name=c_name,
                client_code=c_code,
                officer=officer,
                loan_product=prod,
                loan_amount=amt,
                disbursement_date=str(pl.get("date"))[:10] if pl.get("date") else None
            ))

        res_wr = uow.client.table("withdrawal_requests").select("*") \
            .eq("branch_id", branch_id).eq("status", "PENDING").order("created_at", desc=False).execute()
        pending_wr_items: List[PendingWithdrawalApprovalItem] = []
        for wr in (res_wr.data or []):
            pending_wr_items.append(PendingWithdrawalApprovalItem(
                id=str(wr["id"]),
                client_id=wr.get("client_id"),
                client_name=str(wr.get("client_name") or ""),
                group_name=wr.get("group_name"),
                savings_type=str(wr.get("savings_type") or "Individual"),
                operation_type=str(wr.get("operation_type") or "Cash Withdrawal"),
                amount=float(wr.get("amount") or 0.0),
                requested_by=str(wr.get("requested_by") or "Officer"),
                reference=wr.get("reference"),
                remarks=wr.get("remarks"),
                operational_date=str(wr.get("operational_date"))[:10] if wr.get("operational_date") else None,
                created_at=str(wr.get("created_at")) if wr.get("created_at") else None
            ))

        res_corr = uow.client.table("correction_requests") \
            .select("*, app_users!correction_requests_requested_by_fkey(username, full_name)") \
            .eq("branch_id", branch_id).eq("status", "Pending").order("created_at", desc=False).execute()
        pending_corr_items: List[PendingCorrectionApprovalItem] = []
        for corr in (res_corr.data or []):
            u_data = corr.get("app_users")
            req_u = (u_data.get("full_name") or u_data.get("username")) if isinstance(u_data, dict) else "Officer"
            pending_corr_items.append(PendingCorrectionApprovalItem(
                id=str(corr["id"]),
                record_id=str(corr.get("record_id") or ""),
                record_type=str(corr.get("record_type") or "Transaction"),
                reason=str(corr.get("reason") or ""),
                requested_by=str(req_u),
                created_at=str(corr.get("created_at")) if corr.get("created_at") else None
            ))

        closure = bm_data.get("branch_closure", {})
        return BmDashboardResponse(
            branch_name=branch_name,
            business_date=target_date.isoformat(),
            meeting_day=target_date.strftime("%A"),
            is_closed=bool(closure.get("is_closed", False)),
            closure_reason=str(closure.get("reason", "")),
            branch_summary=branch_summary,
            branch_cash_position=branch_cash_pos,
            officer_collection_status=officer_status_list,
            pending_loans=pending_loan_items,
            pending_withdrawals=pending_wr_items,
            pending_corrections=pending_corr_items
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate BM dashboard: {str(e)}"
        )


# ==========================================
# LOAN APPROVALS & REJECTIONS
# ==========================================

@router.post("/approve-loan", response_model=ActionResponse)
def approve_loan(
    payload: ApproveLoanRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    try:
        d_date = date.fromisoformat(payload.disbursement_date)
        res = LoanService.approve_and_disburse_loan(
            uow=uow,
            loan_id=payload.loan_id,
            approved_by=current_user.username,
            disbursement_date=d_date
        )
        return ActionResponse(
            success=True,
            message=f"Loan #{payload.loan_id[:8]} approved and disbursed on {d_date.isoformat()}."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-loan", response_model=ActionResponse)
def reject_loan(
    payload: RejectLoanRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    try:
        LoanService.reject_loan(
            uow=uow,
            loan_id=payload.loan_id,
            rejected_by=current_user.username,
            reason=payload.reason or "Rejected by BM"
        )
        return ActionResponse(
            success=True,
            message=f"Loan #{payload.loan_id[:8]} rejected."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/batch-approve-loans", response_model=ActionResponse)
def batch_approve_loans(
    payload: BatchApproveLoansRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    s_cnt = 0
    f_cnt = 0
    errors = []
    default_d = date.fromisoformat(payload.default_disbursement_date)
    dates_map = payload.loan_dates_map or {}

    for lid in payload.loan_ids:
        try:
            cur_d = date.fromisoformat(dates_map[lid]) if lid in dates_map else default_d
            LoanService.approve_and_disburse_loan(
                uow=uow,
                loan_id=lid,
                approved_by=current_user.username,
                disbursement_date=cur_d
            )
            s_cnt += 1
        except Exception as ex:
            f_cnt += 1
            errors.append(f"Loan #{lid[:8]}: {str(ex)}")

    return ActionResponse(
        success=(s_cnt > 0),
        message=f"Batch processed: {s_cnt} approved, {f_cnt} failed.",
        details={"successful": s_cnt, "failed": f_cnt, "errors": errors}
    )


# ==========================================
# WITHDRAWAL APPROVALS & REJECTIONS
# ==========================================

@router.post("/approve-withdrawal", response_model=ActionResponse)
def approve_withdrawal(
    payload: ApproveWithdrawalRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    try:
        res = uow.client.table("withdrawal_requests").select("*").eq("id", payload.withdrawal_id).execute()
        if not res.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Withdrawal request not found.")
        wr = res.data[0]
        op_d = date.fromisoformat(payload.operational_date)
        _execute_withdrawal_approval(uow, wr, op_d, current_user.branch, current_user.username)
        return ActionResponse(
            success=True,
            message=f"Withdrawal of ₦{float(wr.get('amount', 0)):,.2f} for {wr.get('client_name')} approved and posted to ledger."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-withdrawal", response_model=ActionResponse)
def reject_withdrawal(
    payload: RejectWithdrawalRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    try:
        uow.client.table("withdrawal_requests").update({
            "status": "REJECTED",
            "approved_by": current_user.username,
            "approved_at": datetime.now().isoformat(),
            "rejection_reason": payload.reason or "Rejected by BM"
        }).eq("id", payload.withdrawal_id).execute()
        return ActionResponse(
            success=True,
            message=f"Withdrawal request #{payload.withdrawal_id[:8]} rejected."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/batch-approve-withdrawals", response_model=ActionResponse)
def batch_approve_withdrawals(
    payload: BatchApproveWithdrawalsRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    s_cnt = 0
    f_cnt = 0
    errors = []
    default_d = date.fromisoformat(payload.default_operational_date)
    dates_map = payload.withdrawal_dates_map or {}

    res = uow.client.table("withdrawal_requests").select("*").in_("id", payload.withdrawal_ids).execute()
    wr_map = {w["id"]: w for w in (res.data or [])}

    for wid in payload.withdrawal_ids:
        wr_item = wr_map.get(wid)
        if not wr_item:
            continue
        try:
            cur_d = date.fromisoformat(dates_map[wid]) if wid in dates_map else default_d
            _execute_withdrawal_approval(uow, wr_item, cur_d, current_user.branch, current_user.username)
            s_cnt += 1
        except Exception as ex:
            f_cnt += 1
            errors.append(f"Withdrawal #{wid[:8]}: {str(ex)}")

    return ActionResponse(
        success=(s_cnt > 0),
        message=f"Batch processed: {s_cnt} approved, {f_cnt} failed.",
        details={"successful": s_cnt, "failed": f_cnt, "errors": errors}
    )


# ==========================================
# ERROR CORRECTION APPROVALS & REJECTIONS
# ==========================================

@router.post("/approve-correction", response_model=ActionResponse)
def approve_correction(
    payload: ApproveCorrectionRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    try:
        user_identifier = current_user.id or current_user.username
        CorrectionService.approve_correction(uow, payload.correction_id, approved_by=user_identifier)
        return ActionResponse(
            success=True,
            message="Reversal approved and executed atomically."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-correction", response_model=ActionResponse)
def reject_correction(
    payload: RejectCorrectionRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    try:
        user_identifier = current_user.id or current_user.username
        CorrectionService.reject_correction(uow, payload.correction_id, approved_by=user_identifier)
        return ActionResponse(
            success=True,
            message="Reversal rejected."
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/batch-approve-corrections", response_model=ActionResponse)
def batch_approve_corrections(
    payload: BatchApproveCorrectionsRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    s_cnt = 0
    f_cnt = 0
    errors = []
    user_identifier = current_user.id or current_user.username

    for cid in payload.correction_ids:
        try:
            CorrectionService.approve_correction(uow, cid, approved_by=user_identifier)
            s_cnt += 1
        except Exception as ex:
            f_cnt += 1
            errors.append(f"Correction #{cid[:8]}: {str(ex)}")

    return ActionResponse(
        success=(s_cnt > 0),
        message=f"Batch processed: {s_cnt} approved, {f_cnt} failed.",
        details={"successful": s_cnt, "failed": f_cnt, "errors": errors}
    )
