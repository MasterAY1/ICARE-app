"""
Reports & Export API Route Adapter.
Full 1:1 Streamlit parity with app.py L13222–13861.
Provides Trial Balance, Savings Summary, Repayment Summary, Portfolio Health & Officer Breakdown,
Area Manager Branch Comparison, and direct in-memory Excel/CSV downloads.
"""
from typing import Optional, List, Dict, Any, Union
from datetime import date, datetime
import io
import csv
import pandas as pd
from fastapi import APIRouter, Depends, Query, HTTPException, status
from fastapi.responses import StreamingResponse

from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, CurrentUser
from domain.queries import LoanFilter, RepaymentFilter
from services.report_service import ReportService
from services.client_risk_rating_service import ClientRiskRatingService
from services.rbac_scope_service import RBACScopeService
from utils.reports import (
    generate_portfolio_summary,
    generate_officer_report,
    export_dataframe_to_excel_bytes,
    export_consolidated_report_to_excel,
)
from api.schemas.reports import (
    BranchOption,
    OfficerOption,
    ReportsMetaResponse,
    TrialBalanceRow,
    TrialBalanceResponse,
    SaverRow,
    SavingsSummaryResponse,
    ProductCollectionRow,
    RepaymentLogRow,
    RepaymentSummaryResponse,
    OfficerPerformanceRow,
    PortfolioPerformanceResponse,
    AreaBranchRow,
    AreaComparisonResponse,
)

router = APIRouter(prefix="/api/v1/reports", tags=["Reports & Export"])

# UI-to-DB Column Mappings matching app.py
DB_TO_UI_LOANS = {
    "client_id": "Client ID", "client_code": "Client Code", "date": "Date", "branch": "Branch", "officer": "Officer",
    "client_name": "Client Name", "phone": "Phone", "address": "Address", "business_type": "Business Type",
    "group_name": "Group Name", "meeting_day": "Meeting Day", "loan_product": "Loan Product",
    "loan_amount": "Loan Amount", "active_credit": "Active Credit", "loan_repay": "Loan Repay",
    "total_due": "Total Due", "status": "Status", "id": "id"
}

DB_TO_UI_REP = {
    "date": "Date", "branch": "Branch", "client_id": "Client ID", "client_code": "Client Code",
    "client_name": "Client Name", "amount_paid": "Amount Paid", "officer": "Officer",
    "note": "Note", "transaction_type": "Transaction Type", "loan_id": "loan_id"
}


def _check_reports_permission(current_user: CurrentUser):
    role = (current_user.role or "").strip().lower()
    if role in ["co", "credit officer", "officer"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access Denied: You do not have permission to access Reports & Export."
        )


