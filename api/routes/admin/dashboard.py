"""
api/routes/admin/dashboard.py
Global Administrator Dashboard, Approvals Clearinghouse & Performance Engine.
Strict Zero-Emoji Governance & Corporate Banking Abstraction.
"""
from datetime import date, timedelta
import time
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, Query, HTTPException, status
from pydantic import BaseModel, Field

from api.dependencies import get_uow, require_role
from models.user import CurrentUser
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.institution_performance_service import InstitutionPerformanceService
from services.correction_service import CorrectionService
from services.loan_service import LoanService
from services.dashboard_service import DashboardService
from services.business_date_service import BusinessDateService
from services.circuit_breaker import get_circuit_breaker
from services.metrics_service import get_metrics_service


router = APIRouter(prefix="/api/v1/admin/dashboard", tags=["Global Administrator Dashboard"])


class AdminReversalApprovalRequest(BaseModel):
    request_id: str = Field(..., description="UUID of correction_requests record")
    action: str = Field("APPROVE", description="APPROVE or REJECT")
    notes: Optional[str] = None


class AdminLoanApprovalRequest(BaseModel):
    loan_id: str = Field(..., description="UUID of loan application")
    action: str = Field("APPROVE", description="APPROVE or REJECT")
    disbursement_date: Optional[str] = None
    notes: Optional[str] = None


class AdminActionResponse(BaseModel):
    success: bool
    message: str


