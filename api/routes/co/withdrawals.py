"""
CO Withdrawal Operations route adapter.
Authoritative 1:1 Streamlit parity against app.py L7260–8801.
Reuses savings repositories, loan queries, ScheduleService, and BusinessDateService directly against Supabase schema.
"""
from typing import Optional, List, Dict, Any
from datetime import datetime, date
import re
import uuid
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.withdrawals import (
    IndividualOptionsResponse, ClientWithdrawalOption, EligibleLoan,
    GroupOptionsResponse, GroupWithdrawalOption, GroupMemberOption,
    MiscBalanceResponse, LapsOptionsResponse, LapsOptionRecord,
    WithdrawalRequestsResponse, WithdrawalRequestItem,
    CreateWithdrawalRequestInput, CreateWithdrawalRequestResponse,
    DailyWithdrawalsResponse, DailyWithdrawalsKpis, DailyWithdrawalRecord,
    LoanFeeDeductionRecord, CashBankPayoutRecord, MyRequestStatusRecord,
    PendingApprovalsResponse, PendingApprovalItem,
    ApproveWithdrawalInput, RejectWithdrawalInput, WithdrawalActionResponse
)
from models.user import CurrentUser
from services.business_date_service import BusinessDateService
from services.schedule_service import ScheduleService
from services.savings_service import SavingsService

router = APIRouter(prefix="/api/v1/co/withdrawals", tags=["CO Withdrawals"])


