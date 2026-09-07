"""
CO Cashbook route adapter.
Queries co_cashbooks and Account 1000 journal projection directly.
"""
from typing import Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.cashbook import CoCashbookResponse, CashbookInflows, CashbookOutflows
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
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live 2-sided Balanced T-Account CO Cashbook projection backed by Account 1000.
    """
    target_date = date.today()
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )

    iso_date = target_date.isoformat()
    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, target_date)

    branch_id = uow.cashbook._resolve_branch_id(current_user.branch)
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    # Query co_cashbooks table
    res_co = uow.client.table("co_cashbooks").select("*").eq("date", iso_date).eq("branch_id", branch_id).eq("officer_id", officer_id).execute()

    inflows = CashbookInflows()
    outflows = CashbookOutflows()
    left_total = 0.0
    right_total = 0.0
    closing_bal = 0.0

    if res_co.data:
        c = res_co.data[0]
        inflows = CashbookInflows(
            opening_balance=float(c.get("opening_balance") or 0.0),
            savings_deposit=float(c.get("savings_deposit") or 0.0),
            laps_reserve=float(c.get("laps_reserve") or 0.0),
            rep_daily=float(c.get("rep_daily") or 0.0),
            rep_12_weeks=float(c.get("rep_12_weeks") or 0.0),
            rep_24_weeks=float(c.get("rep_24_weeks") or 0.0),
            rep_monthly=float(c.get("rep_monthly") or 0.0),
            daily_11_pct=float(c.get("daily_11_pct") or 0.0),
            weekly_11_pct=float(c.get("weekly_11_pct") or 0.0),
            weekly_20_pct=float(c.get("weekly_20_pct") or 0.0),
            risk_premium_returns=float(c.get("risk_premium_returns") or 0.0),
            contingency=float(c.get("contingency") or 0.0),
            app_fee=float(c.get("app_fee") or 0.0),
            credit_form_damage=float(c.get("credit_form_damage") or 0.0),
            passbook=float(c.get("passbook") or 0.0),
            bonus=float(c.get("bonus") or 0.0),
            cash_and_carry=float(c.get("cash_and_carry") or 0.0),
            asset_credit_sales=float(c.get("asset_credit_sales") or 0.0),
            bank_withdrawal=float(c.get("bank_withdrawal") or 0.0)
        )

        outflows = CashbookOutflows(
            active_loan_daily=float(c.get("active_loan_daily") or 0.0),
            active_loan_12w=float(c.get("active_loan_12w") or 0.0),
            active_loan_24w=float(c.get("active_loan_24w") or 0.0),
            active_loan_monthly=float(c.get("active_loan_monthly") or 0.0),
            product_withdrawal=float(c.get("product_withdrawal") or 0.0),
            office_expenses=float(c.get("office_expenses") or 0.0),
            bank_deposit=float(c.get("bank_deposit") or 0.0),
            laps_returns=float(c.get("laps_returns") or 0.0)
        )

        left_total = float(c.get("total_inflows") or 0.0)
        right_total = float(c.get("total_outflows") or 0.0)
        closing_bal = float(c.get("closing_balance") or 0.0)

    return CoCashbookResponse(
        date=iso_date,
        branch=current_user.branch,
        officer=current_user.username,
        is_open=is_open,
        open_reason=open_reason,
        inflows=inflows,
        outflows=outflows,
        total_inflows=left_total,
        total_outflows=right_total,
        closing_balance=closing_bal
    )


@router.post("/reversal-request", response_model=ReversalRequestResponse)
def request_cashbook_reversal(
    payload: ReversalRequestInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a cashbook fee / expense reversal request for BM approval under Four-Eyes rule BR-ERR-001 (app.py L7563-7648).
    """
    from services.correction_service import CorrectionService

    req_id = CorrectionService.request_correction(
        uow=uow,
        record_id=payload.record_id,
        record_type=payload.record_type or "Cashbook",
        reason=payload.reason,
        requested_by=current_user.username,
        branch_id=current_user.branch_id
    )

    return ReversalRequestResponse(
        success=True,
        request_id=req_id,
        status="Pending",
        message="Cashbook transaction reversal request submitted to Branch Manager for approval."
    )


@router.post("/eod-adjustments", response_model=EodAdjustmentsResponse)
def submit_eod_adjustments(
    payload: EodAdjustmentsInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Posts EOD delta adjustments for fees, expenses, bank deposits, and opening balance (app.py L7330-7500).
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
    officer_uuid = uow.loans._resolve_officer_id(current_user.username) or current_user.id

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
            aggregate_id=officer_uuid,
            aggregate_type=agg_type,
            event_type=ev_type,
            payload={
                "branch": current_user.branch,
                "branch_id": b_uuid,
                "officer": current_user.username,
                "officer_id": officer_uuid,
                "amount": amt,
                "date": date_str,
                "narration": narr
            }
        )
        uow.event_store.append(ev)
        FinancialPostingEngine.post_event(uow, ev)

    # 3. Post Delta Adjustments for each fee/expense/deposit:
    _post_adjustment(global_app_fee_val - cur_app_fee, "FeeCharged", "FeeReversed", "Fee", "App Fee", cur_app_fee, global_app_fee_val)
    _post_adjustment(global_passbook_val - cur_pb, "FeeCharged", "FeeReversed", "Fee", "Passbook", cur_pb, global_passbook_val)
    _post_adjustment(global_cfd_val - cur_cfd, "FeeCharged", "FeeReversed", "Fee", "Cr Form Damage", cur_cfd, global_cfd_val)
    _post_adjustment(global_bonus_val - cur_bon, "FeeCharged", "FeeReversed", "Fee", "Bonus", cur_bon, global_bonus_val)
    _post_adjustment(global_misc_fee_val - cur_misc, "FeeCharged", "FeeReversed", "Fee", "Misc Fee", cur_misc, global_misc_fee_val)
    _post_adjustment(global_expenses_val - cur_exp, "ExpenseRecorded", "ExpenseReversed", "Expense", "Expense", cur_exp, global_expenses_val)
    _post_adjustment(global_bank_dep_val - cur_bdep, "BankDeposited", "BankDepositReversed", "Treasury", "Bank Deposit", cur_bdep, global_bank_dep_val)

    # Rebuild Cashbook projection
    if officer_uuid and b_uuid:
        uow.cashbook.rebuild_projection(b_uuid, target_date, officer_id=officer_uuid)

    return EodAdjustmentsResponse(
        success=True,
        date=date_str,
        message="End of Day Outflows & Fees Updated Successfully!"
    )


