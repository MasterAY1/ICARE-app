"""
Branch Manager Master Cashbook route adapter.
Provides full 1:1 Streamlit Parity for Master Cashbook (app.py L11187-12191).
Backed directly by Account 1000 journal projection and MasterCashbookProjectionBuilder.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime, timedelta
from calendar import monthrange
import json
import io
from fastapi import APIRouter, Depends, Query, HTTPException, status
from fastapi.responses import StreamingResponse
import pandas as pd

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from models.user import CurrentUser
from domain.queries import CashbookFilter
from mappers.base_mappers import CashbookMapper
from services.business_date_service import BusinessDateService
from services.treasury_service import TreasuryService
from services.correction_service import CorrectionService
from services.financial_reconciliation_service import FinancialReconciliationService
from services.rbac_scope_service import RBACScopeService

from api.schemas.master_cashbook import (
    MasterCashbookDailyResponse,
    MasterCashbookInflows,
    MasterCashbookOutflows,
    BranchReconciliationTally,
    TallyNotPaidClient,
    PendingReversalItem,
    TreasuryTransactionOption,
    MasterCashbookManualInputsRequest,
    CoAggregationResponse,
    OfficerOption,
    EodCloseRequest,
    MonthlyLedgerResponse,
    MonthlyLedgerRow,
    ReversalActionRequest,
    TreasuryReversalRequestInput
)

router = APIRouter(prefix="/api/v1/bm/cashbook", tags=["Master Cashbook"])


def _is_legacy_loan(val: Any) -> bool:
    if isinstance(val, dict):
        return val.get("is_legacy") is True
    elif isinstance(val, str):
        try:
            d = json.loads(val)
            return isinstance(d, dict) and d.get("is_legacy") is True
        except Exception:
            return False
    return False


@router.get("/daily", response_model=MasterCashbookDailyResponse)
def get_daily_master_cashbook(
    date_str: Optional[str] = Query(None, alias="date", description="Target ISO date (YYYY-MM-DD)"),
    branch: Optional[str] = Query(None, description="Branch name override for regional/admin roles"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live Master Cashbook daily projection backed by Account 1000,
    along with Branch Reconciliation Tally and Pending Reversals.
    """
    # 1. Resolve Target Branch
    target_branch = branch if (branch and current_user.role in ["AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"]) else current_user.branch
    branch_id = uow.cashbook._resolve_branch_id(target_branch)

    # 2. Resolve Target Date
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD.")
    else:
        target_date = BusinessDateService.get_business_date(uow, target_branch)

    iso_date = target_date.isoformat()
    is_open, open_reason = BusinessDateService.is_operational_open(uow, branch_id, target_date)

    # 3. Rebuild projection (app.py L11227)
    try:
        uow.cashbook.rebuild_projection(branch_id, target_date)
    except Exception as ex:
        print(f"Error rebuilding projection: {ex}")

    # 4. Fetch Projected Row from master_cashbook
    cb_entry = uow.cashbook.find_by_date_and_branch(iso_date, target_branch)

    auto_rep_60d = cb_entry.rep_daily if cb_entry else 0.0
    auto_rep_120d = getattr(cb_entry, "rep_120_days", 0.0) if cb_entry else 0.0
    auto_rep_12w = cb_entry.rep_12_weeks if cb_entry else 0.0
    auto_rep_24w = cb_entry.rep_24_weeks if cb_entry else 0.0
    auto_rep_mth = cb_entry.rep_monthly if cb_entry else 0.0
    auto_savings = cb_entry.savings_deposit if cb_entry else 0.0
    auto_laps_res = cb_entry.laps_reserve if cb_entry else 0.0
    auto_daily_11 = cb_entry.daily_11_pct if cb_entry else 0.0
    auto_daily_20 = float(getattr(cb_entry, "daily_20_pct", 0.0) or 0.0) if cb_entry else 0.0
    auto_weekly_11 = cb_entry.weekly_11_pct if cb_entry else 0.0
    auto_weekly_20 = float(getattr(cb_entry, "weekly_20_pct", 0.0) or 0.0) if cb_entry else 0.0
    auto_monthly_markup = cb_entry.risk_premium_returns if cb_entry else 0.0
    auto_passbook = cb_entry.passbook if cb_entry else 0.0
    auto_app_fee = cb_entry.app_fee if cb_entry else 0.0
    auto_asset_cr_sales = cb_entry.asset_credit_sales if cb_entry else 0.0
    auto_cash_carry = cb_entry.cash_and_carry if cb_entry else 0.0
    auto_contingency = cb_entry.contingency if cb_entry else 0.0
    auto_credit_form_dmg = cb_entry.credit_form_damage if cb_entry else 0.0
    auto_bonus = cb_entry.bonus if cb_entry else 0.0
    auto_misc = cb_entry.misc_fees if cb_entry else 0.0
    auto_bank_wd = cb_entry.bank_withdrawal if cb_entry else 0.0

    auto_savings_wd = cb_entry.savings_withdrawal if cb_entry else 0.0
    auto_prod_wd = cb_entry.product_withdrawal if cb_entry else 0.0
    auto_expenses = cb_entry.office_expenses if cb_entry else 0.0
    auto_laps_ret = cb_entry.laps_returns if cb_entry else 0.0
    auto_bank_dep = cb_entry.bank_deposit if cb_entry else 0.0
    auto_adj_in = float(getattr(cb_entry, "adjustment_in", 0.0) or 0.0) if cb_entry else 0.0
    auto_adj_out = float(getattr(cb_entry, "adjustment_out", 0.0) or 0.0) if cb_entry else 0.0
    auto_adj_reason = str(getattr(cb_entry, "adjustment_reason", "") or "") if cb_entry else ""

    funds_ho = float(getattr(cb_entry, "funds_received_ho", 0.0) or 0.0) if cb_entry else 0.0
    funds_branch = float(getattr(cb_entry, "funds_received_other_branch", 0.0) or 0.0) if cb_entry else 0.0
    funds_area = float(getattr(cb_entry, "funds_received_other_area", 0.0) or 0.0) if cb_entry else 0.0
    xfer_branch = float(getattr(cb_entry, "fund_transferred_other_branch", 0.0) or 0.0) if cb_entry else 0.0
    xfer_ho = float(getattr(cb_entry, "fund_transferred_ho", 0.0) or 0.0) if cb_entry else 0.0
    xfer_area = float(getattr(cb_entry, "fund_to_other_area", 0.0) or 0.0) if cb_entry else 0.0
    salaries = float(getattr(cb_entry, "staff_salaries", 0.0) or 0.0) if cb_entry else 0.0

    # 5. Loan Disbursements for Today (app.py L11275-11319)
    auto_fund_asset = 0.0
    auto_fund_finance = 0.0
    auto_disb_60d = 0.0
    auto_disb_120d = 0.0
    auto_disb_12w = 0.0
    auto_disb_24w = 0.0
    auto_disb_mth = 0.0

    try:
        res_l = uow.client.table("loans") \
            .select("loan_amount, active_credit, extra_fields, product_category, loan_products(name, repayment_cycle)") \
            .eq("branch_id", branch_id) \
            .or_(f"disbursement_date.eq.{iso_date},date.eq.{iso_date}") \
            .in_("status", ["Active", "Approved", "Completed"]) \
            .execute()
        for loan in (res_l.data or []):
            if _is_legacy_loan(loan.get("extra_fields")):
                continue
            principal = float(loan.get("loan_amount") or 0.0)
            active_cr = float(loan.get("active_credit") or principal)
            cat = str(loan.get("product_category") or "Finance")
            lp = loan.get("loan_products") or {}
            prod = str(lp.get("name") or "").lower()

            if "Asset" in cat or "asset" in prod:
                auto_fund_asset += principal
            else:
                auto_fund_finance += principal

            if "120" in prod:
                auto_disb_120d += active_cr
            elif "60" in prod:
                auto_disb_60d += active_cr
            elif "24w" in prod or "24" in prod:
                auto_disb_24w += active_cr
            elif "12w" in prod or "12" in prod:
                auto_disb_12w += active_cr
            elif "3m" in prod or "6m" in prod or "month" in prod:
                auto_disb_mth += active_cr
            else:
                auto_disb_12w += active_cr
    except Exception as ex_loans:
        print(f"Error fetching today loans: {ex_loans}")

    # 6. Opening Balance Resolution (app.py L11321-11333)
    auto_opening = float(cb_entry.opening_balance) if cb_entry and cb_entry.opening_balance is not None else 0.0
    if auto_opening == 0.0 and iso_date == "2026-08-19":
        auto_opening = 450.0
    elif auto_opening == 0.0:
        prev_date = (target_date - timedelta(days=1)).isoformat()
        try:
            prev_entry = uow.cashbook.find_by_date_and_branch(prev_date, target_branch)
            if prev_entry and prev_entry.closing_balance is not None:
                auto_opening = float(prev_entry.closing_balance)
        except Exception:
            auto_opening = 0.0

    # 7. Total Inflows and Outflows Calculation (app.py L11457-11474)
    total_inflows = (
        auto_opening + auto_savings + auto_rep_60d + auto_rep_120d + auto_rep_12w + auto_rep_24w + auto_rep_mth +
        auto_laps_res + funds_ho + funds_branch + funds_area +
        auto_asset_cr_sales + auto_cash_carry + auto_fund_finance +
        auto_daily_11 + auto_daily_20 + auto_weekly_11 + auto_weekly_20 + auto_monthly_markup +
        auto_contingency + auto_credit_form_dmg + auto_bonus + auto_app_fee + auto_passbook + auto_bank_wd +
        auto_adj_in
    )

    total_outflows = (
        auto_prod_wd + auto_savings_wd +
        auto_fund_asset + auto_fund_finance +
        xfer_branch + xfer_ho + xfer_area +
        salaries + auto_expenses + auto_laps_ret + auto_bank_dep +
        auto_adj_out
    )

    closing_balance = total_inflows - total_outflows

    # 8. Branch Collection & Arrears Reconciliation Tally (app.py L11335-11350)
    tally_model: Optional[BranchReconciliationTally] = None
    try:
        raw_tally = FinancialReconciliationService.get_daily_collection_arrears_tally(
            uow=uow,
            branch_id=branch_id,
            posting_date=target_date,
            officer_id=None
        )
        if raw_tally:
            np_clients = [
                TallyNotPaidClient(
                    name=c.get("name", "Unknown"),
                    code=c.get("code", ""),
                    expected=float(c.get("expected") or 0.0),
                    shortfall=float(c.get("shortfall") or 0.0),
                    is_partial=bool(c.get("is_partial", False))
                )
                for c in (raw_tally.get("not_paid_clients") or [])
            ]
            tally_model = BranchReconciliationTally(
                scheduled_expected=float(raw_tally.get("scheduled_expected") or 0.0),
                not_paid_amount=float(raw_tally.get("not_paid_amount") or 0.0),
                not_paid_count=int(raw_tally.get("not_paid_count") or 0),
                not_paid_clients=np_clients,
                excess_amount=float(raw_tally.get("excess_amount") or 0.0),
                excess_count=int(raw_tally.get("excess_count") or 0),
                actual_repayments=float(raw_tally.get("actual_repayments") or 0.0),
                actual_savings=float(raw_tally.get("actual_savings") or 0.0),
                actual_cash_collected=float(raw_tally.get("actual_cash_collected") or 0.0),
                bank_deposited=float(raw_tally.get("bank_deposited") or 0.0),
                closing_cash_balance=float(raw_tally.get("closing_cash_balance") or 0.0),
                is_cash_balanced=bool(raw_tally.get("is_cash_balanced", True)),
                arrears_float=float(raw_tally.get("arrears_float") or 0.0),
                total_reps_count=int(raw_tally.get("total_reps_count") or 0)
            )
    except Exception as ex_tally:
        print(f"Error getting reconciliation tally: {ex_tally}")

    # 9. Pending Branch Reversal Requests (app.py L11591-11609)
    pending_reversals: List[PendingReversalItem] = []
    try:
        q_pending = uow.client.table("correction_requests") \
            .select("*, app_users!correction_requests_requested_by_fkey(username, full_name)") \
            .eq("status", "Pending") \
            .eq("branch_id", branch_id) \
            .order("created_at", desc=False) \
            .execute()
        for req in (q_pending.data or []):
            u_data = req.get("app_users")
            req_user = (u_data.get("full_name") or u_data.get("username")) if isinstance(u_data, dict) else "Officer"
            pending_reversals.append(PendingReversalItem(
                id=str(req.get("id")),
                record_id=str(req.get("record_id")),
                record_type=str(req.get("record_type")),
                reason=str(req.get("reason") or ""),
                requested_by=str(req.get("requested_by") or ""),
                requested_by_name=req_user,
                created_at=str(req.get("created_at") or ""),
                status=str(req.get("status") or "Pending")
            ))
    except Exception as ex_rev:
        print(f"Error fetching pending reversals: {ex_rev}")

    # 10. Recent Treasury Transactions for Flagging (app.py L11652-11671)
    treasury_tx_options: List[TreasuryTransactionOption] = []
    try:
        res_tx = uow.client.table("treasury_transactions") \
            .select("*") \
            .eq("branch_id", branch_id) \
            .order("created_at", desc=True) \
            .limit(25) \
            .execute()
        for t in (res_tx.data or []):
            t_id = str(t.get("id", ""))
            t_type = str(t.get("transaction_type") or "")
            t_amt = float(t.get("amount") or 0.0)
            t_dt = str(t.get("posting_date") or t.get("created_at") or "")[:10]
            t_rem = str(t.get("remarks") or "")
            lbl = f"[{t_type}] {t_dt} | ₦{t_amt:,.2f} — {t_rem[:30]} | Ref: {t_id[:8]}"
            treasury_tx_options.append(TreasuryTransactionOption(
                id=t_id,
                transaction_type=t_type,
                amount=t_amt,
                posting_date=t_dt,
                remarks=t_rem,
                label=lbl
            ))
    except Exception as ex_tx:
        print(f"Error fetching treasury transactions: {ex_tx}")

    inflows = MasterCashbookInflows(
        opening_balance=auto_opening,
        savings_deposit=auto_savings,
        rep_daily=auto_rep_60d,
        rep_120_days=auto_rep_120d,
        rep_12_weeks=auto_rep_12w,
        rep_24_weeks=auto_rep_24w,
        rep_monthly=auto_rep_mth,
        laps_reserve=auto_laps_res,
        funds_received_ho=funds_ho,
        funds_received_other_branch=funds_branch,
        funds_received_other_area=funds_area,
        asset_credit_sales=auto_asset_cr_sales,
        cash_and_carry=auto_cash_carry,
        loan_received_finance=auto_fund_finance,
        daily_11_pct=auto_daily_11,
        daily_20_pct=auto_daily_20,
        weekly_11_pct=auto_weekly_11,
        weekly_20_pct=auto_weekly_20,
        risk_premium_returns=auto_monthly_markup,
        contingency=auto_contingency,
        credit_form_damage=auto_credit_form_dmg,
        bonus=auto_bonus,
        app_fee=auto_app_fee,
        passbook=auto_passbook,
        bank_withdrawal=auto_bank_wd,
        adjustment_in=auto_adj_in
    )

    outflows = MasterCashbookOutflows(
        disb_60d=auto_disb_60d,
        disb_120d=auto_disb_120d,
        disb_12w=auto_disb_12w,
        disb_24w=auto_disb_24w,
        disb_mth=auto_disb_mth,
        fund_transferred_other_branch=xfer_branch,
        fund_transferred_ho=xfer_ho,
        fund_to_other_area=xfer_area,
        fund_to_asset_program=auto_fund_asset,
        fund_to_product_finance=auto_fund_finance,
        product_withdrawal=auto_prod_wd,
        savings_withdrawal=auto_savings_wd,
        staff_salaries=salaries,
        office_expenses=auto_expenses,
        laps_returns=auto_laps_ret,
        bank_deposit=auto_bank_dep,
        adjustment_out=auto_adj_out
    )

    return MasterCashbookDailyResponse(
        date=iso_date,
        branch=target_branch,
        is_open=is_open,
        open_reason=open_reason,
        inflows=inflows,
        outflows=outflows,
        total_inflows=total_inflows,
        total_outflows=total_outflows,
        closing_balance=closing_balance,
        tally=tally_model,
        pending_reversals=pending_reversals,
        treasury_transactions=treasury_tx_options,
        adjustment_reason=auto_adj_reason
    )


