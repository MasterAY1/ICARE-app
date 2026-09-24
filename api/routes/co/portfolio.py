"""
CO Portfolio & 360° Client Dossier Route Adapter.
Authoritative endpoints for hierarchical portfolio analytics and client drilldown (app.py L12192–13178).
"""
import calendar
from typing import Optional, Dict, Any, List
from datetime import date, datetime, timedelta
import pandas as pd
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, get_current_scope, CurrentUser
from api.schemas.portfolio import (
    PortfolioOverviewResponse,
    ClientDossierResponse,
    ChangeClientStatusRequest,
    DossierReversalRequest,
    FilterOptions,
    PortfolioMetrics,
    GroupPortfolioItem,
    ClientPortfolioItem
)
from services.rbac_scope_service import RBACScope, RBACScopeService
from services.portfolio_service import PortfolioService
from services.client_status_service import ClientStatusService
from services.correction_service import CorrectionService

router = APIRouter(prefix="/api/v1/co/portfolio", tags=["CO Portfolio"])


@router.get("", response_model=PortfolioOverviewResponse)
@router.get("/", response_model=PortfolioOverviewResponse)
def get_portfolio_overview(
    branch: Optional[str] = Query(None, description="Branch filter"),
    officer: Optional[str] = Query(None, description="Credit officer filter"),
    group: Optional[str] = Query(None, description="Solidarity group filter"),
    product: Optional[str] = Query(None, description="Loan product filter"),
    time_period: Optional[str] = Query("Current Month", description="Time period preset"),
    start_date_param: Optional[str] = Query(None, alias="start_date"),
    end_date_param: Optional[str] = Query(None, alias="end_date"),
    current_user: CurrentUser = Depends(get_current_user),
    scope: RBACScope = Depends(get_current_scope),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns role-scoped portfolio intelligence, category breakdown, group matrix,
    client list, group summary, and filter options (1:1 with app.py L12192–12716).
    """
    today = date.today()
    start_date = today
    end_date = today

    period = time_period or "Current Month"
    if period == "Today":
        start_date = today
        end_date = today
    elif period == "Yesterday":
        yesterday = today - timedelta(days=1)
        start_date = yesterday
        end_date = yesterday
    elif period == "Current Month":
        start_date = today.replace(day=1)
        _, last_day = calendar.monthrange(today.year, today.month)
        end_date = today.replace(day=last_day)
    elif period == "Last Month":
        first = today.replace(day=1)
        last_month = first - timedelta(days=1)
        start_date = last_month.replace(day=1)
        end_date = last_month
    elif period == "Custom Date Range":
        if start_date_param:
            try: start_date = date.fromisoformat(start_date_param)
            except ValueError: pass
        if end_date_param:
            try: end_date = date.fromisoformat(end_date_param)
            except ValueError: pass

    # Resolve Scope & Filters
    sel_branch = branch if branch and branch != "All" else None
    sel_officer = officer if officer and officer != "All" else None
    sel_group = group if group and group != "All" else None
    sel_product = product if product and product != "All" else None

    # Load Scoped Data via authoritative PortfolioService
    p_data = PortfolioService.get_portfolio_data_for_scope(
        uow=uow,
        scope=scope,
        selected_branch=sel_branch,
        selected_officer=sel_officer,
        selected_group=sel_group,
        selected_product=sel_product,
        start_date=start_date,
        end_date=end_date
    )

    p_sum = p_data.get("summary", {})
    cat_sum = p_data.get("category_summary", {})
    
    # Convert DataFrames to clean records
    def _df_to_records(df):
        if isinstance(df, pd.DataFrame):
            if df.empty: return []
            return df.fillna("").to_dict(orient="records")
        if isinstance(df, list): return df
        return []

    group_matrix_records = _df_to_records(p_data.get("group_matrix"))
    client_table_records = _df_to_records(p_data.get("client_table"))
    group_table_records = _df_to_records(p_data.get("group_table"))
    payoff_excess_records = _df_to_records(p_data.get("payoff_excess_table"))
    client_codes = p_data.get("client_codes", [])
    client_lookup = p_data.get("client_lookup", {})

    # Extract Filter Options matching Streamlit L12235–12433
    available_branches = ["All"]
    available_officers = [{"label": "All", "username": "All", "id": ""}]
    allowed_products = ["All"]
    available_groups = ["All"]

    try:
        # Branches
        res_b = uow.client.table("branches").select("name").execute()
        b_names = sorted(list(set(b["name"] for b in (res_b.data or []) if b.get("name"))))
        available_branches += b_names
    except Exception:
        pass

    try:
        # Officers
        q_off = uow.client.table("user_roles") \
            .select("user_id, roles!inner(name), app_users!inner(id, username, full_name, is_active, branch_id)") \
            .eq("roles.name", "Credit Officer") \
            .eq("app_users.is_active", True)
        if scope.scope_level == "BRANCH" and scope.branch_id:
            q_off = q_off.eq("app_users.branch_id", scope.branch_id)
        elif scope.scope_level == "OFFICER" and scope.branch_id:
            q_off = q_off.eq("app_users.branch_id", scope.branch_id)
        res_off = q_off.execute()
        for r in (res_off.data or []):
            o = r.get("app_users") or {}
            u_name = o.get("username")
            f_name = o.get("full_name")
            u_id = o.get("id")
            if u_name:
                lbl = f"{u_name} — {f_name}" if f_name else u_name
                available_officers.append({"label": lbl, "username": u_name, "id": str(u_id or "")})
    except Exception:
        pass

    try:
        # Products
        p_res = uow.client.table("loan_products").select("name").execute()
        prods = sorted(list(set(p["name"] for p in (p_res.data or []) if p.get("name"))))
        allowed_products += prods
    except Exception:
        pass

    try:
        # Groups
        g_q = uow.client.table("groups").select("group_id, name, group_number, meeting_day, officer_id, branch_id")
        if scope.scope_level == "OFFICER" and scope.user_id:
            g_q = g_q.eq("officer_id", scope.user_id)
        elif scope.scope_level == "BRANCH" and scope.branch_id:
            g_q = g_q.eq("branch_id", scope.branch_id)
        g_res = g_q.execute()
        g_list = g_res.data or []
        for g in g_list:
            gn = g.get("name")
            if gn and gn not in available_groups:
                available_groups.append(gn)
    except Exception:
        pass

    # Build backward-compatible items
    group_items = []
    for g in group_table_records:
        group_items.append(GroupPortfolioItem(
            group_name=str(g.get("Group Name") or "Ungrouped"),
            total_clients=int(g.get("Total Clients") or 0),
            total_savings_balance=float(g.get("Total Savings Balance") or 0.0),
            total_active_loan=float(g.get("Total Active Loan") or 0.0),
            total_outstanding_balance=float(g.get("Total Outstanding Balance") or 0.0),
            total_fixed_repayment=float(g.get("Total Fixed Repayment") or 0.0),
            total_paid=float(g.get("Total Paid") or 0.0)
        ))

    client_items = []
    for c in client_table_records:
        client_items.append(ClientPortfolioItem(
            client_id=str(c.get("Client ID") or ""),
            client_code=str(c.get("Client Code") or ""),
            client_name=str(c.get("Client Name") or "Unknown"),
            group_name=str(c.get("Group") or "Ungrouped"),
            savings_balance=float(c.get("Savings Balance") or 0.0),
            active_loan=float(c.get("Active Loan") or 0.0),
            outstanding_balance=float(c.get("Outstanding Balance") or 0.0),
            status=str(c.get("Status") or "Active")
        ))

    return PortfolioOverviewResponse(
        summary=p_sum,
        category_summary=cat_sum,
        group_matrix=group_matrix_records,
        client_table=client_table_records,
        group_table=group_table_records,
        payoff_excess_table=payoff_excess_records,
        client_codes=client_codes,
        client_lookup=client_lookup,
        filter_options=FilterOptions(
            available_branches=available_branches,
            available_officers=available_officers,
            allowed_products=allowed_products,
            available_groups=available_groups,
            time_periods=["Today", "Yesterday", "Current Month", "Last Month", "Custom Date Range"]
        ),
        metrics=PortfolioMetrics(
            total_clients=int(p_sum.get("total_clients") or 0),
            total_active_credit=float(p_sum.get("total_active_credit") or 0.0),
            total_outstanding=float(p_sum.get("total_outstanding_balance") or 0.0),
            total_fixed_repayment=float(p_sum.get("total_expected_repayment") or 0.0),
            total_paid=float(p_sum.get("total_savings_deposit") or 0.0),
            collection_rate=0.0,
            par_30_amount=float(p_sum.get("overdue", {}).get("amount") or 0.0),
            par_30_count=int(p_sum.get("overdue", {}).get("count") or 0)
        ),
        groups=group_items,
        clients=client_items
    )


@router.get("/dossier", response_model=ClientDossierResponse)
def get_client_dossier(
    client_code: str = Query(..., description="Client code to inspect"),
    scope: RBACScope = Depends(get_current_scope),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns 360° authorized client dossier drilldown across 7 dimensions (app.py L12717–13178):
    Customer profile, Guarantor, Loan history, Repayment ledger, Savings ledger with running balance,
    Collection compliance history, Lifecycle status with manual transition history, and Audit log.
    """
    dd = PortfolioService.get_client_360_drilldown(uow=uow, client_id=client_code, scope=scope)
    c_info = dd.get("customer_info", {})
    if not c_info:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Client '{client_code}' not found.")

    cur_cid = c_info.get("client_id") or c_info.get("id") or client_code
    l_hist = dd.get("loan_history", pd.DataFrame())
    r_hist = dd.get("repayment_history", pd.DataFrame())
    s_hist = dd.get("savings_history", pd.DataFrame())
    c_perf = dd.get("collection_history", pd.DataFrame())
    a_hist = dd.get("audit_history", pd.DataFrame())

    # 1. Executive Banner Metrics (Streamlit L12739–12776)
    c_active_credit = 0.0
    c_remaining_balance = 0.0
    c_total_paid = 0.0
    if isinstance(l_hist, pd.DataFrame) and not l_hist.empty:
        for _, l_row in l_hist.iterrows():
            if str(l_row.get("status", "")).upper() in ["ACTIVE", "APPROVED"]:
                a_cred = float(l_row.get("active_credit") or 0.0)
                t_due = float(l_row.get("total_due") if l_row.get("total_due") is not None else a_cred)
                c_active_credit += a_cred
                lid = str(l_row.get("loan_id", ""))
                p_paid = 0.0
                if isinstance(r_hist, pd.DataFrame) and not r_hist.empty and "loan_id" in r_hist.columns:
                    p_paid = float(r_hist[r_hist["loan_id"].astype(str) == lid]["amount_paid"].sum())
                elif isinstance(r_hist, pd.DataFrame) and not r_hist.empty and "amount_paid" in r_hist.columns:
                    p_paid = float(r_hist["amount_paid"].sum())
                rem = max(0.0, t_due - p_paid)
                c_remaining_balance += rem
                c_total_paid += ((a_cred - t_due) + p_paid)

    c_savings_balance = 0.0
    if isinstance(s_hist, pd.DataFrame) and not s_hist.empty:
        dep_tot = float(s_hist.get("deposit_amount", pd.Series([0.0])).sum())
        wth_tot = float(s_hist.get("withdrawal_amount", pd.Series([0.0])).sum())
        c_savings_balance = dep_tot - wth_tot

    c_status_label = "Active Loan" if c_remaining_balance > 0 else ("Fully Settled" if (isinstance(l_hist, pd.DataFrame) and not l_hist.empty) else "No Active Loans")

    # 2. Guarantor Info (Streamlit L12782–12862)
    g_name = "N/A"
    g_phone = "N/A"
    g_rel = "N/A"
    g_pic = ""
    if isinstance(l_hist, pd.DataFrame) and not l_hist.empty:
        for _, l_row in l_hist.iterrows():
            ext = l_row.get("extra_fields") or {}
            if isinstance(ext, str):
                import json
                try: ext = json.loads(ext)
                except: ext = {}
            if ext.get("guarantor_name"):
                g_name = ext.get("guarantor_name", "N/A")
                g_phone = ext.get("guarantor_phone", "N/A")
                g_rel = ext.get("guarantor_relationship", "Guarantor")
                g_pic = l_row.get("guarantor_passport_url", "")
                break

    # 3. Formatted Loan History (Streamlit L12864–12906)
    loan_history_rows = []
    if isinstance(l_hist, pd.DataFrame) and not l_hist.empty:
        paid_map = {}
        if isinstance(r_hist, pd.DataFrame) and not r_hist.empty and "loan_id" in r_hist.columns:
            paid_map = r_hist.groupby("loan_id")["amount_paid"].sum().to_dict()

        for _, row in l_hist.iterrows():
            lid = str(row.get("loan_id", ""))
            a_cred = float(row.get("active_credit") or 0.0)
            t_due = float(row.get("total_due") if row.get("total_due") is not None else a_cred)
            p_paid = float(paid_map.get(row.get("loan_id"), 0.0))
            rem_bal = max(0.0, t_due - p_paid)
            prod = row.get("loan_products", {}).get("name", "Standard") if isinstance(row.get("loan_products"), dict) else "Standard"

            loan_history_rows.append({
                "loan_id": lid,
                "disbursement_date": str(row.get("date") or row.get("disbursement_date") or "")[:10],
                "product": prod,
                "category": str(row.get("product_category") or "Standard"),
                "loan_principal": float(row.get("loan_amount") or 0.0),
                "active_credit": a_cred,
                "expected_installment": float(row.get("loan_repay") or 0.0),
                "remaining_balance": rem_bal,
                "status": str(row.get("status") or "Active")
            })

    # 4. Formatted Repayment Ledger (Streamlit L12908–12962)
    repayment_rows = []
    if isinstance(r_hist, pd.DataFrame) and not r_hist.empty:
        for _, row in r_hist.iterrows():
            repayment_rows.append({
                "id": str(row.get("id") or ""),
                "date": str(row.get("date") or "")[:10],
                "amount_collected": float(row.get("amount_paid") or 0.0),
                "status": str(row.get("payment_status") or "PAID"),
                "transaction_type": str(row.get("transaction_type") or "Repayment"),
                "notes": str(row.get("note") or "")
            })

    # 5. Formatted Savings Ledger with Running Balance (Streamlit L12964–12989)
    savings_rows = []
    if isinstance(s_hist, pd.DataFrame) and not s_hist.empty:
        running_bal = 0.0
        for _, row in s_hist.iterrows():
            dep = float(row.get("deposit_amount") or 0.0)
            wth = float(row.get("withdrawal_amount") or 0.0)
            running_bal += (dep - wth)
            savings_rows.append({
                "id": str(row.get("id") or ""),
                "date": str(row.get("posting_date") or "")[:10],
                "deposit": dep,
                "withdrawal": wth,
                "net_balance": running_bal,
                "remarks": str(row.get("remarks") or "")
            })

    # 6. Meeting Collection History & Compliance (Streamlit L12991–13081)
    coll_metrics = {"total_expected": 0.0, "total_collected": 0.0, "variance": 0.0, "compliance_rate": 0.0}
    coll_rows = []
    if isinstance(c_perf, pd.DataFrame) and not c_perf.empty:
        exp_col = "expected_amount" if "expected_amount" in c_perf.columns else ("Expected" if "Expected" in c_perf.columns else None)
        paid_col = "amount_paid" if "amount_paid" in c_perf.columns else ("collected_amount" if "collected_amount" in c_perf.columns else ("Paid" if "Paid" in c_perf.columns else None))

        tot_exp = float(pd.to_numeric(c_perf[exp_col], errors='coerce').sum()) if exp_col else 0.0
        tot_paid = float(pd.to_numeric(c_perf[paid_col], errors='coerce').sum()) if paid_col else 0.0
        tot_var = max(0.0, tot_exp - tot_paid)
        comp_pct = (tot_paid / tot_exp * 100.0) if tot_exp > 0 else (100.0 if tot_paid > 0 else 0.0)

        coll_metrics = {
            "total_expected": tot_exp,
            "total_collected": tot_paid,
            "variance": tot_var,
            "compliance_rate": round(comp_pct, 1)
        }

        for _, row in c_perf.iterrows():
            exp_val = float(row.get("expected_amount") or row.get("Expected") or 0.0)
            paid_val = float(row.get("amount_paid") or row.get("collected_amount") or row.get("Paid") or 0.0)
            raw_st = str(row.get("status") or row.get("collection_status") or "").upper()
            st_badge = "PAID" if (raw_st in ["PAID", "COMPLETE"] or (exp_val > 0 and paid_val >= exp_val)) else ("PART PAYMENT" if (raw_st in ["PART_PAYMENT", "PARTIAL"] or (paid_val > 0 and paid_val < exp_val)) else "NOT PAID")
            
            coll_rows.append({
                "meeting_date": str(row.get("meeting_date") or row.get("date") or "")[:10],
                "expected": exp_val,
                "collected": paid_val,
                "variance": max(0.0, exp_val - paid_val),
                "compliance_status": st_badge,
                "remarks": str(row.get("remarks") or row.get("note") or "Meeting collection")
            })

    # 7. Lifecycle Status & Audit History (Streamlit L13083–13176)
    curr_status_res = uow.client.table("clients").select("status_id, status_changed_at, status_note, client_statuses(name, color_code, icon)").eq("client_id", cur_cid).execute()
    curr_rec = curr_status_res.data[0] if curr_status_res.data else {}
    cs_dict = curr_rec.get("client_statuses") or {}

    history_records = ClientStatusService.get_client_history(uow, str(cur_cid))
    h_rows = []
    for h in (history_records or []):
        h_rows.append({
            "date_time": str(h.get("changed_at", ""))[:19].replace("T", " "),
            "previous_status": h.get("old_status_name") or (h.get("old_status") or {}).get("name", "Initial"),
            "new_status": h.get("new_status_name") or (h.get("new_status") or {}).get("name", "N/A"),
            "trigger": h.get("trigger_type", "MANUAL"),
            "reason": h.get("reason", "N/A"),
            "changed_by": (h.get("changer") or {}).get("full_name") or "System / Officer"
        })

    audit_records = []
    if isinstance(a_hist, pd.DataFrame) and not a_hist.empty:
        audit_records = a_hist.fillna("").to_dict(orient="records")

    return ClientDossierResponse(
        client_code=client_code,
        customer_info={
            "client_id": str(cur_cid),
            "client_code": str(c_info.get("client_code") or client_code),
            "name": str(c_info.get("name") or "Unknown"),
            "nickname": c_info.get("nickname") or "",
            "group_name": c_info.get("groups", {}).get("name", "Individual") if isinstance(c_info.get("groups"), dict) else (c_info.get("group_name") or "Individual"),
            "phone": str(c_info.get("phone") or "N/A"),
            "address": str(c_info.get("address") or "N/A"),
            "registration_date": str(c_info.get("registration_date") or "N/A")[:10],
            "passport_url": c_info.get("passport_url") or ""
        },
        guarantor_info={
            "name": g_name,
            "relationship": g_rel,
            "phone": g_phone,
            "passport_url": g_pic,
            "is_verified": bool(g_name != "N/A")
        },
        executive_banner={
            "total_active_credit": c_active_credit,
            "outstanding_balance": c_remaining_balance,
            "savings_balance": c_savings_balance,
            "account_status": c_status_label
        },
        loan_history=loan_history_rows,
        repayment_ledger=repayment_rows,
        savings_ledger=savings_rows,
        collection_compliance={
            "metrics": coll_metrics,
            "rows": coll_rows
        },
        lifecycle_status={
            "current_status": cs_dict.get("name", "Registered"),
            "color_code": cs_dict.get("color_code", "#9CA3AF"),
            "last_changed": str(curr_rec.get("status_changed_at") or "Initial Onboarding")[:19],
            "status_note": curr_rec.get("status_note") or "None",
            "history": h_rows
        },
        audit_history=audit_records
    )


@router.post("/status-change")
def update_client_lifecycle_status(
    req: ChangeClientStatusRequest,
    current_user: CurrentUser = Depends(get_current_user),
    scope: RBACScope = Depends(get_current_scope),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Manual Client Lifecycle Status Transition (Streamlit L13108–13151).
    Validates reason and logs immutable audit trail.
    """
    if not req.reason.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Reason for status change is required.")

    success = ClientStatusService.transition_status(
        uow=uow,
        client_id=req.client_id,
        new_status_name=req.target_status,
        changed_by=current_user.id,
        reason=req.reason.strip(),
        trigger_type="MANUAL"
    )

    if not success:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to transition status.")

    return {"status": "success", "message": f"Client lifecycle status transitioned to {req.target_status}."}


@router.post("/reversal-request")
def submit_dossier_reversal_request(
    req: DossierReversalRequest,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a repayment correction/reversal request directly from Client Dossier (Streamlit L12927–12961).
    """
    if not req.reason.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Reason for reversal is required.")

    req_id = CorrectionService.request_correction(
        uow=uow,
        record_id=req.record_id,
        record_type="Repayment",
        reason=req.reason.strip(),
        requested_by=current_user.username,
        branch_id=current_user.branch_id
    )

    return {"status": "success", "request_id": req_id, "message": f"Reversal request #{req_id[:8]} submitted to Branch Manager."}