@router.get("/operations")
def get_admin_operations(
    business_date: Optional[str] = Query(None, description="ISO format operational date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["Admin", "Super Admin", "ADMIN"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
) -> Dict[str, Any]:
    """
    Returns daily operational pulse for Global Admin:
    - Primary Vault Cash across all branches (Account 1000)
    - Today's Collections & Disbursements
    - Net Savings Movements
    - Multi-Branch Operational Status Matrix (Open, EOD Pending, Closed)
    - Pending Exception Queues
    """
    target_date = date.today()
    if business_date and business_date.strip() and business_date.strip().lower() not in ["null", "undefined", "none"]:
        try:
            target_date = date.fromisoformat(business_date.strip())
        except (ValueError, TypeError):
            target_date = date.today()
    p_date_str = target_date.isoformat()

    # 1. Consolidated Vault Cash (Account 1000) across all branches
    vault_cash_total = 0.0
    try:
        res_leg = uow.client.table("financial_ledger_entries") \
            .select("amount, side") \
            .eq("account_code", "1000") \
            .lte("created_at", f"{p_date_str}T23:59:59") \
            .execute()
        for r in (res_leg.data or []):
            amt = float(r.get("amount") or 0.0)
            if r.get("side") == "Debit":
                vault_cash_total += amt
            elif r.get("side") == "Credit":
                vault_cash_total -= amt
        vault_cash_total = max(0.0, vault_cash_total)
    except Exception:
        pass

    # 2. Today's Collections (excluding legacy onboarding)
    today_collections = 0.0
    try:
        res_rep = uow.client.table("repayments") \
            .select("amount_paid, transaction_type, note") \
            .eq("date", p_date_str) \
            .execute()
        for r in (res_rep.data or []):
            if str(r.get("transaction_type", "")).upper() == "ONBOARDING_LEGACY" or str(r.get("note", "")).strip() == "Legacy Repayments Onboarded":
                continue
            today_collections += float(r.get("amount_paid") or 0.0)
    except Exception:
        pass

    # 3. Today's Disbursements
    today_disbursements = 0.0
    disb_count = 0
    try:
        res_disb = uow.client.table("loans") \
            .select("loan_amount, status") \
            .or_(f"disbursement_date.eq.{p_date_str},start_date.eq.{p_date_str}") \
            .execute()
        for l in (res_disb.data or []):
            st = str(l.get("status") or "").upper()
            if st in ["ACTIVE", "APPROVED", "COMPLETED"]:
                disb_count += 1
                today_disbursements += float(l.get("loan_amount") or 0.0)
    except Exception:
        pass

    # 4. Today's Savings Movements
    today_savings_deposit = 0.0
    today_savings_withdrawal = 0.0
    try:
        for tbl in ["individual_savings", "group_savings", "internal_savings"]:
            res_s = uow.client.table(tbl).select("deposit_amount, withdrawal_amount").eq("posting_date", p_date_str).execute()
            for row in (res_s.data or []):
                today_savings_deposit += float(row.get("deposit_amount") or 0.0)
                today_savings_withdrawal += float(row.get("withdrawal_amount") or 0.0)
    except Exception:
        pass

    today_net_savings = today_savings_deposit - today_savings_withdrawal

    # 5. Multi-Branch Operational Status Matrix
    branch_rows = []
    try:
        res_b = uow.client.table("branches").select("branch_id, name, code").execute()
        branch_rows = res_b.data or []
    except Exception:
        branch_rows = []

    # Head Office is a registered branch in the database (Central Treasury & Administration)
    # We flag it explicitly so the UI presents it as the Treasury Hub rather than an empty retail branch
    for b in branch_rows:
        b_name_clean = str(b.get("name", "")).strip().lower()
        b["is_head_office"] = b_name_clean in ["head office", "headquarters", "headoffice"]

    # Map Branch Managers strictly by role (never substitute arbitrary staff or Credit Officers)
    mgr_map = {}
    try:
        q_bm = uow.client.table("user_roles") \
            .select("user_id, roles!inner(name), app_users!inner(id, username, full_name, branch_id)") \
            .in_("roles.name", ["BM", "Branch Manager", "Manager"])
        res_bm = q_bm.execute()
        for r in (res_bm.data or []):
            u = r.get("app_users") or {}
            bid = str(u.get("branch_id") or "")
            if bid and bid not in mgr_map:
                mgr_map[bid] = u.get("full_name") or u.get("username") or "Unassigned"
    except Exception:
        pass

    branch_statuses = []
    for b in branch_rows:
        bid = str(b.get("branch_id") or b.get("id") or "")
        bname = b.get("name") or "Unnamed Branch"
        bcode = b.get("code") or bname[:3].upper()
        bm = mgr_map.get(bid, "Unassigned")

        # Check EOD / Closure state
        op_state = "OPEN"
        try:
            eod_q = uow.client.table("area_eod_confirmations").select("status").eq("branch_id", bid).eq("closure_date", p_date_str).execute()
            if eod_q.data:
                eod_st = str(eod_q.data[0].get("status") or "").upper()
                if eod_st in ["CONFIRMED", "CLOSED"]:
                    op_state = "CLOSED"
                elif eod_st in ["PENDING", "READY_FOR_REVIEW"]:
                    op_state = "EOD_PENDING"
            else:
                mc_q = uow.client.table("master_cashbook").select("status").eq("branch_id", bid).eq("date", p_date_str).execute()
                if mc_q.data:
                    mc_st = str(mc_q.data[0].get("status") or "")
                    if mc_st in ["Closed", "Verified"]:
                        op_state = "EOD_PENDING"
        except Exception:
            pass

        # Branch vault cash today
        b_vault = 0.0
        try:
            res_bv = uow.client.table("financial_ledger_entries") \
                .select("amount, side") \
                .eq("branch_id", bid) \
                .eq("account_code", "1000") \
                .lte("created_at", f"{p_date_str}T23:59:59") \
                .execute()
            for r in (res_bv.data or []):
                amt = float(r.get("amount") or 0.0)
                b_vault += amt if r.get("side") == "Debit" else -amt
            b_vault = max(0.0, b_vault)
        except Exception:
            pass

        # Branch collections today
        b_coll = 0.0
        try:
            b_rep = uow.client.table("repayments").select("amount_paid, transaction_type, note").eq("branch_id", bid).eq("date", p_date_str).execute()
            for r in (b_rep.data or []):
                if str(r.get("transaction_type", "")).upper() == "ONBOARDING_LEGACY" or str(r.get("note", "")).strip() == "Legacy Repayments Onboarded":
                    continue
                b_coll += float(r.get("amount_paid") or 0.0)
        except Exception:
            pass

        is_ho = str(bname).strip().lower() in ["head office", "headquarters", "headoffice"]
        branch_statuses.append({
            "branch_id": bid,
            "branch_name": bname,
            "branch_code": bcode,
            "manager_name": bm,
            "operational_status": op_state,
            "vault_cash": b_vault,
            "today_collected": b_coll,
            "is_head_office": is_ho
        })

    # 6. Action Center Queues (Pending Reversals & High-Value Loans)
    pending_reversals = []
    try:
        q_rev = uow.client.table("correction_requests") \
            .select("id, branch_id, record_type, record_id, reason, requested_by, created_at, status") \
            .eq("status", "Pending") \
            .order("created_at", desc=False) \
            .limit(15) \
            .execute()
        b_map_name = {str(b.get("branch_id") or b.get("id")): (b.get("name") or "Branch") for b in branch_rows}
        for rv in (q_rev.data or []):
            pending_reversals.append({
                "request_id": str(rv.get("id")),
                "branch_name": b_map_name.get(str(rv.get("branch_id")), "Branch"),
                "record_type": rv.get("record_type"),
                "record_id": str(rv.get("record_id")),
                "reason": rv.get("reason"),
                "requested_by": rv.get("requested_by"),
                "created_at": str(rv.get("created_at") or "")[:19]
            })
    except Exception:
        pass

    pending_high_loans = []
    try:
        q_hl = uow.client.table("loans") \
            .select("loan_id, client_id, branch_id, loan_amount, active_credit, created_at, status") \
            .in_("status", ["PENDING", "Pending", "AWAITING_APPROVAL"]) \
            .gt("loan_amount", 300000) \
            .order("created_at", desc=False) \
            .limit(15) \
            .execute()
        b_map_name = {str(b.get("branch_id") or b.get("id")): (b.get("name") or "Branch") for b in branch_rows}
        for hl in (q_hl.data or []):
            pending_high_loans.append({
                "loan_id": str(hl.get("loan_id")),
                "branch_name": b_map_name.get(str(hl.get("branch_id")), "Branch"),
                "loan_amount": float(hl.get("loan_amount") or 0.0),
                "active_credit": float(hl.get("active_credit") or 0.0),
                "created_at": str(hl.get("created_at") or "")[:19]
            })
    except Exception:
        pass

    # Working Day Verification (BR-DATE-001, BR-DATE-004)
    try:
        is_working_day, status_reason = BusinessDateService.is_working_day(target_date)
    except Exception:
        is_working_day, status_reason = True, "Standard operational day"

    try:
        next_working_day = BusinessDateService.get_next_working_day(
            target_date if is_working_day else target_date + timedelta(days=1)
        ).isoformat()
    except Exception:
        next_working_day = (target_date + timedelta(days=1)).isoformat()

    # Overview Totals (BR-DASH-001, BR-CLI-001)
    total_clients_count = 0
    try:
        c_res = uow.client.table("clients").select("id", count="exact").execute()
        cnt = getattr(c_res, "count", None)
        if isinstance(cnt, int):
            total_clients_count = cnt
        elif isinstance(getattr(c_res, "data", None), list):
            total_clients_count = len([r for r in c_res.data if isinstance(r, dict) and r.get("id")])
    except Exception:
        pass
    total_clients_display = f"{total_clients_count:,}"

    total_active_portfolio = 0.0
    valid_loan_ids: List[str] = []
    try:
        res_ac = (
            uow.client.table("loans")
            .select("loan_id, active_credit, status, extra_fields")
            .in_("status", ["ACTIVE", "Active", "APPROVED", "COMPLETED", "DEFAULTER"])
            .execute()
        )
        for r in (res_ac.data or []):
            if not isinstance(r, dict):
                continue
            st_u = str(r.get("status") or "").upper()
            if st_u == "ACTIVE":
                total_active_portfolio += float(r.get("active_credit") or 0.0)
            ef = r.get("extra_fields")
            if isinstance(ef, dict) and ef.get("is_legacy") is True:
                continue
            lid = str(r.get("loan_id") or "").strip()
            if lid:
                valid_loan_ids.append(lid)
    except Exception:
        pass

    # Live Institutional Repayment Schedule Compliance (BR-DASH-003, FP-006)
    collection_compliance_pct = 0.0
    if valid_loan_ids:
        sched_totals = InstitutionPerformanceService.compute_schedule_compliance_by_loan(
            uow,
            valid_loan_ids,
            end_date=p_date_str,
        )
        total_due_sum = sum(v[0] for v in sched_totals.values())
        total_paid_sum = sum(v[1] for v in sched_totals.values())
        if total_due_sum > 0:
            collection_compliance_pct = round((total_paid_sum / total_due_sum) * 100.0, 1)

    # Working Week Financial Activity (Mon-Fri active, Sat-Sun frozen per BR-DATE-004)
    try:
        financial_activity_week = InstitutionPerformanceService.get_working_days_financial_activity(uow, target_date)
    except Exception:
        financial_activity_week = []

    # Branch Performance Progress Summary
    branch_performance_summary = []
    try:
        max_b_vol = max([float(b.get("today_collected") or 0.0) for b in branch_statuses] or [1.0])
        for b in branch_statuses:
            vol = float(b.get("today_collected") or 0.0)
            rel_pct = round((vol / max_b_vol), 2) if max_b_vol > 0 else 0.0
            branch_performance_summary.append({
                "branch_id": str(b.get("branch_id") or ""),
                "branch_name": str(b.get("branch_name") or "Unnamed Branch"),
                "volume": vol,
                "relative_pct": rel_pct,
                "vault_cash": float(b.get("vault_cash") or 0.0),
                "manager_name": str(b.get("manager_name") or "Unassigned"),
                "status": str(b.get("operational_status") or "OPEN"),
                "is_head_office": bool(b.get("is_head_office"))
            })
    except Exception:
        pass

    return {
        "business_date": p_date_str,
        "business_date_status": {
            "is_working_day": is_working_day,
            "status_reason": status_reason,
            "next_working_day": next_working_day
        },
        "overview": {
            "total_clients_count": total_clients_count,
            "total_clients_display": total_clients_display,
            "active_branches_count": len(branch_rows),
            "total_portfolio": total_active_portfolio,
            "today_collections": today_collections
        },
        "liquidity": {
            "vault_cash_in_custody": vault_cash_total,
            "today_collections": today_collections,
            "today_disbursements": today_disbursements,
            "today_disbursed_count": disb_count,
            "today_savings_deposit": today_savings_deposit,
            "today_savings_withdrawal": today_savings_withdrawal,
            "today_net_savings": today_net_savings,
            "collection_compliance_pct": collection_compliance_pct
        },
        "financial_activity_week": financial_activity_week,
        "branch_performance_summary": branch_performance_summary,
        "branch_matrix": branch_statuses,
        "action_center": {
            "pending_reversals_count": len(pending_reversals),
            "pending_reversals": pending_reversals,
            "pending_high_loans_count": len(pending_high_loans),
            "pending_high_loans": pending_high_loans
        }
    }


@router.get("/branch/{branch_id}")
def get_admin_branch_detail(
    branch_id: str,
    business_date: Optional[str] = Query(None, description="ISO format operational date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["Admin", "Super Admin", "ADMIN"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
) -> Dict[str, Any]:
    """
    Detailed operational and portfolio drilldown for a single branch.
    Derived strictly from Account 1000 for vault cash and dedicated payoff/recovery records.
    """
    return InstitutionPerformanceService.get_branch_detail_metrics(uow, branch_id, business_date)


@router.get("/performance")
def get_institution_performance(
    year: int = Query(2026, description="Evaluation cycle year"),
    branch_id: Optional[str] = Query(None, description="Optional branch ID to filter officer rankings"),
    current_user: CurrentUser = Depends(require_role(["Admin", "Super Admin", "ADMIN"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
) -> Dict[str, Any]:
    """
    Returns Branch Performance rankings and Officer Performance rankings.
    Uses the 6-Pillar Scorecard incorporating the Overdue Recovery System.
    """
    branch_rankings = InstitutionPerformanceService.get_branch_performance_rankings(uow, year)
    officer_rankings = InstitutionPerformanceService.get_officer_performance_rankings(uow, year, branch_id)

    return {
        "year": year,
        "branch_performance": branch_rankings,
        "officer_performance": officer_rankings
    }


@router.get("/risk-health")
def get_risk_and_platform_health(
    current_user: CurrentUser = Depends(require_role(["Admin", "Super Admin", "ADMIN"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
) -> Dict[str, Any]:
    """
    Returns institutional risk and platform engine health indicators:
    - PAR delinquency exposure
    - Overdue Recovery overview (loan_overdue_recovery_records)
    - Early Payoff & Excess Collections overview (loan_payoff_excess_records)
    - Platform engine projection status
    """
    # 1. PAR & Overdue
    par_str = DashboardService.calculate_par_pct(uow)
    par_val = float(par_str.replace("%", "").strip() or 0.0)

    total_active_credit = 0.0
    try:
        res_ac = uow.client.table("loans").select("active_credit").in_("status", ["ACTIVE", "Active"]).execute()
        total_active_credit = sum(float(r.get("active_credit") or 0.0) for r in (res_ac.data or []))
    except Exception:
        pass

    # 2. Overdue Recovery System stats
    total_recovered = 0.0
    recoveries_count = 0
    full_recoveries_count = 0
    try:
        q_rec = uow.client.table("loan_overdue_recovery_records").select("recovered_amount, recovery_type").execute()
        r_data = q_rec.data or []
        recoveries_count = len(r_data)
        for r in r_data:
            total_recovered += float(r.get("recovered_amount") or 0.0)
            if str(r.get("recovery_type") or "").upper() == "FULL_RECOVERY":
                full_recoveries_count += 1
    except Exception:
        pass

    # 3. Full Payoff & Excess stats (BR-DASH-005)
    full_payoffs_settled = 0.0
    full_payoff_count = 0
    excess_cash_collected = 0.0
    try:
        q_pay = uow.client.table("loan_payoff_excess_records").select("active_credit_settled, excess_amount, record_type").execute()
        for p in (q_pay.data or []):
            rtype = str(p.get("record_type") or "").upper()
            if "FULL_PAYOFF" in rtype:
                full_payoff_count += 1
                full_payoffs_settled += float(p.get("active_credit_settled") or 0.0)
            excess_cash_collected += float(p.get("excess_amount") or 0.0)
    except Exception:
        pass

    # 4. Live Engine, Queue, EOD & DB Health Telemetry (BR-DASH-003, FP-006)
    today_iso = date.today().isoformat()
    db_t0 = time.monotonic()
    db_connected = False
    db_latency_ms = 0.0
    db_error_name = ""
    field_branch_ids: List[str] = []
    try:
        res_branches = uow.client.table("branches").select("branch_id, name").execute()
        db_connected = True
        db_latency_ms = round((time.monotonic() - db_t0) * 1000.0, 1)
        for br in (res_branches.data or []):
            if not isinstance(br, dict):
                continue
            b_name = str(br.get("name") or "").strip().lower()
            if b_name not in ["head office", "headquarters", "headoffice"]:
                bid = str(br.get("branch_id") or "").strip()
                if bid:
                    field_branch_ids.append(bid)
    except Exception as db_exc:
        db_connected = False
        db_error_name = type(db_exc).__name__

    pending_reversals_cnt = 0
    try:
        res_rev_p = uow.client.table("correction_requests").select("id").eq("status", "Pending").execute()
        pending_reversals_cnt = len([r for r in (res_rev_p.data or []) if isinstance(r, dict) and r.get("id")])
    except Exception:
        pass

    pending_loans_cnt = 0
    try:
        res_loan_p = uow.client.table("loans").select("loan_id").in_("status", ["PENDING", "Pending", "AWAITING_APPROVAL"]).execute()
        pending_loans_cnt = len([r for r in (res_loan_p.data or []) if isinstance(r, dict) and r.get("loan_id")])
    except Exception:
        pass

    pending_eod_cnt = 0
    confirmed_eod_branch_ids = set()
    try:
        res_eod = uow.client.table("area_eod_confirmations").select("branch_id, status").eq("closure_date", today_iso).execute()
        for row in (res_eod.data or []):
            if not isinstance(row, dict):
                continue
            bid = str(row.get("branch_id") or "").strip()
            e_st = str(row.get("status") or "").upper()
            if e_st in ["CONFIRMED", "CLOSED"] and bid:
                confirmed_eod_branch_ids.add(bid)
            elif e_st in ["PENDING", "READY_FOR_REVIEW"] and bid:
                pending_eod_cnt += 1
    except Exception:
        pass

    ledger_entries_cnt = 0
    ledger_verified = False
    try:
        res_led = uow.client.table("financial_ledger_entries").select("id", count="exact").limit(1).execute()
        ledger_verified = True
        cnt_val = getattr(res_led, "count", None)
        if isinstance(cnt_val, int):
            ledger_entries_cnt = cnt_val
        elif isinstance(getattr(res_led, "data", None), list):
            ledger_entries_cnt = len([r for r in res_led.data if isinstance(r, dict) and r.get("id")])
    except Exception:
        ledger_verified = False

    pending_backlog = pending_reversals_cnt + pending_loans_cnt + pending_eod_cnt
    cb_status = get_circuit_breaker("database").get_status()
    cb_state = str(cb_status.get("state") or "UNKNOWN")
    active_alerts = get_metrics_service().get_active_alerts()

    if not db_connected or cb_state != "CLOSED":
        projection_status = f"Degraded ({db_error_name or cb_state})"
    elif active_alerts:
        projection_status = f"Attention ({len(active_alerts)} active alerts)"
    elif pending_backlog > 0:
        projection_status = f"Live ({pending_backlog} queued approvals)"
    else:
        projection_status = f"Live ({db_latency_ms:.0f} ms)"

    if field_branch_ids:
        closed_cnt = len([b for b in field_branch_ids if b in confirmed_eod_branch_ids])
        eod_sync_status = f"{closed_cnt}/{len(field_branch_ids)} Field Branches EOD Closed"
    else:
        eod_sync_status = "0 Field Branches Found"

    return {
        "risk_indicators": {
            "par_pct": par_val,
            "total_active_credit": total_active_credit,
            "recovery_overview": {
                "total_overdue_recovered": total_recovered,
                "recovery_events_count": recoveries_count,
                "full_client_restorations": full_recoveries_count
            },
            "settlement_overview": {
                "full_payoffs_settled_amount": full_payoffs_settled,
                "full_payoff_count": full_payoff_count,
                "excess_cash_collected": excess_cash_collected
            }
        },
        "engine_health": {
            "projection_engine_status": projection_status,
            "pending_event_backlog": pending_backlog,
            "offline_device_sync_status": eod_sync_status,
            "database_cluster": f"Connected ({db_latency_ms:.0f} ms)" if db_connected else f"Unavailable ({db_error_name or cb_state})",
            "immutable_audit_state": f"Verified ({ledger_entries_cnt:,} ledger rows)" if ledger_verified else "Ledger Check Unavailable"
        }
    }


@router.post("/approvals/reversal", response_model=AdminActionResponse)
def handle_reversal_approval(
    payload: AdminReversalApprovalRequest,
    current_user: CurrentUser = Depends(require_role(["Admin", "Super Admin", "ADMIN"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Approves or rejects an escalated error correction / reversal ticket.
    Posts an atomic reversing transaction to the ledger upon approval.
    """
    try:
        action = payload.action.strip().upper()
        if action == "APPROVE":
            CorrectionService.approve_correction(uow, payload.request_id, approved_by=current_user.username)
            return AdminActionResponse(success=True, message="Correction approved. Reversing ledger transaction executed.")
        else:
            CorrectionService.reject_correction(uow, payload.request_id, approved_by=current_user.username)
            return AdminActionResponse(success=True, message="Correction rejected.")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/approvals/loan", response_model=AdminActionResponse)
def handle_loan_approval(
    payload: AdminLoanApprovalRequest,
    current_user: CurrentUser = Depends(require_role(["Admin", "Super Admin", "ADMIN"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Approves or rejects an escalated high-value loan application.
    """
    try:
        action = payload.action.strip().upper()
        if action == "APPROVE":
            d_date = date.fromisoformat(payload.disbursement_date) if payload.disbursement_date else date.today()
            LoanService.approve_and_disburse_loan(
                uow=uow,
                loan_id=payload.loan_id,
                approved_by=current_user.username,
                disbursement_date=d_date
            )
            return AdminActionResponse(success=True, message=f"Loan #{payload.loan_id[:8]} approved and disbursed.")
        else:
            LoanService.reject_loan(uow=uow, loan_id=payload.loan_id, rejected_by=current_user.username)
            return AdminActionResponse(success=True, message=f"Loan #{payload.loan_id[:8]} rejected.")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