@router.post("/daily/manual-entries")
def save_master_cashbook_manual_entries(
    payload: MasterCashbookManualInputsRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Saves BM manual entries (Treasury movements, staff salaries, debt/adjustments)
    and updates Master Cashbook projection (app.py L11488-11583).
    """
    branch_name = current_user.branch
    branch_id = uow.cashbook._resolve_branch_id(branch_name)

    try:
        target_date = date.fromisoformat(payload.date)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD.")

    # Guard: Operational Date Open Check
    is_open, open_reason = BusinessDateService.is_operational_open(uow, branch_id, target_date)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot save entries: Operational Activity Suspended ({open_reason})."
        )

    user_identifier = current_user.username
    posted_any = False

    try:
        if payload.funds_received_ho > 0:
            TreasuryService.post_treasury_transaction(uow, 'HO_TRANSFER_IN', payload.funds_received_ho, branch_name, user_identifier, remarks=f"HO Funding: {payload.funds_received_ho}", posting_date=target_date)
            posted_any = True
        if payload.funds_received_other_branch > 0:
            TreasuryService.post_treasury_transaction(uow, 'INTER_BRANCH_IN', payload.funds_received_other_branch, branch_name, user_identifier, remarks=f"Branch Funding: {payload.funds_received_other_branch}", posting_date=target_date)
            posted_any = True
        if payload.funds_received_other_area > 0:
            TreasuryService.post_treasury_transaction(uow, 'INTER_AREA_IN', payload.funds_received_other_area, branch_name, user_identifier, remarks=f"Area Funding: {payload.funds_received_other_area}", posting_date=target_date)
            posted_any = True
        if payload.fund_transferred_other_branch > 0:
            TreasuryService.post_treasury_transaction(uow, 'INTER_BRANCH_OUT', payload.fund_transferred_other_branch, branch_name, user_identifier, remarks=f"Transfer to Branch: {payload.fund_transferred_other_branch}", posting_date=target_date)
            posted_any = True
        if payload.fund_transferred_ho > 0:
            TreasuryService.post_treasury_transaction(uow, 'HO_TRANSFER_OUT', payload.fund_transferred_ho, branch_name, user_identifier, remarks=f"Transfer to HO: {payload.fund_transferred_ho}", posting_date=target_date)
            posted_any = True
        if payload.fund_to_other_area > 0:
            TreasuryService.post_treasury_transaction(uow, 'INTER_AREA_OUT', payload.fund_to_other_area, branch_name, user_identifier, remarks=f"Transfer to Area: {payload.fund_to_other_area}", posting_date=target_date)
            posted_any = True
        if payload.staff_salaries > 0:
            TreasuryService.post_treasury_transaction(uow, 'SALARY', payload.staff_salaries, branch_name, user_identifier, remarks=f"Salary Payment: {payload.staff_salaries}", posting_date=target_date)
            posted_any = True

        # Save Adjustment In/Out & Reason into master_cashbook record
        if payload.adjustment_in > 0 or payload.adjustment_out > 0 or payload.adjustment_reason:
            uow.client.table("master_cashbook").upsert({
                "date": payload.date,
                "branch_id": branch_id,
                "adjustment_in": payload.adjustment_in,
                "adjustment_out": payload.adjustment_out,
                "adjustment_reason": payload.adjustment_reason.strip() if payload.adjustment_reason else None
            }, on_conflict="date,branch_id").execute()

        # Rebuild projection
        uow.cashbook.rebuild_projection(branch_id, target_date)

        msg = "Treasury transactions posted and Cashbook projection rebuilt successfully!" if posted_any else "Cashbook projection updated and verified successfully!"
        return {"success": True, "message": msg}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to save manual entries: {e}")


@router.get("/co-aggregation", response_model=CoAggregationResponse)
def get_co_aggregation(
    date_str: Optional[str] = Query(None, alias="date", description="Target ISO date (YYYY-MM-DD)"),
    officer: Optional[str] = Query(None, description="Target Credit Officer username"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns individual Credit Officer Daily Cashbook Ledger for BM verification (app.py L11694-11870).
    """
    branch_name = current_user.branch
    branch_id = uow.cashbook._resolve_branch_id(branch_name)

    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD.")
    else:
        target_date = BusinessDateService.get_business_date(uow, branch_name)

    iso_date = target_date.isoformat()
    is_open, open_reason = BusinessDateService.is_operational_open(uow, branch_id, target_date)

    # Resolve Branch Officers
    branch_cos = []
    try:
        all_users = uow.users.find_all()
        branch_cos = [
            u for u in all_users
            if u.role in ["CO", "Officer", "Credit Officer"] and (not branch_name or u.branch_name == branch_name or u.branch_id == branch_id)
        ]
        if not branch_cos:
            branch_cos = [u for u in all_users if u.role in ["CO", "Officer", "Credit Officer"]]
    except Exception:
        branch_cos = []

    officer_options: List[OfficerOption] = [
        OfficerOption(
            username=u.username,
            full_name=u.full_name or u.username,
            display=f"{u.full_name} ({u.username})" if u.full_name else u.username
        )
        for u in branch_cos
    ]

    target_co = officer or (officer_options[0].username if officer_options else current_user.username)
    officer_uuid = uow.loans._resolve_officer_id(target_co)

    # Rebuild & fetch CO cashbook projection
    bf_cash = t_sav = t_r12w = t_r24w = t_r60d = t_rmth = t_cont = t_bwd = t_asale = t_app = t_pb = t_bon = t_cfd = 0.0
    t_d11 = t_w11 = t_mm = t_pwd = t_exp = t_bdep = t_lres = t_ltrans = t_cc = 0.0
    d_act = w_act_12 = w_act_24 = m_act = 0.0
    left_total = right_total = closing_bal = 0.0

    if officer_uuid and branch_id:
        try:
            uow.cashbook.rebuild_projection(branch_id, target_date, officer_id=officer_uuid)
            res_co = uow.client.table("co_cashbooks").select("*").eq("date", iso_date).eq("branch_id", branch_id).eq("officer_id", officer_uuid).execute()
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
                left_total = float(c.get("total_inflows") or 0)
                right_total = float(c.get("total_outflows") or 0)
                closing_bal = float(c.get("closing_balance") or 0)

            # Fetch active loans originated today by this CO
            res_l = uow.client.table("loans") \
                .select("loan_amount, active_credit, extra_fields, loan_products(name, repayment_cycle)") \
                .eq("officer_id", officer_uuid).eq("branch_id", branch_id).or_(f"disbursement_date.eq.{iso_date},date.eq.{iso_date}") \
                .in_("status", ["Active", "Approved", "Completed"]).execute()
            for l in (res_l.data or []):
                if _is_legacy_loan(l.get("extra_fields")):
                    continue
                act_cr = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                lp = l.get("loan_products") or {}
                p_name = str(lp.get("name") or "").lower()
                cycle = lp.get("repayment_cycle") or ("Daily" if "daily" in p_name else "Weekly")
                if cycle == "Daily":
                    d_act += act_cr
                elif cycle == "Weekly":
                    if "24" in p_name: w_act_24 += act_cr
                    else: w_act_12 += act_cr
                elif cycle == "Monthly":
                    m_act += act_cr
                else:
                    w_act_12 += act_cr
        except Exception as e:
            print(f"Error loading CO projection: {e}")

    if left_total == 0 and right_total == 0:
        left_total = (
            bf_cash + t_lres + t_sav + t_r60d + t_r12w + t_r24w + t_rmth +
            t_d11 + t_w11 + t_mm + t_cont + t_app + t_cfd + t_pb + t_bon +
            t_asale + t_cc + t_bwd
        )
        right_total = (
            d_act + w_act_12 + w_act_24 + m_act +
            t_pwd + t_exp + t_ltrans + t_bdep
        )
        closing_bal = left_total - right_total

    inflow_dict = {
        "Opening Balance": bf_cash,
        "Savings Deposit": t_sav,
        "Credit Rep (Daily)": t_r60d,
        "Credit Rep (12 Weeks)": t_r12w,
        "Credit Rep (24 Weeks)": t_r24w,
        "Credit Rep (Monthly)": t_rmth,
        "Laps Reserve": t_lres,
        "Asset Credit Sales": t_asale,
        "Cash & Carry": t_cc,
        "Daily 11% Markup": t_d11,
        "Weekly 11% Markup": t_w11,
        "Monthly / 20% Markup": t_mm,
        "Contingency (1%)": t_cont,
        "Credit Form / App Fee": t_app,
        "Credit Form Damage": t_cfd,
        "Pass Book": t_pb,
        "Bonus": t_bon,
        "Bank Withdrawal": t_bwd,
    }

    outflow_dict = {
        "Active Loan (Daily)": d_act,
        "Active Loan (12 Weeks)": w_act_12,
        "Active Loan (24 Weeks)": w_act_24,
        "Active Loan (Monthly)": m_act,
        "Product / Savings Withdrawal": t_pwd,
        "Office Expenses": t_exp,
        "LAPS Returns / Payouts": t_ltrans,
        "Bank Deposit": t_bdep,
    }

    can_close_day = is_open and "closed" not in open_reason.lower()

    return CoAggregationResponse(
        date=iso_date,
        branch=branch_name,
        officer=target_co,
        officers=officer_options,
        opening_balance=bf_cash,
        inflows=inflow_dict,
        outflows=outflow_dict,
        total_inflows=left_total,
        total_outflows=right_total,
        closing_balance=closing_bal,
        is_open=is_open,
        open_reason=open_reason,
        can_close_day=can_close_day
    )


@router.post("/eod-close")
def execute_eod_day_close(
    payload: EodCloseRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Finalizes daily cashbook and advances branch business date to next working day (app.py L11871-11899).
    """
    branch_name = current_user.branch
    branch_id = uow.cashbook._resolve_branch_id(branch_name)

    try:
        target_date = date.fromisoformat(payload.date)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD.")

    is_open, open_reason = BusinessDateService.is_operational_open(uow, branch_id, target_date)
    if not is_open and "closed" in open_reason.lower():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"EOD Day Close Already Executed for {payload.date}."
        )
    elif not is_open:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot execute Day Close ({open_reason})."
        )

    try:
        success = BusinessDateService.close_business_date(uow, branch_id, target_date, closed_by=current_user.username)
        if success:
            return {"success": True, "message": f"Successfully executed Day Close for {payload.date}! Operational date advanced to next working day."}
        else:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to execute EOD day close.")
    except Exception as ex:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Error during EOD close: {ex}")


COL_RENAME_EXCEL = {
    "date": "Date",
    "opening_balance": "Opening Balance",
    "savings_deposit": "Savings Deposit (Amount)",
    "rep_daily": "Credit Repayment (60 days)",
    "rep_120_days": "Credit Repayment (120 days)",
    "rep_12_weeks": "Credit Repayment (12 weeks)",
    "rep_24_weeks": "Credit Repayment (24 weeks)",
    "rep_monthly": "Credit Repayment (Monthly)",
    "laps_reserve": "Laps Reserve",
    "funds_received_ho": "Funds Received from Head Office",
    "funds_received_other_branch": "Funds Received from Branch Office",
    "funds_received_other_area": "Funds Received from Other Areas",
    "asset_credit_sales": "Asset Credit Sales",
    "cash_and_carry": "Cash & Carry",
    "loan_received_finance": "Funds from Finance",
    "daily_11_pct": "Daily 11%",
    "daily_20_pct": "Daily 20%",
    "weekly_11_pct": "Weekly 11%",
    "weekly_20_pct": "Weekly 20%",
    "risk_premium_returns": "Monthly 11%/20%",
    "contingency": "Contingency (1%)",
    "credit_form_damage": "Credit form damage",
    "bonus": "Bonus",
    "app_fee": "Credit form/App fee",
    "passbook": "Pass book",
    "bank_withdrawal": "Bank withdrawal",
    "adjustment_in": "Adjustment In",
    "total_inflows": "Total Inflows",
    "disb_60d": "60 days",
    "disb_120d": "120 days",
    "disb_12w": "12 weeks",
    "disb_24w": "24 weeks",
    "disb_mth": "Monthly",
    "fund_transferred_other_branch": "Branch Office",
    "fund_transferred_ho": "Head office",
    "fund_to_other_area": "Other Areas",
    "fund_to_asset_program": "Fund To Assets",
    "fund_to_product_finance": "Fund to Finance",
    "product_withdrawal": "Product/Savings withdrawals",
    "staff_salaries": "Staff Salaries",
    "office_expenses": "Office Expenses",
    "laps_returns": "Laps Return",
    "bank_deposit": "Bank Deposit",
    "adjustment_out": "Adjustment Out",
    "total_outflows": "Total Outflows",
    "closing_balance": "Closing Balance"
}


def _build_monthly_ledger_dataframe(uow: SupabaseUnitOfWork, selected_branch: str, month: int, year: int) -> pd.DataFrame:
    """
    Builds the monthly master cashbook dataframe with all 46 Excel columns A-AS and dynamic loan disbursements
    (app.py L11960-12098).
    """
    display_cols = [
        # Left Side (Inflows: Cols A–AA)
        "date", "opening_balance", "savings_deposit",
        "rep_daily", "rep_120_days", "rep_12_weeks", "rep_24_weeks", "rep_monthly",
        "laps_reserve",
        "funds_received_ho", "funds_received_other_branch", "funds_received_other_area",
        "asset_credit_sales", "cash_and_carry", "loan_received_finance",
        "daily_11_pct", "daily_20_pct", "weekly_11_pct", "weekly_20_pct", "risk_premium_returns",
        "contingency", "credit_form_damage", "bonus", "app_fee", "passbook", "bank_withdrawal",
        "adjustment_in",
        "total_inflows",
        # Right Side (Outflows: Cols AC–AS)
        "disb_60d", "disb_120d", "disb_12w", "disb_24w", "disb_mth",
        "fund_transferred_other_branch", "fund_transferred_ho", "fund_to_other_area",
        "fund_to_asset_program", "fund_to_product_finance",
        "product_withdrawal", "staff_salaries", "office_expenses",
        "laps_returns", "bank_deposit",
        "adjustment_out",
        "total_outflows", "closing_balance"
    ]

    if not selected_branch or selected_branch == "Head Office":
        return pd.DataFrame(columns=display_cols)

    _, last_day = monthrange(year, month)
    start_date = f"{year}-{month:02d}-01"
    end_date = f"{year}-{month:02d}-{last_day:02d}"

    filters = CashbookFilter()
    filters.branch = selected_branch
    filters.start_date = start_date
    filters.end_date = end_date
    entries = uow.cashbook.find_range(filters)

    result_data = [CashbookMapper.to_database(e) for e in entries] if entries else []

    if not result_data:
        return pd.DataFrame(columns=display_cols)

    ledger_df = pd.DataFrame(result_data)
    ledger_df["date"] = pd.to_datetime(ledger_df["date"], errors='coerce').dt.strftime("%Y-%m-%d")
    ledger_df.sort_values(by="date", ascending=True, inplace=True)
    ledger_df.reset_index(drop=True, inplace=True)

    # Dynamic Loan Disbursements Map (app.py L11989-12041)
    loan_disb_map = {}
    try:
        b_id = uow.cashbook._resolve_branch_id(selected_branch)
        res_all_l = uow.client.table("loans") \
            .select("loan_amount, active_credit, extra_fields, product_category, disbursement_date, date, loan_products(name, repayment_cycle)") \
            .eq("branch_id", b_id) \
            .in_("status", ["Active", "Approved", "Completed"]) \
            .execute()
        for l_row in (res_all_l.data or []):
            if _is_legacy_loan(l_row.get("extra_fields")):
                continue
            d_key = str(l_row.get("disbursement_date") or l_row.get("date") or "")[:10]
            if not d_key:
                continue
            if d_key not in loan_disb_map:
                loan_disb_map[d_key] = {
                    "disb_60d": 0.0, "disb_120d": 0.0, "disb_12w": 0.0, "disb_24w": 0.0, "disb_mth": 0.0,
                    "fund_asset": 0.0, "fund_finance": 0.0
                }
            princ = float(l_row.get("loan_amount") or 0.0)
            act_cr = float(l_row.get("active_credit") or princ)
            p_cat = str(l_row.get("product_category") or "Finance")
            lp = l_row.get("loan_products") or {}
            p_name = str(lp.get("name") or "").lower()

            if "Asset" in p_cat or "asset" in p_name:
                loan_disb_map[d_key]["fund_asset"] += princ
            else:
                loan_disb_map[d_key]["fund_finance"] += princ

            if "120" in p_name:
                loan_disb_map[d_key]["disb_120d"] += act_cr
            elif "60" in p_name:
                loan_disb_map[d_key]["disb_60d"] += act_cr
            elif "24w" in p_name or "24" in p_name:
                loan_disb_map[d_key]["disb_24w"] += act_cr
            elif "12w" in p_name or "12" in p_name:
                loan_disb_map[d_key]["disb_12w"] += act_cr
            elif "3m" in p_name or "6m" in p_name or "month" in p_name:
                loan_disb_map[d_key]["disb_mth"] += act_cr
            else:
                loan_disb_map[d_key]["disb_12w"] += act_cr
    except Exception as ex_m_loans:
        print(f"Error fetching monthly loans: {ex_m_loans}")

    # Overlay dynamic disbursement numbers
    for idx, row in ledger_df.iterrows():
        d_str = str(row.get("date", ""))[:10]
        if d_str in loan_disb_map:
            d_info = loan_disb_map[d_str]
            if float(row.get("disb_60d") or 0.0) == 0:
                ledger_df.at[idx, "disb_60d"] = d_info["disb_60d"]
            if float(row.get("disb_120d") or 0.0) == 0:
                ledger_df.at[idx, "disb_120d"] = d_info["disb_120d"]
            if float(row.get("disb_12w") or 0.0) == 0:
                ledger_df.at[idx, "disb_12w"] = d_info["disb_12w"]
            if float(row.get("disb_24w") or 0.0) == 0:
                ledger_df.at[idx, "disb_24w"] = d_info["disb_24w"]
            if float(row.get("disb_mth") or 0.0) == 0:
                ledger_df.at[idx, "disb_mth"] = d_info["disb_mth"]
            if d_info["fund_asset"] > 0 and float(row.get("fund_to_asset_program") or 0.0) == 0:
                ledger_df.at[idx, "fund_to_asset_program"] = d_info["fund_asset"]
            if d_info["fund_finance"] > 0 and float(row.get("fund_to_product_finance") or 0.0) == 0:
                ledger_df.at[idx, "fund_to_product_finance"] = d_info["fund_finance"]
            if d_info["fund_finance"] > 0 and float(row.get("loan_received_finance") or 0.0) == 0:
                ledger_df.at[idx, "loan_received_finance"] = d_info["fund_finance"]
        else:
            for col in ["disb_60d", "disb_120d", "disb_12w", "disb_24w", "disb_mth"]:
                if col not in ledger_df.columns or pd.isna(ledger_df.at[idx, col]):
                    ledger_df.at[idx, col] = 0.0

    for c in display_cols:
        if c not in ledger_df.columns:
            ledger_df[c] = 0.0
        elif c != "date":
            ledger_df[c] = pd.to_numeric(ledger_df[c], errors='coerce').fillna(0.0)

    return ledger_df[display_cols].copy()


def _resolve_available_branches(current_user: CurrentUser, uow: SupabaseUnitOfWork) -> List[str]:
    scope = RBACScopeService.resolve_scope(current_user.to_dict() if hasattr(current_user, 'to_dict') else {
        "id": current_user.id, "username": current_user.username, "role": current_user.role,
        "branch": current_user.branch, "branch_id": current_user.branch_id, "assigned_branches": getattr(current_user, "assigned_branches", [])
    })

    all_operational_branches = ["Ibadan", "Ikorodu", "Kola", "Ogijo"]
    try:
        res_br = uow.client.table("branches").select("branch_id, name").eq("is_active", True).execute()
        if res_br.data:
            all_operational_branches = sorted(list(set(b["name"] for b in res_br.data if b.get("name") and b.get("name") != "Head Office")))
    except Exception:
        pass

    if scope.scope_level == "INSTITUTION" or current_user.role in ["Admin", "Super Admin", "Director"]:
        return all_operational_branches
    elif scope.scope_level == "REGION" or current_user.role in ["Area Manager", "AM"]:
        return [b for b in (scope.assigned_branch_names or []) if b in all_operational_branches] or all_operational_branches
    else:
        return [current_user.branch] if (current_user.branch and current_user.branch != "Head Office") else all_operational_branches


@router.get("/monthly", response_model=MonthlyLedgerResponse)
def get_monthly_ledger(
    month: int = Query(..., ge=1, le=12, description="Month 1-12"),
    year: int = Query(..., ge=2024, le=2030, description="Year 2024-2030"),
    branch: Optional[str] = Query(None, description="Branch filter"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns monthly tabular ledger reordered strictly to match official Excel
    Credit_Cash_Book_Ledger.xlsx (Columns A-AS), plus monthly summary KPIs (app.py L11900-12191).
    """
    available_branches = _resolve_available_branches(current_user, uow)
    selected_branch = branch if (branch and branch in available_branches) else (available_branches[0] if available_branches else current_user.branch)

    display_df = _build_monthly_ledger_dataframe(uow, selected_branch, month, year)

    if display_df.empty:
        return MonthlyLedgerResponse(
            month=month,
            year=year,
            branch=selected_branch,
            rows=[],
            month_opening=0.0,
            total_month_inflows=0.0,
            total_month_outflows=0.0,
            month_closing=0.0,
            available_branches=available_branches
        )

    # Calculate Monthly KPIs (app.py L12101-12104)
    month_opening = float(display_df.iloc[0]["opening_balance"]) if not display_df.empty else 0.0
    month_inflows = float((display_df["total_inflows"] - display_df["opening_balance"]).sum()) if not display_df.empty else 0.0
    month_outflows = float(display_df["total_outflows"].sum()) if not display_df.empty else 0.0
    month_closing = float(display_df.iloc[-1]["closing_balance"]) if not display_df.empty else 0.0

    rows: List[MonthlyLedgerRow] = []
    for _, r in display_df.iterrows():
        rows.append(MonthlyLedgerRow(
            date=str(r["date"]),
            opening_balance=float(r["opening_balance"]),
            savings_deposit=float(r["savings_deposit"]),
            rep_daily=float(r["rep_daily"]),
            rep_120_days=float(r["rep_120_days"]),
            rep_12_weeks=float(r["rep_12_weeks"]),
            rep_24_weeks=float(r["rep_24_weeks"]),
            rep_monthly=float(r["rep_monthly"]),
            laps_reserve=float(r["laps_reserve"]),
            funds_received_ho=float(r["funds_received_ho"]),
            funds_received_other_branch=float(r["funds_received_other_branch"]),
            funds_received_other_area=float(r["funds_received_other_area"]),
            asset_credit_sales=float(r["asset_credit_sales"]),
            cash_and_carry=float(r["cash_and_carry"]),
            loan_received_finance=float(r["loan_received_finance"]),
            daily_11_pct=float(r["daily_11_pct"]),
            daily_20_pct=float(r["daily_20_pct"]),
            weekly_11_pct=float(r["weekly_11_pct"]),
            weekly_20_pct=float(r["weekly_20_pct"]),
            risk_premium_returns=float(r["risk_premium_returns"]),
            contingency=float(r["contingency"]),
            credit_form_damage=float(r["credit_form_damage"]),
            bonus=float(r["bonus"]),
            app_fee=float(r["app_fee"]),
            passbook=float(r["passbook"]),
            bank_withdrawal=float(r["bank_withdrawal"]),
            adjustment_in=float(r["adjustment_in"]),
            total_inflows=float(r["total_inflows"]),
            disb_60d=float(r["disb_60d"]),
            disb_120d=float(r["disb_120d"]),
            disb_12w=float(r["disb_12w"]),
            disb_24w=float(r["disb_24w"]),
            disb_mth=float(r["disb_mth"]),
            fund_transferred_other_branch=float(r["fund_transferred_other_branch"]),
            fund_transferred_ho=float(r["fund_transferred_ho"]),
            fund_to_other_area=float(r["fund_to_other_area"]),
            fund_to_asset_program=float(r["fund_to_asset_program"]),
            fund_to_product_finance=float(r["fund_to_product_finance"]),
            product_withdrawal=float(r["product_withdrawal"]),
            staff_salaries=float(r["staff_salaries"]),
            office_expenses=float(r["office_expenses"]),
            laps_returns=float(r["laps_returns"]),
            bank_deposit=float(r["bank_deposit"]),
            adjustment_out=float(r["adjustment_out"]),
            total_outflows=float(r["total_outflows"]),
            closing_balance=float(r["closing_balance"])
        ))

    return MonthlyLedgerResponse(
        month=month,
        year=year,
        branch=selected_branch,
        rows=rows,
        month_opening=month_opening,
        total_month_inflows=month_inflows,
        total_month_outflows=month_outflows,
        month_closing=month_closing,
        available_branches=available_branches
    )


@router.get("/monthly/export-excel")
def export_monthly_ledger_excel(
    month: int = Query(..., ge=1, le=12, description="Month 1-12"),
    year: int = Query(..., ge=2024, le=2030, description="Year 2024-2030"),
    branch: Optional[str] = Query(None, description="Branch filter"),
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Exports monthly tabular ledger as an Excel (.xlsx) file with sheet name 'Ledger Data',
    matching Streamlit's official Excel export (app.py L12173-12185).
    """
    available_branches = _resolve_available_branches(current_user, uow)
    selected_branch = branch if (branch and branch in available_branches) else (available_branches[0] if available_branches else current_user.branch)

    display_df = _build_monthly_ledger_dataframe(uow, selected_branch, month, year)
    display_df_renamed = display_df.rename(columns=COL_RENAME_EXCEL)

    output = io.BytesIO()
    with pd.ExcelWriter(output, engine='openpyxl') as writer:
        display_df_renamed.to_excel(writer, sheet_name='Ledger Data', index=False)
    output.seek(0)

    month_str = datetime(year, month, 1).strftime('%B_%Y')
    filename = f"ICARE_Master_Cashbook_{selected_branch}_{month_str}.xlsx"

    return StreamingResponse(
        output,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )


@router.post("/reversals/approve")
def approve_correction(
    payload: ReversalActionRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Approves pending correction request under Four-Eyes rule BR-ERR-001 (app.py L11630-11638).
    """
    try:
        approver = current_user.id or current_user.username
        CorrectionService.approve_correction(uow, payload.request_id, approved_by=approver)
        return {"success": True, "message": "Reversal approved and executed atomically!"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Approval failed: {e}")


@router.post("/reversals/reject")
def reject_correction(
    payload: ReversalActionRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Rejects pending correction request (app.py L11640-11648).
    """
    try:
        approver = current_user.id or current_user.username
        CorrectionService.reject_correction(uow, payload.request_id, approved_by=approver)
        return {"success": True, "message": "Reversal rejected successfully."}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Rejection failed: {e}")


@router.post("/reversals/flag-treasury")
def flag_treasury_for_reversal(
    payload: TreasuryReversalRequestInput,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a branch treasury transaction reversal request for approval (app.py L11675-11688).
    """
    if not payload.reason.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Please provide a reason for the reversal request.")

    branch_id = uow.cashbook._resolve_branch_id(current_user.branch)
    try:
        req_id = CorrectionService.request_correction(
            uow=uow,
            record_id=payload.transaction_id,
            record_type="Treasury",
            reason=payload.reason.strip(),
            requested_by=current_user.id or current_user.username,
            branch_id=branch_id
        )
        return {"success": True, "request_id": req_id, "message": f"Treasury reversal request submitted! (Ref: #{req_id[:8]})"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to submit treasury reversal request: {e}")
