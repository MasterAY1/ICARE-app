"""
CO Cashbook route adapter.
Queries co_cashbooks and Account 1000 journal projection directly.
Fully parity-matched with Streamlit app.py L10748-11186.
"""
from typing import Optional, List
from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
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

router = APIRouter(prefix="/api/v1/co/cashbook", tags=["CO Cashbook"])


@router.get("", response_model=CoCashbookResponse)
@router.get("/", response_model=CoCashbookResponse, include_in_schema=False)
@router.get("/daily", response_model=CoCashbookResponse, include_in_schema=False)
def get_co_cashbook(
    date_str: Optional[str] = Query(None, alias="date", description="Target ISO date (YYYY-MM-DD)"),
    officer: Optional[str] = Query(None, description="Target Credit Officer username"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live 2-sided Balanced T-Account CO Cashbook projection backed by Account 1000,
    including Arrears Tally, EOD reversal options, and officer selection for managers.
    """
    branch_id = uow.cashbook._resolve_branch_id(current_user.branch)
    
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
        target_date = BusinessDateService.get_business_date(uow, current_user.branch)

    iso_date = target_date.isoformat()
    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, target_date)

    # Determine RBAC scope for officer selection (app.py L10770-10785)
    mgr_roles = {"BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"}
    can_select_officer = current_user.role in mgr_roles

    officer_options: List[OfficerOption] = []
    target_co = current_user.username

    if can_select_officer:
        try:
            res_users = uow.client.table("app_users").select("username, full_name").eq("branch_id", branch_id).execute()
            for u in (res_users.data or []):
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

    # 1. Rebuild projection for fresh live data (app.py L10803)
    if officer_id and branch_id:
        try:
            uow.cashbook.rebuild_projection(branch_id, target_date, officer_id=officer_id)
        except Exception:
            pass

    # 2. Query co_cashbooks table (app.py L10805-10834)
    res_co = uow.client.table("co_cashbooks").select("*").eq("date", iso_date).eq("branch_id", branch_id).eq("officer_id", officer_id).execute()

    bf_cash = t_sav = t_r12w = t_r24w = t_r60d = t_rmth = t_cont = t_bwd = t_asale = t_app = t_pb = t_bon = t_cfd = 0.0
    t_d11 = t_w11 = t_w20 = t_mm = t_pwd = t_exp = t_bdep = t_lres = t_ltrans = t_cc = 0.0
    d_act = w_act_12 = w_act_24 = m_act = 0.0

    if res_co.data:
        c = res_co.data[0]
        bf_cash = float(c.get("opening_balance") or 0)
        t_sav = float(c.get("savings_deposit") or 0)
        t_lres = float(c.get("laps_reserve") or 0)
        t_r60d = float(c.get("rep_daily") or 0)
        t_r12w = float(c.get("rep_12_weeks") or 0)
        t_r24w = float(c.get("rep_24_weeks") or 0)
        t_rmth = float(c.get("rep_monthly") or 0)
        t_d11 = float(c.get("daily_11_pct") or 0)
        t_w11 = float(c.get("weekly_11_pct") or 0)
        t_w20 = float(c.get("weekly_20_pct") or 0)
        t_mm = float(c.get("risk_premium_returns") or 0)
        t_cont = float(c.get("contingency") or 0)
        t_app = float(c.get("app_fee") or 0)
        t_cfd = float(c.get("credit_form_damage") or 0)
        t_pb = float(c.get("passbook") or 0)
        t_bon = float(c.get("bonus") or 0)
        t_cc = float(c.get("cash_and_carry") or 0)
        t_asale = float(c.get("asset_credit_sales") or 0)
        t_bwd = float(c.get("bank_withdrawal") or 0)
        t_pwd = float(c.get("product_withdrawal") or 0)
        t_exp = float(c.get("office_expenses") or 0)
        t_bdep = float(c.get("bank_deposit") or 0)
        t_ltrans = float(c.get("laps_returns") or 0)

    # 3. Fetch active disbursements originated today for breakdown (app.py L10835-10854)
    if officer_id and branch_id:
        try:
            res_l = uow.client.table("loans").select("loan_amount, active_credit, disbursement_date, date, extra_fields, loan_products(name, repayment_cycle)") \
                .eq("officer_id", officer_id).eq("branch_id", branch_id).or_(f"disbursement_date.eq.{iso_date},date.eq.{iso_date}") \
                .in_("status", ["Active", "Approved", "Completed"]).execute()
            for l in (res_l.data or []):
                if isinstance(l.get("extra_fields"), dict) and l["extra_fields"].get("is_legacy") is True:
                    continue
                effective_disb_date = l.get("disbursement_date") or l.get("date")
                if effective_disb_date != iso_date:
                    continue
                act_cr = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                lp = l.get("loan_products") or {}
                p_name = str(lp.get("name") or "").lower()
                cycle = lp.get("repayment_cycle") or ("Daily" if "daily" in p_name else "Weekly")
                if cycle == "Daily":
                    d_act += act_cr
                elif cycle == "Weekly":
                    if "24" in p_name:
                        w_act_24 += act_cr
                    else:
                        w_act_12 += act_cr
                elif cycle == "Monthly":
                    m_act += act_cr
                else:
                    w_act_12 += act_cr
        except Exception:
            pass

    # Compute double-entry totals (app.py L10859-10870)
    left_total = (
        bf_cash + t_lres + t_sav + t_r60d + t_r12w + t_r24w + t_rmth +
        t_d11 + t_w11 + t_w20 + t_mm + t_cont + t_app + t_cfd + t_pb + t_bon +
        t_asale + t_cc + t_bwd
    )
    right_total = (
        d_act + w_act_12 + w_act_24 + m_act +
        t_pwd + t_exp + t_ltrans + t_bdep
    )
    closing_bal = left_total - right_total

    inflows = CashbookInflows(
        opening_balance=bf_cash,
        savings_deposit=t_sav,
        laps_reserve=t_lres,
        rep_daily=t_r60d,
        rep_12_weeks=t_r12w,
        rep_24_weeks=t_r24w,
        rep_monthly=t_rmth,
        daily_11_pct=t_d11,
        weekly_11_pct=t_w11,
        weekly_20_pct=t_w20,
        risk_premium_returns=t_mm,
        contingency=t_cont,
        app_fee=t_app,
        credit_form_damage=t_cfd,
        passbook=t_pb,
        bonus=t_bon,
        cash_and_carry=t_cc,
        asset_credit_sales=t_asale,
        bank_withdrawal=t_bwd
    )

    outflows = CashbookOutflows(
        active_loan_daily=d_act,
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
            .order("created_at", desc=True).limit(30)
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
            ev_off = str(p.get("officer") or p.get("officer_id") or "")
            ev_br = str(p.get("branch") or p.get("branch_id") or "")

            if not can_select_officer and ev_off not in [str(current_user.username), str(current_user.id), str(officer_id)]:
                continue
            if branch_id and ev_br not in [str(current_user.branch), str(branch_id)]:
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
        branch=current_user.branch,
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

    target_date = date.today()
    if payload.date:
        try:
            target_date = date.fromisoformat(payload.date)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )

    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, target_date)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Cannot update End of Day inputs today ({open_reason})."
        )

    date_str = target_date.isoformat()
    b_uuid = uow.cashbook._resolve_branch_id(current_user.branch)

    # Scoping target officer
    mgr_roles = {"BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"}
    target_co = current_user.username
    if current_user.role in mgr_roles and payload.officer:
        target_co = payload.officer

    officer_uuid = uow.loans._resolve_officer_id(target_co)
    if not officer_uuid:
        res_u = uow.client.table("app_users").select("id").eq("username", target_co).execute()
        officer_uuid = res_u.data[0]["id"] if res_u.data else current_user.id

    # 1. Fetch current projection to preserve untouched fields and compute deltas
    cb_res = uow.client.table("co_cashbooks").select("*").eq("branch_id", b_uuid).eq("officer_id", officer_uuid).eq("date", date_str).execute()
    cur_cb = cb_res.data[0] if cb_res.data else {}

    cur_app_fee = float(cur_cb.get("app_fee") or 0.0)
    cur_pb = float(cur_cb.get("passbook") or 0.0)
    cur_cfd = float(cur_cb.get("credit_form_damage") or 0.0)
    cur_bon = float(cur_cb.get("bonus") or 0.0)
    cur_misc = float(cur_cb.get("misc_fees") or 0.0)
    cur_exp = float(cur_cb.get("office_expenses") or 0.0)
    cur_bdep = float(cur_cb.get("bank_deposit") or 0.0)

    # Resolve effective values: preserve untouched fields if None
    global_opening_val = float(payload.opening_balance) if payload.opening_balance is not None else float(cur_cb.get("opening_balance") or 0.0)
    global_expenses_val = float(payload.office_expenses) if payload.office_expenses is not None else cur_exp
    global_bank_dep_val = float(payload.bank_deposit) if payload.bank_deposit is not None else cur_bdep
    global_app_fee_val = float(payload.app_fee) if payload.app_fee is not None else cur_app_fee
    global_passbook_val = float(payload.passbook) if payload.passbook is not None else cur_pb
    global_misc_fee_val = float(payload.misc_fee) if payload.misc_fee is not None else cur_misc
    global_cfd_val = float(payload.credit_form_damage) if payload.credit_form_damage is not None else cur_cfd
    global_bonus_val = float(payload.bonus) if payload.bonus is not None else cur_bon

    # 2. Update manual opening balance if provided
    if payload.opening_balance is not None and global_opening_val > 0:
        uow.client.table("co_cashbooks").upsert({
            "date": date_str,
            "branch_id": b_uuid,
            "officer_id": officer_uuid,
            "opening_balance": global_opening_val
        }, on_conflict="date,branch_id,officer_id").execute()

    # Helper function to post delta with proper reversal handling
    def _post_adjustment(d, ev_pos, ev_neg, agg_type, name, cur_val, new_val):
        if d == 0:
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

    # 3. Post Delta Adjustments for each fee/expense/deposit (app.py L10978-10984):
    _post_adjustment(global_app_fee_val - cur_app_fee, "FeeCharged", "FeeReversed", "Fee", "App Fee", cur_app_fee, global_app_fee_val)
    _post_adjustment(global_passbook_val - cur_pb, "FeeCharged", "FeeReversed", "Fee", "Passbook", cur_pb, global_passbook_val)
    _post_adjustment(global_cfd_val - cur_cfd, "FeeCharged", "FeeReversed", "Fee", "Cr Form Damage", cur_cfd, global_cfd_val)
    _post_adjustment(global_bonus_val - cur_bon, "FeeCharged", "FeeReversed", "Fee", "Bonus", cur_bon, global_bonus_val)
    _post_adjustment(global_misc_fee_val - cur_misc, "FeeCharged", "FeeReversed", "Fee", "Misc Fee", cur_misc, global_misc_fee_val)
    _post_adjustment(global_expenses_val - cur_exp, "ExpenseRecorded", "ExpenseReversed", "Expense", "Expense", cur_exp, global_expenses_val)
    _post_adjustment(global_bank_dep_val - cur_bdep, "BankDeposited", "BankDepositReversed", "Treasury", "Bank Deposit", cur_bdep, global_bank_dep_val)

    # 4. Rebuild projection (app.py L10987-10993)
    if officer_uuid and b_uuid:
        if payload.opening_balance is not None and global_opening_val > 0:
            uow.cashbook.rebuild_projection(b_uuid, target_date, officer_id=officer_uuid, manual_opening_balance=global_opening_val)
            uow.cashbook.cascade_co_projection(b_uuid, officer_uuid, target_date, date.today())
        else:
            uow.cashbook.rebuild_projection(b_uuid, target_date, officer_id=officer_uuid)

    return EodAdjustmentsResponse(
        success=True,
        date=date_str,
        message="End of Day Outflows & Fees Updated Successfully."
    )



