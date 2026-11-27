"""
CO Cashbook route adapter.
Queries co_cashbooks and Account 1000 journal projection directly.
Fully parity-matched with Streamlit app.py L10748-11186.
"""
from typing import Optional, List
from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role, check_branch_access
from api.schemas.cashbook import (
    CoCashbookResponse,
    CashbookInflows,
    CashbookOutflows,
    CollectionArrearsTally,
    TallyNotPaidClient,
    OfficerOption,
    ReversalOption,
    SubmittedReversalRequest,
)
from api.schemas.corrections import ReversalRequestInput, ReversalRequestResponse
from api.schemas.financial_writes import EodAdjustmentsInput, EodAdjustmentsResponse
from models.user import CurrentUser
from services.business_date_service import BusinessDateService
from services.rbac_scope_service import RBACScopeService

router = APIRouter(prefix="/api/v1/co/cashbook", tags=["CO Cashbook"])


def _get_eod_misc_fee_tracked(
    uow: SupabaseUnitOfWork,
    branch_name: str,
    iso_date: str,
    target_co: str,
    branch_id: Optional[str] = None,
) -> float:
    """Computes net EOD Misc Fee routed via internal_savings for (branch, date, target_co)."""
    if not target_co or (not branch_name and not branch_id):
        return 0.0
    try:
        marker = f"[EOD_MISC_FEE:{target_co}]"
        resolved_bid = branch_id or (
            uow.cashbook._resolve_branch_id(branch_name) if branch_name else None
        )
        q = uow.client.table("internal_savings") \
            .select("deposit_amount, withdrawal_amount, remarks, posting_date, created_at")
        if resolved_bid:
            q = q.eq("branch_id", resolved_bid)
        else:
            q = q.eq("branch", branch_name)
        res_ms = q.eq("posting_date", iso_date) \
            .ilike("remarks", f"%{marker}%") \
            .execute()
        total = 0.0
        rows = getattr(res_ms, "data", None)
        if not isinstance(rows, list):
            return 0.0
        for r in rows:
            if not isinstance(r, dict):
                continue
            r_dt = str(r.get("posting_date") or r.get("date") or r.get("created_at") or "")[:10]
            if r_dt == iso_date:
                total += float(r.get("deposit_amount") or 0.0) - float(r.get("withdrawal_amount") or 0.0)
        return max(0.0, total)
    except Exception:
        return 0.0