@router.get("/individual-options", response_model=IndividualOptionsResponse)
def get_individual_options(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns authorized groups, clients, individual-savings balance, and eligible loans with exact balance metrics.
    1:1 replica of app.py L7325–7492.
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    is_manager = current_user.role in ["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"]

    # 1. Query clients scoped by role
    query = uow.client.table("clients").select(
        "client_id, client_code, name, status, status_id, client_memberships(group_id, groups(group_id, name, group_number, meeting_day)), client_statuses(name)"
    )
    if current_user.role in ["AM", "Area Manager"]:
        query = query.in_("branch_id", getattr(current_user, "assigned_branches", [current_user.branch_id]))
    elif is_manager:
        query = query.eq("branch_id", current_user.branch_id)
    else:
        query = query.eq("officer_id", officer_id)

    res_c = query.execute()
    all_clients = [
        c for c in (res_c.data or [])
        if ((c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")) not in ["Closed", "Suspended"]
    ]

    # 2. Build disambiguated groups list matching app.py L7360-7383
    _all_g_infos = {}
    for c in all_clients:
        memberships = c.get("client_memberships") or []
        if isinstance(memberships, dict):
            memberships = [memberships]
        for m in memberships:
            if m and m.get("group_id"):
                gid = m["group_id"]
                grp = m.get("groups") or {}
                _all_g_infos[gid] = grp

    _gn_counts = {}
    for grp in _all_g_infos.values():
        gn = grp.get("name", "")
        _gn_counts[gn] = _gn_counts.get(gn, 0) + 1

    group_label_to_id = {"All Groups": None}
    all_groups_payload = []
    for gid, grp in _all_g_infos.items():
        gn = grp.get("name") or "Unknown"
        if _gn_counts.get(gn, 1) > 1:
            lbl = f"{gn} (#{grp.get('group_number', '?')} - {grp.get('meeting_day', '?')})"
        else:
            lbl = gn
        group_label_to_id[lbl] = gid
        all_groups_payload.append({"group_id": gid, "name": gn, "label": lbl, "group_number": grp.get("group_number")})

    groups_list = list(group_label_to_id.keys())

    # 3. Pre-fetch active loans with ScheduleService metrics
    client_ids = [c["client_id"] for c in all_clients]
    loans_by_client: Dict[str, List[EligibleLoan]] = {}

    if client_ids:
        try:
            res_l = uow.client.table("loans").select(
                "loan_id, client_id, loan_amount, active_credit, total_due, product_category, extra_fields, loan_products(name)"
            ).in_("client_id", client_ids).in_("status", ["Active", "Approved", "ACTIVE", "Pending", "PENDING"]).execute()

            raw_loans = res_l.data or []
            loan_ids = [l["loan_id"] for l in raw_loans]
            repaid_by_loan: Dict[str, float] = {}
            if loan_ids:
                reps = uow.client.table("repayments").select("loan_id, amount_paid").in_("loan_id", loan_ids).execute().data or []
                for r in reps:
                    lid = r.get("loan_id")
                    if lid:
                        repaid_by_loan[lid] = repaid_by_loan.get(lid, 0.0) + float(r.get("amount_paid") or 0.0)

            for l in raw_loans:
                cid = l["client_id"]
                lid = l["loan_id"]
                lp = l.get("loan_products") or {}
                l_prod_name = str(lp.get("name") or "")
                is_asset_l = "asset" in str(l.get("product_category") or "").lower() or "asset" in l_prod_name.lower()
                prefix = "Asset " if is_asset_l else ""

                extra = l.get("extra_fields") or {}
                act_cred = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                td_base = float(l.get("total_due") or extra.get("total_due") or act_cred)

                paid_amt = repaid_by_loan.get(lid, 0.0)
                bal = max(0.0, td_base - paid_amt)

                lbl = f"{prefix}Loan {lid[:8]} — Balance: ₦{bal:,.2f} (Active Credit: ₦{act_cred:,.0f})"

                if cid not in loans_by_client:
                    loans_by_client[cid] = []

                loans_by_client[cid].append(EligibleLoan(
                    loan_id=lid,
                    active_credit=act_cred,
                    loan_amount=float(l.get("loan_amount") or 0.0),
                    total_due=td_base,
                    total_repaid=paid_amt,
                    balance=bal,
                    is_asset=is_asset_l,
                    label=lbl,
                    product_name=l_prod_name or ("Asset Loan" if is_asset_l else "Standard Loan")
                ))
        except Exception as e:
            logger.warning(f"Batch fetch loans failed: {e}")

    # 4. Batch-fetch individual savings balances in ONE single query
    bal_by_client: Dict[str, float] = {}
    if client_ids:
        try:
            sav_rows = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").in_("client_id", client_ids).execute().data or []
            for r in sav_rows:
                cid = r.get("client_id")
                if cid:
                    bal_by_client[cid] = bal_by_client.get(cid, 0.0) + (float(r.get("deposit_amount") or 0.0) - float(r.get("withdrawal_amount") or 0.0))
        except Exception as e:
            logger.warning(f"Batch fetch individual savings failed: {e}")

    client_options: List[ClientWithdrawalOption] = []
    for c in all_clients:
        cid = c["client_id"]
        sav_bal = max(0.0, bal_by_client.get(cid, 0.0))

        g_id = None
        g_name = None
        memberships = c.get("client_memberships") or []
        if isinstance(memberships, dict):
            memberships = [memberships]
        for m in memberships:
            if m and m.get("group_id"):
                g_id = m.get("group_id")
                g_name = (m.get("groups") or {}).get("name")
                break

        client_options.append(ClientWithdrawalOption(
            client_id=cid,
            client_code=c.get("client_code") or cid[:8],
            name=c["name"],
            group_id=g_id,
            group_name=g_name or "Ungrouped",
            savings_balance=sav_bal,
            eligible_loans=loans_by_client.get(cid, [])
        ))

    return IndividualOptionsResponse(
        groups=groups_list,
        clients=client_options,
        all_groups=all_groups_payload
    )


@router.get("/group-options", response_model=GroupOptionsResponse)
def get_group_options(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns authorized groups, group members, group-savings balance, and eligible member loans.
    1:1 replica of app.py L7650–7795.
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    is_manager = current_user.role in ["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"]

    query = uow.client.table("groups").select("group_id, name, group_number, meeting_day, officer_id")
    if current_user.role in ["AM", "Area Manager"]:
        query = query.in_("branch_id", getattr(current_user, "assigned_branches", [current_user.branch_id]))
    elif is_manager:
        query = query.eq("branch_id", current_user.branch_id)
    else:
        query = query.eq("branch_id", current_user.branch_id).eq("officer_id", officer_id)

    res_g = query.execute()
    _g_list = res_g.data or []

    _gn_counts = {}
    for g in _g_list:
        gn = g.get("name", "")
        _gn_counts[gn] = _gn_counts.get(gn, 0) + 1

    group_options: List[GroupWithdrawalOption] = []
    all_groups_payload = []
    gid_list = [g["group_id"] for g in _g_list]

    # Batch-fetch group savings balances in ONE query
    bal_by_group: Dict[str, float] = {}
    if gid_list:
        try:
            grp_sav_rows = uow.client.table("group_savings").select("group_id, deposit_amount, withdrawal_amount").in_("group_id", gid_list).execute().data or []
            for r in grp_sav_rows:
                gid = r.get("group_id")
                if gid:
                    bal_by_group[gid] = bal_by_group.get(gid, 0.0) + (float(r.get("deposit_amount") or 0.0) - float(r.get("withdrawal_amount") or 0.0))
        except Exception as e:
            logger.warning(f"Batch fetch group savings failed: {e}")

    # Batch-fetch memberships for all groups in ONE query
    members_by_group: Dict[str, List[dict]] = {}
    all_member_client_ids = set()
    if gid_list:
        try:
            res_m = uow.client.table("client_memberships").select("group_id, clients(client_id, client_code, name)").in_("group_id", gid_list).execute().data or []
            for m in res_m:
                gid = m.get("group_id")
                cl = m.get("clients")
                if gid and cl and isinstance(cl, dict) and cl.get("client_id"):
                    if gid not in members_by_group:
                        members_by_group[gid] = []
                    members_by_group[gid].append(cl)
                    all_member_client_ids.add(cl["client_id"])
        except Exception as e:
            logger.warning(f"Batch fetch memberships failed: {e}")

    # Batch-fetch loans for all members in ONE query
    loans_by_member: Dict[str, List[EligibleLoan]] = {}
    if all_member_client_ids:
        try:
            res_l = uow.client.table("loans").select(
                "loan_id, client_id, loan_amount, active_credit, total_due, product_category, extra_fields, loan_products(name)"
            ).in_("client_id", list(all_member_client_ids)).in_("status", ["Active", "Approved", "ACTIVE", "Pending", "PENDING"]).execute().data or []

            raw_m_loans = res_l
            m_loan_ids = [l["loan_id"] for l in raw_m_loans]
            repaid_by_m_loan: Dict[str, float] = {}
            if m_loan_ids:
                reps = uow.client.table("repayments").select("loan_id, amount_paid").in_("loan_id", m_loan_ids).execute().data or []
                for r in reps:
                    lid = r.get("loan_id")
                    if lid:
                        repaid_by_m_loan[lid] = repaid_by_m_loan.get(lid, 0.0) + float(r.get("amount_paid") or 0.0)

            for l in raw_m_loans:
                cid = l["client_id"]
                lid = l["loan_id"]
                lp = l.get("loan_products") or {}
                l_prod_name = str(lp.get("name") or "")
                is_asset_l = "asset" in str(l.get("product_category") or "").lower() or "asset" in l_prod_name.lower()
                prefix = "Asset " if is_asset_l else ""

                extra = l.get("extra_fields") or {}
                act_cred = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
                td_base = float(l.get("total_due") or extra.get("total_due") or act_cred)

                paid_amt = repaid_by_m_loan.get(lid, 0.0)
                bal = max(0.0, td_base - paid_amt)
                lbl_loan = f"{prefix}Loan {lid[:8]} — Balance: ₦{bal:,.2f} (Active Credit: ₦{act_cred:,.0f})"

                if cid not in loans_by_member:
                    loans_by_member[cid] = []

                loans_by_member[cid].append(EligibleLoan(
                    loan_id=lid,
                    active_credit=act_cred,
                    loan_amount=float(l.get("loan_amount") or 0.0),
                    total_due=td_base,
                    total_repaid=paid_amt,
                    balance=bal,
                    is_asset=is_asset_l,
                    label=lbl_loan,
                    product_name=l_prod_name or ("Asset Loan" if is_asset_l else "Standard Loan")
                ))
        except Exception as e:
            logger.warning(f"Batch fetch member loans failed: {e}")

    for g in _g_list:
        gid = g["group_id"]
        gn = g.get("name") or "Unknown"
        if _gn_counts.get(gn, 1) > 1:
            lbl = f"{gn} (#{g.get('group_number', '?')} - {g.get('meeting_day', '?')})"
        else:
            lbl = gn

        all_groups_payload.append({"group_id": gid, "name": gn, "label": lbl, "group_number": g.get("group_number")})

        grp_bal = max(0.0, bal_by_group.get(gid, 0.0))

        members_list: List[GroupMemberOption] = []
        for cl in members_by_group.get(gid, []):
            cid = cl["client_id"]
            members_list.append(GroupMemberOption(
                client_id=cid,
                client_code=cl.get("client_code") or cid[:8],
                name=cl.get("name") or "Member",
                eligible_loans=loans_by_member.get(cid, [])
            ))

        group_options.append(GroupWithdrawalOption(
            group_id=gid,
            name=lbl,
            savings_balance=grp_bal,
            members=members_list
        ))

    return GroupOptionsResponse(
        groups=group_options,
        all_groups=all_groups_payload
    )


@router.get("/misc-balance", response_model=MiscBalanceResponse)
def get_misc_balance(
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns the authorized branch's misc-savings balance with exact Streamlit role restriction (app.py L7961-7966).
    """
    misc_bal = uow.misc_savings.get_total_balance(branch=current_user.branch)
    can_withdraw = current_user.role in ["BM", "Branch Manager", "Admin", "Super Admin", "AM", "Area Manager"]

    role_notice = "Misc Savings is managed by the Branch Manager and the Designated Officer. You can view the balance but cannot submit withdrawals."
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
    Returns eligible LAPS records and positive balances only for payout (app.py L8190-8208).
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
    Returns the caller's existing withdrawal requests (app.py L8633-8651).
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
    Creates a withdrawal request for Branch Manager approval (app.py L7530–7645 / L7840–7956).
    If caller is BM/Admin with auto_execute=True, directly executes atomic posting via SavingsService.
    """
    # 1. Validate Business Date Openness
    target_dt = date.today()
    if payload.operational_date:
        try:
            target_dt = date.fromisoformat(payload.operational_date[:10])
        except Exception:
            pass

    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, target_dt)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Operational Activity Suspended ({open_reason}): Savings withdrawals and LAPS payouts are frozen today."
        )

    # 2. Validate Positive Amount
    if payload.amount <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Withdrawal amount must be greater than zero."
        )

    stype = payload.savings_type
    op_type = payload.operation_type
    is_manager = current_user.role in ["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"]
    can_auto_exec = bool(payload.auto_execute and is_manager)

    prefix_code = "WTH" if stype == "Individual" else ("GRP" if stype == "Group" else ("MISC" if stype == "Misc" else "LAPS"))
    ref_code = f"REF-{prefix_code}-{datetime.now().strftime('%Y%m%d%H%M%S')}"

    # 3. Type-specific validation and balance verification
    if stype == "Individual":
        if not payload.client_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Client ID is required for Individual withdrawal.")
        
        ind_bal = uow.individual_savings.get_total_balance(client_id=payload.client_id)
        if payload.amount > ind_bal:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient balance. Available: ₦{ind_bal:,.2f}"
            )
        if op_type in ["Loan Repayment / Asset Debt Offset", "Loan Offset"] and not payload.loan_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Select an eligible loan for offset."
            )

        client_name = payload.client_name or "Client"
        if not payload.client_name:
            res_c = uow.client.table("clients").select("name").eq("client_id", payload.client_id).execute()
            if res_c.data:
                client_name = res_c.data[0]["name"]

        if can_auto_exec:
            # Direct BM execution
            if "Bank Account" in op_type or op_type == "Bank Transfer":
                SavingsService.post_individual_savings(
                    uow=uow, client_id=payload.client_id, client_name=client_name,
                    branch=current_user.branch, officer=current_user.username, deposit_amount=0.0, withdrawal_amount=float(payload.amount),
                    reference=ref_code, remarks=f"[BM DIRECT EXECUTION] {payload.remarks or ''}",
                    posting_date=target_dt
                )
            elif "Loan Repayment" in op_type or op_type == "Loan Offset":
                SavingsService.post_loan_offset_from_savings(
                    uow=uow, client_id=payload.client_id, client_name=client_name,
                    loan_id=payload.loan_id, source_savings_type="IndividualSavings",
                    branch=current_user.branch, officer=current_user.username, amount=float(payload.amount),
                    reference=ref_code, remarks=f"[BM DIRECT LOAN OFFSET] {payload.remarks or ''}",
                    posting_date=target_dt
                )
            elif "Fee Payment" in op_type or op_type == "Fee Offset":
                fee_code = "misc_fees"
                if "[FEE:" in (payload.remarks or ""):
                    try: fee_code = payload.remarks.split("[FEE:")[1].split("]")[0].strip()
                    except Exception: pass
                SavingsService.post_fee_offset_from_savings(
                    uow=uow, client_id=payload.client_id, client_name=client_name,
                    source_savings_type="IndividualSavings", branch=current_user.branch, officer=current_user.username,
                    fee_type=fee_code, amount=float(payload.amount),
                    reference=ref_code, remarks=f"[BM DIRECT FEE OFFSET] {payload.remarks or ''}",
                    posting_date=target_dt
                )
            elif "LAPS Reserve" in op_type or op_type == "LAPS Transfer":
                SavingsService.transfer_to_laps(
                    uow=uow, client_id=payload.client_id, client_name=client_name,
                    source_savings_type="IndividualSavings", branch=current_user.branch, officer=current_user.username, amount=float(payload.amount),
                    reference=ref_code, remarks=f"[BM DIRECT LAPS] {payload.remarks or ''}",
                    posting_date=target_dt
                )

        rec = {
            "savings_type": "Individual",
            "operation_type": op_type,
            "client_id": payload.client_id,
            "client_name": client_name,
            "loan_id": payload.loan_id,
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "reference": ref_code,
            "remarks": payload.remarks or f"{op_type} request for {client_name}",
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None
        }

    elif stype == "Group":
        if not payload.group_name:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Group name is required for Group withdrawal.")

        grp_bal = uow.group_savings.get_total_balance(group_id=payload.group_name)
        if payload.amount > grp_bal:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient group balance. Available: ₦{grp_bal:,.2f}"
            )

        if can_auto_exec:
            if "Bank Account" in op_type or op_type == "Bank Transfer":
                SavingsService.post_group_savings(
                    uow=uow, group_name=payload.group_name,
                    branch=current_user.branch, officer=current_user.username, deposit_amount=0.0, withdrawal_amount=float(payload.amount),
                    reference=ref_code, remarks=f"[BM DIRECT EXECUTION] {payload.remarks or ''}",
                    posting_date=target_dt
                )

        rec = {
            "savings_type": "Group",
            "operation_type": op_type,
            "client_id": payload.client_id,
            "client_name": payload.client_name or payload.group_name,
            "group_name": payload.group_name,
            "loan_id": payload.loan_id,
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "reference": ref_code,
            "remarks": payload.remarks or f"Group {op_type} from {payload.group_name}",
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None
        }

    elif stype == "Misc":
        if not is_manager:
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

        rec = {
            "savings_type": "Misc",
            "operation_type": op_type,
            "client_name": f"Branch Misc - {current_user.branch}",
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "reference": ref_code,
            "remarks": payload.remarks or f"Misc Savings withdrawal by {current_user.username}",
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None
        }

    elif stype == "LAPS":
        if not payload.client_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="LAPS client ID is required.")

        rec = {
            "savings_type": "LAPS",
            "operation_type": "LAPS Payout",
            "client_id": payload.client_id,
            "client_name": payload.remarks.split('\n')[0][:50] if payload.remarks else f"LAPS Client {payload.client_id[:8]}",
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "payout_method": payload.payout_method or "Cash",
            "reference": ref_code,
            "remarks": payload.remarks or f"LAPS payout for {payload.client_id[:8]}",
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None
        }
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported savings type: '{stype}'")

    res_ins = uow.client.table("withdrawal_requests").insert(rec).execute()
    inserted_id = res_ins.data[0]["id"] if res_ins.data else str(uuid.uuid4())

    msg = f"Withdrawal request of ₦{payload.amount:,.2f} submitted for BM approval! (Ref: {ref_code})"
    if can_auto_exec:
        msg = f"Withdrawal of ₦{payload.amount:,.2f} authorized and posted to financial ledger! (Ref: {ref_code})"

    return CreateWithdrawalRequestResponse(
        success=True,
        request_id=str(inserted_id),
        reference=ref_code,
        status="APPROVED" if can_auto_exec else "PENDING",
        message=msg
    )


