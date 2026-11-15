"""
Branch Manager Dashboard route adapter.
Provides presentation-ready dashboard dataset and approval endpoints for BM / Supervising roles.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime
import re
from concurrent.futures import ThreadPoolExecutor
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
from services.rbac_scope_service import RBACScopeService

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


def _resolve_branch_name(uow: SupabaseUnitOfWork, branch_id: Optional[str]) -> str:
    """Resolves branch name from branch_id UUID."""
    if not branch_id:
        return ""
    try:
        res = uow.client.table("branches").select("name").eq("branch_id", branch_id).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("name", "")
    except Exception:
        pass
    return ""


def _check_branch_access(current_user: CurrentUser, target_branch_id: Optional[str], action_desc: str = "manage records"):
    """
    Strict multi-branch authorization guard:
    - Admin / Super Admin / Director: allowed across all branches
    - Branch Manager: target_branch_id must match current_user.branch_id exactly
    - Area Manager: target_branch_id must be in current_user.assigned_branch_ids
    - Any other role: 403 Forbidden
    """
    norm_role = RBACScopeService.normalize_role(current_user.role)
    if norm_role in ["Admin", "Director"]:
        return

    if not target_branch_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Target record has no valid branch assignment; cannot {action_desc}."
        )

    if norm_role == "Branch Manager":
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


def _execute_withdrawal_approval(uow_exec: SupabaseUnitOfWork, wr_item: dict, op_date: date, branch: str, user: str):
    w_id = wr_item["id"]
    now_iso = datetime.now().isoformat()
    # Atomic status lock: claim the withdrawal request using atomic conditional update
    claim_res = uow_exec.client.table("withdrawal_requests").update({
        "status": "PROCESSING",
        "approved_by": user,
        "approved_at": now_iso
    }).eq("id", w_id).eq("status", "PENDING").execute()

    if not claim_res.data:
        chk = uow_exec.client.table("withdrawal_requests").select("status").eq("id", w_id).execute()
        if chk.data and chk.data[0].get("status") in ["APPROVED", "PROCESSING"]:
            return
        raise ValueError(f"Withdrawal request #{w_id[:8]} cannot be approved (current status: {chk.data[0].get('status') if chk.data else 'Unknown'}).")

    # Authoritative branch resolution: ensure ledger postings target the withdrawal's actual branch vault
    wr_branch_id = wr_item.get("branch_id")
    resolved_branch = _resolve_branch_name(uow_exec, wr_branch_id) if wr_branch_id else ""
    posting_branch = resolved_branch or branch

    wr_update_op = {
        "type": "update",
        "table": "withdrawal_requests",
        "match": {"id": w_id, "status": "PROCESSING"},
        "record": {
            "status": "APPROVED",
            "approved_by": user,
            "approved_at": now_iso,
            "operational_date": op_date.isoformat(),
        },
    }

    try:
        SavingsService.execute_approved_withdrawal(
            uow=uow_exec,
            wr_item=wr_item,
            op_date=op_date,
            branch=posting_branch,
            actor_username=user,
            actor_role="Branch Manager",
            extra_operations=[wr_update_op],
            validate_balance=True,
            narration_prefix="[BM APPROVED]",
        )
    except Exception:
        try:
            uow_exec.client.table("withdrawal_requests").update({
                "status": "PENDING",
                "approved_by": None,
                "approved_at": None,
            }).eq("id", w_id).eq("status", "PROCESSING").execute()
        except Exception:
            pass
        raise


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
        def _fetch_bm_data():
            return DashboardService.get_bm_dashboard_data(
                uow=uow,
                branch_name=branch_name,
                branch_id=branch_id,
                target_date=target_date
            )

        def _fetch_withdrawals():
            return uow.client.table("withdrawal_requests").select("*") \
                .eq("branch_id", branch_id).eq("status", "PENDING").order("created_at", desc=False).execute()

        def _fetch_corrections():
            return uow.client.table("correction_requests") \
                .select("*, app_users!correction_requests_requested_by_fkey(username, full_name)") \
                .eq("branch_id", branch_id).eq("status", "Pending").order("created_at", desc=False).execute()

        with ThreadPoolExecutor(max_workers=3) as executor:
            fut_bm = executor.submit(_fetch_bm_data)
            fut_wr = executor.submit(_fetch_withdrawals)
            fut_corr = executor.submit(_fetch_corrections)

            bm_data = fut_bm.result()
            res_wr = fut_wr.result()
            res_corr = fut_corr.result()

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

        def _strip_wr_tags(val: Optional[str]) -> Optional[str]:
            if not val:
                return None
            cleaned = str(val)
            for pat in (
                r"\[DEST_ID:[^\]]*\]",
                r"\[DEST_NAME:[^\]]*\]",
                r"\[DEST_TYPE:[^\]]*\]",
                r"\[FEE:[^\]]*\]",
                r"\[LOAN_OFFSET:[^\]]*\]",
            ):
                cleaned = re.sub(pat, "", cleaned, flags=re.IGNORECASE)
            cleaned = re.sub(r"\s+", " ", cleaned).strip()
            return cleaned or None

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
                remarks=_strip_wr_tags(wr.get("remarks")),
                operational_date=str(wr.get("operational_date"))[:10] if wr.get("operational_date") else None,
                created_at=str(wr.get("created_at")) if wr.get("created_at") else None
            ))

        # Batch enrich pending corrections with transaction amount and client details
        rep_ids = [str(c["record_id"]) for c in (res_corr.data or []) if c.get("record_type") in ["Repayment", "Loan"]]
        sav_ids = [
            str(c["record_id"]) for c in (res_corr.data or [])
            if c.get("record_type") in [
                "Savings", "SavingsDeposit", "SavingsWithdrawal", "Savings Withdrawal",
                "individual_savings", "group_savings", "internal_savings", "laps_savings",
            ]
        ]
        try_ids = [str(c["record_id"]) for c in (res_corr.data or []) if c.get("record_type") in ["Treasury", "TreasuryTransaction", "Expense", "Salary", "Fee", "FeeCharged"]]

        rep_meta = {}
        if rep_ids:
            try:
                r_res = uow.client.table("repayments").select("id, amount_paid, clients(name, client_code)").in_("id", rep_ids).execute()
                for r in (r_res.data or []):
                    c_info = r.get("clients") or {} if isinstance(r.get("clients"), dict) else {}
                    rep_meta[str(r["id"])] = {
                        "amount": float(r.get("amount_paid") or 0.0),
                        "client_name": c_info.get("name") or "Member",
                        "client_code": c_info.get("client_code") or ""
                    }
            except Exception:
                pass

        sav_meta = {}
        if sav_ids:
            for s_tbl, s_sel, lbl_default in [
                ("individual_savings", "id, deposit_amount, withdrawal_amount, clients(name, client_code)", "Member"),
                ("group_savings", "id, deposit_amount, withdrawal_amount, groups(name)", "Group"),
                ("internal_savings", "id, deposit_amount, withdrawal_amount, remarks", "Branch Misc Reserve"),
                ("laps_savings", "id, client_id, deposit_amount, withdrawal_amount, remarks", "LAPS Reserve"),
            ]:
                remaining = [sid for sid in sav_ids if sid not in sav_meta]
                if not remaining:
                    break
                try:
                    s_res = uow.client.table(s_tbl).select(s_sel).in_("id", remaining).execute()
                    for s in (s_res.data or []):
                        dep_v = float(s.get("deposit_amount") or 0.0)
                        wth_v = float(s.get("withdrawal_amount") or 0.0)
                        amt_v = dep_v if dep_v != 0 else wth_v
                        if s_tbl == "individual_savings":
                            c_info = s.get("clients") or {} if isinstance(s.get("clients"), dict) else {}
                            c_n = c_info.get("name") or lbl_default
                            c_c = c_info.get("client_code") or ""
                        elif s_tbl == "group_savings":
                            g_info = s.get("groups") or {} if isinstance(s.get("groups"), dict) else {}
                            c_n = g_info.get("name") or lbl_default
                            c_c = "GROUP"
                        elif s_tbl == "internal_savings":
                            c_n = lbl_default
                            c_c = "MISC"
                        else:
                            c_n = lbl_default
                            c_c = str(s.get("client_id") or "")[:8] or "LAPS"
                        sav_meta[str(s["id"])] = {
                            "amount": amt_v,
                            "client_name": c_n,
                            "client_code": c_c,
                        }
                except Exception:
                    pass

        try_meta = {}
        if try_ids:
            try:
                t_res = uow.client.table("treasury_transactions").select("id, amount, remarks, transaction_type").in_("id", try_ids).execute()
                for t in (t_res.data or []):
                    try_meta[str(t["id"])] = {
                        "amount": float(t.get("amount") or 0.0),
                        "client_name": str(t.get("remarks") or t.get("transaction_type") or "Branch Treasury"),
                        "client_code": str(t.get("transaction_type") or "TREASURY")
                    }
            except Exception:
                pass

        pending_corr_items: List[PendingCorrectionApprovalItem] = []
        for corr in (res_corr.data or []):
            u_data = corr.get("app_users")
            req_u = (u_data.get("full_name") or u_data.get("username")) if isinstance(u_data, dict) else "Officer"
            rec_id_str = str(corr.get("record_id") or "")
            meta = rep_meta.get(rec_id_str) or sav_meta.get(rec_id_str) or try_meta.get(rec_id_str) or {}

            pending_corr_items.append(PendingCorrectionApprovalItem(
                id=str(corr["id"]),
                record_id=rec_id_str,
                record_type=str(corr.get("record_type") or "Transaction"),
                reason=str(corr.get("reason") or ""),
                requested_by=str(req_u),
                amount=meta.get("amount", 0.0),
                client_name=meta.get("client_name"),
                client_code=meta.get("client_code"),
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
    res_l = uow.client.table("loans").select("branch_id, loan_amount, status").eq("loan_id", payload.loan_id).execute()
    if not res_l.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan not found.")
    loan_row = res_l.data[0]
    if str(loan_row.get("status", "")).lower() == "active":
        return ActionResponse(
            success=True,
            message=f"Loan #{payload.loan_id[:8]} has already been approved and disbursed."
        )
    _check_branch_access(current_user, loan_row.get("branch_id"), "approve loans")

    # Enforce BM loan approval threshold ceiling of ₦300,000
    norm_role = RBACScopeService.normalize_role(current_user.role)
    loan_amt = float(loan_row.get("loan_amount") or 0.0)
    if norm_role == "Branch Manager" and loan_amt > 300000:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Loan #{payload.loan_id[:8]} amount (₦{loan_amt:,.2f}) exceeds Branch Manager limit of ₦300,000. Escalated to Area Manager."
        )

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
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-loan", response_model=ActionResponse)
def reject_loan(
    payload: RejectLoanRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    res_l = uow.client.table("loans").select("branch_id").eq("loan_id", payload.loan_id).execute()
    if not res_l.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan not found.")
    _check_branch_access(current_user, res_l.data[0].get("branch_id"), "reject loans")

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
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/batch-approve-loans", response_model=ActionResponse)
def batch_approve_loans(
    payload: BatchApproveLoansRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    if not payload.loan_ids:
        return ActionResponse(success=True, message="No loans provided.")

    res_l = uow.client.table("loans").select("loan_id, branch_id, loan_amount").in_("loan_id", payload.loan_ids).execute()
    loans_map = {row["loan_id"]: row for row in (res_l.data or [])}

    s_cnt = 0
    f_cnt = 0
    errors = []
    default_d = date.fromisoformat(payload.default_disbursement_date)
    dates_map = payload.loan_dates_map or {}
    norm_role = RBACScopeService.normalize_role(current_user.role)

    for lid in payload.loan_ids:
        if lid not in loans_map:
            f_cnt += 1
            errors.append(f"Loan #{lid[:8]}: Loan not found.")
            continue

        l_info = loans_map[lid]
        target_bid = l_info.get("branch_id")
        l_amt = float(l_info.get("loan_amount") or 0.0)

        # Enforce BM ceiling
        if norm_role == "Branch Manager" and l_amt > 300000:
            f_cnt += 1
            errors.append(f"Loan #{lid[:8]}: Amount ₦{l_amt:,.2f} exceeds BM limit of ₦300,000; escalated to AM.")
            continue
        target_branch_id = target_bid
        try:
            _check_branch_access(current_user, target_branch_id, "approve loans")
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
    res = uow.client.table("withdrawal_requests").select("*").eq("id", payload.withdrawal_id).execute()
    if not res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Withdrawal request not found.")
    wr = res.data[0]
    wr_branch_id = wr.get("branch_id")
    _check_branch_access(current_user, wr_branch_id, "approve withdrawals")

    curr_st = str(wr.get("status") or "").upper()
    if curr_st == "REJECTED":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cannot approve a rejected withdrawal request.")

    try:
        op_d = date.fromisoformat(payload.operational_date)
        is_open, open_reason = BusinessDateService.is_operational_open(uow, wr_branch_id or current_user.branch_id, op_d)
        if not is_open:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Operational Activity Suspended ({open_reason}): Approvals blocked for closed branch date."
            )
        _execute_withdrawal_approval(uow, wr, op_d, current_user.branch, current_user.username)
        return ActionResponse(
            success=True,
            message=f"Withdrawal of ₦{float(wr.get('amount', 0)):,.2f} for {wr.get('client_name')} approved and posted to ledger."
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-withdrawal", response_model=ActionResponse)
def reject_withdrawal(
    payload: RejectWithdrawalRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    res = uow.client.table("withdrawal_requests").select("id, branch_id, status, client_name").eq("id", payload.withdrawal_id).execute()
    if not res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Withdrawal request not found.")
    wr = res.data[0]
    wr_branch_id = wr.get("branch_id")
    _check_branch_access(current_user, wr_branch_id, "reject withdrawals")

    curr_st = str(wr.get("status") or "").upper()
    if curr_st in ("APPROVED", "PROCESSING"):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Cannot reject request in status '{curr_st}'.")
    if curr_st == "REJECTED":
        return ActionResponse(success=True, message=f"Withdrawal request #{payload.withdrawal_id[:8]} is already rejected.")

    reason_text = payload.reason or "Rejected by BM"
    try:
        upd_res = uow.client.table("withdrawal_requests").update({
            "status": "REJECTED",
            "approved_by": current_user.username,
            "approved_at": datetime.now().isoformat(),
            "rejection_reason": reason_text
        }).eq("id", payload.withdrawal_id).eq("status", "PENDING").execute()
        if not upd_res.data:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Withdrawal request is no longer PENDING.")
        try:
            actor_uuid, actor_uname, actor_role, _ = SavingsService._resolve_actor_audit_info(uow, current_user.username, current_user.role)
            uow.client.table("user_audit_logs").insert(
                SavingsService._build_user_audit_op(
                    user_id=actor_uuid,
                    username=actor_uname,
                    role=actor_role,
                    branch=_resolve_branch_name(uow, wr_branch_id) or current_user.branch or "",
                    action="REJECT",
                    module="Withdrawals",
                    entity_type="withdrawal_requests",
                    entity_id=payload.withdrawal_id,
                    display_name=str(wr.get("client_name") or "Client"),
                    previous_value={"status": "PENDING"},
                    new_value={"status": "REJECTED", "reason": reason_text},
                    audit_status="REJECTED",
                )["record"]
            ).execute()
        except Exception:
            pass
        return ActionResponse(
            success=True,
            message=f"Withdrawal request #{payload.withdrawal_id[:8]} rejected."
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/batch-approve-withdrawals", response_model=ActionResponse)
def batch_approve_withdrawals(
    payload: BatchApproveWithdrawalsRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    if not payload.withdrawal_ids:
        return ActionResponse(success=True, message="No withdrawals provided.")

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
            f_cnt += 1
            errors.append(f"Withdrawal #{wid[:8]}: Request not found.")
            continue
        try:
            wr_branch_id = wr_item.get("branch_id")
            _check_branch_access(current_user, wr_branch_id, "approve withdrawals")
            cur_d = date.fromisoformat(dates_map[wid]) if wid in dates_map else default_d
            is_open, open_reason = BusinessDateService.is_operational_open(uow, wr_branch_id or current_user.branch_id, cur_d)
            if not is_open:
                raise ValueError(f"Operational Activity Suspended ({open_reason}) on {cur_d.isoformat()}")
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
    res_c = uow.client.table("correction_requests").select("branch_id").eq("id", payload.correction_id).execute()
    if not res_c.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Correction request not found.")
    _check_branch_access(current_user, res_c.data[0].get("branch_id"), "approve correction requests")

    try:
        user_identifier = current_user.id or current_user.username
        CorrectionService.approve_correction(uow, payload.correction_id, approved_by=user_identifier)
        return ActionResponse(
            success=True,
            message="Reversal approved and executed atomically."
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/reject-correction", response_model=ActionResponse)
def reject_correction(
    payload: RejectCorrectionRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    res_c = uow.client.table("correction_requests").select("branch_id").eq("id", payload.correction_id).execute()
    if not res_c.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Correction request not found.")
    _check_branch_access(current_user, res_c.data[0].get("branch_id"), "reject correction requests")

    try:
        user_identifier = current_user.id or current_user.username
        CorrectionService.reject_correction(uow, payload.correction_id, approved_by=user_identifier)
        return ActionResponse(
            success=True,
            message="Reversal rejected."
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/batch-approve-corrections", response_model=ActionResponse)
def batch_approve_corrections(
    payload: BatchApproveCorrectionsRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    if not payload.correction_ids:
        return ActionResponse(success=True, message="No corrections provided.")

    res_c = uow.client.table("correction_requests").select("id, branch_id").in_("id", payload.correction_ids).execute()
    corr_map = {row["id"]: row.get("branch_id") for row in (res_c.data or [])}

    s_cnt = 0
    f_cnt = 0
    errors = []
    user_identifier = current_user.id or current_user.username

    for cid in payload.correction_ids:
        if cid not in corr_map:
            f_cnt += 1
            errors.append(f"Correction #{cid[:8]}: Request not found.")
            continue
        try:
            _check_branch_access(current_user, corr_map[cid], "approve correction requests")
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
