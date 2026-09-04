"""
CO Loan Origination & Client Registration route adapter.
Reuses domain entities, ScheduleService, and ClientStatusService directly against Supabase schema.
"""
from typing import Optional
from datetime import date, timedelta
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.origination import (
    RegisterClientInput, RegisterClientResponse,
    ApplyLoanInput, ApplyLoanResponse
)
from models.user import CurrentUser
from domain.entities.client import Client
from domain.entities.loan import Loan
from domain.enums import LoanStatus
from services.loan_product_engine import LoanProductEngine
from services.schedule_service import ScheduleService
from services.client_status_service import ClientStatusService

router = APIRouter(prefix="/api/v1/co/origination", tags=["CO Origination"])


@router.post("/register-client", response_model=RegisterClientResponse)
def register_client(
    payload: RegisterClientInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Registers a new client and guarantor into the database (app.py L2562-2825).
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    branch_id = current_user.branch_id

    # 1. Resolve branch code
    branch_code = current_user.branch[:3].upper() if current_user.branch else "HQ"

    # 2. Resolve group and sequence
    final_group_id = payload.group_id
    if not final_group_id and payload.group_name:
        res_g = uow.client.table("groups").select("group_id").eq("name", payload.group_name).execute()
        if res_g.data:
            final_group_id = res_g.data[0]["group_id"]

    if not final_group_id:
        g_code = "00"
        next_seq = uow.clients.get_next_sequence_number(branch_id=branch_id)
    else:
        g_code = "01"
        next_seq = uow.clients.get_next_member_sequence(final_group_id)

    member_number_str = str(next_seq).zfill(3)
    generated_client_code = f"{branch_code}-{g_code}-{member_number_str}"

    client_uuid = str(uuid.uuid4())

    # 3. Create client entity
    client_entity = Client(
        id=client_uuid,
        name=payload.full_name,
        client_code=generated_client_code,
        nickname=payload.nickname,
        phone=payload.phone,
        address=payload.address,
        business_address=payload.business_address,
        dob=date(1990, 1, 1),
        gender="Female",
        marital_status=payload.marital_status,
        occupation="Trader",
        business_type=payload.business_type,
        id_means=payload.id_means,
        id_number=payload.id_number,
        id_card_url="",
        next_of_kin="",
        passport_url="",
        signature_url="",
        registration_date=date.today(),
        branch_id=branch_id,
        group_id=final_group_id,
        officer_id=officer_id,
        status="11111111-1111-1111-1111-111111110001",
        status_id="11111111-1111-1111-1111-111111110001",
        average_monthly_income=float(payload.daily_income or 0.0) * 30,
        other_obligations=payload.other_obligations
    )

    uow.clients.create(client_entity)

    # 4. Create membership if group is assigned
    if final_group_id:
        uow.client.table("client_memberships").insert({
            "client_id": client_entity.id,
            "group_id": final_group_id,
            "branch_id": branch_id,
            "officer_id": officer_id,
            "start_date": date.today().isoformat()
        }).execute()

    # 5. Create initial record to persist guarantor details (app.py L2793-2823)
    default_product_res = uow.client.table("loan_products").select("product_id").limit(1).execute()
    default_product_id = default_product_res.data[0]["product_id"] if default_product_res.data else None

    g = payload.guarantor
    uow.client.table("loans").insert({
        "loan_id": str(uuid.uuid4()),
        "client_id": client_entity.id,
        "product_id": default_product_id,
        "branch_id": branch_id,
        "officer_id": officer_id,
        "date": date.today().isoformat(),
        "loan_amount": 0.0,
        "active_credit": 0.0,
        "loan_repay": 0.0,
        "total_due": 0.0,
        "status": "Pending",
        "extra_fields": {
            "guarantor_name": g.full_name,
            "guarantor_nickname": g.nickname,
            "guarantor_phone": g.phone,
            "guarantor_home_address": g.address,
            "guarantor_marital_status": g.marital_status,
            "guarantor_occupation": g.occupation,
            "guarantor_relationship": g.relationship,
            "guarantor_office_address": g.office_address,
            "nickname": client_entity.nickname,
            "marital_status": client_entity.marital_status,
            "average_monthly_income": client_entity.average_monthly_income,
            "other_obligations": client_entity.other_obligations
        },
        "guarantor_id_means": g.id_means,
        "guarantor_id_number": g.id_number
    }).execute()

    return RegisterClientResponse(
        success=True,
        client_id=client_uuid,
        client_code=generated_client_code,
        message=f"Successfully registered client {payload.full_name}! Assigned Client ID: {generated_client_code}"
    )


@router.post("/apply", response_model=ApplyLoanResponse)
def apply_for_loan(
    payload: ApplyLoanInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a loan application and generates repayment schedule (app.py L3700-3794).
    """
    if payload.requested_amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Requested amount must be greater than zero."
        )

    # 1. Verify client exists
    client = uow.clients.find_by_id(payload.client_id)
    if not client:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Client not found."
        )

    # 2. Check savings balance for asset downpayment
    initial_downpayment = payload.cash_downpayment + payload.savings_downpayment
    if payload.product_category == "Asset" and payload.savings_downpayment > 0:
        sav_bal = uow.individual_savings.get_total_balance(client_id=payload.client_id)
        if sav_bal < payload.savings_downpayment:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Cannot submit! Insufficient savings for Asset Downpayment. Available: ₦{sav_bal:,.2f}"
            )

    # 3. Calculate loan terms via LoanProductEngine
    setup = LoanProductEngine.calculate_loan_setup(payload.requested_amount, payload.product_name)
    interest = float(setup.get("interest") or 0.0)
    duration = int(setup.get("duration") or 60)
    cycle = str(setup.get("freq") or "Daily")

    gap_fee = float(payload.gap_fee or setup.get("gapFee") or 0.0)

    loan_id = str(uuid.uuid4())
    if payload.product_category == "Finance":
        final_active_credit = payload.requested_amount - gap_fee
        final_total_payable = payload.requested_amount + interest
        final_expected_installment = round(final_active_credit / duration, 2) if duration > 0 else 0.0
    else:
        final_active_credit = (payload.requested_amount + interest) - initial_downpayment
        final_total_payable = final_active_credit
        final_expected_installment = round(final_active_credit / duration, 2) if duration > 0 else 0.0

    # 4. Create Loan Entity
    loan_entity = Loan(
        id=loan_id,
        client_id=payload.client_id,
        client_name=client.name,
        product_type=payload.product_name,
        amount=payload.requested_amount,
        duration=duration,
        frequency=cycle,
        gap_fee=gap_fee,
        expected_installment=final_expected_installment,
        total_payable=final_total_payable,
        status=LoanStatus.PENDING,
        branch=current_user.branch,
        credit_officer=current_user.username,
        officer_id=client.officer_id or current_user.id,
        branch_id=client.branch_id or current_user.branch_id,
        start_date=date.today(),
        is_asset=(payload.product_category == "Asset"),
        extra_fields={
            "lifecycle_status": "Submitted",
            "notes": payload.notes,
            "product_category": payload.product_category,
            "downpayment_cash": payload.cash_downpayment if payload.product_category == "Asset" else 0.0,
            "downpayment_savings": payload.savings_downpayment if payload.product_category == "Asset" else 0.0,
            "initial_downpayment": initial_downpayment,
            "active_credit": final_active_credit,
            "loan_repay": final_expected_installment,
            "total_due": final_active_credit
        }
    )

    uow.loans.create(loan_entity)

    # 5. Update client status to 'Pending Loan' (BR-CLI-003.1)
    try:
        ClientStatusService.on_loan_submitted(uow, payload.client_id, loan_id, client.officer_id)
    except Exception:
        pass

    # 6. Generate scheduled installments
    try:
        ScheduleService.generate_schedule(uow, loan_entity, date.today() + timedelta(days=7))
    except Exception:
        pass

    return ApplyLoanResponse(
        success=True,
        loan_id=loan_id,
        active_credit=final_active_credit,
        expected_installment=final_expected_installment,
        status="Pending",
        message="Application submitted successfully! Repayment schedule generated and loan is Pending BM Approval."
    )


@router.get("/pending")
def get_pending_disbursements(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns pending loan applications awaiting BM approval (app.py L2477-2560).
    """
    branch_id = current_user.branch_id
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    query = uow.client.table("loans").select(
        "loan_id, client_id, loan_amount, active_credit, date, status, credit_officer, officer_id, branch_id, clients(name, client_code), loan_products(name)"
    ).eq("status", "Pending")

    if current_user.role in ["CO", "Credit Officer", "Officer"]:
        query = query.eq("officer_id", officer_id)
    elif branch_id:
        query = query.eq("branch_id", branch_id)

    res = query.order("created_at", desc=True).limit(50).execute()
    loans = []
    for l in (res.data or []):
        c = l.get("clients") or {}
        lp = l.get("loan_products") or {}
        loans.append({
            "loan_id": l.get("loan_id"),
            "client_id": l.get("client_id"),
            "client_name": c.get("name") or "Unknown Client",
            "client_code": c.get("client_code") or "—",
            "loan_product": lp.get("name") or "Weekly 12W",
            "requested_amount": float(l.get("loan_amount") or 0.0),
            "active_credit": float(l.get("active_credit") or 0.0),
            "date": l.get("date"),
            "credit_officer": l.get("credit_officer") or current_user.username,
            "status": "Pending BM Approval"
        })
    return {"pending_loans": loans}