@router.get("/daily-withdrawals", response_model=DailyWithdrawalsResponse)
def get_daily_withdrawals(
    target_date: Optional[str] = Query(None, alias="date", description="Operational date (YYYY-MM-DD)"),
    show_all: bool = Query(False, description="Show all dates if true"),
    category_filter: Optional[str] = Query(None, alias="category"),
    search: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live daily withdrawals data, Top 5 KPIs, and 4 categorized lists.
    Exact 1:1 replica of app.py L8460–8800.
    """
    is_manager = current_user.role in ["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"]
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    target_date_str = None if show_all else (target_date or date.today().isoformat())

    # 1. Fetch clients belonging to officer
    c_q = uow.client.table("clients").select("client_id, client_code, name, nickname, officer_id, branch_id")
    if not is_manager:
        c_q = c_q.eq("officer_id", officer_id)
    else:
        if current_user.role in ["AM", "Area Manager"]:
            c_q = c_q.in_("branch_id", getattr(current_user, "assigned_branches", [current_user.branch_id]))
        else:
            c_q = c_q.eq("branch_id", current_user.branch_id)

    dw_clients = c_q.execute().data or []
    dw_c_map = {c["client_id"]: c for c in dw_clients}
    dw_cids = list(dw_c_map.keys())

    # 2. Client memberships for group names
    dw_cm_res = uow.client.table("client_memberships").select("client_id, groups(group_id, name)").execute()
    dw_group_map = {}
    for m in (dw_cm_res.data or []):
        cid = m.get("client_id")
        if cid and m.get("groups"):
            dw_group_map[cid] = m["groups"].get("name", "Individual")

    # 3. Query individual_savings withdrawals
    dw_sav_q = uow.client.table("individual_savings").select("*").gt("withdrawal_amount", 0)
    if target_date_str:
        dw_sav_q = dw_sav_q.eq("posting_date", target_date_str)
    else:
        dw_sav_q = dw_sav_q.order("posting_date", desc=True).limit(500)

    if current_user.branch_id and not (current_user.role in ["Admin", "Super Admin"]):
        dw_sav_q = dw_sav_q.eq("branch_id", current_user.branch_id)

    raw_sav_w = dw_sav_q.execute().data or []

    if not is_manager:
        filtered_sav_w = [
            r for r in raw_sav_w
            if r.get("officer_id") == officer_id or r.get("client_id") in dw_cids
        ]
    else:
        filtered_sav_w = raw_sav_w

    parsed_records: List[Dict[str, Any]] = []
    for r in filtered_sav_w:
        remarks = r.get("remarks") or ""
        amt = float(r.get("withdrawal_amount") or 0.0)
        cid = r.get("client_id")
        c_info = dw_c_map.get(cid, {})
        c_name = c_info.get("name") or "Unknown Client"
        c_code = c_info.get("client_code") or (cid[:8] if cid else "-")
        g_name = dw_group_map.get(cid, "Individual")
        p_date = str(r.get("posting_date") or "")[:10]
        ref = r.get("reference") or "-"

        is_upfront = "Auto-deducted Upfront Fees" in remarks or "Upfront" in remarks or "Downpayment deducted" in remarks
        is_offset = "loan offset" in remarks.lower() or "debt offset" in remarks.lower()
        is_fee = "fee offset" in remarks.lower() or "fee" in remarks.lower()
        is_bank = "bank transfer" in remarks.lower() or "client bank account" in remarks.lower()

        if is_upfront:
            category = "Loan Fee Deduction"
            int_m = re.search(r"Interest:\s*([0-9,.]+)", remarks)
            gap_m = re.search(r"Gap:\s*([0-9,.]+)", remarks)
            loan_m = re.search(r"Loan\s+([A-Za-z0-9\-]+)", remarks)
            u_int = float(int_m.group(1).replace(",", "")) if int_m else 0.0
            u_gap = float(gap_m.group(1).replace(",", "")) if gap_m else 0.0
            l_ref = loan_m.group(1) if loan_m else "Loan"
            details = f"Interest: ₦{u_int:,.2f} + Gap: ₦{u_gap:,.2f}"
        elif is_offset:
            category = "Loan Offset"
            u_int, u_gap, l_ref = 0.0, 0.0, "-"
            details = remarks.replace("[BM APPROVED]", "").strip() or "Loan debt offset from savings"
        elif is_fee:
            category = "Fee Payment"
            u_int, u_gap, l_ref = 0.0, 0.0, "-"
            details = remarks.replace("[BM APPROVED]", "").strip() or "Fee payment from savings"
        elif is_bank:
            category = "Bank Transfer"
            u_int, u_gap, l_ref = 0.0, 0.0, "-"
            details = remarks.replace("[BM APPROVED]", "").strip() or "Bank transfer payout"
        else:
            category = "Cash Payout"
            u_int, u_gap, l_ref = 0.0, 0.0, "-"
            details = remarks.replace("[BM APPROVED]", "").strip() or "Cash payout to member"

        parsed_records.append({
            "date": p_date,
            "client_name": c_name,
            "client_code": c_code,
            "group": g_name,
            "category": category,
            "amount": amt,
            "details": details,
            "loan_ref": l_ref,
            "interest": u_int,
            "gap": u_gap,
            "reference": ref,
            "remarks": remarks
        })

    # 4. Query group_savings withdrawals
    gw_q = uow.client.table("group_savings").select("*, groups(name, branch_id, officer_id)").gt("withdrawal_amount", 0)
    if target_date_str:
        gw_q = gw_q.eq("posting_date", target_date_str)
    else:
        gw_q = gw_q.order("posting_date", desc=True).limit(100)

    gw_res = gw_q.execute()
    for gr in (gw_res.data or []):
        grp = gr.get("groups") or {}
        if not is_manager and grp.get("officer_id") != officer_id:
            continue
        g_amt = float(gr.get("withdrawal_amount") or 0.0)
        parsed_records.append({
            "date": str(gr.get("posting_date") or "")[:10],
            "client_name": f"{grp.get('name', 'Group')} (Group Account)",
            "client_code": "-",
            "group": grp.get("name", "Group"),
            "category": "Group Withdrawal",
            "amount": g_amt,
            "details": gr.get("remarks") or "Group communal savings withdrawal",
            "loan_ref": "-",
            "interest": 0.0,
            "gap": 0.0,
            "reference": gr.get("reference") or "-",
            "remarks": gr.get("remarks") or ""
        })

    parsed_records.sort(key=lambda x: x["date"], reverse=True)

    # 5. Query withdrawal_requests
    wr_q = uow.client.table("withdrawal_requests").select("*")
    if not is_manager:
        wr_q = wr_q.eq("requested_by", current_user.username)
    else:
        if current_user.branch_id:
            wr_q = wr_q.eq("branch_id", current_user.branch_id)

    if target_date_str:
        wr_q = wr_q.or_(f"operational_date.eq.{target_date_str},created_at.gte.{target_date_str}T00:00:00")
    else:
        wr_q = wr_q.order("created_at", desc=True).limit(100)

    dw_reqs = wr_q.execute().data or []

    # 6. Calculate Top 5 KPIs matching app.py L8653-8667
    total_withdrawn = sum(p["amount"] for p in parsed_records)
    upfront_total = sum(p["amount"] for p in parsed_records if p["category"] == "Loan Fee Deduction")
    payout_total = sum(p["amount"] for p in parsed_records if p["category"] in ["Cash Payout", "Bank Transfer", "Group Withdrawal"])
    offset_total = sum(p["amount"] for p in parsed_records if p["category"] in ["Loan Offset", "Fee Payment"])

    pending_reqs = [r for r in dw_reqs if r.get("status") == "PENDING"]
    pending_amt = sum(float(r.get("amount") or 0.0) for r in pending_reqs)

    kpis = DailyWithdrawalsKpis(
        total_withdrawn=total_withdrawn,
        loan_fees_deducted=upfront_total,
        cash_bank_paid=payout_total,
        debt_fee_offsets=offset_total,
        waiting_for_approval_count=len(pending_reqs),
        waiting_for_approval_amount=pending_amt
    )

    # 7. Apply category and search filters
    display_records = parsed_records
    if category_filter and category_filter != "All Types":
        if category_filter == "Loan Fee Deductions":
            display_records = [p for p in display_records if p["category"] == "Loan Fee Deduction"]
        elif category_filter == "Cash & Bank Payouts":
            display_records = [p for p in display_records if p["category"] in ["Cash Payout", "Bank Transfer"]]
        elif category_filter == "Loan & Fee Offsets":
            display_records = [p for p in display_records if p["category"] in ["Loan Offset", "Fee Payment"]]
        elif category_filter == "Group Withdrawals":
            display_records = [p for p in display_records if p["category"] == "Group Withdrawal"]

    if search:
        sk = search.lower().strip()
        display_records = [
            p for p in display_records
            if sk in p["client_name"].lower() or sk in p["client_code"].lower() or sk in p["loan_ref"].lower() or sk in p["reference"].lower()
        ]

    all_records = [
        DailyWithdrawalRecord(
            date=p["date"],
            client_name=p["client_name"],
            client_code=p["client_code"],
            group=p["group"],
            category=p["category"],
            amount=p["amount"],
            details=p["details"],
            loan_ref=p["loan_ref"],
            reference=p["reference"]
        )
        for p in display_records
    ]

    loan_fee_deductions = [
        LoanFeeDeductionRecord(
            date=p["date"],
            client_name=p["client_name"],
            client_code=p["client_code"],
            loan_ref=p["loan_ref"],
            interest_deducted=p["interest"],
            gap_fee_deducted=p["gap"],
            total_deducted=p["amount"],
            status="Auto-deducted on Disbursement"
        )
        for p in display_records if p["category"] == "Loan Fee Deduction"
    ]

    cash_bank_payouts = [
        CashBankPayoutRecord(
            date=p["date"],
            client_name=p["client_name"],
            group=p["group"],
            payment_type=p["category"],
            amount=p["amount"],
            approval_notes=p["details"],
            reference=p["reference"]
        )
        for p in display_records if p["category"] in ["Cash Payout", "Bank Transfer", "Group Withdrawal"]
    ]

    my_requests = [
        MyRequestStatusRecord(
            id=str(r.get("id") or ""),
            client_name=str(r.get("client_name") or "Unknown"),
            savings_type=str(r.get("savings_type") or "Savings"),
            operation_type=str(r.get("operation_type") or "Withdrawal"),
            reference=str(r.get("reference") or "-"),
            requested_by=str(r.get("requested_by") or "-"),
            operational_date=str(r.get("operational_date") or str(r.get("created_at") or ""))[:10],
            remarks=r.get("remarks"),
            rejection_reason=r.get("rejection_reason"),
            approved_by=r.get("approved_by"),
            approved_at=str(r.get("approved_at") or "")[:19] if r.get("approved_at") else None,
            amount=float(r.get("amount") or 0.0),
            status=str(r.get("status") or "PENDING")
        )
        for r in dw_reqs
    ]

    return DailyWithdrawalsResponse(
        kpis=kpis,
        all_records=all_records,
        loan_fee_deductions=loan_fee_deductions,
        cash_bank_payouts=cash_bank_payouts,
        my_requests=my_requests
    )


@router.get("/pending-approvals", response_model=PendingApprovalsResponse)
def get_pending_approvals(
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns pending withdrawal requests for Branch Manager approval queue (app.py L7291–7301).
    """
    query = uow.client.table("withdrawal_requests").select("*").eq("status", "PENDING").order("created_at", desc=False)
    if current_user.role in ["AM", "Area Manager"]:
        query = query.in_("branch_id", getattr(current_user, "assigned_branches", [current_user.branch_id]))
    elif current_user.role in ["BM", "Branch Manager"]:
        query = query.eq("branch_id", current_user.branch_id)

    res = query.execute()
    items = []
    for r in (res.data or []):
        items.append(PendingApprovalItem(
            id=str(r.get("id")),
            client_id=r.get("client_id"),
            client_name=r.get("client_name") or "Unknown",
            savings_type=r.get("savings_type") or "Individual",
            operation_type=r.get("operation_type") or "Cash Withdrawal",
            group_name=r.get("group_name"),
            loan_id=r.get("loan_id"),
            branch_id=r.get("branch_id") or current_user.branch_id,
            requested_by=r.get("requested_by") or "Officer",
            amount=float(r.get("amount") or 0.0),
            operational_date=str(r.get("operational_date") or str(r.get("created_at") or ""))[:10],
            reference=r.get("reference") or str(r.get("id"))[:8],
            remarks=r.get("remarks"),
            payout_method=r.get("payout_method") or "Cash"
        ))
    return PendingApprovalsResponse(requests=items)


@router.post("/approve", response_model=WithdrawalActionResponse)
def approve_withdrawal(
    payload: ApproveWithdrawalInput,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Approves a withdrawal request, invoking domain posting to general ledger atomically (app.py L8336-8438).
    """
    res = uow.client.table("withdrawal_requests").select("*").eq("id", payload.request_id).execute()
    if not res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Withdrawal request not found.")

    wr = res.data[0]
    if wr.get("status") == "APPROVED":
        return WithdrawalActionResponse(success=True, message="Request has already been approved.")

    wr_name = wr.get("client_name") or "Client"
    wr_type = wr.get("savings_type") or "Individual"
    wr_op = wr.get("operation_type") or "Cash Withdrawal"
    wr_amt = float(wr.get("amount") or 0.0)
    wr_by = wr.get("requested_by") or current_user.username
    wr_remarks = wr.get("remarks") or ""

    effective_op_date = payload.operational_date or wr.get("operational_date")
    if isinstance(effective_op_date, str):
        try: effective_op_date = date.fromisoformat(effective_op_date[:10])
        except Exception: effective_op_date = date.today()
    else:
        effective_op_date = date.today()

    source_type = "GroupSavings" if wr_type == "Group" else ("MiscSavings" if wr_type == "Misc" else "IndividualSavings")

    try:
        if wr_op in ["Cash Withdrawal", "Bank Transfer", "Client Bank Account (Transfer)", "Group Bank Account (Transfer)"]:
            if wr_type == "Individual":
                SavingsService.post_individual_savings(
                    uow=uow, client_id=wr.get("client_id"), client_name=wr_name,
                    branch=current_user.branch, officer=wr_by, deposit_amount=0.0, withdrawal_amount=wr_amt,
                    reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}",
                    posting_date=effective_op_date
                )
            elif wr_type == "Group":
                SavingsService.post_group_savings(
                    uow=uow, group_name=wr.get("group_name") or wr_name, branch=current_user.branch,
                    officer=wr_by, deposit_amount=0.0, withdrawal_amount=wr_amt,
                    reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}",
                    posting_date=effective_op_date
                )
            elif wr_type == "Misc":
                SavingsService.post_misc_savings(
                    uow=uow, client_id=wr.get("client_id") or "", client_name=wr_name,
                    branch=current_user.branch, officer=wr_by, deposit_amount=0.0, withdrawal_amount=wr_amt,
                    reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}",
                    posting_date=effective_op_date
                )
        elif wr_op in ["Loan Offset", "Asset Downpayment", "Loan Repayment / Asset Debt Offset"]:
            SavingsService.post_loan_offset_from_savings(
                uow=uow, client_id=wr.get("client_id"), client_name=wr_name,
                loan_id=wr.get("loan_id"), source_savings_type=source_type,
                branch=current_user.branch, officer=wr_by, amount=wr_amt,
                reference=wr.get("reference"), remarks=f"[BM APPROVED {wr_op.upper()}] {wr_remarks}",
                posting_date=effective_op_date
            )
        elif wr_op in ["Fee Offset", "Fee Payment from Savings"]:
            fee_code = "misc_fees"
            if "[FEE:" in wr_remarks:
                try: fee_code = wr_remarks.split("[FEE:")[1].split("]")[0].strip()
                except Exception: pass
            SavingsService.post_fee_offset_from_savings(
                uow=uow, client_id=wr.get("client_id"), client_name=wr_name,
                source_savings_type=source_type, branch=current_user.branch, officer=wr_by,
                fee_type=fee_code, amount=wr_amt,
                reference=wr.get("reference"), remarks=f"[BM APPROVED FEE OFFSET] {wr_remarks}",
                posting_date=effective_op_date
            )
        elif wr_op in ["Savings Transfer", "Transfer to Another Savings", "Another Member or Group Savings"]:
            dest_id = wr.get("client_id")
            dest_name = wr_name
            dest_type = "IndividualSavings"
            if "[DEST_ID:" in wr_remarks:
                try:
                    dest_id = wr_remarks.split("[DEST_ID:")[1].split("]")[0].strip()
                    dest_name = wr_remarks.split("[DEST_NAME:")[1].split("]")[0].strip()
                    dest_type = wr_remarks.split("[DEST_TYPE:")[1].split("]")[0].strip()
                except Exception: pass
            SavingsService.transfer_savings(
                uow=uow, source_id=wr.get("client_id"), source_name=wr_name,
                source_type=source_type, destination_id=dest_id,
                destination_name=dest_name, destination_type=dest_type,
                branch=current_user.branch, officer=wr_by, amount=wr_amt,
                reference=wr.get("reference"), remarks=f"[BM APPROVED TRANSFER] {wr_remarks}",
                posting_date=effective_op_date
            )
        elif wr_op == "LAPS Payout":
            cash_paid = (wr.get("payout_method") or "Cash") == "Cash"
            SavingsService.pay_laps(
                uow=uow, client_id=wr.get("client_id"), client_name=wr_name,
                branch=current_user.branch, officer=wr_by, amount=wr_amt, cash_paid=cash_paid,
                reference=wr.get("reference"), remarks=f"[BM APPROVED] {wr_remarks}",
                posting_date=effective_op_date
            )

        uow.client.table("withdrawal_requests").update({
            "status": "APPROVED",
            "approved_by": current_user.username,
            "approved_at": datetime.now().isoformat()
        }).eq("id", payload.request_id).execute()

        return WithdrawalActionResponse(
            success=True,
            message=f"Withdrawal of ₦{wr_amt:,.2f} for {wr_name} approved and posted to the financial ledger!"
        )
    except Exception as ex:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Approval execution failed: {str(ex)}")


@router.post("/reject", response_model=WithdrawalActionResponse)
def reject_withdrawal(
    payload: RejectWithdrawalInput,
    current_user: CurrentUser = Depends(require_role(["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Rejects a withdrawal request with an audit reason (app.py L8440-8456).
    """
    uow.client.table("withdrawal_requests").update({
        "status": "REJECTED",
        "approved_by": current_user.username,
        "approved_at": datetime.now().isoformat(),
        "rejection_reason": payload.rejection_reason or "Rejected by Manager"
    }).eq("id", payload.request_id).execute()

    return WithdrawalActionResponse(
        success=True,
        message=f"Withdrawal request rejected successfully."
    )