def _load_loans_df(uow: SupabaseUnitOfWork) -> pd.DataFrame:
    try:
        loans = uow.loans.find_all()
        if not loans:
            return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))
        from mappers.base_mappers import LoanMapper
        df = pd.DataFrame([LoanMapper.to_database(L) for L in loans]).rename(columns=DB_TO_UI_LOANS)
        if not df.empty and 'Date' in df.columns:
            df['Date'] = pd.to_datetime(df['Date'], errors='coerce').dt.strftime('%Y-%m-%d')

        res_c = uow.client.table("clients").select(
            "client_id, client_code, group_id, groups(name, meeting_day), "
            "client_memberships(group_id, groups(name, meeting_day)), "
            "app_users!clients_officer_id_fkey(full_name)"
        ).execute()
        if res_c.data:
            code_to_group = {}
            code_to_meeting = {}
            code_to_officer = {}
            for c in res_c.data:
                cid_uuid = c.get("client_id")
                code = c.get("client_code")
                g_name = c.get("groups", {}).get("name") if c.get("groups") else None
                if not g_name and c.get("client_memberships"):
                    m_list = c.get("client_memberships")
                    if isinstance(m_list, list) and len(m_list) > 0:
                        g_name = (m_list[0].get("groups") or {}).get("name")
                m_day = None
                if c.get("groups"):
                    m_day = c.get("groups", {}).get("meeting_day")
                if not m_day and c.get("client_memberships"):
                    m_list = c.get("client_memberships")
                    if isinstance(m_list, list) and len(m_list) > 0:
                        m_day = (m_list[0].get("groups") or {}).get("meeting_day")
                o_name = c.get("app_users", {}).get("full_name") if c.get("app_users") else None
                if cid_uuid:
                    if g_name: code_to_group[cid_uuid] = g_name
                    if m_day: code_to_meeting[cid_uuid] = m_day
                    if o_name: code_to_officer[cid_uuid] = o_name
                if code:
                    if g_name: code_to_group[code] = g_name
                    if m_day: code_to_meeting[code] = m_day
                    if o_name: code_to_officer[code] = o_name
            c_col = 'Client Code' if 'Client Code' in df.columns else ('client_code' if 'client_code' in df.columns else None)
            if c_col:
                df['Group Name'] = df['Client ID'].map(code_to_group).fillna(df[c_col].map(code_to_group)).fillna(df.get('Group Name'))
                df['Meeting Day'] = df['Client ID'].map(code_to_meeting).fillna(df[c_col].map(code_to_meeting)).fillna(df.get('Meeting Day'))
                df['Officer'] = df['Client ID'].map(code_to_officer).fillna(df[c_col].map(code_to_officer)).fillna(df.get('Officer'))
            else:
                df['Group Name'] = df['Client ID'].map(code_to_group).fillna(df.get('Group Name'))
                df['Meeting Day'] = df['Client ID'].map(code_to_meeting).fillna(df.get('Meeting Day'))
                df['Officer'] = df['Client ID'].map(code_to_officer).fillna(df.get('Officer'))

        num_cols = ['Loan Amount', 'Active Credit', 'Loan Repay', 'Total Due']
        for c in num_cols:
            if c in df.columns:
                df[c] = pd.to_numeric(df[c], errors='coerce').fillna(0)
        if not df.empty and 'Date' in df.columns:
            df = df.sort_values('Date', ascending=True).reset_index(drop=True)
        return df
    except Exception:
        return pd.DataFrame(columns=list(DB_TO_UI_LOANS.values()))


def _load_repayments_df(uow: SupabaseUnitOfWork) -> pd.DataFrame:
    try:
        filters = RepaymentFilter()
        filters.size = 2000
        reps = uow.repayments.find_recent(filters)
        if not reps:
            return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))
        from mappers.base_mappers import RepaymentMapper
        df = pd.DataFrame([RepaymentMapper.to_database(R) for R in reps]).rename(columns=DB_TO_UI_REP)
        if not df.empty:
            if 'date' in df.columns and 'Date' not in df.columns:
                df['Date'] = df['date']
        return df
    except Exception:
        return pd.DataFrame(columns=list(DB_TO_UI_REP.values()))


def _resolve_scope_and_branches(
    current_user: CurrentUser,
    uow: SupabaseUnitOfWork,
    requested_branch_name: Optional[str] = None
) -> tuple[str, Optional[Union[str, List[str]]], List[str], Dict[str, str]]:
    """
    Returns (scope_level, resolved_branch_id_or_ids, relevant_branch_names, branch_name_to_id).
    """
    role = (current_user.role or "").strip()
    is_bm = role in ["BM", "Branch Manager"]
    is_am = role in ["AM", "Area Manager"]

    res_b = uow.client.table("branches").select("branch_id, name").eq("is_active", True).order("name").execute()
    branch_rows = res_b.data or []
    branch_name_to_id = {b["name"]: b["branch_id"] for b in branch_rows}

    if is_bm:
        scope_level = "BRANCH"
        branch_name = current_user.branch or (branch_rows[0]["name"] if branch_rows else "Default Branch")
        branch_id = branch_name_to_id.get(branch_name) or current_user.branch_id
        return scope_level, branch_id, [branch_name], branch_name_to_id

    elif is_am:
        scope_level = "AREA"
        assigned_names = getattr(current_user, "assigned_branches", [])
        assigned_ids = getattr(current_user, "assigned_branch_ids", [])
        if not assigned_names or not assigned_ids:
            try:
                am_recs = uow.users.load_am_assignments(current_user.id)
                assigned_ids = [r["branch_id"] for r in am_recs if r.get("branch_id")]
                assigned_names = [r["name"] for r in am_recs if r.get("name")]
            except Exception:
                assigned_names = [b["name"] for b in branch_rows]
                assigned_ids = [b["branch_id"] for b in branch_rows]

        if not requested_branch_name or requested_branch_name in ["All Assigned Branches (Consolidated Area View)", "All Branches", "All"]:
            return scope_level, assigned_ids, assigned_names, branch_name_to_id
        else:
            single_id = branch_name_to_id.get(requested_branch_name)
            return scope_level, single_id, [requested_branch_name], branch_name_to_id

    else:
        scope_level = "INSTITUTION"
        all_names = [b["name"] for b in branch_rows]
        if not requested_branch_name or requested_branch_name in ["All Branches (Consolidated)", "All Branches", "All"]:
            return scope_level, None, all_names, branch_name_to_id
        else:
            single_id = branch_name_to_id.get(requested_branch_name)
            return scope_level, single_id, [requested_branch_name], branch_name_to_id


