"""
CO Collections route adapter.
Reuses RepaymentService and BusinessDateService directly against Supabase schema.
"""
from typing import Optional, List
from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.collections import CollectionSheetResponse, CollectionSheetMember
from api.schemas.corrections import ReversalRequestInput, ReversalRequestResponse
from api.schemas.financial_writes import BatchCollectionInput, BatchCollectionResponse
from models.user import CurrentUser
from services.business_date_service import BusinessDateService

router = APIRouter(prefix="/api/v1/co/collections", tags=["CO Collections"])


@router.get("/sheet", response_model=CollectionSheetResponse)
def get_collection_sheet(
    group_name: Optional[str] = Query(None, description="Solidarity group name"),
    date_str: Optional[str] = Query(None, alias="date", description="Collection Date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live collection sheet for the requested group and officer.
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

    meeting_day = target_date.strftime("%A")
    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, target_date)

    # 1. Resolve officer ID and fetch active clients
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    
    # Query clients matching exact Streamlit logic (app.py L4250-4290)
    query = uow.client.table("clients").select(
        "client_id, client_code, name, status, status_id, group_id, groups(name), client_memberships(groups(name)), client_statuses(name)"
    ).eq("officer_id", officer_id)

    res_c = query.execute()
    clients_data = res_c.data or []

    # Filter by group_name if specified
    filtered_clients = []
    for c in clients_data:
        c_stat = (c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")
        if c_stat in ["Closed", "Suspended"]:
            continue

        g_name = (c.get("groups") or {}).get("name") if isinstance(c.get("groups"), dict) else None
        if not g_name:
            m_list = c.get("client_memberships") or []
            if isinstance(m_list, list):
                for m in m_list:
                    if m.get("groups") and m["groups"].get("name"):
                        g_name = m["groups"]["name"]
                        break
            elif isinstance(m_list, dict):
                if m_list.get("groups") and m_list["groups"].get("name"):
                    g_name = m_list["groups"]["name"]

        if not g_name:
            g_name = "Ungrouped"

        if group_name and group_name != "All" and g_name != group_name:
            continue

        filtered_clients.append({
            "client_id": c["client_id"],
            "client_code": c.get("client_code") or c["client_id"][:8],
            "name": c["name"],
            "group_name": g_name
        })

    # 2. Fetch active loans and savings for these clients
    members: List[CollectionSheetMember] = []
    client_ids = [c["client_id"] for c in filtered_clients]

    if client_ids:
        res_l = uow.client.table("loans").select(
            "loan_id, client_id, loan_amount, active_credit, total_due, product_category, duration, loan_products(name, repayment_cycle)"
        ).in_("client_id", client_ids).in_("status", ["Active", "Approved", "ACTIVE"]).execute()
        loans = res_l.data or []
        loans_by_client = {l["client_id"]: l for l in loans}

        # Lifetime repayments
        loan_ids = [l["loan_id"] for l in loans]
        reps_by_loan = {}
        if loan_ids:
            res_rep = uow.client.table("repayments").select("loan_id, amount_paid").in_("loan_id", loan_ids).execute()
            for r in (res_rep.data or []):
                lid = r["loan_id"]
                reps_by_loan[lid] = reps_by_loan.get(lid, 0.0) + float(r.get("amount_paid") or 0.0)

        # Build member roster
        for c in filtered_clients:
            cid = c["client_id"]
            l_info = loans_by_client.get(cid)
            
            act_cred = 0.0
            rem_bal = 0.0
            exp_repay = 0.0
            prod_name = "None"
            is_asset = False

            if l_info:
                act_cred = float(l_info.get("active_credit") or l_info.get("loan_amount") or 0.0)
                tot_due = float(l_info.get("total_due") if l_info.get("total_due") is not None else act_cred)
                tot_paid = reps_by_loan.get(l_info["loan_id"], 0.0)
                rem_bal = max(0.0, tot_due - tot_paid)
                
                lp = l_info.get("loan_products") or {}
                prod_name = str(lp.get("name") or "Standard Loan")
                is_asset = (l_info.get("product_category") == "Asset" or "asset" in prod_name.lower())
                
                dur = int(l_info.get("duration") or 60)
                if dur > 0 and act_cred > 0:
                    exp_repay = round(act_cred / dur, 2)

            sav_bal = uow.individual_savings.get_total_balance(client_id=cid)

            members.append(CollectionSheetMember(
                client_id=cid,
                client_code=c["client_code"],
                client_name=c["name"],
                loan_product=prod_name,
                active_credit=act_cred,
                remaining_balance=rem_bal,
                expected_repayment=exp_repay,
                savings_balance=sav_bal,
                is_asset=is_asset
            ))

    return CollectionSheetResponse(
        group_name=group_name or "All Groups",
        date=target_date.isoformat(),
        meeting_day=meeting_day,
        is_open=is_open,
        open_reason=open_reason,
        members=members
    )


@router.post("/reversal-request", response_model=ReversalRequestResponse)
def request_repayment_reversal(
    payload: ReversalRequestInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a repayment reversal request for BM approval under Four-Eyes rule BR-ERR-001 (app.py L5062-5157).
    """
    from services.correction_service import CorrectionService

    req_id = CorrectionService.request_correction(
        uow=uow,
        record_id=payload.record_id,
        record_type=payload.record_type or "Repayment",
        reason=payload.reason,
        requested_by=current_user.username,
        branch_id=current_user.branch_id
    )

    return ReversalRequestResponse(
        success=True,
        request_id=req_id,
        status="Pending",
        message="Repayment reversal request submitted to Branch Manager for approval."
    )


@router.post("/batch-submit", response_model=BatchCollectionResponse)
def submit_batch_collections(
    payload: BatchCollectionInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Atomically posts bulk loan repayments and savings collections directly to Account 1000 and rebuilds cashbook (app.py L4800-4939 & save_repayments).
    """
    from services.posting_engine import FinancialPostingEngine

    # 1. Date resolution & Business Date validation
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
            detail=f"Cannot submit new collections today ({open_reason})."
        )

    date_str = target_date.isoformat()
    to_insert = []

    tot_rep = 0.0
    tot_sav = 0.0
    tot_cash_in = 0.0

    # 2. Format per-client transactions
    for item in payload.collections:
        sav = float(item.savings_deposit_amount or 0)
        sav_wd = float(item.savings_withdrawal_amount or 0)
        rep = float(item.loan_repayment_amount or 0)
        app = float(item.app_fee or 0)
        pb = float(item.passbook_bonus or 0)
        misc = float(item.misc_fees or 0)
        asset_cr = float(item.asset_credit_sales or 0)
        cc = float(item.cash_and_carry or 0)
        cfd = float(item.credit_form_damage or 0)
        bon = float(item.bonus or 0)
        exp_amt = float(item.expected_amount or 0)
        is_marked_not_paid = bool(item.mark_not_paid)

        if is_marked_not_paid or rep == 0.0:
            rep = 0.0
            p_status = "NOT_PAID"
            overdue_val = exp_amt
        elif exp_amt > 0 and rep == exp_amt:
            p_status = "PAID"
            overdue_val = 0.0
        elif exp_amt > 0 and rep > exp_amt:
            p_status = "EXCESS"
            overdue_val = 0.0
        elif exp_amt > 0 and rep < exp_amt and rep > 0:
            p_status = "PART_PAID"
            overdue_val = max(0.0, exp_amt - rep)
        else:
            p_status = "PAID"
            overdue_val = 0.0

        if sav == 0 and sav_wd == 0 and rep == 0 and app == 0 and pb == 0 and misc == 0 and asset_cr == 0 and cc == 0 and cfd == 0 and bon == 0:
            if p_status != "NOT_PAID":
                continue

        prod_low = str(item.loan_product or "60 day").lower()
        rep_12w = rep_24w = rep_60d = rep_120d = rep_mth = 0
        if "12 week" in prod_low or "12w" in prod_low: rep_12w = rep
        elif "24 week" in prod_low or "24w" in prod_low: rep_24w = rep
        elif "60 day" in prod_low or ("daily" in prod_low and "120" not in prod_low) or "60-day" in prod_low: rep_60d = rep
        elif "120 day" in prod_low or "120-day" in prod_low: rep_120d = rep
        elif "month" in prod_low: rep_mth = rep
        else: rep_60d = rep

        tot_rep += rep
        tot_sav += sav
        tot_cash_in += (rep + sav + app + pb + misc + asset_cr + cc + cfd + bon)

        to_insert.append({
            "Date": date_str,
            "Client ID": item.client_id,
            "Client Name": item.client_name,
            "Officer": current_user.username,
            "Branch": current_user.branch,
            "Amount Paid": rep,
            "Transaction Type": "Loan",
            "Note": f"Daily Collection - {payload.group_name}",
            "Savings Amount": sav,
            "Withdrawal Amount": sav_wd,
            "Loan Repayment Amount": rep,
            "Repayment 12 Weeks": rep_12w,
            "Repayment 24 Weeks": rep_24w,
            "Repayment 60 Days": rep_60d,
            "Repayment 120 Days": rep_120d,
            "Monthly": rep_mth,
            "App Fee": app,
            "Pass Book Bonus": pb,
            "Misc Fees": misc,
            "Asset Credit Sales": asset_cr,
            "Cash and Carry": cc,
            "Credit Form Damage": cfd,
            "Bonus": bon,
            "Payment Status": p_status,
            "Expected Amount": exp_amt,
            "Overdue Amount": overdue_val
        })

    # 3. Add Group Savings if provided
    g_dep = float(payload.group_savings_deposit or 0)
    g_wd = float(payload.group_savings_withdrawal or 0)
    if g_dep > 0 or g_wd > 0:
        tot_sav += g_dep
        tot_cash_in += g_dep
        to_insert.append({
            "Date": date_str,
            "Client ID": f"GROUP-{payload.group_name}",
            "Client Name": f"{payload.group_name} Meeting",
            "Officer": current_user.username,
            "Branch": current_user.branch,
            "Amount Paid": g_dep,
            "Transaction Type": "Group Meeting",
            "Note": f"Group Savings for {payload.group_name}",
            "Savings Amount": g_dep,
            "Withdrawal Amount": g_wd,
            "Group Savings Deposit": g_dep,
            "Group Savings Withdrawal": g_wd,
            "Loan Repayment Amount": 0
        })

    if not to_insert:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No collection entries provided.")

    # 4. Atomic Execution via save_repayments engine
    original_defer = getattr(FinancialPostingEngine, 'defer_projections', False)
    FinancialPostingEngine.defer_projections = True

    try:
        from app import save_repayment
        for data in to_insert:
            save_repayment(data, override_uow=uow)

        # Rebuild Cashbook Projection
        branch_id = uow.cashbook._resolve_branch_id(current_user.branch)
        officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
        if branch_id:
            uow.cashbook.rebuild_projection(branch_id, target_date, officer_id=officer_id)
    finally:
        FinancialPostingEngine.defer_projections = original_defer

    return BatchCollectionResponse(
        success=True,
        total_cash_in=tot_cash_in,
        total_repayments=tot_rep,
        total_savings=tot_sav,
        items_processed=len(to_insert),
        message=f"Successfully posted {len(to_insert)} collection entries for {payload.group_name}! (Total Cash In: ₦{tot_cash_in:,.2f})"
    )


