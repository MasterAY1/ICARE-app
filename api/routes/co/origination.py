"""
CO Loan Origination & Client Registration route adapter.
Reuses domain entities, ScheduleService, RenewalService, LoanService,
and ClientStatusService directly against Supabase schema with 1:1 parity against app.py L3217–4838.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime, timedelta
import io
import json
import re
import uuid
from PIL import Image, ImageOps
from fastapi import APIRouter, Depends, HTTPException, Query, status, UploadFile, File, Form
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role, check_branch_access
from services.rbac_scope_service import RBACScopeService
from api.schemas.origination import (
    GroupOption, ClientSearchItem, ClientProfileDetails, GuarantorDetails,
    RegisterClientInput, RegisterClientResponse,
    EligibilityCheckRequest, EligibilityCheckResponse,
    SchedulePreviewRequest, SchedulePreviewItem, SchedulePreviewResponse,
    ApplyLoanInput, ApplyLoanResponse,
    PendingDisbursementsResponse, PendingLoanItem,
    DisburseLoanRequest, DisburseLoanResponse,
    RejectLoanApplicationRequest, RejectLoanApplicationResponse,
    BranchAssetCatalogResponse, AdjustBranchInventoryInput, AdjustBranchInventoryResponse,
    UpdateClientGuarantorInput, UpdateClientGuarantorResponse
)
from models.user import CurrentUser
from domain.entities.client import Client
from domain.entities.loan import Loan
from domain.enums import LoanStatus
from mappers.base_mappers import LoanMapper
from services.asset_inventory_service import AssetInventoryService
from services.loan_product_engine import LoanProductEngine
from services.schedule_service import ScheduleService
from services.renewal_service import RenewalService
from services.loan_service import LoanService
from services.client_status_service import ClientStatusService
from services.business_date_service import BusinessDateService

router = APIRouter(prefix="/api/v1/co/origination", tags=["CO Origination"])

_BM_DISBURSEMENT_CEILING = 300000.0
_ALLOWED_UPLOAD_EXTENSIONS = {"jpg", "jpeg", "png", "webp", "jfif", "pdf"}
_MAX_UPLOAD_BYTES = 10 * 1024 * 1024  # 10 MB


def _resolve_current_officer_id(current_user: CurrentUser, uow: SupabaseUnitOfWork) -> Optional[str]:
    """Resolves the active user's database officer UUID, safely handling mock repositories."""
    resolved = None
    if hasattr(uow, "loans") and hasattr(uow.loans, "_resolve_officer_id"):
        try:
            candidate = uow.loans._resolve_officer_id(current_user.username)
            if isinstance(candidate, (str, uuid.UUID)) and str(candidate).strip():
                resolved = str(candidate).strip()
        except Exception:
            resolved = None
    return resolved or current_user.id


def _verify_client_ownership(current_user: CurrentUser, uow: SupabaseUnitOfWork, client: Any, action: str) -> None:
    """Enforces branch scoping AND strict Credit Officer client ownership."""
    c_branch = getattr(client, "branch_id", None) if not isinstance(client, dict) else client.get("branch_id")
    check_branch_access(current_user, c_branch, action)
    norm_role = RBACScopeService.normalize_role(current_user.role)
    if norm_role == "CO":
        valid_ids = {str(current_user.id)} if current_user.id else set()
        resolved = _resolve_current_officer_id(current_user, uow)
        if resolved:
            valid_ids.add(str(resolved))
        c_officer = getattr(client, "officer_id", None) if not isinstance(client, dict) else client.get("officer_id")
        if c_officer and valid_ids and str(c_officer) not in valid_ids:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"You are not authorized to {action} for a client assigned to another officer."
            )


def _extract_guarantor_fallback(client: Any) -> Dict[str, Any]:
    """Parses structured guarantor metadata cached on clients.next_of_kin if present."""
    raw = getattr(client, "next_of_kin", None) if not isinstance(client, dict) else client.get("next_of_kin")
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str) and raw.strip().startswith("{"):
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            pass
    return {}


def _resolve_meeting_day(uow: SupabaseUnitOfWork, client_id: str, group_id: Optional[str] = None) -> str:
    """Resolves meeting day from client_memberships or clients.group_id."""
    try:
        res_m = (
            uow.client.table("client_memberships")
            .select("groups(meeting_day)")
            .eq("client_id", client_id)
            .is_("end_date", "null")
            .limit(1)
            .execute()
        )
        if res_m.data and isinstance(res_m.data[0].get("groups"), dict):
            md = res_m.data[0]["groups"].get("meeting_day") or ""
            if md:
                return str(md)
    except Exception:
        pass
    try:
        gid = group_id
        if not gid:
            c_res = uow.client.table("clients").select("group_id").eq("client_id", client_id).limit(1).execute()
            if c_res.data:
                gid = c_res.data[0].get("group_id")
        if gid:
            g_res = uow.client.table("groups").select("meeting_day").eq("group_id", gid).limit(1).execute()
            if g_res.data and g_res.data[0].get("meeting_day"):
                return str(g_res.data[0]["meeting_day"])
    except Exception:
        pass
    return ""


@router.get("/business-date")
def get_origination_business_date(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Returns the authoritative active business date for the user's branch."""
    b_date = BusinessDateService.get_business_date(uow, current_user.branch_id)
    return {"business_date": b_date.isoformat()}


@router.get("/asset-catalog", response_model=BranchAssetCatalogResponse)
def get_branch_asset_catalog(
    branch_id: Optional[str] = Query(None, description="Target branch ID (defaults to signed-in user branch)"),
    category: Optional[str] = Query(None, description="Filter by October 2026 category"),
    search: Optional[str] = Query(None, description="Search item name, SKU, or branch alias"),
    in_stock_only: bool = Query(False, description="Only return SKUs with available units > 0"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Procurement Officer", "Asset Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns the October 2026 Master Asset Price Catalog joined with live branch inventory.
    """
    target_branch_id = branch_id or current_user.branch_id
    if branch_id:
        check_branch_access(current_user, branch_id, "view branch asset inventory")
    res = AssetInventoryService.get_branch_asset_catalog(
        uow=uow,
        branch_id=target_branch_id,
        branch_name=None if branch_id else current_user.branch,
        category=category,
        search=search,
        in_stock_only=in_stock_only,
    )
    return BranchAssetCatalogResponse(**res)


@router.post("/branch-inventory/adjust", response_model=AdjustBranchInventoryResponse)
def adjust_branch_asset_inventory(
    payload: AdjustBranchInventoryInput,
    current_user: CurrentUser = Depends(require_role(["Procurement Officer", "Asset Manager"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Strictly restricted to Procurement Officer / Asset Manager to restock physical units or update cost & selling prices.
    """
    target_branch_id = payload.branch_id or current_user.branch_id
    if target_branch_id:
        check_branch_access(current_user, target_branch_id, "adjust branch asset inventory")
    try:
        updated_item = AssetInventoryService.adjust_branch_inventory(
            uow=uow,
            branch_id=target_branch_id,
            branch_name=None if payload.branch_id else current_user.branch,
            item_id=payload.item_id,
            quantity_delta=payload.quantity_delta,
            new_cash_price=payload.new_cash_price,
            new_cost_price=payload.new_cost_price,
            supplier_name=payload.supplier_name,
            reference_code=payload.reference_code,
            remarks=payload.remarks or "",
            performed_by=current_user.username,
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except RuntimeError as re_err:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(re_err))

    try:
        uow.client.table("audit_logs").insert({
            "id": str(uuid.uuid4()),
            "user_id": current_user.id,
            "action": "ADJUST_ASSET_INVENTORY",
            "description": f"Adjusted {updated_item['item_name']} ({updated_item['sku_code']}): delta={payload.quantity_delta:+d}, cash_price=₦{updated_item['cash_and_carry_price']:,.2f}",
            "table_name": "branch_asset_inventory",
            "record_id": updated_item["item_id"],
        }).execute()
    except Exception:
        pass

    return AdjustBranchInventoryResponse(
        success=True,
        message=f"Updated {updated_item['item_name']}: {updated_item['quantity_available']} available (₦{updated_item['cash_and_carry_price']:,.2f}).",
        item=updated_item,
    )


@router.get("/groups", response_model=List[GroupOption])
def get_origination_groups(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns active groups in the user's branch with duplicate name disambiguation (app.py L3355-3384).
    """
    branch_id = current_user.branch_id
    if not branch_id and current_user.branch:
        res_b = uow.client.table("branches").select("branch_id").eq("name", current_user.branch).execute()
        if res_b.data:
            branch_id = res_b.data[0]["branch_id"]

    query = uow.client.table("groups").select("group_id, name, group_number, meeting_day, officer_id, is_deleted")
    if branch_id:
        query = query.eq("branch_id", branch_id)

    norm_role = RBACScopeService.normalize_role(current_user.role)
    if norm_role == "CO":
        officer_id = _resolve_current_officer_id(current_user, uow)
        if officer_id:
            query = query.eq("officer_id", officer_id)

    res_g = query.execute()
    groups_list = [g for g in (res_g.data or []) if not g.get("is_deleted")]

    # Disambiguate duplicate group names matching Streamlit app.py L3370-3382
    counts: Dict[str, int] = {}
    for g in groups_list:
        gn = g.get("name", "")
        counts[gn] = counts.get(gn, 0) + 1

    options: List[GroupOption] = []
    for g in groups_list:
        gn = g.get("name", "")
        g_num = str(g.get("group_number") or "")
        m_day = str(g.get("meeting_day") or "Daily")
        if counts.get(gn, 1) > 1:
            lbl = f"{gn} (#{g_num} - {m_day})"
        else:
            lbl = gn

        options.append(GroupOption(
            group_id=str(g.get("group_id")),
            name=gn,
            group_number=g_num,
            meeting_day=m_day,
            display_label=lbl
        ))

    return options


@router.get("/search-clients", response_model=List[ClientSearchItem])
def search_clients_for_origination(
    q: str = Query(..., min_length=1, description="Client name or client code"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Searches clients by name or client_code with RBAC hierarchy filtering (app.py L4211-4238, L4587-4611).
    """
    found_clients = uow.clients.search_by_name_or_code(q)

    # RBAC hierarchy filtering
    norm_role = RBACScopeService.normalize_role(current_user.role)
    if norm_role == "CO":
        user_id = _resolve_current_officer_id(current_user, uow)
        found_clients = [c for c in found_clients if c.officer_id == user_id]
    elif norm_role == "Branch Manager" and current_user.branch_id:
        found_clients = [c for c in found_clients if c.branch_id == current_user.branch_id]
    elif norm_role == "Area Manager":
        allowed_branch_ids = getattr(current_user, "assigned_branch_ids", [])
        if allowed_branch_ids:
            found_clients = [c for c in found_clients if c.branch_id in allowed_branch_ids]

    items: List[ClientSearchItem] = []
    for c in found_clients:
        # Resolve group name
        g_name = "Individual (No Group)"
        if c.group_id:
            res_g = uow.client.table("groups").select("name").eq("group_id", c.group_id).execute()
            if res_g.data:
                g_name = res_g.data[0]["name"]

        # Resolve officer name
        o_name = "Unknown"
        if c.officer_id:
            res_u = uow.client.table("app_users").select("full_name").eq("id", c.officer_id).execute()
            if res_u.data:
                o_name = res_u.data[0]["full_name"]

        # Resolve pooled savings balance
        res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", c.id).execute()
        res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", c.id).execute()
        sav_bal = sum(float(d.get("deposit_amount") or 0) for d in (res_dep.data or [])) - sum(float(w.get("withdrawal_amount") or 0) for w in (res_wd.data or []))

        items.append(ClientSearchItem(
            client_id=str(c.id),
            client_code=str(c.client_code or "—"),
            name=str(c.name),
            group_name=g_name,
            officer_name=o_name,
            savings_balance=round(sav_bal, 2)
        ))

    return items


@router.get("/client-details/{client_id}", response_model=ClientProfileDetails)
def get_client_origination_details(
    client_id: str,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Fetches full client profile, pooled savings balance, and existing guarantor details (app.py L4240-4282, L4612-4691).
    """
    client = uow.clients.find_by_id(client_id)
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found.")

    # Guard: verify user is authorized to access client's branch & ownership
    _verify_client_ownership(current_user, uow, client, "view client origination details")

    # Branch name
    res_b = uow.client.table("branches").select("name").eq("branch_id", client.branch_id).execute() if client.branch_id else None
    branch_name = res_b.data[0]["name"] if res_b and res_b.data else (current_user.branch or "Unknown")

    # Group name
    res_g = uow.client.table("groups").select("name").eq("group_id", client.group_id).execute() if client.group_id else None
    group_name = res_g.data[0]["name"] if res_g and res_g.data else "Individual (No Group)"

    # Officer name
    res_u = uow.client.table("app_users").select("full_name").eq("id", client.officer_id).execute() if client.officer_id else None
    officer_name = res_u.data[0]["full_name"] if res_u and res_u.data else current_user.username

    # Pooled savings balance
    res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", client_id).execute()
    res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", client_id).execute()
    sav_bal = sum(float(d.get("deposit_amount") or 0) for d in (res_dep.data or [])) - sum(float(w.get("withdrawal_amount") or 0) for w in (res_wd.data or []))

    # Guarantor details: check latest loan extra_fields first, fallback to registration metadata on client
    guar_details = None
    res_l = uow.client.table("loans").select("*").eq("client_id", client_id).order("created_at", desc=True).limit(1).execute()
    latest_loan = res_l.data[0] if res_l and res_l.data else {}
    extra = latest_loan.get("extra_fields") or {}
    nok_g = _extract_guarantor_fallback(client)

    g_name = extra.get("guarantor_name") or nok_g.get("full_name") or nok_g.get("name") or ""
    g_phone = extra.get("guarantor_phone") or nok_g.get("phone") or ""

    if g_name or g_phone:
        guar_details = GuarantorDetails(
            full_name=g_name,
            nickname=extra.get("guarantor_nickname") or nok_g.get("nickname"),
            phone=g_phone,
            address=extra.get("guarantor_home_address") or nok_g.get("address"),
            marital_status=extra.get("guarantor_marital_status") or nok_g.get("marital_status") or "Married",
            occupation=extra.get("guarantor_occupation") or nok_g.get("occupation") or "Trader",
            relationship=extra.get("guarantor_relationship") or nok_g.get("relationship"),
            office_address=extra.get("guarantor_office_address") or nok_g.get("office_address"),
            id_means=latest_loan.get("guarantor_id_means") or nok_g.get("id_means") or "National ID (NIN)",
            id_number=latest_loan.get("guarantor_id_number") or nok_g.get("id_number"),
            id_card_url=latest_loan.get("guarantor_id_card_url") or nok_g.get("id_card_url"),
            passport_url=latest_loan.get("guarantor_passport_url") or nok_g.get("passport_url")
        )

    return ClientProfileDetails(
        client_id=str(client.id),
        client_code=str(client.client_code or "—"),
        name=str(client.name),
        nickname=client.nickname,
        phone=client.phone,
        address=client.address,
        marital_status=client.marital_status or "Single",
        business_type=client.business_type or "Trader",
        business_address=client.business_address,
        average_monthly_income=float(client.average_monthly_income or 0.0),
        other_obligations=client.other_obligations,
        id_means=client.id_means or "National ID (NIN)",
        id_number=client.id_number,
        id_card_url=client.id_card_url,
        passport_url=client.passport_url,
        branch_name=branch_name,
        group_name=group_name,
        officer_name=officer_name,
        savings_balance=round(sav_bal, 2),
        guarantor=guar_details
    )


@router.post("/check-eligibility", response_model=EligibilityCheckResponse)
def check_loan_eligibility(
    payload: EligibilityCheckRequest,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Evaluates loan renewal/origination eligibility via RenewalService (app.py L4372-4388).
    """
    client = uow.clients.find_by_id(payload.client_id)
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found.")
    _verify_client_ownership(current_user, uow, client, "check loan eligibility")

    is_eligible, reasons, warnings = RenewalService.check_eligibility(
        uow, payload.client_id, payload.requested_amount, payload.product_type, payload.product_category
    )
    return EligibilityCheckResponse(
        is_eligible=is_eligible,
        reasons=reasons,
        warnings=warnings
    )


@router.post("/preview-schedule", response_model=SchedulePreviewResponse)
def preview_loan_schedule(
    payload: SchedulePreviewRequest,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Generates an authoritative working-day, Nigerian holiday, and branch-closure adjusted
    amortization preview matching ScheduleService and LoanProductEngine.
    """
    if payload.requested_amount <= 0:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Requested amount must be greater than zero.")

    branch_id = current_user.branch_id
    meeting_day = ""
    if payload.client_id:
        client = uow.clients.find_by_id(payload.client_id)
        if client:
            _verify_client_ownership(current_user, uow, client, "preview loan schedule")
            branch_id = client.branch_id or branch_id
            meeting_day = _resolve_meeting_day(uow, payload.client_id, client.group_id)

    base_date = (
        date.fromisoformat(payload.application_date)
        if payload.application_date
        else BusinessDateService.get_business_date(uow, branch_id)
    )
    closures = BusinessDateService.get_branch_closures(uow, branch_id) if branch_id else []
    closed_dates = BusinessDateService.expand_closure_dates(closures)

    setup = LoanProductEngine.calculate_loan_setup(
        payload.requested_amount, payload.product_type, payload.product_category
    )
    interest = float(setup.get("interest", 0.0))
    duration = int(setup.get("duration", 12) or 1)
    cycle = str(setup.get("freq", "Weekly"))

    initial_dp = max(0.0, float(payload.cash_downpayment or 0.0) + float(payload.savings_downpayment or 0.0))
    gap_fee = max(0.0, float(payload.gap_fee or 0.0))

    if payload.product_category == "Asset":
        total_cost = payload.requested_amount + interest
        active_credit = max(0.0, total_cost - initial_dp)
        expected_inst = round(active_credit / duration, 2) if duration > 0 else 0.0
        total_upfront = 0.0
        gap_fee = 0.0
    elif "cash and carry" in payload.product_type.lower() or "cash & carry" in payload.product_type.lower():
        active_credit = payload.requested_amount
        expected_inst = payload.requested_amount
        gap_fee = 0.0
        total_upfront = 0.0
    else:
        active_credit = max(0.0, payload.requested_amount - gap_fee)
        expected_inst = round(active_credit / duration, 2) if duration > 0 else 0.0
        total_upfront = interest + gap_fee

    if cycle == "One-Time" or "cash and carry" in payload.product_type.lower() or "cash & carry" in payload.product_type.lower():
        return SchedulePreviewResponse(
            product_type=payload.product_type,
            product_category=payload.product_category,
            frequency="One-Time",
            duration=1,
            interest=round(interest, 2),
            active_credit=round(active_credit, 2),
            expected_installment=round(expected_inst, 2),
            gap_fee=0.0,
            total_upfront_required=round(total_upfront, 2),
            first_due_date=base_date.isoformat(),
            expected_end_date=base_date.isoformat(),
            installments=[],
        )

    dates = LoanProductEngine.generate_repayment_schedule(
        start_date=base_date,
        duration=duration,
        frequency=cycle,
        meeting_day=meeting_day,
        closed_dates=closed_dates,
    )

    inst_principal = round(active_credit / duration, 2) if duration > 0 else 0.0
    items: List[SchedulePreviewItem] = []
    for idx, d in enumerate(dates, start=1):
        p_val = inst_principal + (gap_fee if idx == 1 and payload.product_category != "Asset" and gap_fee > 0 else 0.0)
        items.append(SchedulePreviewItem(
            installment_number=idx,
            due_date=d.isoformat(),
            principal=round(p_val, 2),
            interest=0.0,
            total_due=round(p_val, 2),
        ))

    return SchedulePreviewResponse(
        product_type=payload.product_type,
        product_category=payload.product_category,
        frequency=cycle,
        duration=duration,
        interest=round(interest, 2),
        active_credit=round(active_credit, 2),
        expected_installment=round(expected_inst, 2),
        gap_fee=round(gap_fee, 2),
        total_upfront_required=round(total_upfront, 2),
        first_due_date=dates[0].isoformat() if dates else base_date.isoformat(),
        expected_end_date=dates[-1].isoformat() if dates else base_date.isoformat(),
        installments=items,
    )


@router.post("/register-client", response_model=RegisterClientResponse)
def register_client(
    payload: RegisterClientInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Registers a new client and guarantor into the database (app.py L3335-3630).
    """
    name_val = payload.full_name.strip()
    phone_val = payload.phone.strip()

    if not name_val or not phone_val:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Name and Phone are required!")

    # Resolve branch (Fail closed: never fallback to hardcoded strings)
    branch_name = current_user.branch
    branch_id = current_user.branch_id
    if not branch_id and branch_name:
        res_b = uow.client.table("branches").select("branch_id, code").eq("name", branch_name).execute()
        if res_b.data:
            branch_id = res_b.data[0]["branch_id"]
            branch_code = res_b.data[0]["code"] or branch_name[:3].upper()
        else:
            branch_code = branch_name[:3].upper()
    elif branch_id:
        res_b = uow.client.table("branches").select("name, code").eq("branch_id", branch_id).execute()
        if res_b.data:
            branch_name = res_b.data[0].get("name") or branch_name
            branch_code = res_b.data[0].get("code") or (branch_name or "BRN")[:3].upper()
        else:
            branch_code = (branch_name or "BRN")[:3].upper()
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Authenticated user has no valid branch assignment. Cannot register client."
        )

    officer_id = _resolve_current_officer_id(current_user, uow)
    norm_role = RBACScopeService.normalize_role(current_user.role)
    reg_date = (
        date.fromisoformat(payload.registration_date)
        if payload.registration_date
        else BusinessDateService.get_business_date(uow, branch_id)
    )

    operations: List[Dict[str, Any]] = []

    # 1. Group creation / resolution (atomic with client insert when creating new group)
    final_group_id = None
    final_group_number = ""
    is_new_group_created = False

    if payload.group_mode == "+ Create New Group":
        new_g_name = (payload.new_group_name or "").strip()
        new_g_num = str(payload.new_group_number or "").strip()
        meeting_day = payload.new_group_meeting_day or "Daily"

        if not new_g_name or not new_g_num:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Please enter the Group Name and Group Number.")

        res_eg = uow.client.table("groups").select("group_id, group_number, officer_id").eq("branch_id", branch_id).eq("group_number", new_g_num).execute()
        if res_eg.data:
            final_group_id = res_eg.data[0]["group_id"]
            final_group_number = str(res_eg.data[0].get("group_number") or "")
            if norm_role == "CO" and res_eg.data[0].get("officer_id") and str(res_eg.data[0]["officer_id"]) != str(officer_id):
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Existing group belongs to another officer.")
        else:
            final_group_id = str(uuid.uuid4())
            final_group_number = new_g_num
            is_new_group_created = True
            operations.append({
                "type": "insert",
                "table": "groups",
                "record": {
                    "group_id": final_group_id,
                    "name": new_g_name,
                    "group_number": new_g_num,
                    "meeting_day": meeting_day,
                    "branch_id": branch_id,
                    "officer_id": officer_id,
                    "status": "Active",
                    "current_member_sequence": 1,
                },
            })
    elif payload.group_mode != "Individual (No Group)":
        if payload.group_id:
            res_g = uow.client.table("groups").select("group_id, group_number, branch_id, officer_id").eq("group_id", payload.group_id).execute()
            if not res_g.data or str(res_g.data[0].get("branch_id")) != str(branch_id):
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Selected group not found in your branch.")
            if norm_role == "CO" and res_g.data[0].get("officer_id") and str(res_g.data[0]["officer_id"]) != str(officer_id):
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Selected group is not assigned to you.")
            final_group_id = res_g.data[0]["group_id"]
            final_group_number = str(res_g.data[0].get("group_number") or "")
        else:
            base_group_name = re.sub(r"\s*\(#.*\)\s*$", "", str(payload.group_mode or "").strip()).strip()
            res_g = uow.client.table("groups").select("group_id, group_number, officer_id").eq("branch_id", branch_id).eq("name", base_group_name).execute()
            if not res_g.data:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Selected group '{payload.group_mode}' not found in your branch.")
            if len(res_g.data) > 1 and norm_role == "CO":
                matching = [g for g in res_g.data if str(g.get("officer_id")) == str(officer_id)]
                g_row = matching[0] if matching else res_g.data[0]
            else:
                g_row = res_g.data[0]
            final_group_id = g_row["group_id"]
            final_group_number = str(g_row.get("group_number") or "")

    # 2. Sequential Client Code Generation
    if not final_group_id:
        g_code = "IND"
        res_count = uow.client.table("clients").select("client_id", count="exact").is_("group_id", "null").eq("branch_id", branch_id).execute()
        next_seq = (res_count.count or 0) + 1
    else:
        digits_match = re.findall(r'\d+', str(final_group_number))
        g_code = digits_match[-1].zfill(2) if digits_match else str(final_group_number).zfill(2)
        next_seq = 1 if is_new_group_created else uow.clients.get_next_member_sequence(final_group_id)

    member_number_str = str(next_seq).zfill(3)
    generated_client_code = f"{branch_code}-{g_code}-{member_number_str}"
    client_uuid = str(uuid.uuid4())
    status_id = ClientStatusService.resolve_status_id(uow, "Registered")
    if not status_id:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Client lifecycle status 'Registered' is not configured in database."
        )

    # Persist structured guarantor metadata on clients.next_of_kin so Tab 2 and /apply inherit it pre-loan
    nok_payload = None
    if payload.guarantor and payload.guarantor.full_name and payload.guarantor.full_name.strip():
        g = payload.guarantor
        nok_payload = json.dumps({
            "full_name": g.full_name.strip(),
            "nickname": g.nickname.strip() if g.nickname else None,
            "phone": (g.phone or "").strip(),
            "address": (g.address or "").strip(),
            "marital_status": g.marital_status or "Single",
            "occupation": (g.occupation or "Trader").strip(),
            "relationship": (g.relationship or "").strip(),
            "office_address": (g.office_address or "").strip(),
            "id_means": g.id_means or "National ID (NIN)",
            "id_number": (g.id_number or "").strip(),
            "id_card_url": payload.guarantor_id_card_url or "",
            "passport_url": payload.guarantor_passport_url or "",
        })

    # 3. Client insert operation
    operations.append({
        "type": "insert",
        "table": "clients",
        "record": {
            "client_id": client_uuid,
            "name": name_val,
            "client_code": generated_client_code,
            "nickname": payload.nickname,
            "phone": phone_val,
            "address": payload.address or "",
            "business_address": payload.business_address,
            "marital_status": payload.marital_status,
            "occupation": "Trader",
            "business_type": payload.business_type,
            "id_means": payload.id_means,
            "id_number": payload.id_number,
            "id_card_url": payload.id_card_url or "",
            "next_of_kin": nok_payload or "",
            "passport_url": payload.passport_url or "",
            "registration_date": reg_date.isoformat(),
            "branch_id": branch_id,
            "group_id": final_group_id,
            "officer_id": officer_id,
            "status": "Registered",
            "status_id": status_id,
            "status_changed_by": current_user.id or officer_id,
            "status_note": f"Client registered by {current_user.username}",
            "average_monthly_income": float(payload.average_monthly_income or 0.0),
            "other_obligations": payload.other_obligations,
        },
    })

    # 4. Create membership + initial status history
    if final_group_id:
        operations.append({
            "type": "insert",
            "table": "client_memberships",
            "record": {
                "membership_id": str(uuid.uuid4()),
                "client_id": client_uuid,
                "group_id": final_group_id,
                "branch_id": branch_id,
                "officer_id": officer_id,
                "start_date": reg_date.isoformat(),
            },
        })

    operations.append({
        "type": "insert",
        "table": "client_status_history",
        "record": {
            "id": str(uuid.uuid4()),
            "client_id": client_uuid,
            "old_status_id": None,
            "new_status_id": status_id,
            "changed_by": current_user.id or officer_id,
            "reason": f"Client registered ({generated_client_code})",
            "trigger_type": "MANUAL",
            "trigger_reference": client_uuid,
        },
    })

    # 5. Save Guarantor details atomically if provided
    if payload.guarantor and payload.guarantor.full_name and payload.guarantor.full_name.strip():
        g = payload.guarantor
        g_name_val = g.full_name.strip()
        g_phone_val = (g.phone or "").strip()
        existing_g = uow.guarantors.find_by_phone(g_phone_val) if g_phone_val else None
        if not existing_g:
            operations.append({
                "type": "insert",
                "table": "guarantors",
                "record": {
                    "guarantor_id": str(uuid.uuid4()),
                    "name": g_name_val,
                    "phone": g_phone_val,
                    "address": (g.address or "").strip(),
                    "occupation": (g.occupation or "Trader").strip(),
                    "business_address": (g.office_address or "").strip(),
                    "id_means": g.id_means,
                    "id_number": (g.id_number or "").strip(),
                    "id_card_url": payload.guarantor_id_card_url or "",
                    "passport_url": payload.guarantor_passport_url or "",
                },
            })

    operations.append({
        "type": "insert",
        "table": "audit_logs",
        "record": {
            "id": str(uuid.uuid4()),
            "user_id": current_user.id or officer_id,
            "action": "REGISTER_CLIENT",
            "description": f"Registered client {name_val} ({generated_client_code})",
            "table_name": "clients",
            "record_id": client_uuid,
        },
    })

    uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

    return RegisterClientResponse(
        success=True,
        client_id=client_uuid,
        client_code=generated_client_code,
        message=f"Successfully registered {name_val}. Assigned Client ID: {generated_client_code}"
    )


@router.post("/upload-document")
async def upload_document(
    file: UploadFile = File(...),
    category: str = Form("passport"),
    client_id: Optional[str] = Form(None),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Uploads and optimizes client identity documents & passport photos to Supabase Storage.
    Automatically compresses and downsamples camera captures to <= 1000px and JPEG quality 75 (~50-120 KB).
    """
    raw_bytes = await file.read()
    if not raw_bytes:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty.")
    if len(raw_bytes) > _MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Uploaded file exceeds maximum allowed size of 10 MB.")

    if client_id:
        c_obj = uow.clients.find_by_id(client_id)
        if not c_obj:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found for document upload.")
        _verify_client_ownership(current_user, uow, c_obj, "upload documents")

    filename = file.filename or "upload"
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in _ALLOWED_UPLOAD_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported file format '.{ext or 'unknown'}'. Allowed formats: JPG, JPEG, PNG, WEBP, PDF."
        )

    is_image = ext in {"jpg", "jpeg", "png", "webp", "jfif"}
    target_bytes = raw_bytes
    target_content_type = "application/pdf" if ext == "pdf" else "image/jpeg"
    target_ext = ext

    if is_image:
        try:
            img = Image.open(io.BytesIO(raw_bytes))
            try:
                img = ImageOps.exif_transpose(img)
            except Exception:
                pass

            if img.mode in ("RGBA", "P", "LA"):
                img = img.convert("RGB")

            max_dimension = 1000
            if img.width > max_dimension or img.height > max_dimension:
                img.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)

            out_buf = io.BytesIO()
            img.save(out_buf, format="JPEG", quality=75, optimize=True)
            target_bytes = out_buf.getvalue()
            target_content_type = "image/jpeg"
            target_ext = "jpg"
        except Exception:
            pass

    folder_id = client_id or str(uuid.uuid4())
    safe_category = re.sub(r'[^a-zA-Z0-9_-]', '_', category)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    storage_path = f"{folder_id}/{safe_category}_{timestamp}.{target_ext}"

    try:
        buckets = uow.client.storage.list_buckets()
        bucket_names = [b.name for b in buckets]
        if "client-ids" not in bucket_names:
            uow.client.storage.create_bucket("client-ids", options={"public": True})
    except Exception:
        pass

    try:
        uow.client.storage.from_("client-ids").upload(
            path=storage_path,
            file=target_bytes,
            file_options={"content-type": target_content_type}
        )
    except Exception:
        try:
            uow.client.storage.from_("client-ids").remove([storage_path])
            uow.client.storage.from_("client-ids").upload(
                path=storage_path,
                file=target_bytes,
                file_options={"content-type": target_content_type}
            )
        except Exception as upload_err:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to store file: {upload_err}")

    public_url = uow.client.storage.from_("client-ids").get_public_url(storage_path)

    return {
        "success": True,
        "url": public_url,
        "file_name": filename,
        "size_kb": round(len(target_bytes) / 1024.0, 1),
        "category": category
    }


@router.post("/apply", response_model=ApplyLoanResponse)
def apply_for_loan(
    payload: ApplyLoanInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a loan application and generates repayment schedule (app.py L4284-4582).
    """
    if payload.requested_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Requested amount must be greater than zero."
        )

    # 1. Verify client exists
    client = uow.clients.find_by_id(payload.client_id)
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found.")

    # Guard: verify branch AND CO officer ownership
    _verify_client_ownership(current_user, uow, client, "submit loan application")

    # Guard: check allowed products assignment if defined for credit officer
    norm_role = RBACScopeService.normalize_role(current_user.role)
    if norm_role == "CO" and current_user.allowed_products:
        normalized_allowed = [p.strip().lower() for p in current_user.allowed_products]
        if payload.product_type.strip().lower() not in normalized_allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"You are not authorized to originate loans for '{payload.product_type}'. Please select from your assigned products: {', '.join(current_user.allowed_products)}."
            )

    # Resolve branch up front so catalog & stock checks scope accurately
    res_b = uow.client.table("branches").select("name").eq("branch_id", client.branch_id).execute() if client.branch_id else None
    loan_branch_name = res_b.data[0]["name"] if res_b and isinstance(res_b.data, list) and res_b.data else (current_user.branch or "")
    loan_branch_id = client.branch_id or current_user.branch_id

    # Validate selected physical assets from branch stock and lock authoritative catalog base price
    resolved_asset_items: List[Dict[str, Any]] = []
    resolved_asset_summary = ""
    if payload.selected_assets:
        try:
            asset_check = AssetInventoryService.validate_selected_assets(
                uow=uow,
                branch_id=loan_branch_id,
                branch_name=loan_branch_name,
                selected_assets=payload.selected_assets,
            )
            resolved_asset_items = asset_check["asset_items"]
            resolved_asset_summary = asset_check["asset_summary"]
            if asset_check["total_cash_price"] > 0:
                payload.requested_amount = float(asset_check["total_cash_price"])
        except ValueError as stock_err:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(stock_err),
            )

    # 1b. Enforce authoritative RenewalService eligibility gate on server
    is_eligible, elig_reasons, _elig_warnings = RenewalService.check_eligibility(
        uow, payload.client_id, payload.requested_amount, payload.product_type, payload.product_category
    )
    if not is_eligible:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Client is not eligible for this loan: {'; '.join(elig_reasons)}"
        )

    # 2. Check savings balance
    res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", payload.client_id).execute()
    res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", payload.client_id).execute()
    savings_bal = sum(float(d.get("deposit_amount") or 0) for d in (res_dep.data or [])) - sum(float(w.get("withdrawal_amount") or 0) for w in (res_wd.data or []))
    if savings_bal == 0.0 and hasattr(uow, "individual_savings") and hasattr(uow.individual_savings, "get_total_balance"):
        try:
            repo_bal = uow.individual_savings.get_total_balance(client_id=payload.client_id)
            if repo_bal:
                savings_bal = float(repo_bal)
        except Exception:
            pass

    # 3. Product parameters & interest calculation via authoritative LoanProductEngine
    setup = LoanProductEngine.calculate_loan_setup(
        payload.requested_amount, payload.product_type, payload.product_category
    )
    interest = float(setup.get("interest", 0.0))
    duration = int(setup.get("duration", 12) or 1)
    cycle = str(setup.get("freq", "Weekly"))
    is_cash_and_carry = (
        "cash and carry" in payload.product_type.lower()
        or "cash & carry" in payload.product_type.lower()
        or cycle == "One-Time"
    )

    # 4. Financial Calculations
    cash_dp = max(0.0, float(payload.cash_downpayment or 0.0))
    sav_dp = max(0.0, float(payload.savings_downpayment or 0.0))
    initial_downpayment = cash_dp + sav_dp
    gap_fee = 0.0 if (payload.product_category == "Asset" or is_cash_and_carry) else max(0.0, float(payload.gap_fee or 0.0))
    total_upfront_required = 0.0 if (payload.product_category == "Asset" or is_cash_and_carry) else (interest + gap_fee)

    if payload.product_category == "Asset":
        total_cost = payload.requested_amount + interest
        if initial_downpayment > total_cost:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Total downpayment cannot exceed total asset cost."
            )
        final_active_credit = max(0.0, total_cost - initial_downpayment)
        final_total_payable = final_active_credit
        final_expected_installment = round(final_active_credit / duration, 2) if duration > 0 else 0.0

        if sav_dp > 0 and savings_bal < sav_dp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"INSUFFICIENT SAVINGS: Client has ₦{savings_bal:,.2f} but needs ₦{sav_dp:,.2f} from savings for downpayment."
            )
    else:
        if gap_fee > payload.requested_amount:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Gap fee cannot exceed requested loan amount."
            )
        final_active_credit = payload.requested_amount - gap_fee
        final_total_payable = final_active_credit
        final_expected_installment = round(final_active_credit / duration, 2) if duration > 0 else 0.0

        if total_upfront_required > 0 and savings_bal < total_upfront_required:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"INSUFFICIENT SAVINGS: Client has ₦{savings_bal:,.2f} but needs ₦{total_upfront_required:,.2f}. Please collect additional savings first."
            )

    # 5. Active / Pending loan duplicate validation with Auto-Heal
    check_prod_cat = payload.product_category
    res_existing = uow.client.table("loans").select("*").eq("client_id", payload.client_id).eq("status", "Pending").execute()
    res_active = uow.client.table("loans").select("*").eq("client_id", payload.client_id).eq("status", "Active").execute()

    is_blocked = False
    for L in (res_existing.data or []) + (res_active.data or []):
        if L.get("product_category", "Finance") == check_prod_cat and float(L.get("loan_amount", 0)) > 0:
            if L.get("status") == "Active":
                lid = L.get("loan_id")
                act_c = float(L.get("active_credit") or L.get("loan_amount") or 0.0)
                tot_d = float(L.get("total_due") if L.get("total_due") is not None else act_c)
                rep_res = uow.client.table("repayments").select("amount_paid").eq("loan_id", lid).execute()
                tot_p = sum(float(r.get("amount_paid") or 0.0) for r in (rep_res.data or []))
                if max(0.0, tot_d - tot_p) <= 0.0:
                    ClientStatusService.on_loan_repayment_check(uow, payload.client_id, lid)
                    continue
            is_blocked = True

    if is_blocked:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot submit: This client already has an Active or Pending {check_prod_cat} loan."
        )

    # 6. Create Loan Entity + Provisional Schedule + Client Status atomically
    loan_id = str(uuid.uuid4())
    app_date = (
        date.fromisoformat(payload.application_date)
        if payload.application_date
        else BusinessDateService.get_business_date(uow, loan_branch_id)
    )

    # Resolve product_id
    product_id = None
    try:
        res_p = uow.client.table("loan_products").select("product_id").eq("name", payload.product_type).limit(1).execute()
        if isinstance(res_p.data, list) and res_p.data:
            product_id = res_p.data[0].get("product_id")
    except Exception:
        pass
    if not product_id and hasattr(uow, "loans") and hasattr(uow.loans, "_resolve_product_id"):
        try:
            p_cand = uow.loans._resolve_product_id(payload.product_type)
            if isinstance(p_cand, (str, uuid.UUID)) and str(p_cand).strip():
                product_id = str(p_cand).strip()
        except Exception:
            product_id = None
    if not product_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unknown loan product '{payload.product_type}'.")

    # Compute provisional schedule dates based on branch closures + group meeting day
    meeting_day = _resolve_meeting_day(uow, payload.client_id, getattr(client, "group_id", None))
    closures = BusinessDateService.get_branch_closures(uow, loan_branch_id) if loan_branch_id else []
    closed_dates = BusinessDateService.expand_closure_dates(closures)
    if is_cash_and_carry:
        sched_dates = [app_date]
    else:
        sched_dates = LoanProductEngine.generate_repayment_schedule(
            start_date=app_date,
            duration=duration,
            frequency=cycle,
            meeting_day=meeting_day,
            closed_dates=closed_dates,
        )
    prov_start_date = sched_dates[0] if sched_dates else app_date
    prov_end_date = sched_dates[-1] if sched_dates else app_date

    # Inherit guarantor metadata from registration / latest loan so it stays visible pre-disbursement
    nok_g = _extract_guarantor_fallback(client)
    res_prev_l = uow.client.table("loans").select("extra_fields, guarantor_id_means, guarantor_id_number, guarantor_id_card_url, guarantor_passport_url").eq("client_id", payload.client_id).order("created_at", desc=True).limit(1).execute()
    prev_l = res_prev_l.data[0] if res_prev_l and isinstance(res_prev_l.data, list) and res_prev_l.data and isinstance(res_prev_l.data[0], dict) else {}
    prev_extra = prev_l.get("extra_fields") if isinstance(prev_l.get("extra_fields"), dict) else {}

    combined_notes = (payload.notes or "").strip()
    if resolved_asset_summary and resolved_asset_summary not in combined_notes:
        combined_notes = f"{resolved_asset_summary}" + (f" | {combined_notes}" if combined_notes else "")

    loan_extra = {
        "lifecycle_status": "Submitted",
        "product_type": payload.product_type,
        "notes": combined_notes,
        "product_category": payload.product_category,
        "downpayment_source": payload.downpayment_mode if payload.product_category == "Asset" else None,
        "downpayment_cash": cash_dp if payload.product_category == "Asset" else 0.0,
        "downpayment_savings": sav_dp if payload.product_category == "Asset" else 0.0,
        "initial_downpayment": initial_downpayment,
        "active_credit": final_active_credit,
        "loan_repay": final_expected_installment,
        "total_due": final_active_credit,
        "gap_fee": gap_fee,
        "upfront_interest": interest if (payload.product_category == "Finance" and not is_cash_and_carry) else 0.0,
        "total_upfront_required": total_upfront_required,
        "asset_items": resolved_asset_items,
        "asset_summary": resolved_asset_summary or None,
        "guarantor_name": prev_extra.get("guarantor_name") or nok_g.get("full_name") or nok_g.get("name"),
        "guarantor_nickname": prev_extra.get("guarantor_nickname") or nok_g.get("nickname"),
        "guarantor_phone": prev_extra.get("guarantor_phone") or nok_g.get("phone"),
        "guarantor_home_address": prev_extra.get("guarantor_home_address") or nok_g.get("address"),
        "guarantor_marital_status": prev_extra.get("guarantor_marital_status") or nok_g.get("marital_status"),
        "guarantor_occupation": prev_extra.get("guarantor_occupation") or nok_g.get("occupation"),
        "guarantor_relationship": prev_extra.get("guarantor_relationship") or nok_g.get("relationship"),
        "guarantor_office_address": prev_extra.get("guarantor_office_address") or nok_g.get("office_address"),
    }

    officer_uid = getattr(client, "officer_id", None) or current_user.id
    loan_entity = Loan(
        id=loan_id,
        client_id=payload.client_id,
        client_name=client.name,
        product_type=payload.product_type,
        amount=payload.requested_amount,
        duration=duration,
        frequency=cycle,
        gap_fee=gap_fee,
        expected_installment=final_expected_installment,
        total_payable=final_total_payable,
        status=LoanStatus.PENDING,
        branch=loan_branch_name,
        credit_officer=current_user.username,
        officer_id=officer_uid,
        branch_id=loan_branch_id,
        start_date=prov_start_date,
        end_date=prov_end_date,
        is_asset=(payload.product_category == "Asset"),
        extra_fields=loan_extra,
    )

    operations: List[Dict[str, Any]] = [
        {
            "type": "insert",
            "table": "loans",
            "record": {
                "loan_id": loan_id,
                "client_id": payload.client_id,
                "product_id": product_id,
                "branch_id": loan_branch_id,
                "officer_id": officer_uid,
                "date": app_date.isoformat(),
                "loan_amount": round(payload.requested_amount, 2),
                "active_credit": round(final_active_credit, 2),
                "loan_repay": round(final_expected_installment, 2),
                "total_due": round(final_total_payable, 2),
                "status": "Pending",
                "product_category": payload.product_category,
                "start_date": prov_start_date.isoformat(),
                "expected_end_date": prov_end_date.isoformat(),
                "disbursement_date": None,
                "extra_fields": loan_extra,
                "guarantor_id_means": prev_l.get("guarantor_id_means") or nok_g.get("id_means"),
                "guarantor_id_number": prev_l.get("guarantor_id_number") or nok_g.get("id_number"),
                "guarantor_id_card_url": prev_l.get("guarantor_id_card_url") or nok_g.get("id_card_url"),
                "guarantor_passport_url": prev_l.get("guarantor_passport_url") or nok_g.get("passport_url"),
            },
        }
    ]

    # 7. Update client status to 'Pending Loan' inside atomic batch (BR-CLI-003.1)
    ClientStatusService.on_loan_submitted(
        uow, payload.client_id, loan_id, officer_uid, defer_operations=operations
    )

    # 8. Generate scheduled installments inside atomic batch
    if not is_cash_and_carry:
        ScheduleService.generate_schedule(uow, loan_entity, app_date, defer_operations=operations)

    operations.append({
        "type": "insert",
        "table": "audit_logs",
        "record": {
            "id": str(uuid.uuid4()),
            "user_id": current_user.id or officer_uid,
            "action": "SUBMIT_LOAN_APPLICATION",
            "description": f"Submitted {payload.product_category} ({payload.product_type}) loan application {loan_id[:8]} for {client.name} (₦{payload.requested_amount:,.2f})",
            "table_name": "loans",
            "record_id": loan_id,
        },
    })

    uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

    if resolved_asset_items:
        AssetInventoryService.reserve_stock_for_loan(
            uow=uow,
            branch_id=loan_branch_id,
            loan_id=loan_id,
            asset_items=resolved_asset_items,
            performed_by=current_user.username,
        )

    # Link guarantor row if available
    g_phone_link = loan_extra.get("guarantor_phone")
    if g_phone_link:
        try:
            g_found = uow.guarantors.find_by_phone(g_phone_link)
            if g_found:
                from domain.entities.guarantor import LoanGuarantor
                uow.guarantors.link_to_loan(LoanGuarantor(
                    id=str(uuid.uuid4()),
                    loan_id=loan_id,
                    guarantor_id=g_found.guarantor_id,
                    relationship=loan_extra.get("guarantor_relationship") or "",
                ))
        except Exception:
            pass

    return ApplyLoanResponse(
        success=True,
        loan_id=loan_id,
        active_credit=final_active_credit,
        expected_installment=final_expected_installment,
        status="Pending",
        message="Application submitted successfully! Repayment schedule generated and loan is Pending Branch Manager Approval."
    )


@router.get("/pending", response_model=PendingDisbursementsResponse)
def get_pending_disbursements(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns pending loan applications with columns matching Streamlit app.py L3234-3250.
    """
    branch_id = current_user.branch_id
    officer_id = _resolve_current_officer_id(current_user, uow)

    query = uow.client.table("loans").select(
        "loan_id, client_id, loan_amount, active_credit, date, status, product_category, officer_id, branch_id, extra_fields, is_deleted, clients(name, client_code, group_id), app_users(username, full_name), loan_products(name)"
    ).eq("status", "Pending")

    norm_role = RBACScopeService.normalize_role(current_user.role)
    if norm_role == "CO":
        query = query.eq("officer_id", officer_id)
    elif norm_role == "Branch Manager" and branch_id:
        query = query.eq("branch_id", branch_id)
    elif norm_role == "Area Manager":
        allowed_ids = getattr(current_user, "assigned_branch_ids", [])
        if allowed_ids:
            query = query.in_("branch_id", allowed_ids)

    res = query.order("created_at", desc=True).limit(100).execute()
    loans: List[PendingLoanItem] = []

    # Pre-cache groups for group_name resolution
    res_all_groups = uow.client.table("groups").select("group_id, name").execute()
    group_map = {str(g["group_id"]): g["name"] for g in (res_all_groups.data or [])}

    for l in (res_data := (res.data or [])):
        if l.get("is_deleted"):
            continue
        amt = float(l.get("loan_amount") or 0.0)
        if amt <= 0:
            continue

        c = l.get("clients") or {}
        c_name = c.get("name") or "Unknown Client"
        c_code = c.get("client_code")
        gid = str(c.get("group_id") or "")
        grp_name = group_map.get(gid, "-")

        u = l.get("app_users") or {}
        officer_name = u.get("full_name") or u.get("username") or current_user.username

        lp = l.get("loan_products") or {}
        extra = l.get("extra_fields") or {}
        prod_name = lp.get("name") or extra.get("product_type") or "Unspecified Product"
        prod_cat = l.get("product_category") or extra.get("product_category") or "Finance"

        loans.append(PendingLoanItem(
            loan_id=str(l.get("loan_id")),
            client_id=str(l.get("client_id")),
            client_name=c_name,
            client_code=c_code,
            group_name=grp_name,
            date=str(l.get("date") or ""),
            credit_officer=officer_name,
            loan_amount=amt,
            loan_product=prod_name,
            product_category=prod_cat,
            exceeds_bm_limit=(norm_role == "Branch Manager" and amt > _BM_DISBURSEMENT_CEILING),
            asset_summary=extra.get("asset_summary"),
            selected_assets=extra.get("asset_items"),
        ))

    can_auth = current_user.role in ["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"]
    return PendingDisbursementsResponse(
        pending_loans=loans,
        can_authorize=can_auth
    )


@router.post("/disburse", response_model=DisburseLoanResponse)
def disburse_loan(
    payload: DisburseLoanRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Checker Action: Authorizes and activates disbursement (app.py L3252-3332).
    """
    disb_date = date.fromisoformat(payload.disbursement_date)
    today_str = disb_date.strftime("%Y-%m-%d")

    # 1. Find target loan with product, branch, client & officer metadata
    res_l = (
        uow.client.table("loans")
        .select("*, loan_products(name), branches(name), app_users(username, full_name), clients(name, client_code, group_id)")
        .eq("loan_id", payload.loan_id)
        .execute()
    )
    if not res_l.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan not found.")

    loan_row = res_l.data[0]
    branch_id = loan_row.get("branch_id")
    check_branch_access(current_user, branch_id, "disburse loans")

    if str(loan_row.get("status") or "") != "Pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Loan cannot be disbursed because its current status is '{loan_row.get('status')}'."
        )

    # Enforce BM ceiling of ₦300,000
    norm_role = RBACScopeService.normalize_role(current_user.role)
    loan_amt = float(loan_row.get("loan_amount") or 0.0)
    if norm_role == "Branch Manager" and loan_amt > _BM_DISBURSEMENT_CEILING:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Loan amount (₦{loan_amt:,.2f}) exceeds Branch Manager limit of ₦{_BM_DISBURSEMENT_CEILING:,.0f}. Escalated to Area Manager."
        )

    # Validate working day + operational EOD open status using branch_closures
    closures = BusinessDateService.get_branch_closures(uow, branch_id)
    is_open, open_reason = BusinessDateService.is_operational_open(uow, branch_id, disb_date)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Operational Restriction: Cannot disburse loan on {disb_date.isoformat()}. {open_reason}."
        )

    extra_row = loan_row.get("extra_fields") or {}
    lp_row = loan_row.get("loan_products") or {}
    product = str(lp_row.get("name") or extra_row.get("product_type") or loan_row.get("product_type") or "").strip()
    if not product:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Loan product is missing and cannot be resolved.")

    c_row = loan_row.get("clients") or {}
    meeting_day = _resolve_meeting_day(uow, loan_row["client_id"], c_row.get("group_id"))
    closed_dates = BusinessDateService.expand_closure_dates(closures)

    if loan_amt <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Loan principal amount must be greater than zero.")
    setup = LoanProductEngine.calculate_loan_setup(loan_amt, product, loan_row.get("product_category") or "Finance")
    loan_freq = str(setup.get("freq", "Daily"))
    duration_in_installments = int(setup.get("duration", 60) or 1)
    is_cash_and_carry = "cash and carry" in product.lower() or "cash & carry" in product.lower() or loan_freq == "One-Time"

    if is_cash_and_carry:
        final_start_date = disb_date
        expected_end_date = disb_date
        is_adjusted = False
    else:
        schedule = LoanProductEngine.generate_repayment_schedule(
            disb_date,
            duration_in_installments,
            loan_freq,
            meeting_day=meeting_day,
            closed_dates=closed_dates,
        )
        final_start_date = schedule[0] if schedule else disb_date
        expected_end_date = schedule[-1] if schedule else final_start_date
        # Compute nominal (unshifted) first installment date to detect holiday/closure adjustment accurately
        nom_schedule = LoanProductEngine.generate_repayment_schedule(
            disb_date,
            duration_in_installments,
            loan_freq,
            meeting_day=meeting_day,
            closed_dates=[],
        )
        is_adjusted = bool(nom_schedule and schedule and schedule[0] != nom_schedule[0])

    loan_domain = LoanMapper.to_domain(loan_row)
    loan_domain.product_type = product
    loan_domain.start_date = final_start_date
    loan_domain.end_date = expected_end_date
    loan_domain.expected_end_date = expected_end_date

    LoanService.disburse_loan(uow, loan_domain, disbursement_date=disb_date)

    shift_msg = None
    if is_adjusted:
        shift_msg = f"The first repayment was automatically moved to {final_start_date.strftime('%A, %b %d')} because the original date fell on a non-working day or closure."

    return DisburseLoanResponse(
        success=True,
        message=f"Successfully activated and disbursed loan. Disbursement Date set to {today_str}.",
        schedule_adjusted=is_adjusted,
        final_start_date=final_start_date.strftime("%Y-%m-%d"),
        shift_reason=shift_msg
    )


@router.post("/reject", response_model=RejectLoanApplicationResponse)
def reject_pending_loan(
    payload: RejectLoanApplicationRequest,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Checker Action: Rejects a pending loan application and releases any reserved branch asset stock.
    """
    res_l = (
        uow.client.table("loans")
        .select("loan_id, branch_id, status")
        .eq("loan_id", payload.loan_id)
        .execute()
    )
    if not res_l.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan application not found.")
    loan_row = res_l.data[0]
    check_branch_access(current_user, loan_row.get("branch_id"), "reject loans")

    try:
        LoanService.reject_loan(
            uow=uow,
            loan_id=payload.loan_id,
            rejected_by=current_user.username,
            reason=payload.reason.strip() or "Not approved",
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))

    return RejectLoanApplicationResponse(
        success=True,
        message=f"Loan application #{payload.loan_id[:8]} rejected and any reserved stock released.",
    )


@router.put("/update-client/{client_id}", response_model=UpdateClientGuarantorResponse)
def update_client_and_guarantor(
    client_id: str,
    payload: UpdateClientGuarantorInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Updates client personal details and guarantor info across tables (app.py L4694-4835).
    """
    c_name = payload.name.strip()
    if not c_name:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Client Name is required.")

    client = uow.clients.find_by_id(client_id)
    if not client:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found.")
    _verify_client_ownership(current_user, uow, client, "update client details")

    norm_role = RBACScopeService.normalize_role(current_user.role)
    if norm_role == "CO":
        from services.client_service import ClientService
        proposed = {
            "name": c_name,
            "nickname": payload.nickname.strip() if payload.nickname else None,
            "phone": payload.phone.strip() if payload.phone else None,
            "address": payload.address.strip() if payload.address else None,
            "business_address": payload.business_address.strip() if payload.business_address else None,
            "marital_status": payload.marital_status,
            "business_type": payload.business_type.strip() if payload.business_type else None,
            "average_monthly_income": payload.average_monthly_income,
            "other_obligations": payload.other_obligations.strip() if payload.other_obligations else None,
            "id_means": payload.id_means,
            "id_number": payload.id_number.strip() if payload.id_number else None,
            "guarantor_name": payload.guarantor_name.strip() if payload.guarantor_name else None,
            "guarantor_nickname": payload.guarantor_nickname.strip() if payload.guarantor_nickname else None,
            "guarantor_phone": payload.guarantor_phone.strip() if payload.guarantor_phone else None,
            "guarantor_address": payload.guarantor_address.strip() if payload.guarantor_address else None,
            "guarantor_marital_status": payload.guarantor_marital_status,
            "guarantor_occupation": payload.guarantor_occupation.strip() if payload.guarantor_occupation else None,
            "guarantor_relationship": payload.guarantor_relationship.strip() if payload.guarantor_relationship else None,
            "guarantor_office_address": payload.guarantor_office_address.strip() if payload.guarantor_office_address else None,
            "guarantor_id_means": payload.guarantor_id_means,
            "guarantor_id_number": payload.guarantor_id_number.strip() if payload.guarantor_id_number else None,
        }
        res_req = ClientService.submit_profile_update_request(
            uow=uow,
            client_id=client_id,
            requested_by=current_user.id or current_user.username,
            branch_id=client.branch_id,
            proposed_changes=proposed
        )
        return UpdateClientGuarantorResponse(
            success=True,
            message=res_req["message"],
            status="PENDING_APPROVAL",
            request_id=res_req["request_id"]
        )

    # Direct atomic update for BM / AM / Admin
    operations: List[Dict[str, Any]] = []
    client_update_data = {
        "name": c_name,
        "nickname": payload.nickname.strip() if payload.nickname else None,
        "phone": payload.phone.strip() if payload.phone else None,
        "address": payload.address.strip() if payload.address else None,
        "business_address": payload.business_address.strip() if payload.business_address else None,
        "marital_status": payload.marital_status,
        "business_type": payload.business_type.strip() if payload.business_type else None,
        "average_monthly_income": payload.average_monthly_income,
        "other_obligations": payload.other_obligations.strip() if payload.other_obligations else None,
        "id_means": payload.id_means,
        "id_number": payload.id_number.strip() if payload.id_number else None,
    }
    operations.append({
        "type": "update",
        "table": "clients",
        "match": {"client_id": client_id},
        "record": client_update_data,
    })

    res_l = uow.client.table("loans").select("*").eq("client_id", client_id).order("created_at", desc=True).limit(1).execute()
    latest_loan = res_l.data[0] if res_l and res_l.data else {}
    g_name = (payload.guarantor_name or "").strip()
    g_phone = (payload.guarantor_phone or "").strip()

    if latest_loan:
        loan_extra = dict(latest_loan.get("extra_fields") or {})
        loan_extra.update({
            "guarantor_name": g_name or None,
            "guarantor_nickname": payload.guarantor_nickname.strip() if payload.guarantor_nickname else None,
            "guarantor_phone": g_phone or None,
            "guarantor_home_address": payload.guarantor_address.strip() if payload.guarantor_address else None,
            "guarantor_marital_status": payload.guarantor_marital_status,
            "guarantor_occupation": payload.guarantor_occupation.strip() if payload.guarantor_occupation else None,
            "guarantor_relationship": payload.guarantor_relationship.strip() if payload.guarantor_relationship else None,
            "guarantor_office_address": payload.guarantor_office_address.strip() if payload.guarantor_office_address else None,
        })
        operations.append({
            "type": "update",
            "table": "loans",
            "match": {"loan_id": latest_loan["loan_id"]},
            "record": {
                "_allow_active_metadata_update": True,
                "extra_fields": loan_extra,
                "guarantor_id_means": payload.guarantor_id_means,
                "guarantor_id_number": payload.guarantor_id_number.strip() if payload.guarantor_id_number else None,
            },
        })

    guarantor_id = None
    if g_name and g_phone:
        res_g = uow.guarantors.find_by_phone(g_phone)
        g_fields = {
            "name": g_name,
            "address": payload.guarantor_address.strip() if payload.guarantor_address else None,
            "occupation": payload.guarantor_occupation.strip() if payload.guarantor_occupation else None,
            "business_address": payload.guarantor_office_address.strip() if payload.guarantor_office_address else None,
            "id_means": payload.guarantor_id_means,
            "id_number": payload.guarantor_id_number.strip() if payload.guarantor_id_number else None,
        }
        if res_g:
            guarantor_id = res_g.guarantor_id
            operations.append({
                "type": "update",
                "table": "guarantors",
                "match": {"guarantor_id": guarantor_id},
                "record": g_fields,
            })
        else:
            guarantor_id = str(uuid.uuid4())
            g_fields["guarantor_id"] = guarantor_id
            g_fields["phone"] = g_phone
            operations.append({
                "type": "insert",
                "table": "guarantors",
                "record": g_fields,
            })

    operations.append({
        "type": "insert",
        "table": "audit_logs",
        "record": {
            "id": str(uuid.uuid4()),
            "user_id": current_user.id,
            "action": "UPDATE_CLIENT_PROFILE",
            "description": f"Direct manager profile update for client {c_name}",
            "table_name": "clients",
            "record_id": client_id,
        },
    })

    uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

    if guarantor_id and latest_loan:
        try:
            res_link = uow.client.table("loan_guarantors").select("*").eq("loan_id", latest_loan["loan_id"]).eq("guarantor_id", guarantor_id).execute()
            if not res_link.data:
                from domain.entities.guarantor import LoanGuarantor
                uow.guarantors.link_to_loan(LoanGuarantor(
                    id=str(uuid.uuid4()),
                    loan_id=latest_loan["loan_id"],
                    guarantor_id=guarantor_id,
                    relationship=payload.guarantor_relationship or ""
                ))
        except Exception:
            pass

    return UpdateClientGuarantorResponse(
        success=True,
        message="Client and Guarantor details updated successfully.",
        status="APPROVED"
    )