# -----------------------------------------------------------------------------
# 1. Metadata / Filter Options
# -----------------------------------------------------------------------------
@router.get("/meta", response_model=ReportsMetaResponse)
def get_reports_meta(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Provides dynamic filter options (branches, products, officers) scoped to user role."""
    _check_reports_permission(current_user)
    scope_level, _, branch_names, branch_name_to_id = _resolve_scope_and_branches(current_user, uow)

    # 1. Branches list
    branches = [BranchOption(branch_id=branch_name_to_id.get(name), name=name) for name in branch_names]

    # 2. Loan products
    try:
        res_prods = uow.client.table("loan_products").select("name").execute()
        products = sorted(list(set(p["name"] for p in (res_prods.data or []) if p.get("name"))))
    except Exception:
        products = ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"]

    # 3. Credit Officers scoped to branches
    try:
        all_app_users = uow.users.find_all()
        co_users = [u for u in all_app_users if u.role in ["CO", "Officer", "Credit Officer"]]
        if scope_level == "BRANCH":
            bm_branch = current_user.branch
            co_users = [u for u in co_users if u.branch_name == bm_branch or u.branch_id == branch_name_to_id.get(bm_branch)]
        elif scope_level == "AREA":
            co_users = [u for u in co_users if u.branch_name in branch_names or u.branch_id in [branch_name_to_id.get(n) for n in branch_names]]

        officers = [
            OfficerOption(
                user_id=u.id,
                username=u.username,
                full_name=u.full_name or u.username,
                branch_id=u.branch_id,
                branch_name=u.branch_name
            )
            for u in co_users
        ]
    except Exception:
        officers = []

    default_branch = current_user.branch if scope_level == "BRANCH" else None

    return ReportsMetaResponse(
        branches=branches,
        products=products,
        officers=officers,
        default_branch=default_branch,
        scope_level=scope_level
    )


# -----------------------------------------------------------------------------
# 2. General Ledger & Trial Balance
# -----------------------------------------------------------------------------
@router.get("/trial-balance", response_model=TrialBalanceResponse)
def get_trial_balance(
    branch_name: Optional[str] = Query(None),
    as_of_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Double-entry verification of all Chart of Accounts balances."""
    _check_reports_permission(current_user)
    _, resolved_branch_id, _, _ = _resolve_scope_and_branches(current_user, uow, branch_name)

    tb_dict = ReportService.get_trial_balance(
        uow=uow,
        branch_id=resolved_branch_id,
        as_of_date=as_of_date,
        start_date=start_date,
        end_date=end_date
    )

    rows = [
        TrialBalanceRow(
            account_code=r.get("Account Code", ""),
            account_name=r.get("Account Name", ""),
            account_type=r.get("Account Type", ""),
            normal_balance=r.get("Normal Balance", "Debit"),
            gross_debits=float(r.get("Gross Debits", 0.0)),
            gross_credits=float(r.get("Gross Credits", 0.0)),
            debit_balance=float(r.get("Debit Balance", 0.0)),
            credit_balance=float(r.get("Credit Balance", 0.0)),
            net_position=float(r.get("Net Position", 0.0))
        )
        for r in tb_dict.get("rows", [])
    ]

    return TrialBalanceResponse(
        is_balanced=tb_dict["is_balanced"],
        status=tb_dict["status"],
        total_debits=tb_dict["total_debits"],
        total_credits=tb_dict["total_credits"],
        total_net_debits=tb_dict["total_net_debits"],
        total_net_credits=tb_dict["total_net_credits"],
        variance=tb_dict["variance"],
        as_of_date=tb_dict.get("as_of_date"),
        start_date=tb_dict.get("start_date"),
        end_date=tb_dict.get("end_date"),
        rows=rows
    )


# -----------------------------------------------------------------------------
# 3. Savings Summary
# -----------------------------------------------------------------------------
@router.get("/savings-summary", response_model=SavingsSummaryResponse)
def get_savings_summary(
    branch_name: Optional[str] = Query(None),
    product_name: Optional[str] = Query(None),
    officer_name: Optional[str] = Query(None),
    as_of_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Savings Portfolio & Savers Breakdown derived from individual deposits and group reserves."""
    _check_reports_permission(current_user)
    _, resolved_branch_id, _, _ = _resolve_scope_and_branches(current_user, uow, branch_name)

    sav_dict = ReportService.get_savings_summary(
        uow=uow,
        branch_id=resolved_branch_id,
        start_date=start_date,
        end_date=end_date,
        as_of_date=as_of_date,
        officer_name=officer_name if officer_name != "All Officers" else None,
        product_name=product_name if product_name != "All Products" else None
    )

    savers = []
    df_savers = sav_dict.get("savers_dataframe")
    if df_savers is not None and not df_savers.empty:
        for _, r in df_savers.iterrows():
            savers.append(SaverRow(
                client_id=str(r.get("Client ID", "")),
                client_name=str(r.get("Client Name", "")),
                group=str(r.get("Group", "")),
                branch=str(r.get("Branch", "")),
                officer=str(r.get("Officer", "")),
                total_deposited=float(r.get("Total Deposited", 0.0)),
                total_withdrawn=float(r.get("Total Withdrawn", 0.0)),
                net_savings_balance=float(r.get("Net Savings Balance", 0.0)),
                last_transaction_date=str(r.get("Last Transaction Date", "")) if r.get("Last Transaction Date") else None
            ))

    return SavingsSummaryResponse(
        total_individual_deposits=sav_dict["total_individual_deposits"],
        total_individual_withdrawals=sav_dict["total_individual_withdrawals"],
        net_individual_savings=sav_dict["net_individual_savings"],
        total_group_deposits=sav_dict["total_group_deposits"],
        total_group_withdrawals=sav_dict["total_group_withdrawals"],
        net_group_savings=sav_dict["net_group_savings"],
        laps_reserve=sav_dict["laps_reserve"],
        total_consolidated_savings=sav_dict["total_consolidated_savings"],
        active_savers_count=sav_dict["active_savers_count"],
        total_savers_recorded=sav_dict["total_savers_recorded"],
        savers=savers
    )


# -----------------------------------------------------------------------------
# 4. Repayment Summary
# -----------------------------------------------------------------------------
@router.get("/repayment-summary", response_model=RepaymentSummaryResponse)
def get_repayment_summary(
    branch_name: Optional[str] = Query(None),
    product_name: Optional[str] = Query(None),
    officer_name: Optional[str] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Repayments, collections efficiency, full early payoffs, and excess payments."""
    _check_reports_permission(current_user)
    _, resolved_branch_id, _, _ = _resolve_scope_and_branches(current_user, uow, branch_name)

    rep_dict = ReportService.get_repayment_summary(
        uow=uow,
        branch_id=resolved_branch_id,
        start_date=start_date,
        end_date=end_date,
        product_name=product_name if product_name != "All Products" else None,
        officer_name=officer_name if officer_name != "All Officers" else None
    )

    products = []
    df_prod = rep_dict.get("product_dataframe")
    if df_prod is not None and not df_prod.empty:
        for _, r in df_prod.iterrows():
            products.append(ProductCollectionRow(
                loan_product=str(r.get("Loan Product", "")),
                collections_ngn=float(r.get("Collections (NGN)", 0.0)),
                transactions=int(r.get("Transactions", 0)),
                unique_clients=int(r.get("Unique Clients", 0))
            ))

    repayments = []
    df_reps = rep_dict.get("repayments_dataframe")
    if df_reps is not None and not df_reps.empty:
        for _, r in df_reps.iterrows():
            repayments.append(RepaymentLogRow(
                date=str(r.get("Date", "")),
                client_code=str(r.get("Client Code", "")),
                client_name=str(r.get("Client Name", "")),
                loan_product=str(r.get("Loan Product", "")),
                officer=str(r.get("Officer", "")),
                branch=str(r.get("Branch", "")),
                amount_paid=float(r.get("Amount Paid", 0.0)),
                expected_amount=float(r.get("Expected Amount", 0.0)),
                payment_status=str(r.get("Payment Status", "PAID")),
                transaction_type=str(r.get("Transaction Type", "Collection"))
            ))

    return RepaymentSummaryResponse(
        total_collected=rep_dict["total_collected"],
        total_expected=rep_dict["total_expected"],
        base_collections=rep_dict["base_collections"],
        collection_efficiency=rep_dict["collection_efficiency"],
        total_overdue_collected=rep_dict["total_overdue_collected"],
        full_payoff_amount=rep_dict["full_payoff_amount"],
        full_payoff_count=rep_dict["full_payoff_count"],
        excess_payment_amount=rep_dict["excess_payment_amount"],
        excess_payment_count=rep_dict["excess_payment_count"],
        status_counts=rep_dict.get("status_counts", {}),
        total_transactions=rep_dict.get("total_transactions", 0),
        products=products,
        repayments=repayments
    )


# -----------------------------------------------------------------------------
# 5. Portfolio & Officer Performance
# -----------------------------------------------------------------------------
@router.get("/portfolio-performance", response_model=PortfolioPerformanceResponse)
def get_portfolio_performance(
    branch_name: Optional[str] = Query(None),
    product_name: Optional[str] = Query(None),
    officer_name: Optional[str] = Query(None),
    inspect_officer: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Portfolio health KPIs, Officer performance breakdown, and Credit Risk Ratings."""
    _check_reports_permission(current_user)
    scope_level, resolved_branch_id, branch_names, branch_name_to_id = _resolve_scope_and_branches(current_user, uow, branch_name)

    all_loans = _load_loans_df(uow)
    all_reps = _load_repayments_df(uow)

    filtered_loans = all_loans.copy() if not all_loans.empty else pd.DataFrame()
    filtered_reps = all_reps.copy() if not all_reps.empty else pd.DataFrame()

    # Apply branch filtering
    if scope_level == "BRANCH":
        bm_branch = current_user.branch
        if not filtered_loans.empty and "Branch" in filtered_loans.columns:
            filtered_loans = filtered_loans[filtered_loans["Branch"] == bm_branch]
        if not filtered_reps.empty and "Branch" in filtered_reps.columns:
            filtered_reps = filtered_reps[filtered_reps["Branch"] == bm_branch]
    elif scope_level == "AREA":
        if branch_name and branch_name not in ["All Assigned Branches (Consolidated Area View)", "All Branches", "All"]:
            if not filtered_loans.empty and "Branch" in filtered_loans.columns:
                filtered_loans = filtered_loans[filtered_loans["Branch"] == branch_name]
            if not filtered_reps.empty and "Branch" in filtered_reps.columns:
                filtered_reps = filtered_reps[filtered_reps["Branch"] == branch_name]
        else:
            if not filtered_loans.empty and "Branch" in filtered_loans.columns:
                filtered_loans = filtered_loans[filtered_loans["Branch"].isin(branch_names)]
            if not filtered_reps.empty and "Branch" in filtered_reps.columns:
                filtered_reps = filtered_reps[filtered_reps["Branch"].isin(branch_names)]
    else:
        if branch_name and branch_name not in ["All Branches (Consolidated)", "All Branches", "All"]:
            if not filtered_loans.empty and "Branch" in filtered_loans.columns:
                filtered_loans = filtered_loans[filtered_loans["Branch"] == branch_name]
            if not filtered_reps.empty and "Branch" in filtered_reps.columns:
                filtered_reps = filtered_reps[filtered_reps["Branch"] == branch_name]

    # Apply product filtering
    if product_name and product_name not in ["All", "All Products"]:
        if not filtered_loans.empty and "Loan Product" in filtered_loans.columns:
            filtered_loans = filtered_loans[filtered_loans["Loan Product"] == product_name]
        if not filtered_reps.empty:
            prod_loan_ids = set(filtered_loans["id"].tolist()) if "id" in filtered_loans.columns else set()
            if prod_loan_ids and "loan_id" in filtered_reps.columns:
                filtered_reps = filtered_reps[filtered_reps["loan_id"].isin(prod_loan_ids)]

    # Apply officer filter
    if officer_name and officer_name not in ["All", "All Officers"]:
        if not filtered_loans.empty and "Officer" in filtered_loans.columns:
            filtered_loans = filtered_loans[filtered_loans["Officer"].astype(str).str.strip().str.lower() == officer_name.strip().lower()]
        if not filtered_reps.empty and "Officer" in filtered_reps.columns:
            filtered_reps = filtered_reps[filtered_reps["Officer"].astype(str).str.strip().str.lower() == officer_name.strip().lower()]

    # Generate portfolio summary
    port_sum = generate_portfolio_summary(filtered_loans, filtered_reps)

    # Officer performance breakdown
    officers_list = sorted([str(o) for o in filtered_loans["Officer"].dropna().unique()]) if not filtered_loans.empty and "Officer" in filtered_loans.columns else []
    target_inspect = inspect_officer if (inspect_officer and inspect_officer not in ["All", "All Officers"]) else None

    df_officer_rep = generate_officer_report(filtered_loans, filtered_reps, target_inspect)
    officer_records = []
    if not df_officer_rep.empty:
        for _, r in df_officer_rep.iterrows():
            officer_records.append(OfficerPerformanceRow(
                client_id=str(r.get("Client ID", "")),
                client_name=str(r.get("Client Name", "")),
                phone=str(r.get("Phone", "")),
                group=str(r.get("Group", "")),
                product=str(r.get("Product", "")),
                active_credit=float(r.get("Active Credit", 0.0)),
                loan_repay=float(r.get("Loan Repay", 0.0)),
                paid_to_loan=float(r.get("Paid to Loan", 0.0)),
                loan_balance=float(r.get("Loan Balance", 0.0)),
                savings=float(r.get("Savings", 0.0)),
                overdue=float(r.get("Overdue", 0.0)),
                status=str(r.get("Status", "Active"))
            ))

    # Risk Rating distribution
    risk_target_branch = resolved_branch_id if isinstance(resolved_branch_id, str) else (current_user.branch_id or (list(branch_name_to_id.values())[0] if branch_name_to_id else None))
    try:
        risk_dist = ClientRiskRatingService.get_branch_risk_distribution(uow, risk_target_branch)
    except Exception:
        risk_dist = {"EXCELLENT": 0, "GOOD": 0, "FAIR": 0, "RISKY": 0, "HIGH_RISK": 0}

    return PortfolioPerformanceResponse(
        active_loans=port_sum.get("active_loans", 0),
        total_portfolio=float(port_sum.get("total_portfolio", 0.0)),
        par_percentage=float(port_sum.get("par_percentage", 0.0)),
        officers_list=officers_list,
        officer_records=officer_records,
        risk_distribution=risk_dist
    )


# -----------------------------------------------------------------------------
# 6. Area Manager Branch Comparison (AM Exclusive)
# -----------------------------------------------------------------------------
@router.get("/area-comparison", response_model=AreaComparisonResponse)
def get_area_comparison(
    product_name: Optional[str] = Query(None),
    as_of_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Side-by-side comparative matrix of all branches under regional supervision."""
    _check_reports_permission(current_user)
    role = (current_user.role or "").strip()
    if role not in ["AM", "Area Manager", "Admin", "Super Admin", "Director"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Area Branches Comparison is exclusive to Area Managers and Executives."
        )

    _, resolved_ids, _, _ = _resolve_scope_and_branches(current_user, uow)
    if isinstance(resolved_ids, str):
        assigned_branch_ids = [resolved_ids]
    elif isinstance(resolved_ids, list):
        assigned_branch_ids = resolved_ids
    else:
        # Institutional scope: all active branch IDs
        res_b = uow.client.table("branches").select("branch_id").eq("is_active", True).execute()
        assigned_branch_ids = [b["branch_id"] for b in (res_b.data or [])]

    area_dict = ReportService.get_area_branch_comparison(
        uow=uow,
        assigned_branch_ids=assigned_branch_ids,
        start_date=start_date,
        end_date=end_date,
        as_of_date=as_of_date,
        product_name=product_name if product_name != "All Products" else None
    )

    rows = []
    df_area = area_dict.get("dataframe")

    def _to_float(val, default=0.0):
        if val is None:
            return default
        if isinstance(val, (int, float)):
            return float(val)
        if isinstance(val, str):
            try:
                return float(val.replace("%", "").strip())
            except Exception:
                return default
        return default

    if df_area is not None and not df_area.empty:
        for _, r in df_area.iterrows():
            rows.append(AreaBranchRow(
                branch=str(r.get("Branch", "")),
                people_on_loan=int(r.get("No. of People on Loan", 0)),
                active_loans=int(r.get("Active Loans", 0)),
                active_savers=int(r.get("No. of Active Savers", 0)),
                total_savings=_to_float(r.get("Total Savings", 0.0)),
                collections_received=_to_float(r.get("Collections Received", 0.0)),
                expected_collections=_to_float(r.get("Expected Collections", 0.0)),
                collection_efficiency=_to_float(r.get("_raw_eff", r.get("Collection Efficiency", 100.0))),
                outstanding_portfolio=_to_float(r.get("Outstanding Portfolio", 0.0)),
                par_percentage=_to_float(r.get("_raw_par", r.get("PAR %", 0.0))),
                status=str(r.get("Status", "HEALTHY"))
            ))

    return AreaComparisonResponse(
        total_branches=area_dict.get("total_branches", 0),
        total_people_on_loan=area_dict.get("total_people_on_loan", 0),
        total_active_loans=area_dict.get("total_active_loans", 0),
        total_active_savers=area_dict.get("total_active_savers", 0),
        total_area_collections=float(area_dict.get("total_area_collections", 0.0)),
        total_area_expected=float(area_dict.get("total_area_expected", 0.0)),
        overall_efficiency=float(area_dict.get("overall_efficiency", 100.0)),
        total_area_savings=float(area_dict.get("total_area_savings", 0.0)),
        total_area_portfolio=float(area_dict.get("total_area_portfolio", 0.0)),
        overall_par=float(area_dict.get("overall_par", 0.0)),
        rows=rows
    )


# -----------------------------------------------------------------------------
# 7. Excel Consolidated Export
# -----------------------------------------------------------------------------
@router.get("/export/excel")
def export_excel(
    branch_name: Optional[str] = Query(None),
    product_name: Optional[str] = Query(None),
    officer_name: Optional[str] = Query(None),
    as_of_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Generates and streams multi-tab consolidated Excel workbook."""
    _check_reports_permission(current_user)
    scope_level, resolved_branch_id, branch_names, _ = _resolve_scope_and_branches(current_user, uow, branch_name)

    tb_dict = ReportService.get_trial_balance(uow, branch_id=resolved_branch_id, as_of_date=as_of_date, start_date=start_date, end_date=end_date)
    sav_dict = ReportService.get_savings_summary(uow, branch_id=resolved_branch_id, start_date=start_date, end_date=end_date, as_of_date=as_of_date, officer_name=officer_name if officer_name != "All Officers" else None, product_name=product_name if product_name != "All Products" else None)
    rep_dict = ReportService.get_repayment_summary(uow, branch_id=resolved_branch_id, start_date=start_date, end_date=end_date, product_name=product_name if product_name != "All Products" else None, officer_name=officer_name if officer_name != "All Officers" else None)

    all_loans = _load_loans_df(uow)
    all_reps = _load_repayments_df(uow)
    filtered_loans = all_loans.copy()
    if scope_level == "BRANCH":
        bm_branch = current_user.branch
        if "Branch" in filtered_loans.columns:
            filtered_loans = filtered_loans[filtered_loans["Branch"] == bm_branch]
    elif scope_level == "AREA":
        if branch_name and branch_name not in ["All Assigned Branches (Consolidated Area View)", "All Branches", "All"]:
            filtered_loans = filtered_loans[filtered_loans["Branch"] == branch_name]
        else:
            filtered_loans = filtered_loans[filtered_loans["Branch"].isin(branch_names)]

    port_sum = generate_portfolio_summary(filtered_loans, all_reps)

    area_df = None
    if scope_level == "AREA" or current_user.role in ["AM", "Area Manager", "Admin"]:
        assigned_ids = resolved_branch_id if isinstance(resolved_branch_id, list) else ([resolved_branch_id] if resolved_branch_id else [])
        area_dict = ReportService.get_area_branch_comparison(uow, assigned_branch_ids=assigned_ids, start_date=start_date, end_date=end_date, as_of_date=as_of_date)
        area_df = area_dict.get("dataframe")

    excel_bytes = export_consolidated_report_to_excel(
        trial_balance_df=tb_dict.get("dataframe"),
        savings_df=sav_dict.get("savers_dataframe"),
        repayments_df=rep_dict.get("repayments_dataframe"),
        loans_df=filtered_loans,
        portfolio_summary=port_sum,
        area_comparison_df=area_df
    )

    filename = f"icare_master_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
    return StreamingResponse(
        io.BytesIO(excel_bytes),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


# -----------------------------------------------------------------------------
# 8. CSV Single Table Export
# -----------------------------------------------------------------------------
@router.get("/export/csv")
def export_csv(
    report_type: str = Query(..., description="trial_balance | savings | repayments | loans | area_comparison"),
    branch_name: Optional[str] = Query(None),
    product_name: Optional[str] = Query(None),
    officer_name: Optional[str] = Query(None),
    as_of_date: Optional[date] = Query(None),
    start_date: Optional[date] = Query(None),
    end_date: Optional[date] = Query(None),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Generates and streams individual CSV reports."""
    _check_reports_permission(current_user)
    scope_level, resolved_branch_id, branch_names, _ = _resolve_scope_and_branches(current_user, uow, branch_name)

    if report_type == "trial_balance":
        tb_dict = ReportService.get_trial_balance(uow, branch_id=resolved_branch_id, as_of_date=as_of_date, start_date=start_date, end_date=end_date)
        df = tb_dict.get("dataframe", pd.DataFrame())
        filename = f"trial_balance_{datetime.now().strftime('%Y%m%d')}.csv"
    elif report_type == "savings":
        sav_dict = ReportService.get_savings_summary(uow, branch_id=resolved_branch_id, start_date=start_date, end_date=end_date, as_of_date=as_of_date, officer_name=officer_name if officer_name != "All Officers" else None, product_name=product_name if product_name != "All Products" else None)
        df = sav_dict.get("savers_dataframe", pd.DataFrame())
        filename = f"savings_summary_{datetime.now().strftime('%Y%m%d')}.csv"
    elif report_type == "repayments":
        rep_dict = ReportService.get_repayment_summary(uow, branch_id=resolved_branch_id, start_date=start_date, end_date=end_date, product_name=product_name if product_name != "All Products" else None, officer_name=officer_name if officer_name != "All Officers" else None)
        df = rep_dict.get("repayments_dataframe", pd.DataFrame())
        filename = f"repayments_summary_{datetime.now().strftime('%Y%m%d')}.csv"
    elif report_type == "loans":
        all_loans = _load_loans_df(uow)
        df = all_loans
        if scope_level == "BRANCH":
            df = df[df["Branch"] == current_user.branch] if "Branch" in df.columns else df
        elif scope_level == "AREA":
            if branch_name and branch_name not in ["All Assigned Branches (Consolidated Area View)", "All Branches", "All"]:
                df = df[df["Branch"] == branch_name] if "Branch" in df.columns else df
            else:
                df = df[df["Branch"].isin(branch_names)] if "Branch" in df.columns else df
        filename = f"raw_loans_{datetime.now().strftime('%Y%m%d')}.csv"
    elif report_type == "area_comparison":
        assigned_ids = resolved_branch_id if isinstance(resolved_branch_id, list) else ([resolved_branch_id] if resolved_branch_id else [])
        area_dict = ReportService.get_area_branch_comparison(uow, assigned_branch_ids=assigned_ids, start_date=start_date, end_date=end_date, as_of_date=as_of_date)
        df = area_dict.get("dataframe", pd.DataFrame())
        filename = f"area_branch_comparison_{datetime.now().strftime('%Y%m%d')}.csv"
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported report_type '{report_type}'.")

    csv_bytes = df.to_csv(index=False).encode('utf-8') if not df.empty else b""
    return StreamingResponse(
        io.BytesIO(csv_bytes),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )
