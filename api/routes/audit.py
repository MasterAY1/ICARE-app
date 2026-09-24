"""
Audit Ledger & Audit Center Route Adapter.
Provides full 1:1 Streamlit Parity for Phase 9: Audit Ledger & Audit Center (app.py L9833–10747).
Backed by SupabaseAuditViewRepository, AuditEnricher, FinancialReconciliationService,
TransactionExplorerService, and ClientRiskRatingService.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime, timedelta
import io
import csv

from fastapi import APIRouter, Depends, Query, HTTPException, status
from fastapi.responses import StreamingResponse

from database.repositories.unit_of_work import SupabaseUnitOfWork
from database.repositories.audit_view_repository import SupabaseAuditViewRepository
from api.dependencies import get_uow, get_current_user
from models.user import CurrentUser
from services.audit_enricher_service import AuditEnricher
from services.audit_reporting_service import AuditReportingService
from services.financial_reconciliation_service import FinancialReconciliationService
from services.transaction_explorer_service import TransactionExplorerService
from services.client_risk_rating_service import ClientRiskRatingService
from services.rbac_scope_service import RBACScopeService

from api.schemas.audit import (
    BranchOption,
    OfficerOption,
    ProductOption,
    AuditMetaResponse,
    Integrity6WayResponse,
    VarianceItem,
    AuditSummaryMetrics,
    FeeLedgerResponse,
    TreasuryLedgerResponse,
    SavingsSummaryMetrics,
    SavingsLedgerResponse,
    LoanDisbursementMetrics,
    LoanRepaymentMetrics,
    LoanLedgerResponse,
    CollectionPerformanceMetrics,
    CollectionPerformanceResponse,
    ExceptionReportsResponse,
    UniversalExplorerResponse,
    LoanTimelineResponse,
    RiskDistributionResponse,
    ReconciliationRepairRequest,
    ReconciliationRepairResponse,
)

router = APIRouter(prefix="/api/v1/audit", tags=["Audit Ledger"])


def _resolve_scope(
    current_user: CurrentUser,
    requested_branch_id: Optional[str] = None,
    requested_officer_id: Optional[str] = None
) -> tuple[Optional[str], Optional[str]]:
    """Enforces strict RBAC scoping rules."""
    role = (current_user.role or "").strip()
    is_officer = role in ["CO", "Officer", "Credit Officer", "CREDIT_OFFICER"]
    is_bm = role in ["BM", "Branch Manager", "BRANCH_MANAGER"]
    is_am = role in ["AM", "Area Manager", "AREA_MANAGER"]
    is_admin = role in ["Admin", "Super Admin", "ADMIN", "Director", "Board Director"]

    final_branch_id = requested_branch_id
    final_officer_id = requested_officer_id

    if is_officer:
        final_branch_id = current_user.branch_id
        final_officer_id = current_user.user_id
    elif is_bm:
        final_branch_id = current_user.branch_id
        if requested_officer_id in ["All", "All Officers", ""]:
            final_officer_id = None
    elif is_am:
        if requested_branch_id in ["All", "All Branches", ""]:
            final_branch_id = current_user.branch_id
        if requested_officer_id in ["All", "All Officers", ""]:
            final_officer_id = None
    else:  # Admin / Director
        if requested_branch_id in ["All", "All Branches", ""]:
            final_branch_id = None
        if requested_officer_id in ["All", "All Officers", ""]:
            final_officer_id = None

    return final_branch_id, final_officer_id


def _get_resilient_collection_records(
    audit_views: SupabaseAuditViewRepository,
    uow: SupabaseUnitOfWork,
    b_id: Optional[str] = None,
    off_id: Optional[str] = None,
    c_id: Optional[str] = None,
    d_from: Optional[date] = None,
    d_to: Optional[date] = None,
    limit: int = 500
) -> List[Dict[str, Any]]:
    """Resilient collection performance record loader matching app.py L9930-10036."""
    if audit_views and hasattr(audit_views, "get_collection_performance"):
        try:
            records = audit_views.get_collection_performance(
                branch_id=b_id,
                officer_id=off_id if off_id not in ["All", "All Officers"] else None,
                client_id=c_id,
                date_from=d_from,
                date_to=d_to,
                limit=limit
            )
            if records:
                return records
        except Exception:
            pass

    d_from_iso = d_from.isoformat() if isinstance(d_from, date) else (str(d_from)[:10] if d_from else None)
    d_to_iso = d_to.isoformat() if isinstance(d_to, date) else (str(d_to)[:10] if d_to else None)

    branch_officer_ids = []
    if b_id and b_id not in ["All", "All Branches"]:
        try:
            res_off = uow.client.table("app_users").select("id").eq("branch_id", b_id).execute()
            branch_officer_ids = [str(u["id"]) for u in (res_off.data or []) if u.get("id")]
        except Exception:
            pass

    cp_records = []
    try:
        query_cp = uow.client.table("collection_performance").select("*")
        if off_id and off_id not in ["All", "All Officers"]:
            query_cp = query_cp.eq("officer_id", off_id)
        elif branch_officer_ids:
            query_cp = query_cp.in_("officer_id", branch_officer_ids)

        if c_id:
            query_cp = query_cp.eq("client_id", c_id)
        if d_from_iso:
            query_cp = query_cp.gte("meeting_date", d_from_iso)
        if d_to_iso:
            query_cp = query_cp.lte("meeting_date", d_to_iso)

        res_cp = query_cp.order("meeting_date", desc=True).limit(limit).execute()
        for r in (res_cp.data or []):
            if b_id and not r.get("branch_id"):
                r["branch_id"] = b_id
            cp_records.append(r)
    except Exception:
        cp_records = []

    if not cp_records:
        try:
            query_rep = uow.client.table("repayments").select("*")
            if b_id and b_id not in ["All", "All Branches"]:
                query_rep = query_rep.eq("branch_id", b_id)
            if off_id and off_id not in ["All", "All Officers"]:
                query_rep = query_rep.eq("officer_id", off_id)
            elif branch_officer_ids:
                query_rep = query_rep.in_("officer_id", branch_officer_ids)

            if c_id:
                query_rep = query_rep.eq("client_id", c_id)
            if d_from_iso:
                query_rep = query_rep.gte("date", d_from_iso)
            if d_to_iso:
                query_rep = query_rep.lte("date", f"{d_to_iso}T23:59:59")

            res_rep = query_rep.order("date", desc=True).limit(limit).execute()
            for r in (res_rep.data or []):
                paid = float(r.get("amount_paid") or 0.0)
                expected = float(r.get("expected_amount") or 0.0)
                if expected <= 0.0 and paid > 0.0:
                    expected = paid

                status = r.get("payment_status")
                if not status or status.upper() not in ["PAID", "PART_PAYMENT", "NOT_PAID"]:
                    if expected > 0:
                        ratio = (paid / expected) * 100.0
                        status = "PAID" if ratio >= 99.0 else ("PART_PAYMENT" if paid > 0 else "NOT_PAID")
                    else:
                        status = "PAID" if paid > 0 else "NOT_PAID"

                m_date = str(r.get("date") or r.get("created_at") or "")[:10]
                cp_records.append({
                    "id": r.get("id"),
                    "client_id": r.get("client_id"),
                    "loan_id": r.get("loan_id"),
                    "officer_id": r.get("officer_id"),
                    "branch_id": r.get("branch_id") or b_id,
                    "meeting_date": m_date,
                    "date": m_date,
                    "expected_amount": expected,
                    "amount_paid": paid,
                    "collected_amount": paid,
                    "status": status,
                    "remarks": r.get("note") or r.get("transaction_type") or "Meeting repayment",
                    "created_at": r.get("created_at")
                })
        except Exception:
            pass

    cp_records.sort(key=lambda x: str(x.get("meeting_date") or x.get("date") or x.get("created_at") or ""), reverse=True)
    return cp_records[:limit]


# -----------------------------------------------------------------------------
# Metadata Endpoint
# -----------------------------------------------------------------------------
@router.get("/meta", response_model=AuditMetaResponse)
def get_audit_metadata(
    branch_id: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Returns branches, officers, and loan products for dropdown filters."""
    # 1. Branches
    branches: List[BranchOption] = []
    try:
        res_b = uow.client.table("branches").select("branch_id, name, code").eq("is_active", True).execute()
        for b in (res_b.data or []):
            branches.append(BranchOption(
                branch_id=str(b.get("branch_id")),
                name=str(b.get("name") or b.get("code") or "Unknown Branch"),
                code=b.get("code")
            ))
    except Exception:
        pass

    # 2. Officers
    officers: List[OfficerOption] = []
    try:
        res_ur = uow.client.table("user_roles").select("user_id, roles(name)").execute()
        user_role_map = {r["user_id"]: ((r.get("roles") or {}).get("name") or "") for r in (res_ur.data or []) if r.get("user_id")}

        q_off = uow.client.table("app_users").select("id, username, full_name, branch_id").eq("is_active", True)
        if branch_id and branch_id not in ["All", "All Branches"]:
            q_off = q_off.eq("branch_id", branch_id)
        res_o = q_off.execute()
        for u in (res_o.data or []):
            uid = str(u.get("id") or "")
            uname = u.get("username", "")
            fname = u.get("full_name") or uname
            role_name = user_role_map.get(uid, "")
            role_str = role_name.lower()
            if uname.startswith("CO") or "officer" in uname.lower() or "co" in uname.lower() or "officer" in role_str or "credit" in role_str:
                disp = f"{fname} ({uname})"
                officers.append(OfficerOption(
                    id=uid or uname,
                    username=uname,
                    full_name=fname,
                    display_name=disp,
                    role=role_name or None
                ))
    except Exception:
        pass

    # 3. Loan Products
    products: List[ProductOption] = []
    try:
        res_p = uow.client.table("loan_products").select("product_id, name, code").execute()
        for p in (res_p.data or []):
            products.append(ProductOption(
                product_id=str(p.get("product_id")),
                name=str(p.get("name") or p.get("code") or "Product"),
                code=p.get("code")
            ))
    except Exception:
        pass

    return AuditMetaResponse(branches=branches, officers=officers, products=products)