@router.get("", response_model=CoCashbookResponse)
@router.get("/", response_model=CoCashbookResponse, include_in_schema=False)
@router.get("/daily", response_model=CoCashbookResponse, include_in_schema=False)
def get_co_cashbook(
    date_str: Optional[str] = Query(None, alias="date", description="Target ISO date (YYYY-MM-DD)"),
    officer: Optional[str] = Query(None, description="Target Credit Officer username"),
    branch: Optional[str] = Query(None, description="Branch override for supervisory roles"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live 2-sided Balanced T-Account CO Cashbook projection backed by Account 1000,
    including Arrears Tally, EOD reversal options, and officer selection for managers.
    """
    mgr_roles = {"BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"}
    can_manage = current_user.role in mgr_roles

    if branch and not can_manage and branch != current_user.branch and branch != current_user.branch_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Credit Officers cannot view another branch's cashbook."
        )

    target_branch = branch if (branch and can_manage) else current_user.branch
    branch_id = uow.cashbook._resolve_branch_id(target_branch)
    check_branch_access(current_user, branch_id, "view CO cashbook")
    
    # Resolve target business date
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )
    else:
        target_date = BusinessDateService.get_business_date(uow, target_branch)

    iso_date = target_date.isoformat()
    is_open, open_reason = BusinessDateService.is_operational_open(uow, branch_id, target_date)

    # Determine RBAC scope for officer selection (app.py L10770-10785)
    can_select_officer = can_manage

    officer_options: List[OfficerOption] = []
    target_co = current_user.username

    if can_select_officer:
        try:
            res_users = uow.client.table("app_users").select("username, full_name, role").eq("branch_id", branch_id).execute()
            user_rows = getattr(res_users, "data", None)
            for u in (user_rows if isinstance(user_rows, list) else []):
                if not isinstance(u, dict):
                    continue
                u_role = u.get("role")
                if u_role and RBACScopeService.normalize_role_or_none(str(u_role)) != "CO":
                    continue
                u_name = u.get("username", "")
                f_name = u.get("full_name") or u_name
                officer_options.append(OfficerOption(
                    username=u_name,
                    full_name=f_name,
                    display=f"{f_name} ({u_name})"
                ))
            if officer and any(o.username == officer for o in officer_options):
                target_co = officer
            elif officer:
                target_co = officer
        except Exception:
            pass
    else:
        target_co = current_user.username

    # Resolve officer UUID
    officer_id = uow.loans._resolve_officer_id(target_co)
    if not officer_id:
        res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
        if res_u.data:
            officer_id = res_u.data[0]["id"]
        else:
            officer_id = current_user.id

    # 1. Check persisted snapshot first; preserve immutable Closed/Verified cashbooks without rebuilding
    c = {}
    existing_status = ""
    if officer_id and branch_id:
        try:
            res_co = uow.client.table("co_cashbooks").select("*").eq("date", iso_date).eq("branch_id", branch_id).eq("officer_id", officer_id).execute()
            ex_rows = getattr(res_co, "data", None)
            if isinstance(ex_rows, list) and ex_rows and isinstance(ex_rows[0], dict):
                c = ex_rows[0]
                existing_status = str(c.get("status") or "").strip().lower()
        except Exception:
            c = {}

        if existing_status not in {"closed", "verified"}:
            try:
                from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
                from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
                rebuilt = CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, officer_id, target_date) or {}
                if isinstance(rebuilt, dict) and rebuilt:
                    c = rebuilt
                MasterCashbookProjectionBuilder.rebuild_master_projection(uow, branch_id, target_date)
            except Exception:
                pass

    bf_cash = t_sav = t_r12w = t_r24w = t_r60d = t_r120d = t_rmth = t_cont = t_bwd = t_asale = t_app = t_pb = t_bon = t_cfd = 0.0
    t_d11 = t_d20 = t_w11 = t_w20 = t_mm = t_misc = t_pwd = t_exp = t_bdep = t_lres = t_ltrans = t_cc = 0.0
    d_act = d_act_120d = w_act_12 = w_act_24 = m_act = 0.0

    if c:
        bf_cash = float(c.get("opening_balance") or 0)
        t_sav = float(c.get("savings_deposit") or 0)
        t_lres = float(c.get("laps_reserve") or 0)
        t_r60d = float(c.get("rep_daily") or 0)
        t_r120d = float(c.get("rep_120_days") or 0)
        t_r12w = float(c.get("rep_12_weeks") or 0)
        t_r24w = float(c.get("rep_24_weeks") or 0)
        t_rmth = float(c.get("rep_monthly") or 0)
        t_d11 = float(c.get("daily_11_pct") or 0)
        t_d20 = float(c.get("daily_20_pct") or 0)
        t_w11 = float(c.get("weekly_11_pct") or 0)
        t_w20 = float(c.get("weekly_20_pct") or 0)
        t_mm = float(c.get("risk_premium_returns") or 0)
        t_cont = float(c.get("contingency") or 0)
        t_app = float(c.get("app_fee") or 0) + float(c.get("credit_form") or 0)
        t_cfd = float(c.get("credit_form_damage") or 0)
        t_pb = float(c.get("passbook") or 0)
        t_bon = float(c.get("bonus") or 0)
        t_misc = float(c.get("misc_fees") or 0)
        t_cc = float(c.get("cash_and_carry") or 0)
        t_asale = float(c.get("asset_credit_sales") or 0)
        t_bwd = float(c.get("bank_withdrawal") or 0)
        d_act = float(c.get("disb_60d") or 0)
        d_act_120d = float(c.get("disb_120d") or 0)
        w_act_12 = float(c.get("disb_12w") or 0)
        w_act_24 = float(c.get("disb_24w") or 0)
        m_act = float(c.get("disb_mth") or 0)
        t_pwd = float(c.get("product_withdrawal") or 0)
        t_exp = float(c.get("office_expenses") or 0)
        t_bdep = float(c.get("bank_deposit") or 0)
        t_ltrans = float(c.get("laps_returns") or 0)

    eod_misc_tracked = _get_eod_misc_fee_tracked(
        uow, target_branch, iso_date, target_co, branch_id=branch_id
    )

    # Compute double-entry totals (note: eod_misc_tracked flows through Misc Savings savings_deposit, never double-added into left_total)
    left_total = (
        bf_cash + t_lres + t_sav + t_r60d + t_r120d + t_r12w + t_r24w + t_rmth +
        t_d11 + t_d20 + t_w11 + t_w20 + t_mm + t_cont + t_app + t_cfd + t_pb + t_bon + t_misc +
        t_asale + t_cc + t_bwd
    )
    right_total = (
        d_act + d_act_120d + w_act_12 + w_act_24 + m_act +
        t_pwd + t_exp + t_ltrans + t_bdep
    )
    closing_bal = left_total - right_total

    inflows = CashbookInflows(
        opening_balance=bf_cash,
        savings_deposit=t_sav + t_misc,
        laps_reserve=t_lres,
        rep_daily=t_r60d,
        rep_120_days=t_r120d,
        rep_12_weeks=t_r12w,
        rep_24_weeks=t_r24w,
        rep_monthly=t_rmth,
        daily_11_pct=t_d11,
        daily_20_pct=t_d20,
        weekly_11_pct=t_w11,
        weekly_20_pct=t_w20,
        risk_premium_returns=t_mm,
        contingency=t_cont,
        app_fee=t_app,
        credit_form_damage=t_cfd,
        passbook=t_pb,
        bonus=t_bon,
        misc_fees=0.0,
        eod_misc_fee=eod_misc_tracked,
        cash_and_carry=t_cc,
        asset_credit_sales=t_asale,
        bank_withdrawal=t_bwd
    )

    outflows = CashbookOutflows(
        active_loan_daily=d_act,
        active_loan_120d=d_act_120d,
        active_loan_12w=w_act_12,
        active_loan_24w=w_act_24,
        active_loan_monthly=m_act,
        product_withdrawal=t_pwd,
        office_expenses=t_exp,
        bank_deposit=t_bdep,
        laps_returns=t_ltrans
    )

    # 4. Daily Field Collection & Arrears Reconciliation Tally (app.py L11005-11019)
    tally_result: Optional[CollectionArrearsTally] = None
    if branch_id and officer_id:
        try:
            from services.financial_reconciliation_service import FinancialReconciliationService
            t_data = FinancialReconciliationService.get_daily_collection_arrears_tally(
                uow=uow,
                branch_id=branch_id,
                posting_date=target_date,
                officer_id=officer_id
            )
            tally_clients = [
                TallyNotPaidClient(
                    name=c.get("name", "Unknown Client"),
                    code=c.get("code", ""),
                    expected=float(c.get("expected") or 0.0),
                    shortfall=float(c.get("shortfall") or 0.0),
                    is_partial=bool(c.get("is_partial", False))
                )
                for c in (t_data.get("not_paid_clients") or [])
            ]
            tally_result = CollectionArrearsTally(
                scheduled_expected=float(t_data.get("scheduled_expected") or 0.0),
                not_paid_amount=float(t_data.get("not_paid_amount") or 0.0),
                not_paid_count=int(t_data.get("not_paid_count") or 0),
                not_paid_clients=tally_clients,
                excess_amount=float(t_data.get("excess_amount") or 0.0),
                excess_count=int(t_data.get("excess_count") or 0),
                actual_repayments=float(t_data.get("actual_repayments") or 0.0),
                actual_savings=float(t_data.get("actual_savings") or 0.0),
                actual_cash_collected=float(t_data.get("actual_cash_collected") or 0.0),
                bank_deposited=float(t_data.get("bank_deposited") or 0.0),
                closing_cash_balance=float(t_data.get("closing_cash_balance") or 0.0),
                is_cash_balanced=bool(t_data.get("is_cash_balanced", True)),
                arrears_float=float(t_data.get("arrears_float") or 0.0),
                total_reps_count=int(t_data.get("total_reps_count") or 0)
            )
        except Exception as ex:
            print(f"Error computing CO cashbook tally: {ex}")

    # 5. Error Correction Hub: Reversal Options & Submitted Requests (app.py L11084-11183)
    reversal_options: List[ReversalOption] = []
    submitted_reversals: List[SubmittedReversalRequest] = []
    try:
        q_events = uow.client.table("event_store").select("*") \
            .in_("event_type", ["FeeCharged", "ExpenseRecorded", "BankDeposited", "BankWithdrawn"]) \
            .order("created_at", desc=True).limit(200)
        res_events = q_events.execute()
        raw_events = res_events.data or []

        cb_blocked = set()
        try:
            res_c_req = uow.client.table("correction_requests").select("record_id").in_("status", ["Pending", "Approved"]).execute()
            for cr in (res_c_req.data or []):
                if cr.get("record_id"):
                    cb_blocked.add(str(cr["record_id"]))
        except Exception:
            pass

        for ev in raw_events:
            ev_id = str(ev.get("event_id") or "")
            if ev_id in cb_blocked:
                continue

            p = ev.get("payload") or {}
            ev_dt = str(p.get("date") or p.get("posting_date") or "")[:10]
            if ev_dt and ev_dt != iso_date:
                continue
            ev_off = str(p.get("officer") or p.get("officer_id") or "")
            ev_br = str(p.get("branch") or p.get("branch_id") or "")

            if not can_select_officer and ev_off not in [str(current_user.username), str(current_user.id), str(officer_id)]:
                continue
            if branch_id and ev_br not in [str(target_branch), str(branch_id)]:
                continue

            ev_type = ev.get("event_type")
            amt = float(p.get("amount") or 0.0)
            narr = p.get("narration") or p.get("remarks") or ev_type

            amt_str = f"₦{amt:,.2f}" if (amt % 1 != 0) else f"₦{amt:,.0f}"
            typ_badge = "Fee" if ev_type == "FeeCharged" else ("Expense" if ev_type == "ExpenseRecorded" else "Bank")
            rec_type = "Fee" if ev_type == "FeeCharged" else ("Expense" if ev_type == "ExpenseRecorded" else "Treasury")
            label = f"{amt_str} | {typ_badge} | {narr[:16]} (#{ev_id[:6]})"
            reversal_options.append(ReversalOption(label=label, record_type=rec_type, record_id=ev_id))

        req_query = uow.client.table("correction_requests").select("*")
        if current_user.id:
            req_query = req_query.eq("requested_by", current_user.id)
        elif branch_id:
            req_query = req_query.eq("branch_id", branch_id)
        res_my_reqs = req_query.order("created_at", desc=True).limit(15).execute()
        for mr in (res_my_reqs.data or []):
            submitted_reversals.append(SubmittedReversalRequest(
                date=str(mr.get("created_at", ""))[:16].replace("T", " "),
                record_type=str(mr.get("record_type") or "Cashbook"),
                record_id=str(mr.get("record_id") or "")[:8],
                reason=str(mr.get("reason") or ""),
                status=str(mr.get("status") or "Pending"),
                approved_by=mr.get("approved_by")
            ))
    except Exception as ex:
        print(f"Error loading reversal options: {ex}")

    return CoCashbookResponse(
        date=iso_date,
        branch=target_branch,
        officer=target_co,
        is_open=is_open,
        open_reason=open_reason,
        inflows=inflows,
        outflows=outflows,
        total_inflows=round(left_total, 2),
        total_outflows=round(right_total, 2),
        closing_balance=round(closing_bal, 2),
        tally=tally_result,
        officers=officer_options,
        can_select_officer=can_select_officer,
        reversal_options=reversal_options,
        submitted_reversals=submitted_reversals,
        active_loan_breakdown={
            "daily": d_act,
            "120d": d_act_120d,
            "12w": w_act_12,
            "24w": w_act_24,
            "monthly": m_act,
        }
    )


@router.post("/reversal-request", response_model=ReversalRequestResponse)
def request_cashbook_reversal(
    payload: ReversalRequestInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a cashbook fee / expense reversal request for BM approval under Four-Eyes rule BR-ERR-001 (app.py L11135-11150).
    """
    from services.correction_service import CorrectionService

    req_id = CorrectionService.request_correction(
        uow=uow,
        record_id=payload.record_id,
        record_type=payload.record_type or "Cashbook",
        reason=payload.reason,
        requested_by=current_user.id or current_user.username,
        branch_id=current_user.branch_id
    )

    return ReversalRequestResponse(
        success=True,
        request_id=req_id,
        status="Pending",
        message=f"Cashbook transaction reversal request submitted to Branch Manager! (Ref: #{req_id[:8]})"
    )


@router.post("/eod-adjustments", response_model=EodAdjustmentsResponse)
def submit_eod_adjustments(
    payload: EodAdjustmentsInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Posts EOD delta adjustments for fees, expenses, bank deposits, and opening balance (app.py L10900-11000).
    """
    import uuid
    from domain.entities.event_store import DomainEvent
    from services.posting_engine import FinancialPostingEngine

    b_uuid = uow.cashbook._resolve_branch_id(current_user.branch) or current_user.branch_id

    if payload.date:
        try:
            target_date = date.fromisoformat(payload.date)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )
    else:
        biz_dt = BusinessDateService.get_business_date(uow, b_uuid or current_user.branch)
        target_date = biz_dt if isinstance(biz_dt, date) else date.today()

    is_open, open_reason = BusinessDateService.is_operational_open(uow, b_uuid or current_user.branch_id, target_date)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Cannot update End of Day inputs today ({open_reason})."
        )

    date_str = target_date.isoformat()

    # Scoping target officer
    mgr_roles = {"BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"}
    target_co = current_user.username
    if current_user.role in mgr_roles and payload.officer:
        target_co = payload.officer

    officer_uuid = uow.loans._resolve_officer_id(target_co)
    if not officer_uuid:
        res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
        officer_uuid = res_u.data[0]["id"] if res_u.data else current_user.id

    # 1. Check persisted status first; preserve immutable Closed/Verified cashbooks
    from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
    from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
    from services.savings_service import SavingsService

    cur_cb = {}
    if b_uuid and officer_uuid:
        try:
            cb_res = uow.client.table("co_cashbooks").select("*").eq("branch_id", b_uuid).eq("officer_id", officer_uuid).eq("date", date_str).execute()
            cb_rows = getattr(cb_res, "data", None)
            if isinstance(cb_rows, list) and cb_rows and isinstance(cb_rows[0], dict):
                cur_cb = cb_rows[0]
                if str(cur_cb.get("status") or "").strip().lower() in {"closed", "verified"}:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Cannot update End of Day inputs: this officer cashbook is already Closed or Verified."
                    )
        except HTTPException:
            raise
        except Exception:
            cur_cb = {}

    rebuilt_cb = CoCashbookProjectionBuilder.rebuild_co_projection(uow, b_uuid, officer_uuid, target_date) or {}
    if isinstance(rebuilt_cb, dict) and rebuilt_cb:
        cur_cb = rebuilt_cb

    # Strict Single-Page Fee Consolidation: unattributed lump-sum EOD fee inputs are retired.
    retired_fee_inputs = [
        name
        for name, val in (
            ("App Fee", payload.app_fee),
            ("Passbook", payload.passbook),
            ("Misc Fee", payload.misc_fee),
            ("Credit Form Damage", payload.credit_form_damage),
            ("Bonus", payload.bonus),
        )
        if val is not None
    ]
    if retired_fee_inputs:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Client fee recording ({', '.join(retired_fee_inputs)}) has moved exclusively to "
                "Daily Collections -> Single Client Quick Entry so every fee carries client attribution "
                "and a complete audit trail. Only Opening Balance, Office Expenses, and Bank Deposit can "
                "be updated on Daily Cashbook."
            ),
        )

    cur_open = float(cur_cb.get("opening_balance") or 0.0)
    cur_exp = float(cur_cb.get("office_expenses") or 0.0)
    cur_bdep = float(cur_cb.get("bank_deposit") or 0.0)

    # Resolve effective values: preserve untouched fields if None
    global_opening_val = float(payload.opening_balance) if payload.opening_balance is not None else cur_open
    global_expenses_val = float(payload.office_expenses) if payload.office_expenses is not None else cur_exp
    global_bank_dep_val = float(payload.bank_deposit) if payload.bank_deposit is not None else cur_bdep

    opening_changed = payload.opening_balance is not None and abs(global_opening_val - cur_open) > 0.001

    # 2. Update manual opening balance if changed (including clearing down to 0.0 or negative adjustment)
    if opening_changed:
        uow.client.table("co_cashbooks").upsert({
            "date": date_str,
            "branch_id": b_uuid,
            "officer_id": officer_uuid,
            "opening_balance": global_opening_val
        }, on_conflict="date,branch_id,officer_id").execute()

    adjusted_fields: List[str] = []
    if opening_changed:
        adjusted_fields.append(f"opening_balance={global_opening_val:,.2f}")

    # Helper function to post delta with proper reversal handling
    def _post_adjustment(d, ev_pos, ev_neg, agg_type, name, cur_val, new_val):
        if abs(d) <= 0.001:
            return
        if d > 0:
            ev_type = ev_pos
            amt = d
            narr = f"EOD {name} Update (Added ₦{amt:,.2f}, Total: ₦{new_val:,.2f})"
        else:
            ev_type = ev_neg
            amt = abs(d)
            narr = f"EOD {name} Adjustment (Reduced ₦{amt:,.2f}, Adjusted from ₦{cur_val:,.2f} to ₦{new_val:,.2f})"

        ev = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=officer_uuid or str(uuid.uuid4()),
            aggregate_type=agg_type,
            event_type=ev_type,
            payload={
                "branch": current_user.branch,
                "branch_id": b_uuid,
                "officer": target_co,
                "officer_id": officer_uuid,
                "amount": amt,
                "date": date_str,
                "narration": narr
            }
        )
        uow.event_store.append(ev)
        FinancialPostingEngine.post_event(uow, ev)
        adjusted_fields.append(f"{name}={new_val:,.2f}")

    # 3. Post Delta Adjustments for EOD Operational Cash Movements (Expenses & Bank Deposits):
    _post_adjustment(global_expenses_val - cur_exp, "ExpenseRecorded", "ExpenseReversed", "Expense", "Expense", cur_exp, global_expenses_val)
    _post_adjustment(global_bank_dep_val - cur_bdep, "BankDeposited", "BankDepositReversed", "Treasury", "Bank Deposit", cur_bdep, global_bank_dep_val)

    # 4. Rebuild projection & emit audit log
    if officer_uuid and b_uuid:
        if opening_changed:
            CoCashbookProjectionBuilder.rebuild_co_projection(uow, b_uuid, officer_uuid, target_date, manual_opening_balance=global_opening_val)
            cascade_end_dt = BusinessDateService.get_business_date(uow, b_uuid or current_user.branch)
            cascade_end = cascade_end_dt if isinstance(cascade_end_dt, date) else target_date
            uow.cashbook.cascade_co_projection(b_uuid, officer_uuid, target_date, max(target_date, cascade_end))
            MasterCashbookProjectionBuilder.rebuild_master_projection(uow, b_uuid, target_date)
        else:
            uow.cashbook.rebuild_projection(b_uuid, target_date, officer_id=officer_uuid)

    if adjusted_fields:
        try:
            uow.client.table("audit_logs").insert({
                "id": str(uuid.uuid4()),
                "user_id": current_user.id or officer_uuid,
                "action": "EOD_ADJUSTMENTS",
                "description": f"EOD cashbook updates for {target_co} on {date_str}: {', '.join(adjusted_fields)}",
                "table_name": "co_cashbooks",
                "record_id": officer_uuid,
            }).execute()
        except Exception:
            pass

    return EodAdjustmentsResponse(
        success=True,
        date=date_str,
        message="End of Day Opening Balance & Outflows Updated Successfully."
    )





from pydantic import BaseModel, Field

class RecordClientFeeInput(BaseModel):
    client_id: str
    fee_type: str  # e.g., 'Credit Form / App Fee', 'Pass Book', 'Misc Fee', 'Cr Form Dmg', 'Bonus'
    amount: float = Field(..., gt=0)
    date: Optional[str] = None
    officer: Optional[str] = None
    remarks: Optional[str] = None

class RecordClientFeeResponse(BaseModel):
    success: bool
    message: str
    fee_id: str
    date: str
    client_name: str
    fee_type: str
    amount: float

class ClientFeeItem(BaseModel):
    id: str
    date: str
    client_id: Optional[str] = None
    client_code: str
    client_name: str
    fee_type: str
    amount: float
    remarks: Optional[str] = None
    reference: Optional[str] = None
    created_at: Optional[str] = None


@router.post("/client-fee", response_model=RecordClientFeeResponse)
def record_client_fee(
    payload: RecordClientFeeInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Records an individual client fee (Processing, Passbook, Misc Fee, CFD, Bonus)
    with full client attribution, immutable persistence in public.fees, and automatic CO cashbook projection update.
    """
    import uuid
    from domain.entities.event_store import DomainEvent
    from services.posting_engine import FinancialPostingEngine

    b_uuid = uow.cashbook._resolve_branch_id(current_user.branch) or current_user.branch_id
    if payload.date:
        try:
            target_date = date.fromisoformat(payload.date)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )
    else:
        biz_dt = BusinessDateService.get_business_date(uow, b_uuid or current_user.branch)
        target_date = biz_dt if isinstance(biz_dt, date) else date.today()

    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id or b_uuid, target_date)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Cannot record client fee today ({open_reason})."
        )

    date_str = target_date.isoformat()

    # Fetch client to verify existence and get details
    res_c = uow.client.table("clients").select("client_id, client_code, name, branch_id").eq("client_id", payload.client_id).execute()
    if not res_c.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Client not found."
        )
    c_row = res_c.data[0]
    check_branch_access(current_user, c_row.get("branch_id"), "record client fee")
    client_name = c_row.get("name") or "Unknown Client"
    client_code = c_row.get("client_code") or "N/A"
    eff_branch_id = c_row.get("branch_id") or b_uuid
    eff_branch_name = current_user.branch
    if eff_branch_id and str(eff_branch_id) != str(b_uuid):
        is_c_open, c_reason = BusinessDateService.is_operational_open(uow, eff_branch_id, target_date)
        if not is_c_open:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Cannot record client fee for branch today ({c_reason})."
            )
        try:
            res_br = uow.client.table("branches").select("name").eq("id", eff_branch_id).limit(1).execute()
            br_rows = getattr(res_br, "data", None)
            if isinstance(br_rows, list) and br_rows and isinstance(br_rows[0], dict) and br_rows[0].get("name"):
                eff_branch_name = str(br_rows[0]["name"])
        except Exception:
            pass

    # Scoping target officer
    mgr_roles = {"BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"}
    target_co = current_user.username
    if current_user.role in mgr_roles and payload.officer:
        target_co = payload.officer

    officer_uuid = uow.loans._resolve_officer_id(target_co)
    if not officer_uuid:
        res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
        officer_uuid = res_u.data[0]["id"] if res_u.data else current_user.id

    if eff_branch_id and officer_uuid:
        try:
            cb_chk = uow.client.table("co_cashbooks").select("status").eq("branch_id", eff_branch_id).eq("officer_id", officer_uuid).eq("date", date_str).limit(1).execute()
            cb_chk_rows = getattr(cb_chk, "data", None)
            if isinstance(cb_chk_rows, list) and cb_chk_rows and isinstance(cb_chk_rows[0], dict):
                if str(cb_chk_rows[0].get("status") or "").strip().lower() in {"closed", "verified"}:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Cannot record client fee: officer cashbook is already Closed or Verified."
                    )
        except HTTPException:
            raise
        except Exception:
            pass

    # Normalize fee classification & display name
    ft_low = payload.fee_type.lower()
    if "pass" in ft_low:
        fee_cls = "PASSBOOK"
        fee_name = "Passbook Fee"
    elif "bonus" in ft_low:
        fee_cls = "BONUS"
        fee_name = "Bonus"
    elif "damage" in ft_low or "dmg" in ft_low or "cfd" in ft_low:
        fee_cls = "CREDIT_FORM_DAMAGE"
        fee_name = "Credit Form Damage Fee"
    elif "misc" in ft_low:
        fee_cls = "MISC_FEE"
        fee_name = "Misc Fee"
    else:
        fee_cls = "PROCESSING_FEE"
        fee_name = "Credit Form / App Fee"

    fee_id = str(uuid.uuid4())
    ev_ref = f"FEE-{date_str}-{uuid.uuid4().hex[:6].upper()}"
    narr = payload.remarks or f"{fee_name} from {client_code} ({client_name}) recorded at EOD"
    fee_record = {
        "id": fee_id,
        "posting_date": date_str,
        "client_id": payload.client_id,
        "branch_id": eff_branch_id,
        "officer_id": officer_uuid,
        "fee_type": fee_cls,
        "amount": payload.amount,
        "reference": ev_ref,
        "remarks": narr,
    }
    audit_op = {
        "type": "insert",
        "table": "audit_logs",
        "record": {
            "id": str(uuid.uuid4()),
            "user_id": current_user.id or officer_uuid,
            "action": "RECORD_CLIENT_FEE",
            "description": f"Recorded {fee_name} of ₦{payload.amount:,.2f} for {client_name} ({client_code})",
            "table_name": "fees",
            "record_id": fee_id,
        },
    }

    # Route according to authoritative banking rules (BR-ACCT-001, BR-SAV-001, BR-SAV-002, BR-SAV-005)
    if fee_cls == "MISC_FEE":
        # 1. Misc Fee is Misc Savings (Internal Savings pool) -> Debit 1000 (Vault Cash), Credit 2020 (Internal Savings)
        from services.savings_service import SavingsService
        SavingsService.post_misc_savings(
            uow, payload.client_id, client_name, eff_branch_name, target_co,
            payload.amount, reference=ev_ref, remarks=narr, posting_date=target_date
        )
        # 2. Persist operational fee register + audit log atomically
        uow.client.rpc("atomic_execute_operations", {
            "p_operations": [
                {"type": "insert", "table": "fees", "record": fee_record},
                audit_op,
            ]
        }).execute()
    else:
        # True Fee Revenue (Account 3000: Fee Income) -> Debit 1000 (Vault Cash), Credit 3000 (Fee Income)
        ev = DomainEvent(
            event_id=fee_id,
            aggregate_id=payload.client_id,
            aggregate_type="Fee",
            event_type="FeeCharged",
            payload={
                "branch": eff_branch_name,
                "branch_id": eff_branch_id,
                "officer": target_co,
                "officer_id": officer_uuid,
                "client_id": payload.client_id,
                "client_name": client_name,
                "client": client_name,
                "amount": payload.amount,
                "date": date_str,
                "classification": fee_cls,
                "reference": ev_ref,
                "narration": narr
            }
        )
        operations = [
            {
                "type": "insert",
                "table": "event_store",
                "record": {
                    "event_id": ev.event_id,
                    "aggregate_id": ev.aggregate_id,
                    "aggregate_type": ev.aggregate_type,
                    "event_type": ev.event_type,
                    "version": ev.version,
                    "payload": ev.payload,
                    "status": "Completed",
                },
            }
        ]
        post_res = FinancialPostingEngine.post_event(uow, ev, defer_commit=True)
        if isinstance(post_res, tuple) and len(post_res) == 2 and isinstance(post_res[1], dict):
            operations.append(post_res[1])
        operations.append({"type": "insert", "table": "fees", "record": fee_record})
        operations.append(audit_op)
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

    # Rebuild CO & Master cashbook projections
    if officer_uuid and eff_branch_id:
        uow.cashbook.rebuild_projection(eff_branch_id, target_date, officer_id=officer_uuid)
        try:
            from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
            MasterCashbookProjectionBuilder.rebuild_master_projection(uow, eff_branch_id, target_date)
        except Exception:
            pass

    return RecordClientFeeResponse(
        success=True,
        message=f"Recorded {fee_name} of ₦{payload.amount:,.2f} for {client_name}.",
        fee_id=fee_id,
        date=date_str,
        client_name=client_name,
        fee_type=fee_cls,
        amount=payload.amount
    )


@router.get("/client-fees", response_model=List[ClientFeeItem])
def get_client_fees(
    date_str: Optional[str] = Query(None, alias="date"),
    officer: Optional[str] = Query(None),
    branch: Optional[str] = Query(None, description="Branch override for supervisory roles"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns all client fees recorded for the given officer and date.
    """
    mgr_roles = {"BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"}
    can_manage = current_user.role in mgr_roles

    if branch and not can_manage and branch != current_user.branch and branch != current_user.branch_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Credit Officers cannot view another branch's client fees."
        )

    target_branch = branch if (branch and can_manage) else current_user.branch
    b_uuid = uow.cashbook._resolve_branch_id(target_branch)
    check_branch_access(current_user, b_uuid, "view client fees")

    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            biz_dt = BusinessDateService.get_business_date(uow, b_uuid or target_branch)
            target_date = biz_dt if isinstance(biz_dt, date) else date.today()
    else:
        biz_dt = BusinessDateService.get_business_date(uow, b_uuid or target_branch)
        target_date = biz_dt if isinstance(biz_dt, date) else date.today()
    p_date_str = target_date.isoformat()

    target_co = current_user.username
    if can_manage and officer:
        target_co = officer

    officer_uuid = uow.loans._resolve_officer_id(target_co)
    if not officer_uuid:
        res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
        officer_uuid = res_u.data[0]["id"] if res_u.data else current_user.id

    # Query public.fees
    results: List[ClientFeeItem] = []
    try:
        res_fees = uow.client.table("fees").select("*, clients(client_code, name)")\
            .eq("branch_id", b_uuid).eq("officer_id", officer_uuid)\
            .eq("posting_date", p_date_str)\
            .order("created_at", desc=True).execute()
        for f in (res_fees.data or []):
            cl = f.get("clients") or {}
            results.append(ClientFeeItem(
                id=str(f.get("id")),
                date=str(f.get("posting_date")),
                client_id=str(f.get("client_id") or ""),
                client_code=cl.get("client_code") or "N/A",
                client_name=cl.get("name") or "Unknown Client",
                fee_type=f.get("fee_type") or "FEE",
                amount=float(f.get("amount") or 0.0),
                remarks=f.get("remarks"),
                reference=f.get("reference"),
                created_at=str(f.get("created_at") or "")
            ))
    except Exception as e:
        print(f"[CLIENT FEES QUERY WARNING]: {e}")

    return results
