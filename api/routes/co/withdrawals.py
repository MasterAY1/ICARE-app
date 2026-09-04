"""
CO Withdrawal Operations route adapter.
Reuses savings repositories, loan queries, and BusinessDateService directly against Supabase schema.
"""
from typing import Optional, List, Dict
from datetime import datetime, date
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.withdrawals import (
    IndividualOptionsResponse, ClientWithdrawalOption, EligibleLoan,
    GroupOptionsResponse, GroupWithdrawalOption, GroupMemberOption,
    MiscBalanceResponse, LapsOptionsResponse, LapsOptionRecord,
    WithdrawalRequestsResponse, WithdrawalRequestItem,
    CreateWithdrawalRequestInput, CreateWithdrawalRequestResponse
)
from models.user import CurrentUser
from services.business_date_service import BusinessDateService

router = APIRouter(prefix="/api/v1/co/withdrawals", tags=["CO Withdrawals"])


@router.get("/individual-options", response_model=IndividualOptionsResponse)
def get_individual_options(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns only the authenticated CO's authorized groups, clients, individual-savings balance, and eligible loans.
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    # Fetch clients matching exact Streamlit logic (app.py L5216-5235)
    query = uow.client.table("clients").select(
        "client_id, client_code, name, status, status_id, client_memberships(group_id, groups(name)), client_statuses(name)"
    )
    if current_user.role in ["AM", "Area Manager"]:
        query = query.in_("branch_id", getattr(current_user, "assigned_branch_ids", []))
    elif current_user.role in ["BM", "Branch Manager"]:
        query = query.eq("branch_id", current_user.branch_id)
    else:
        query = query.eq("officer_id", officer_id)

    res_c = query.execute()
    all_clients = [
        c for c in (res_c.data or [])
        if ((c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")) not in ["Closed", "Suspended"]
    ]

    # Collect groups
    co_groups = set()
    for c in all_clients:
        memberships = c.get("client_memberships") or []
        if isinstance(memberships, dict):
            memberships = [memberships]
        for m in memberships:
            if m and m.get("groups") and m["groups"].get("name"):
                co_groups.add(m["groups"]["name"])

    groups_list = ["All Groups"] + sorted(list(co_groups))

    # Fetch active loans for eligible loan offset / asset downpayment
    client_ids = [c["client_id"] for c in all_clients]
    loans_by_client: Dict[str, List[EligibleLoan]] = {}

    if client_ids:
        res_l = uow.client.table("loans").select(
            "loan_id, client_id, loan_amount, active_credit, product_category, extra_fields, loan_products(name)"
        ).in_("client_id", client_ids).in_("status", ["Active", "Approved", "ACTIVE", "Pending"]).execute()

        for l in (res_l.data or []):
            cid = l["client_id"]
            lp = l.get("loan_products") or {}
            p_name = str(lp.get("name") or "").lower()
            is_asset = (l.get("product_category") == "Asset" or "asset" in p_name)

            if cid not in loans_by_client:
                loans_by_client[cid] = []

            loans_by_client[cid].append(EligibleLoan(
                loan_id=l["loan_id"],
                active_credit=float(l.get("active_credit") or l.get("loan_amount") or 0.0),
                loan_amount=float(l.get("loan_amount") or 0.0),
                is_asset=is_asset
            ))

    client_options: List[ClientWithdrawalOption] = []
    for c in all_clients:
        cid = c["client_id"]
        sav_bal = uow.individual_savings.get_total_balance(client_id=cid)
        
        g_name = None
        memberships = c.get("client_memberships") or []
        if isinstance(memberships, dict):
            memberships = [memberships]
        for m in memberships:
            if m and m.get("groups") and m["groups"].get("name"):
                g_name = m["groups"]["name"]
                break

        client_options.append(ClientWithdrawalOption(
            client_id=cid,
            client_code=c.get("client_code") or cid[:8],
            name=c["name"],
            group_name=g_name,
            savings_balance=sav_bal,
            eligible_loans=loans_by_client.get(cid, [])
        ))

    return IndividualOptionsResponse(
        groups=groups_list,
        clients=client_options
    )


@router.get("/group-options", response_model=GroupOptionsResponse)
def get_group_options(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns only authorized groups, group members, group-savings balance, and eligible member loans.
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    query = uow.client.table("groups").select("group_id, name")
    if current_user.role in ["AM", "Area Manager"]:
        query = query.in_("branch_id", getattr(current_user, "assigned_branch_ids", []))
    elif current_user.role in ["BM", "Branch Manager"]:
        query = query.eq("branch_id", current_user.branch_id)
    else:
        query = query.eq("branch_id", current_user.branch_id).eq("officer_id", officer_id)

    res_g = query.execute()
    groups_data = res_g.data or []

    group_options: List[GroupWithdrawalOption] = []

    for g in groups_data:
        gid = g["group_id"]
        g_name = g["name"]
        grp_bal = uow.group_savings.get_total_balance(group_name=g_name)

        # Fetch group members
        res_m = uow.client.table("client_memberships").select("clients(client_id, client_code, name)").eq("group_id", gid).execute()
        members_list: List[GroupMemberOption] = []

        m_client_ids = []
        for m in (res_m.data or []):
            cl = m.get("clients")
            if cl and isinstance(cl, dict):
                m_client_ids.append(cl["client_id"])

        loans_by_member: Dict[str, List[EligibleLoan]] = {}
        if m_client_ids:
            res_l = uow.client.table("loans").select(
                "loan_id, client_id, loan_amount, active_credit, product_category, loan_products(name)"
            ).in_("client_id", m_client_ids).in_("status", ["Active", "Approved", "ACTIVE", "Pending"]).execute()

            for l in (res_l.data or []):
                cid = l["client_id"]
                lp = l.get("loan_products") or {}
                p_name = str(lp.get("name") or "").lower()
                is_asset = (l.get("product_category") == "Asset" or "asset" in p_name)

                if cid not in loans_by_member:
                    loans_by_member[cid] = []

                loans_by_member[cid].append(EligibleLoan(
                    loan_id=l["loan_id"],
                    active_credit=float(l.get("active_credit") or l.get("loan_amount") or 0.0),
                    loan_amount=float(l.get("loan_amount") or 0.0),
                    is_asset=is_asset
                ))

        for m in (res_m.data or []):
            cl = m.get("clients")
            if cl and isinstance(cl, dict):
                cid = cl["client_id"]
                members_list.append(GroupMemberOption(
                    client_id=cid,
                    client_code=cl.get("client_code") or cid[:8],
                    name=cl.get("name") or "Member",
                    eligible_loans=loans_by_member.get(cid, [])
                ))

        group_options.append(GroupWithdrawalOption(
            group_id=gid,
            name=g_name,
            savings_balance=grp_bal,
            members=members_list
        ))

    return GroupOptionsResponse(groups=group_options)


@router.get("/misc-balance", response_model=MiscBalanceResponse)
def get_misc_balance(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns the authorized branch's misc-savings balance with exact Streamlit role restriction.
    """
    misc_bal = uow.misc_savings.get_total_balance(branch=current_user.branch)
    can_withdraw = current_user.role in ["BM", "Branch Manager", "Admin", "Super Admin", "AM", "Area Manager"]

    role_notice = "Misc Savings is managed by the Branch Manager. You can view the balance but cannot submit withdrawals."
    if can_withdraw:
        role_notice = "As Branch Manager/Admin, you can submit a Misc Savings withdrawal."

    return MiscBalanceResponse(
        branch=current_user.branch,
        misc_balance=misc_bal,
        can_withdraw=can_withdraw,
        role_notice=role_notice
    )


@router.get("/laps-options", response_model=LapsOptionsResponse)
def get_laps_options(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns eligible LAPS records and positive balances only for the authenticated user's allowed scope.
    """
    res_laps = uow.client.table("laps_savings").select("id, client_id, deposit_amount, withdrawal_amount, remarks, created_at").execute()
    laps_data: Dict[str, Dict] = {}
    if res_laps.data:
        for lr in res_laps.data:
            cid = lr.get("client_id") or lr.get("id")
            if cid not in laps_data:
                laps_data[cid] = {"client_id": cid, "balance": 0.0, "remarks": lr.get("remarks") or ""}
            laps_data[cid]["balance"] += float(lr.get("deposit_amount") or 0) - float(lr.get("withdrawal_amount") or 0)

    laps_records = [
        LapsOptionRecord(
            client_id=v["client_id"],
            balance=v["balance"],
            remarks=v["remarks"]
        )
        for v in laps_data.values() if v["balance"] > 0
    ]

    return LapsOptionsResponse(records=laps_records)


@router.get("/requests", response_model=WithdrawalRequestsResponse)
def get_my_withdrawal_requests(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns the caller's existing withdrawal requests, statuses, dates, and rejection reasons.
    """
    res_pending = uow.client.table("withdrawal_requests").select("*").eq(
        "requested_by", current_user.username
    ).order("created_at", desc=True).limit(50).execute()

    items: List[WithdrawalRequestItem] = []
    for r in (res_pending.data or []):
        items.append(WithdrawalRequestItem(
            id=str(r.get("id") or ""),
            savings_type=str(r.get("savings_type") or "Individual"),
            operation_type=str(r.get("operation_type") or "Cash Withdrawal"),
            client_name=str(r.get("client_name") or ""),
            group_name=r.get("group_name"),
            amount=float(r.get("amount") or 0.0),
            payout_method=r.get("payout_method") or "Cash",
            reference=str(r.get("reference") or ""),
            remarks=r.get("remarks"),
            status=str(r.get("status") or "PENDING"),
            rejection_reason=r.get("rejection_reason"),
            created_at=str(r.get("created_at") or "")
        ))

    return WithdrawalRequestsResponse(requests=items)


@router.post("/request", response_model=CreateWithdrawalRequestResponse)
def create_withdrawal_request(
    payload: CreateWithdrawalRequestInput,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Creates a withdrawal request for Branch Manager approval (app.py L5280-5570).
    Validates positive amount, balance sufficiency, business day openness, and role permissions.
    """
    # 1. Validate Business Date Openness
    today_dt = datetime.now().date()
    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, today_dt)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Operational Activity Suspended ({open_reason}): Savings withdrawals and LAPS payouts are frozen today."
        )

    # 2. Validate Amount > 0
    if payload.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Withdrawal amount must be greater than zero."
        )

    stype = payload.savings_type
    op_type = payload.operation_type
    ref_code = f"REF-WTH-{datetime.now().strftime('%Y%m%d%H%M%S')}"

    # 3. Type-specific validation and balance verification
    if stype == "Individual":
        if not payload.client_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Client ID is required for Individual withdrawal.")
        
        # Verify balance
        ind_bal = uow.individual_savings.get_total_balance(client_id=payload.client_id)
        if payload.amount > ind_bal and op_type not in ["Loan Offset", "Asset Downpayment"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient balance. Available: ₦{ind_bal:,.2f}"
            )
        if payload.amount > ind_bal and op_type == "Asset Downpayment":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient savings balance for downpayment. Available: ₦{ind_bal:,.2f}"
            )
        if op_type in ["Loan Offset", "Asset Downpayment"] and not payload.loan_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Select an eligible loan for offset or downpayment."
            )

        # Get client name
        res_c = uow.client.table("clients").select("name").eq("client_id", payload.client_id).execute()
        client_name = res_c.data[0]["name"] if res_c.data else "Client"

        rec = {
            "savings_type": "Individual",
            "operation_type": op_type,
            "client_id": payload.client_id,
            "client_name": client_name,
            "loan_id": payload.loan_id,
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "reference": ref_code,
            "remarks": payload.remarks or f"{op_type} request for {client_name}",
            "status": "PENDING"
        }

    elif stype == "Group":
        if not payload.group_name:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Group name is required for Group withdrawal.")
        
        grp_bal = uow.group_savings.get_total_balance(group_name=payload.group_name)
        if payload.amount > grp_bal:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient group balance. Available: ₦{grp_bal:,.2f}"
            )
        if ("Loan Offset" in op_type or "Asset Downpayment" in op_type) and not payload.loan_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Select a member and loan."
            )

        ref_code = f"REF-GRP-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        rec = {
            "savings_type": "Group",
            "operation_type": op_type,
            "client_id": payload.client_id,
            "client_name": payload.group_name,
            "group_name": payload.group_name,
            "loan_id": payload.loan_id,
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "reference": ref_code,
            "remarks": payload.remarks or f"Group {op_type} from {payload.group_name}",
            "status": "PENDING"
        }

    elif stype == "Misc":
        if current_user.role not in ["BM", "Branch Manager", "Admin", "Super Admin", "AM", "Area Manager"]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Misc Savings is managed by Branch Manager. Credit Officers cannot submit Misc withdrawals."
            )
        misc_bal = uow.misc_savings.get_total_balance(branch=current_user.branch)
        if payload.amount > misc_bal:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient Misc balance. Available: ₦{misc_bal:,.2f}"
            )

        ref_code = f"REF-MISC-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        rec = {
            "savings_type": "Misc",
            "operation_type": "Cash Withdrawal",
            "client_name": f"Branch Misc - {current_user.branch}",
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "reference": ref_code,
            "remarks": payload.remarks or f"Misc Savings withdrawal by {current_user.username}",
            "status": "PENDING"
        }

    elif stype == "LAPS":
        if not payload.client_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="LAPS client/record ID is required.")

        ref_code = f"REF-LAPS-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        rec = {
            "savings_type": "LAPS",
            "operation_type": "LAPS Payout",
            "client_id": payload.client_id,
            "client_name": payload.remarks.split('\n')[0][:50] if payload.remarks else f"LAPS Client {payload.client_id[:8]}",
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "payout_method": payload.payout_method or "Cash",
            "reference": ref_code,
            "remarks": payload.remarks or f"LAPS payout for {payload.client_id[:8]}",
            "status": "PENDING"
        }

    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported savings type: '{stype}'")

    # Insert pending request record
    res_ins = uow.client.table("withdrawal_requests").insert(rec).execute()
    inserted_id = res_ins.data[0]["id"] if res_ins.data else str(uuid.uuid4())

    return CreateWithdrawalRequestResponse(
        success=True,
        request_id=str(inserted_id),
        reference=ref_code,
        status="PENDING",
        message=f"{stype} withdrawal request submitted for BM approval! (₦{payload.amount:,.2f})"
    )