# -----------------------------------------------------------------------------
# TAB 1: 6-Way Financial Integrity Verification
# -----------------------------------------------------------------------------
@router.get("/integrity-6way", response_model=Integrity6WayResponse)
def get_6way_integrity(
    branch_id: Optional[str] = None,
    posting_date: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Automated 6-Way mathematical balance verification (app.py L10057-10082)."""
    target_b_id = branch_id or current_user.branch_id
    p_date_iso = posting_date or date.today().isoformat()
    try:
        p_date = date.fromisoformat(p_date_iso)
    except Exception:
        p_date = date.today()

    rec_result = FinancialReconciliationService.verify_6way_financial_integrity(uow, target_b_id, p_date)

    variances = [
        VarianceItem(
            source=v.get("source", ""),
            expected=float(v.get("expected", 0.0)),
            actual=float(v.get("actual", 0.0)),
            variance=float(v.get("variance", 0.0)),
            cause=v.get("cause", "")
        )
        for v in rec_result.get("variances", [])
    ]

    is_bal = bool(rec_result.get("is_balanced", False))
    return Integrity6WayResponse(
        branch_id=target_b_id,
        posting_date=p_date_iso,
        is_balanced=is_bal,
        status_text=str(rec_result.get("status_text", "Integrity Checked")),
        status_badge="PERFECT_MATCH" if is_bal else "MISMATCH",
        ledger_total=float(rec_result.get("ledger_total", 0.0)),
        audit_views_total=float(rec_result.get("audit_views_total", 0.0)),
        co_cashbooks_total=float(rec_result.get("co_cashbooks_total", 0.0)),
        master_cashbook_total=float(rec_result.get("master_cashbook_total", 0.0)),
        dashboard_total=float(rec_result.get("dashboard_total", 0.0)),
        reports_total=float(rec_result.get("reports_total", 0.0)),
        variances=variances
    )


# -----------------------------------------------------------------------------
# TAB 2: Fee Audit Ledgers
# -----------------------------------------------------------------------------
@router.get("/fees", response_model=FeeLedgerResponse)
def get_fees_audit_ledger(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    fee_type: str = "ALL",
    branch_id: Optional[str] = None,
    officer_id: Optional[str] = None,
    search: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Itemized audit trail of loan origination fees, passbooks, and charges (app.py L10086-10160)."""
    b_id, off_id = _resolve_scope(current_user, branch_id, officer_id)
    d_from = date.fromisoformat(date_from) if date_from else date.today().replace(day=1)
    d_to = date.fromisoformat(date_to) if date_to else date.today()

    audit_views = SupabaseAuditViewRepository(uow.client)
    raw_records = audit_views.get_fee_ledger(
        fee_type=fee_type,
        branch_id=b_id,
        officer_id=off_id,
        date_from=d_from,
        date_to=d_to,
        limit=500
    )

    enricher = AuditEnricher(uow=uow)
    enriched = enricher.enrich_fee_records(raw_records)

    if search:
        s_lower = search.lower()
        enriched = [
            f for f in enriched
            if s_lower in str(f.get("Client Code", "")).lower()
            or s_lower in str(f.get("Client Name", "")).lower()
            or s_lower in str(f.get("Officer", "")).lower()
            or s_lower in str(f.get("Branch", "")).lower()
            or s_lower in str(f.get("Reference", "")).lower()
        ]

    summary = AuditReportingService.calculate_summary_metrics(enriched, amount_key="Amount_Raw")
    metrics = AuditSummaryMetrics(
        total_amount=float(summary.get("total_amount", 0.0)),
        total_count=int(summary.get("total_count", 0)),
        average_amount=float(summary.get("average_amount", 0.0)),
        last_transaction_date=str(summary.get("last_transaction_date", "N/A")),
        highest_amount=float(summary.get("highest_amount", 0.0))
    )

    return FeeLedgerResponse(metrics=metrics, records=enriched)


# -----------------------------------------------------------------------------
# TAB 3: Treasury Audit Ledgers
# -----------------------------------------------------------------------------
@router.get("/treasury", response_model=TreasuryLedgerResponse)
def get_treasury_audit_ledger(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    category: str = "ALL",
    branch_id: Optional[str] = None,
    officer_id: Optional[str] = None,
    search: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Audit trail of bank deposits, withdrawals, staff salaries, and transfers (app.py L10164-10237)."""
    b_id, off_id = _resolve_scope(current_user, branch_id, officer_id)
    d_from = date.fromisoformat(date_from) if date_from else date.today().replace(day=1)
    d_to = date.fromisoformat(date_to) if date_to else date.today()

    audit_views = SupabaseAuditViewRepository(uow.client)
    raw_records = audit_views.get_treasury_ledger(
        category,
        branch_id=b_id,
        officer_id=off_id,
        date_from=d_from,
        date_to=d_to,
        limit=500
    )

    enricher = AuditEnricher(uow=uow)
    enriched = enricher.enrich_treasury_records(raw_records)

    if search:
        s_lower = search.lower()
        enriched = [
            t for t in enriched
            if s_lower in str(t.get("Category", "")).lower()
            or s_lower in str(t.get("Officer", "")).lower()
            or s_lower in str(t.get("Branch", "")).lower()
            or s_lower in str(t.get("Reference", "")).lower()
            or s_lower in str(t.get("Narration", "")).lower()
        ]

    summary = AuditReportingService.calculate_summary_metrics(enriched, amount_key="Amount_Raw")
    metrics = AuditSummaryMetrics(
        total_amount=float(summary.get("total_amount", 0.0)),
        total_count=int(summary.get("total_count", 0)),
        average_amount=float(summary.get("average_amount", 0.0)),
        last_transaction_date=str(summary.get("last_transaction_date", "N/A")),
        highest_amount=float(summary.get("highest_amount", 0.0))
    )

    return TreasuryLedgerResponse(metrics=metrics, records=enriched)


# -----------------------------------------------------------------------------
# TAB 4: Savings Audit Ledgers
# -----------------------------------------------------------------------------
@router.get("/savings", response_model=SavingsLedgerResponse)
def get_savings_audit_ledger(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    savings_ledger: str = "ALL",
    branch_id: Optional[str] = None,
    officer_id: Optional[str] = None,
    search: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Audit trail of voluntary deposits, group collateral, and laps (app.py L10241-10340)."""
    b_id, off_id = _resolve_scope(current_user, branch_id, officer_id)
    d_from = date.fromisoformat(date_from) if date_from else date.today().replace(day=1)
    d_to = date.fromisoformat(date_to) if date_to else date.today()

    tbl_map = {
        "ALL": "ALL",
        "Individual Savings": "individual_savings",
        "Group Savings": "group_savings",
        "Misc Savings": "internal_savings",
        "Laps Savings": "laps_savings"
    }
    table_target = tbl_map.get(savings_ledger, "ALL")

    audit_views = SupabaseAuditViewRepository(uow.client)
    raw_records = audit_views.get_savings_ledger(
        table_target,
        branch_id=b_id,
        officer_id=off_id,
        date_from=d_from,
        date_to=d_to,
        limit=500
    )

    enricher = AuditEnricher(uow=uow)
    enriched = enricher.enrich_savings_records(raw_records)

    # Scoping for CO
    role = (current_user.role or "").strip()
    if role in ["CO", "Officer", "Credit Officer", "CREDIT_OFFICER"]:
        co_full = current_user.full_name or ""
        enriched = [
            s for s in enriched
            if str(s.get("_raw_record", {}).get("officer_id") or "") == str(current_user.user_id)
            or str(s.get("Officer", "")).lower() in [
                str(current_user.username or "").lower(),
                co_full.lower(),
                f"{co_full.lower()} ({str(current_user.username or '').lower()})"
            ]
        ]

    if search:
        s_lower = search.lower()
        enriched = [
            s for s in enriched
            if s_lower in str(s.get("Client Code", "")).lower()
            or s_lower in str(s.get("Client Name", "")).lower()
            or s_lower in str(s.get("Officer", "")).lower()
            or s_lower in str(s.get("Branch", "")).lower()
        ]

    tot_dep = sum(float(s.get("Deposit_Raw", 0.0) or 0.0) for s in enriched)
    tot_wth = sum(float(s.get("Withdrawal_Raw", 0.0) or 0.0) for s in enriched)
    unique_clients = len(set(s.get("Client Code") for s in enriched if s.get("Client Code") not in [None, "N/A"]))

    metrics = SavingsSummaryMetrics(
        total_deposits=tot_dep,
        total_withdrawals=tot_wth,
        net_savings_movement=tot_dep - tot_wth,
        transactions_count=len(enriched),
        active_accounts_count=unique_clients
    )

    return SavingsLedgerResponse(metrics=metrics, records=enriched)


# -----------------------------------------------------------------------------
# TAB 5: Loan Audit Ledgers
# -----------------------------------------------------------------------------
@router.get("/loans", response_model=LoanLedgerResponse)
def get_loans_audit_ledger(
    view_type: str = "Loan Disbursements",  # "Loan Disbursements" or "Repayments"
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    product_id: Optional[str] = None,
    branch_id: Optional[str] = None,
    officer_id: Optional[str] = None,
    search: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Audit trail of loan disbursements and repayments (app.py L10344-10505)."""
    b_id, off_id = _resolve_scope(current_user, branch_id, officer_id)
    d_from = date.fromisoformat(date_from) if date_from else date.today().replace(day=1)
    d_to = date.fromisoformat(date_to) if date_to else date.today()
    p_id = product_id if product_id not in ["All Products", "All", "", None] else None

    audit_views = SupabaseAuditViewRepository(uow.client)
    enricher = AuditEnricher(uow=uow)
    role = (current_user.role or "").strip()
    is_co = role in ["CO", "Officer", "Credit Officer", "CREDIT_OFFICER"]

    if view_type == "Loan Disbursements":
        raw_records = audit_views.get_loan_disbursements(
            branch_id=b_id,
            officer_id=off_id,
            product_id=p_id,
            date_from=d_from,
            date_to=d_to,
            limit=500
        )
        enriched = enricher.enrich_loan_records(raw_records)

        if is_co:
            co_full = current_user.full_name or ""
            enriched = [
                l for l in enriched
                if str(l.get("_raw_record", {}).get("officer_id") or "") == str(current_user.user_id)
                or str(l.get("Officer", "")).lower() in [
                    str(current_user.username or "").lower(),
                    co_full.lower(),
                    f"{co_full.lower()} ({str(current_user.username or '').lower()})"
                ]
            ]

        if search:
            s_lower = search.lower()
            enriched = [
                l for l in enriched
                if s_lower in str(l.get("Loan Number", "")).lower()
                or s_lower in str(l.get("Client Code", "")).lower()
                or s_lower in str(l.get("Client Name", "")).lower()
                or s_lower in str(l.get("Officer", "")).lower()
                or s_lower in str(l.get("Branch", "")).lower()
                or s_lower in str(l.get("Product", "")).lower()
            ]

        tot_p = sum(float(l.get("Principal_Raw", 0.0) or 0.0) for l in enriched)
        borrowers = len(set(l.get("Client Code") for l in enriched if l.get("Client Code") not in [None, "N/A"]))
        d_metrics = LoanDisbursementMetrics(
            total_principal_disbursed=tot_p,
            loans_disbursed=len(enriched),
            average_principal=(tot_p / len(enriched)) if enriched else 0.0,
            borrowers_count=borrowers,
            active_portfolio=tot_p
        )
        return LoanLedgerResponse(
            view_type="Loan Disbursements",
            disbursement_metrics=d_metrics,
            records=enriched
        )

    else:  # Repayments
        raw_records = audit_views.get_loan_repayments(
            branch_id=b_id,
            officer_id=off_id,
            product_id=p_id,
            date_from=d_from,
            date_to=d_to,
            limit=500
        )
        enriched = enricher.enrich_repayment_records(raw_records)

        if is_co:
            co_full = current_user.full_name or ""
            enriched = [
                r for r in enriched
                if str(r.get("_raw_record", {}).get("officer_id") or "") == str(current_user.user_id)
                or str(r.get("Officer", "")).lower() in [
                    str(current_user.username or "").lower(),
                    co_full.lower(),
                    f"{co_full.lower()} ({str(current_user.username or '').lower()})"
                ]
            ]

        if search:
            s_lower = search.lower()
            enriched = [
                r for r in enriched
                if s_lower in str(r.get("Loan Number", "")).lower()
                or s_lower in str(r.get("Client Code", "")).lower()
                or s_lower in str(r.get("Client Name", "")).lower()
                or s_lower in str(r.get("Product", "")).lower()
                or s_lower in str(r.get("Officer", "")).lower()
                or s_lower in str(r.get("Branch", "")).lower()
            ]

        tot_r = sum(float(r.get("Amount_Raw", 0.0) or 0.0) for r in enriched)
        active_payers = len(set(r.get("Client Code") for r in enriched if r.get("Client Code") not in [None, "N/A"]))
        r_metrics = LoanRepaymentMetrics(
            total_repayments_collected=tot_r,
            repayment_count=len(enriched),
            average_repayment=(tot_r / len(enriched)) if enriched else 0.0,
            active_paying_clients=active_payers
        )
        return LoanLedgerResponse(
            view_type="Repayments",
            repayment_metrics=r_metrics,
            records=enriched
        )


# -----------------------------------------------------------------------------
# TAB 6: Collection Performance Audit
# -----------------------------------------------------------------------------
@router.get("/collections", response_model=CollectionPerformanceResponse)
def get_collections_audit_ledger(
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    branch_id: Optional[str] = None,
    officer_id: Optional[str] = None,
    compliance_status: str = "ALL",  # ALL, PAID, PART_PAYMENT, NOT_PAID
    search: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Meeting compliance matrix comparing expected collections against actual payments (app.py L10509-10624)."""
    b_id, off_id = _resolve_scope(current_user, branch_id, officer_id)
    d_from = date.fromisoformat(date_from) if date_from else (date.today() - timedelta(days=30))
    d_to = date.fromisoformat(date_to) if date_to else date.today()

    audit_views = SupabaseAuditViewRepository(uow.client)
    raw_records = _get_resilient_collection_records(
        audit_views,
        uow=uow,
        b_id=b_id,
        off_id=off_id,
        d_from=d_from,
        d_to=d_to,
        limit=500
    )

    enricher = AuditEnricher(uow=uow)
    enriched = enricher.enrich_collection_records(raw_records)

    role = (current_user.role or "").strip()
    if role in ["CO", "Officer", "Credit Officer", "CREDIT_OFFICER"]:
        co_full = current_user.full_name or ""
        enriched = [
            c for c in enriched
            if str(c.get("_raw_record", {}).get("officer_id") or "") == str(current_user.user_id)
            or str(c.get("Officer", "")).lower() in [
                str(current_user.username or "").lower(),
                co_full.lower(),
                f"{co_full.lower()} ({str(current_user.username or '').lower()})"
            ]
        ]

    if compliance_status != "ALL":
        enriched = [
            c for c in enriched
            if c.get("Status_Raw") == compliance_status or compliance_status in str(c.get("Status", ""))
        ]

    if search:
        s_lower = search.lower()
        enriched = [
            c for c in enriched
            if s_lower in str(c.get("Client Code", "")).lower()
            or s_lower in str(c.get("Client Name", "")).lower()
            or s_lower in str(c.get("Officer", "")).lower()
            or s_lower in str(c.get("Group", "")).lower()
            or s_lower in str(c.get("Branch", "")).lower()
        ]

    tot_exp = sum(float(c.get("Expected_Raw", 0.0) or 0.0) for c in enriched)
    tot_act = sum(float(c.get("Paid_Raw", 0.0) or 0.0) for c in enriched)
    tot_var = sum(max(0.0, float(c.get("Expected_Raw", 0.0) or 0.0) - float(c.get("Paid_Raw", 0.0) or 0.0)) for c in enriched)
    comp_ratio = (tot_act / tot_exp * 100.0) if tot_exp > 0 else (100.0 if tot_act > 0 else 0.0)
    paid_count = sum(1 for c in enriched if c.get("Status_Raw") == "PAID" or "PAID" in str(c.get("Status", "")).upper())

    metrics = CollectionPerformanceMetrics(
        expected_collections=tot_exp,
        actual_collections=tot_act,
        collection_variance=tot_var,
        meeting_compliance_ratio=comp_ratio,
        meetings_audited=len(enriched),
        paid_count=paid_count
    )

    return CollectionPerformanceResponse(metrics=metrics, records=enriched)


# -----------------------------------------------------------------------------
# TAB 7: 15 Exception Reports
# -----------------------------------------------------------------------------
@router.get("/exceptions", response_model=ExceptionReportsResponse)
def get_15_exception_reports(
    branch_id: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Scans core database for compliance breaches, unposted transactions, or anomalies (app.py L10628-10642)."""
    target_b_id = branch_id if branch_id not in ["All", "All Branches", None] else None
    if current_user.role in ["BM", "Branch Manager"]:
        target_b_id = current_user.branch_id

    ex_data = FinancialReconciliationService.run_15_exception_reports(uow, target_b_id)
    return ExceptionReportsResponse(
        total_exceptions=int(ex_data.get("total_exceptions", 0)),
        exception_rules_evaluated=int(ex_data.get("exception_rules_evaluated", 15)),
        details=ex_data.get("details", {})
    )


# -----------------------------------------------------------------------------
# TAB 8: 360° Universal Explorer & Timeline
# -----------------------------------------------------------------------------
@router.get("/explorer", response_model=UniversalExplorerResponse)
def search_360_universal_explorer(
    query: str,
    branch_id: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Universal 360-degree transaction search by Client Code / Name / Ref (app.py L10646-10716)."""
    target_b_id = branch_id if branch_id not in ["All", "All Branches", None] else None
    if current_user.role in ["BM", "Branch Manager", "CO", "Officer"]:
        target_b_id = current_user.branch_id

    res = TransactionExplorerService.explore_transaction(uow, query, branch_id=target_b_id)
    return UniversalExplorerResponse(
        query=str(res.get("query", query)),
        found=bool(res.get("found", False)),
        loans=res.get("loans", []),
        repayments=res.get("repayments", []),
        savings=res.get("savings", []),
        fees=res.get("fees", []),
        treasury_transactions=res.get("treasury_transactions", []),
        ledger_transactions=res.get("ledger_transactions", []),
        audit_logs=res.get("audit_logs", [])
    )


@router.get("/explorer/loan-timeline", response_model=LoanTimelineResponse)
def get_loan_audit_timeline(
    loan_id: str,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Builds chronological audit timeline for a specific loan (app.py L10666-10670)."""
    timeline = TransactionExplorerService.build_loan_audit_timeline(uow, loan_id)
    return LoanTimelineResponse(loan_id=loan_id, timeline=timeline)


# -----------------------------------------------------------------------------
# TAB 9: Executive Performance Insights
# -----------------------------------------------------------------------------
@router.get("/performance-insights", response_model=RiskDistributionResponse)
def get_performance_insights(
    branch_id: Optional[str] = None,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Returns risk distribution breakdown for branch portfolio (app.py L10720-10730)."""
    target_b_id = branch_id or current_user.branch_id
    risk_dist = ClientRiskRatingService.get_branch_risk_distribution(uow, target_b_id)
    dist = {
        "EXCELLENT": int(risk_dist.get("EXCELLENT", 0)),
        "GOOD": int(risk_dist.get("GOOD", 0)),
        "FAIR": int(risk_dist.get("FAIR", 0)),
        "RISKY": int(risk_dist.get("RISKY", 0)),
        "HIGH_RISK": int(risk_dist.get("HIGH_RISK", 0)),
        "total_clients": int(risk_dist.get("total_clients", 0)),
    }
    return RiskDistributionResponse(branch_id=target_b_id, distribution=dist)


# -----------------------------------------------------------------------------
# TAB 10: Guided Reconciliation Wizard Repair
# -----------------------------------------------------------------------------
@router.post("/reconciliation-wizard/repair", response_model=ReconciliationRepairResponse)
def execute_reconciliation_wizard_repair(
    req: ReconciliationRepairRequest,
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Guided projection repair and 6-way integrity re-evaluation (app.py L10734-10746)."""
    try:
        rw_date = date.fromisoformat(req.reconciliation_date)
    except Exception:
        rw_date = date.today()

    repair_res = FinancialReconciliationService.run_reconciliation_wizard_repair(
        uow, req.branch_id, rw_date
    )
    verification = repair_res.get("verification_after_repair", {})
    variances = [
        VarianceItem(
            source=v.get("source", ""),
            expected=float(v.get("expected", 0.0)),
            actual=float(v.get("actual", 0.0)),
            variance=float(v.get("variance", 0.0)),
            cause=v.get("cause", "")
        )
        for v in verification.get("variances", [])
    ]
    is_bal = bool(verification.get("is_balanced", False))

    verif_resp = Integrity6WayResponse(
        branch_id=req.branch_id,
        posting_date=req.reconciliation_date,
        is_balanced=is_bal,
        status_text=str(verification.get("status_text", "Repaired")),
        status_badge="PERFECT_MATCH" if is_bal else "MISMATCH",
        ledger_total=float(verification.get("ledger_total", 0.0)),
        audit_views_total=float(verification.get("audit_views_total", 0.0)),
        co_cashbooks_total=float(verification.get("co_cashbooks_total", 0.0)),
        master_cashbook_total=float(verification.get("master_cashbook_total", 0.0)),
        dashboard_total=float(verification.get("dashboard_total", 0.0)),
        reports_total=float(verification.get("reports_total", 0.0)),
        variances=variances
    )

    return ReconciliationRepairResponse(
        rebuilt_officer_count=int(repair_res.get("rebuilt_officer_count", 0)),
        master_cashbook_rebuilt=bool(repair_res.get("master_cashbook_rebuilt", True)),
        verification_after_repair=verif_resp
    )


# -----------------------------------------------------------------------------
# CSV Export Endpoint
# -----------------------------------------------------------------------------
@router.get("/export-csv")
def export_audit_csv(
    ledger: str,  # fees, treasury, savings, loan_disbursements, repayments, collections
    date_from: Optional[str] = None,
    date_to: Optional[str] = None,
    fee_type: str = "ALL",
    category: str = "ALL",
    savings_ledger: str = "ALL",
    product_id: Optional[str] = None,
    branch_id: Optional[str] = None,
    officer_id: Optional[str] = None,
    compliance_status: str = "ALL",
    uow: SupabaseUnitOfWork = Depends(get_uow),
    current_user: CurrentUser = Depends(get_current_user),
):
    """Export filtered audit ledgers directly to clean CSV."""
    records = []
    filename = f"audit_{ledger}_{date.today().isoformat()}.csv"

    if ledger == "fees":
        resp = get_fees_audit_ledger(date_from, date_to, fee_type, branch_id, officer_id, None, uow, current_user)
        records = resp.records
    elif ledger == "treasury":
        resp = get_treasury_audit_ledger(date_from, date_to, category, branch_id, officer_id, None, uow, current_user)
        records = resp.records
    elif ledger == "savings":
        resp = get_savings_audit_ledger(date_from, date_to, savings_ledger, branch_id, officer_id, None, uow, current_user)
        records = resp.records
    elif ledger == "loan_disbursements":
        resp = get_loans_audit_ledger("Loan Disbursements", date_from, date_to, product_id, branch_id, officer_id, None, uow, current_user)
        records = resp.records
    elif ledger == "repayments":
        resp = get_loans_audit_ledger("Repayments", date_from, date_to, product_id, branch_id, officer_id, None, uow, current_user)
        records = resp.records
    elif ledger == "collections":
        resp = get_collections_audit_ledger(date_from, date_to, branch_id, officer_id, compliance_status, None, uow, current_user)
        records = resp.records

    clean_records = []
    for r in records:
        clean_records.append({k: v for k, v in r.items() if not k.endswith("_Raw") and not k.startswith("_")})

    output = io.StringIO()
    if clean_records:
        writer = csv.DictWriter(output, fieldnames=clean_records[0].keys())
        writer.writeheader()
        writer.writerows(clean_records)

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )
