"""
CO Loan Origination & Client Registration route adapter.
Reuses domain entities, ScheduleService, RenewalService, LoanService,
and ClientStatusService directly against Supabase schema with 1:1 parity against app.py L3217–4838.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime, timedelta
import re
import uuid
from fastapi import APIRouter, Depends, HTTPException, Query, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.origination import (
    GroupOption, ClientSearchItem, ClientProfileDetails, GuarantorDetails,
    RegisterClientInput, RegisterClientResponse,
    EligibilityCheckRequest, EligibilityCheckResponse,
    ApplyLoanInput, ApplyLoanResponse,
    PendingDisbursementsResponse, PendingLoanItem,
    DisburseLoanRequest, DisburseLoanResponse,
    UpdateClientGuarantorInput, UpdateClientGuarantorResponse
)
from models.user import CurrentUser
from domain.entities.client import Client
from domain.entities.loan import Loan
from domain.enums import LoanStatus
from services.loan_product_engine import LoanProductEngine
from services.schedule_service import ScheduleService
from services.renewal_service import RenewalService
from services.loan_service import LoanService
from services.client_status_service import ClientStatusService
from services.business_date_service import BusinessDateService

router = APIRouter(prefix="/api/v1/co/origination", tags=["CO Origination"])


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

    query = uow.client.table("groups").select("group_id, name, group_number, meeting_day, officer_id")
    if branch_id:
        query = query.eq("branch_id", branch_id)

    # If Credit Officer, query groups assigned to this officer or branch
    if current_user.role in ['CO', 'Officer', 'Credit Officer']:
        officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
        if officer_id:
            query = query.eq("officer_id", officer_id)

    res_g = query.execute()
    groups_list = res_g.data or []

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
    if current_user.role in ['CO', 'Officer', 'Credit Officer']:
        user_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
        found_clients = [c for c in found_clients if c.officer_id == user_id]
    elif current_user.role in ['BM', 'Branch Manager'] and current_user.branch_id:
        found_clients = [c for c in found_clients if c.branch_id == current_user.branch_id]

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

    # Guarantor details: query latest loan extra_fields & first-class guarantors
    guar_details = None
    res_l = uow.client.table("loans").select("*").eq("client_id", client_id).order("created_at", desc=True).limit(1).execute()
    latest_loan = res_l.data[0] if res_l and res_l.data else {}
    extra = latest_loan.get("extra_fields") or {}

    g_name = extra.get("guarantor_name") or ""
    g_phone = extra.get("guarantor_phone") or ""

    if g_name or g_phone:
        guar_details = GuarantorDetails(
            full_name=g_name,
            nickname=extra.get("guarantor_nickname"),
            phone=g_phone,
            address=extra.get("guarantor_home_address"),
            marital_status=extra.get("guarantor_marital_status") or "Married",
            occupation=extra.get("guarantor_occupation") or "Trader",
            relationship=extra.get("guarantor_relationship"),
            office_address=extra.get("guarantor_office_address"),
            id_means=latest_loan.get("guarantor_id_means") or "National ID (NIN)",
            id_number=latest_loan.get("guarantor_id_number"),
            id_card_url=latest_loan.get("guarantor_id_card_url"),
            passport_url=latest_loan.get("guarantor_passport_url")
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
    is_eligible, reasons, warnings = RenewalService.check_eligibility(
        uow, payload.client_id, payload.requested_amount, payload.product_type, payload.product_category
    )
    return EligibilityCheckResponse(
        is_eligible=is_eligible,
        reasons=reasons,
        warnings=warnings
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

    # Resolve branch
    branch_name = current_user.branch or "Ogijo"
    res_b = uow.client.table("branches").select("branch_id, code").eq("name", branch_name).execute()
    if res_b.data:
        branch_id = res_b.data[0]["branch_id"]
        branch_code = res_b.data[0]["code"] or branch_name[:3].upper()
    else:
        branch_id = current_user.branch_id
        branch_code = branch_name[:3].upper()

    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    # 1. Group creation / resolution
    final_group_id = None
    final_group_number = ""

    if payload.group_mode == "+ Create New Group":
        new_g_name = (payload.new_group_name or "").strip()
        new_g_num = str(payload.new_group_number or "").strip()
        meeting_day = payload.new_group_meeting_day or "Daily"

        if not new_g_name or not new_g_num:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Please enter the Group Name and Group Number.")

        # Check if group with same number exists in this branch
        res_eg = uow.client.table("groups").select("group_id, group_number").eq("branch_id", branch_id).eq("group_number", new_g_num).execute()
        if res_eg.data:
            final_group_id = res_eg.data[0]["group_id"]
            final_group_number = res_eg.data[0]["group_number"]
        else:
            new_group = {
                "name": new_g_name,
                "group_number": new_g_num,
                "meeting_day": meeting_day,
                "branch_id": branch_id,
                "officer_id": officer_id,
                "current_member_sequence": 0
            }
            res_g_ins = uow.client.table("groups").insert(new_group).execute()
            if res_g_ins.data:
                final_group_id = res_g_ins.data[0]["group_id"]
                final_group_number = res_g_ins.data[0]["group_number"]
    elif payload.group_mode != "Individual (No Group)":
        if payload.group_id:
            final_group_id = payload.group_id
            res_g = uow.client.table("groups").select("group_number").eq("group_id", final_group_id).execute()
            if res_g.data:
                final_group_number = res_g.data[0].get("group_number") or ""
        else:
            res_g = uow.client.table("groups").select("group_id, group_number").eq("branch_id", branch_id).eq("name", payload.group_mode).execute()
            if res_g.data:
                final_group_id = res_g.data[0]["group_id"]
                final_group_number = res_g.data[0].get("group_number") or ""

    # 2. Sequential Client Code Generation (app.py L3497-3509)
    if not final_group_id:
        g_code = "IND"
        res_count = uow.client.table("clients").select("client_id", count="exact").is_("group_id", "null").eq("branch_id", branch_id).execute()
        next_seq = (res_count.count or 0) + 1
    else:
        digits_match = re.findall(r'\d+', str(final_group_number))
        g_code = digits_match[-1].zfill(2) if digits_match else str(final_group_number).zfill(2)
        next_seq = uow.clients.get_next_member_sequence(final_group_id)

    member_number_str = str(next_seq).zfill(3)
    generated_client_code = f"{branch_code}-{g_code}-{member_number_str}"

    client_uuid = str(uuid.uuid4())
    reg_date = date.fromisoformat(payload.registration_date) if payload.registration_date else date.today()

    # 3. Create client entity
    client_entity = Client(
        id=client_uuid,
        name=name_val,
        client_code=generated_client_code,
        nickname=payload.nickname,
        phone=phone_val,
        address=payload.address or "",
        business_address=payload.business_address,
        dob=date(1990, 1, 1),
        gender="Female",
        marital_status=payload.marital_status,
        occupation="Trader",
        business_type=payload.business_type,
        id_means=payload.id_means,
        id_number=payload.id_number,
        id_card_url=payload.id_card_url or "",
        next_of_kin="",
        passport_url=payload.passport_url or "",
        signature_url="",
        registration_date=reg_date,
        branch_id=branch_id,
        group_id=final_group_id,
        officer_id=officer_id,
        status="11111111-1111-1111-1111-111111110001",
        status_id="11111111-1111-1111-1111-111111110001",
        average_monthly_income=float(payload.average_monthly_income or 0.0),
        other_obligations=payload.other_obligations
    )
    uow.clients.create(client_entity)

    # 4. Create membership (app.py L3584-3590)
    if final_group_id:
        uow.client.table("client_memberships").insert({
            "client_id": client_entity.id,
            "group_id": final_group_id,
            "branch_id": branch_id,
            "officer_id": client_entity.officer_id,
            "start_date": reg_date.isoformat()
        }).execute()

    # 5. Save Guarantor details to guarantors table if provided (app.py L3592-3612)
    if payload.guarantor and payload.guarantor.full_name and payload.guarantor.full_name.strip():
        g = payload.guarantor
        g_name_val = g.full_name.strip()
        g_phone_val = (g.phone or "").strip()
        from domain.entities.guarantor import Guarantor
        existing_g = uow.guarantors.find_by_phone(g_phone_val) if g_phone_val else None
        if not existing_g:
            g_entity = Guarantor(
                guarantor_id=str(uuid.uuid4()),
                name=g_name_val,
                phone=g_phone_val,
                address=(g.address or "").strip(),
                occupation=(g.occupation or "Trader").strip(),
                business_address=(g.office_address or "").strip(),
                id_means=g.id_means,
                id_number=(g.id_number or "").strip(),
                id_card_url=payload.guarantor_id_card_url or "",
                passport_url=payload.guarantor_passport_url or ""
            )
            uow.guarantors.create_guarantor(g_entity)

    return RegisterClientResponse(
        success=True,
        client_id=client_uuid,
        client_code=generated_client_code,
        message=f"Successfully registered **{name_val}**! Assigned Client ID: **{generated_client_code}**"
    )



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

    # 2. Check savings balance
    res_dep = uow.client.table("individual_savings").select("deposit_amount").eq("client_id", payload.client_id).execute()
    res_wd = uow.client.table("individual_savings").select("withdrawal_amount").eq("client_id", payload.client_id).execute()
    savings_bal = sum(float(d.get("deposit_amount") or 0) for d in (res_dep.data or [])) - sum(float(w.get("withdrawal_amount") or 0) for w in (res_wd.data or []))

    # 3. Product parameters & interest rate calculation
    rate = 0.12
    duration = 12
    cycle = "Weekly"

    pt = payload.product_type
    if "Cash and Carry" in pt:
        rate = 0.0
        duration = 1
        cycle = "One-Time"
    elif "120" in pt:
        rate = 0.21
        duration = 120
        cycle = "Daily"
    elif "Daily" in pt or "60" in pt:
        rate = 0.12
        duration = 60
        cycle = "Daily"
    elif "3 Month" in pt or "3M" in pt:
        rate = 0.12
        duration = 3
        cycle = "Monthly"
    elif "6 Month" in pt or "6M" in pt:
        rate = 0.21
        duration = 6
        cycle = "Monthly"
    elif "12 Week" in pt or "12W" in pt:
        rate = 0.12
        duration = 12
        cycle = "Weekly"
    elif "24 Week" in pt or "24W" in pt:
        rate = 0.21
        duration = 24
        cycle = "Weekly"

    interest = payload.requested_amount * rate

    # 4. Financial Calculations
    initial_downpayment = payload.cash_downpayment + payload.savings_downpayment
    gap_fee = payload.gap_fee
    total_upfront_required = interest + gap_fee

    if payload.product_category == "Asset":
        total_cost = payload.requested_amount + interest
        final_active_credit = total_cost - initial_downpayment
        final_total_payable = final_active_credit
        final_expected_installment = round(final_active_credit / duration, 2) if duration > 0 else 0.0

        if payload.savings_downpayment > 0 and savings_bal < payload.savings_downpayment:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"INSUFFICIENT SAVINGS: Client has ₦{savings_bal:,.2f} but needs ₦{payload.savings_downpayment:,.2f} from savings for downpayment."
            )
    else:
        final_active_credit = payload.requested_amount - gap_fee
        final_total_payable = payload.requested_amount + interest
        final_expected_installment = round(final_active_credit / duration, 2) if duration > 0 else 0.0

        if total_upfront_required > 0 and savings_bal < total_upfront_required:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"INSUFFICIENT SAVINGS: Client has ₦{savings_bal:,.2f} but needs ₦{total_upfront_required:,.2f}. Please collect additional savings first."
            )

    # 5. Active / Pending loan duplicate validation with Auto-Heal (app.py L4482-4506)
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
                    # Auto-heal: loan is fully paid
                    ClientStatusService.on_loan_repayment_check(uow, payload.client_id, lid)
                    continue
            is_blocked = True

    if is_blocked:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot submit: This client already has an Active or Pending {check_prod_cat} loan!"
        )

    # 6. Create Loan Entity
    loan_id = str(uuid.uuid4())
    app_date = date.fromisoformat(payload.application_date) if payload.application_date else date.today()

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
        branch=current_user.branch or "Ogijo",
        credit_officer=current_user.username,
        officer_id=client.officer_id or current_user.id,
        branch_id=client.branch_id or current_user.branch_id,
        start_date=app_date,
        is_asset=(payload.product_category == "Asset"),
        extra_fields={
            "lifecycle_status": "Submitted",
            "notes": payload.notes,
            "product_category": payload.product_category,
            "downpayment_source": payload.downpayment_mode if payload.product_category == "Asset" else None,
            "downpayment_cash": payload.cash_downpayment if payload.product_category == "Asset" else 0.0,
            "downpayment_savings": payload.savings_downpayment if payload.product_category == "Asset" else 0.0,
            "initial_downpayment": initial_downpayment,
            "active_credit": final_active_credit,
            "loan_repay": final_expected_installment,
            "total_due": final_active_credit,
            "gap_fee": gap_fee,
            "upfront_interest": interest if payload.product_category == "Finance" else 0.0,
            "total_upfront_required": total_upfront_required if payload.product_category == "Finance" else 0.0
        }
    )
    uow.loans.create(loan_entity)

    # 7. Update client status to 'Pending Loan' (BR-CLI-003.1)
    try:
        ClientStatusService.on_loan_submitted(uow, payload.client_id, loan_id, client.officer_id)
    except Exception as e:
        print(f"[STATUS TRACE] Failed to update client status: {e}")

    # 8. Generate scheduled installments
    try:
        ScheduleService.generate_schedule(uow, loan_entity, app_date + timedelta(days=7))
    except Exception as e:
        print(f"[SCHEDULE TRACE] Schedule generation notice: {e}")

    return ApplyLoanResponse(
        success=True,
        loan_id=loan_id,
        active_credit=final_active_credit,
        expected_installment=final_expected_installment,
        status="Pending",
        message="Application submitted successfully! Repayment schedule generated and loan is Pending BM Approval."
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
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    query = uow.client.table("loans").select(
        "loan_id, client_id, loan_amount, active_credit, date, status, officer_id, branch_id, extra_fields, clients(name, client_code, group_id), app_users(username, full_name), loan_products(name)"
    ).eq("status", "Pending")

    if current_user.role in ["CO", "Credit Officer", "Officer"]:
        query = query.eq("officer_id", officer_id)
    elif branch_id:
        query = query.eq("branch_id", branch_id)

    res = query.order("created_at", desc=True).limit(100).execute()
    loans: List[PendingLoanItem] = []

    # Pre-cache groups for group_name resolution
    res_all_groups = uow.client.table("groups").select("group_id, name").execute()
    group_map = {str(g["group_id"]): g["name"] for g in (res_all_groups.data or [])}

    for l in (res_data := (res.data or [])):
        amt = float(l.get("loan_amount") or 0.0)
        if amt <= 0:
            continue

        c = l.get("clients") or {}
        c_name = c.get("name") or "Unknown Client"
        gid = str(c.get("group_id") or "")
        grp_name = group_map.get(gid, "-")

        u = l.get("app_users") or {}
        officer_name = u.get("full_name") or u.get("username") or current_user.username

        lp = l.get("loan_products") or {}
        extra = l.get("extra_fields") or {}
        prod_name = lp.get("name") or extra.get("product_type") or "Weekly 12W"

        loans.append(PendingLoanItem(
            loan_id=str(l.get("loan_id")),
            client_id=str(l.get("client_id")),
            client_name=c_name,
            group_name=grp_name,
            date=str(l.get("date") or ""),
            credit_officer=officer_name,
            loan_amount=amt,
            loan_product=prod_name
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
    # 1. Parse date and validate working day
    disb_date = date.fromisoformat(payload.disbursement_date)
    today_str = disb_date.strftime("%Y-%m-%d")

    # Get custom closures
    res_c = uow.client.table("custom_closures").select("closure_date, reason").execute()
    closures = [(c["closure_date"], c.get("reason", "Closure")) for c in (res_c.data or [])]

    is_workday, workday_reason = BusinessDateService.is_working_day(disb_date, closures)
    if not is_workday:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Non-Working Day Restriction: Loans cannot be activated or disbursed on {workday_reason}. Please select a valid working day."
        )

    # 2. Find target loan
    res_l = uow.client.table("loans").select("*").eq("loan_id", payload.loan_id).execute()
    if not res_l.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Loan not found.")

    loan_row = res_l.data[0]
    product = str(loan_row.get("product_type", ""))

    # Find meeting day from group
    meeting_day = ""
    res_m = uow.client.table("client_memberships").select("groups(meeting_day)").eq("client_id", loan_row["client_id"]).execute()
    if res_m.data and res_m.data[0].get("groups"):
        meeting_day = res_m.data[0]["groups"].get("meeting_day") or ""

    # 3. Calculate initial start date
    if "Daily" in product or "60" in product or "120" in product:
        initial_start_date = disb_date + timedelta(days=1)
    else:
        days_of_week = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6}
        if meeting_day and meeting_day in days_of_week:
            target_weekday = days_of_week[meeting_day]
            current_weekday = disb_date.weekday()
            days_ahead = target_weekday - current_weekday
            if days_ahead <= 0:
                days_ahead += 7
            initial_start_date = disb_date + timedelta(days=days_ahead)
        else:
            initial_start_date = disb_date + timedelta(days=7)

    final_start_date = BusinessDateService.get_next_working_day(initial_start_date, closures)
    is_adjusted = (final_start_date != initial_start_date)

    # 4. Generate schedule end date
    setup = LoanProductEngine.calculate_loan_setup(100000, product)
    loan_freq = setup.get("freq", "Daily")
    duration_in_installments = setup.get("duration", 60)

    schedule = LoanProductEngine.generate_repayment_schedule(
        final_start_date, duration_in_installments, loan_freq,
        meeting_day=meeting_day, closed_dates=[c[0] for c in closures]
    )
    expected_end_date = schedule[-1] if schedule else final_start_date

    # 5. Execute disbursement via LoanService
    loans = uow.loans.find_by_client_id(loan_row["client_id"])
    target_loans = [L for L in loans if str(L.id) == str(payload.loan_id)]
    if not target_loans:
        target_loans = [L for L in loans if (L.status.value == "Pending" if hasattr(L.status, 'value') else L.status == "Pending")]

    if not target_loans:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No pending loan found to disburse.")

    for L in target_loans:
        L.start_date = final_start_date
        L.expected_end_date = expected_end_date
        LoanService.disburse_loan(uow, L, disbursement_date=disb_date)

    shift_msg = None
    if is_adjusted:
        shift_msg = f"The first repayment was automatically moved to {final_start_date.strftime('%A, %b %d')} because the original date fell on a non-working day or closure."

    return DisburseLoanResponse(
        success=True,
        message=f"Successfully activated and disbursed loan! Disbursement Date set to {today_str}.",
        schedule_adjusted=is_adjusted,
        final_start_date=final_start_date.strftime("%Y-%m-%d"),
        shift_reason=shift_msg
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

    # 1. Update Client Record
    client_update_data = {
        "name": c_name,
        "phone": payload.phone.strip() if payload.phone else None,
        "address": payload.address.strip() if payload.address else None,
        "marital_status": payload.marital_status,
        "business_type": payload.business_type.strip() if payload.business_type else None,
        "average_monthly_income": payload.average_monthly_income,
        "other_obligations": payload.other_obligations.strip() if payload.other_obligations else None,
        "id_means": payload.id_means,
        "id_number": payload.id_number.strip() if payload.id_number else None
    }
    uow.client.table("clients").update(client_update_data).eq("client_id", client_id).execute()

    # 2. Update latest loan guarantor extra_fields
    res_l = uow.client.table("loans").select("*").eq("client_id", client_id).order("created_at", desc=True).limit(1).execute()
    latest_loan = res_l.data[0] if res_l and res_l.data else {}

    g_name = (payload.guarantor_name or "").strip()
    g_phone = (payload.guarantor_phone or "").strip()

    if latest_loan:
        loan_extra = latest_loan.get("extra_fields") or {}
        loan_extra.update({
            "guarantor_name": g_name or None,
            "guarantor_phone": g_phone or None,
            "guarantor_home_address": payload.guarantor_address.strip() if payload.guarantor_address else None,
            "guarantor_marital_status": payload.guarantor_marital_status,
            "guarantor_occupation": payload.guarantor_occupation.strip() if payload.guarantor_occupation else None,
            "guarantor_relationship": payload.guarantor_relationship.strip() if payload.guarantor_relationship else None,
            "guarantor_office_address": payload.guarantor_office_address.strip() if payload.guarantor_office_address else None,
        })
        loan_update_data = {
            "extra_fields": loan_extra,
            "guarantor_id_means": payload.guarantor_id_means,
            "guarantor_id_number": payload.guarantor_id_number.strip() if payload.guarantor_id_number else None
        }
        uow.client.table("loans").update(loan_update_data).eq("loan_id", latest_loan["loan_id"]).execute()

    # 3. Sync to public.guarantors table
    if g_name and g_phone:
        res_g = uow.guarantors.find_by_phone(g_phone)
        if res_g:
            guarantor_id = res_g.guarantor_id
            g_update = {
                "name": g_name,
                "address": payload.guarantor_address.strip() if payload.guarantor_address else None,
                "occupation": payload.guarantor_occupation.strip() if payload.guarantor_occupation else None,
                "business_address": payload.guarantor_office_address.strip() if payload.guarantor_office_address else None,
                "id_means": payload.guarantor_id_means,
                "id_number": payload.guarantor_id_number.strip() if payload.guarantor_id_number else None
            }
            uow.client.table("guarantors").update(g_update).eq("guarantor_id", guarantor_id).execute()
        else:
            from domain.entities.guarantor import Guarantor
            g_new = Guarantor(
                guarantor_id=str(uuid.uuid4()),
                name=g_name,
                phone=g_phone,
                address=payload.guarantor_address.strip() if payload.guarantor_address else None,
                occupation=payload.guarantor_occupation.strip() if payload.guarantor_occupation else None,
                business_address=payload.guarantor_office_address.strip() if payload.guarantor_office_address else None,
                id_means=payload.guarantor_id_means,
                id_number=payload.guarantor_id_number.strip() if payload.guarantor_id_number else None
            )
            g_ent = uow.guarantors.create_guarantor(g_new)
            guarantor_id = g_ent.guarantor_id

        if latest_loan:
            res_link = uow.client.table("loan_guarantors").select("*").eq("loan_id", latest_loan["loan_id"]).eq("guarantor_id", guarantor_id).execute()
            if not res_link.data:
                from domain.entities.guarantor import LoanGuarantor
                uow.guarantors.link_to_loan(LoanGuarantor(
                    id=str(uuid.uuid4()),
                    loan_id=latest_loan["loan_id"],
                    guarantor_id=guarantor_id,
                    relationship=payload.guarantor_relationship or ""
                ))

    return UpdateClientGuarantorResponse(
        success=True,
        message="Client and Guarantor details updated successfully."
    )
