"""
CO Withdrawal Operations route adapter.
Authoritative 1:1 Streamlit parity against app.py L7260–8801.
Reuses savings repositories, loan queries, ScheduleService, and BusinessDateService directly against Supabase schema.
"""
from typing import Optional, List, Dict, Any
from datetime import datetime, date
import logging
import re
import secrets
import uuid
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role, check_branch_access
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

logger = logging.getLogger(__name__)


def _resolve_branch_name(uow: SupabaseUnitOfWork, branch_id: Optional[str]) -> str:
    if not branch_id:
        return ""
    try:
        res = uow.client.table("branches").select("name").eq("branch_id", branch_id).execute()
        if res.data and len(res.data) > 0:
            return res.data[0].get("name", "")
    except Exception:
        pass
    return ""


def _clean_ui_remarks(remarks: Optional[str]) -> str:
    """Strip internal control tags and execution brackets before rendering text to the UI."""
    text = str(remarks or "")
    for pat in (
        r"\[DEST_ID:[^\]]*\]",
        r"\[DEST_NAME:[^\]]*\]",
        r"\[DEST_TYPE:[^\]]*\]",
        r"\[FEE:[^\]]*\]",
        r"\[LOAN_OFFSET:[^\]]*\]",
        r"\[BM DIRECT EXECUTION\]",
        r"\[BM DIRECT LOAN OFFSET\]",
        r"\[BM DIRECT FEE OFFSET\]",
        r"\[BM DIRECT LAPS RETURN\]",
        r"\[BM DIRECT LAPS\]",
        r"\[BM APPROVED[^\]]*\]",
    ):
        text = re.sub(pat, "", text, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", text).strip()


def _emit_wr_user_audit(
    uow: SupabaseUnitOfWork,
    current_user: CurrentUser,
    action: str,
    entity_id: str,
    display_name: str,
    previous_value: str,
    new_value: str,
    status_val: str = "SUCCESS",
) -> None:
    """Safely record a user_audit_logs entry directly via Supabase without Streamlit coupling."""
    try:
        actor_uuid, actor_uname, actor_role, _ = SavingsService._resolve_actor_audit_info(
            uow, current_user.username, current_user.role
        )
        op = SavingsService._build_user_audit_op(
            user_id=actor_uuid,
            username=actor_uname,
            role=actor_role,
            branch=current_user.branch or "",
            action=action,
            module="Withdrawals",
            entity_type="withdrawal_requests",
            entity_id=entity_id,
            display_name=display_name,
            previous_value={"value": previous_value},
            new_value={"value": new_value},
            audit_status=status_val,
        )
        uow.client.table("user_audit_logs").insert(op["record"]).execute()
    except Exception as ex:
        logger.warning(f"Failed to emit withdrawal audit log: {ex}")

WR_ALLOWED_ROLES = [
    "CO", "Credit Officer", "Officer",
    "BM", "Branch Manager",
]
WR_MANAGER_ROLES = [
    "BM", "Branch Manager",
]


def _is_designated_misc_officer(uow: SupabaseUnitOfWork, current_user: CurrentUser) -> bool:
    """Return True if current_user is designated in the database as their branch's Misc Savings manager."""
    try:
        misc_oid, misc_oname = SavingsService.get_branch_misc_savings_officer(
            uow, current_user.branch_id or current_user.branch
        )
        if not misc_oid and not misc_oname:
            return False
        resolved_oid = uow.loans._resolve_officer_id(current_user.username) or current_user.id
        if misc_oid and str(misc_oid) in {str(current_user.id or ""), str(resolved_oid or "")}:
            return True
        if misc_oname:
            cand_low = str(misc_oname).strip().lower()
            if cand_low and cand_low in {
                str(current_user.username or "").strip().lower(),
                str(getattr(current_user, "full_name", "") or "").strip().lower(),
            }:
                return True
    except Exception as ex:
        logger.warning(f"Misc officer resolution failed: {ex}")
    return False


def _fetch_pending_reserved_map(
    uow: SupabaseUnitOfWork,
    branch_id: Optional[str] = None,
) -> tuple[Dict[str, float], Dict[str, float], Dict[str, float], float]:
    """Sum PENDING/PROCESSING withdrawal_requests per account to prevent concurrent balance overdrafts."""
    ind_pending: Dict[str, float] = {}
    grp_pending: Dict[str, float] = {}
    laps_pending: Dict[str, float] = {}
    misc_pending = 0.0
    try:
        q = uow.client.table("withdrawal_requests").select(
            "savings_type, client_id, group_id, group_name, amount, branch_id"
        ).in_("status", ["PENDING", "PROCESSING"])
        if branch_id:
            q = q.eq("branch_id", branch_id)
        rows = q.execute().data or []
        for r in rows:
            if not isinstance(r, dict):
                continue
            amt = float(r.get("amount") or 0.0)
            if amt <= 0:
                continue
            st = str(r.get("savings_type") or "").strip()
            if st == "Individual":
                cid = str(r.get("client_id") or "").strip()
                if cid:
                    ind_pending[cid] = ind_pending.get(cid, 0.0) + amt
            elif st == "Group":
                gid = str(r.get("group_id") or r.get("client_id") or "").strip()
                if gid:
                    grp_pending[gid] = grp_pending.get(gid, 0.0) + amt
                gname = str(r.get("group_name") or "").strip()
                if gname:
                    grp_pending[gname] = grp_pending.get(gname, 0.0) + amt
            elif st == "LAPS":
                cid = str(r.get("client_id") or "").strip()
                if cid:
                    laps_pending[cid] = laps_pending.get(cid, 0.0) + amt
            elif st == "Misc":
                misc_pending += amt
    except Exception as ex:
        logger.warning(f"Pending withdrawal reservation lookup failed: {ex}")
    return ind_pending, grp_pending, laps_pending, misc_pending


def _chunked(items: List[str], size: int = 100):
    """Yield sequential fixed-size slices to avoid oversized PostgREST IN clauses."""
    for i in range(0, len(items), size):
        yield items[i:i + size]


def _fetch_repaid_totals_by_loan(uow: SupabaseUnitOfWork, loan_ids: List[str]) -> Dict[str, float]:
    """Batch-aggregates repaid amounts per loan via SQL RPC with chunked table fallback."""
    totals: Dict[str, float] = {}
    unique_ids = list(dict.fromkeys(str(lid) for lid in loan_ids if lid))
    if not unique_ids:
        return totals

    try:
        rpc_res = uow.client.rpc("get_loan_repaid_totals_batch", {"p_loan_ids": unique_ids}).execute()
        rows = getattr(rpc_res, "data", None)
        if isinstance(rows, list) and rows and isinstance(rows[0], dict) and "loan_id" in rows[0]:
            for r in rows:
                lid = r.get("loan_id")
                if lid:
                    totals[str(lid)] = float(r.get("total_paid") or 0.0)
            return totals
    except Exception:
        pass

    for chunk in _chunked(unique_ids):
        reps = uow.client.table("repayments").select("loan_id, amount_paid").in_("loan_id", chunk).execute().data or []
        for r in reps:
            if isinstance(r, dict) and r.get("loan_id"):
                lid = str(r["loan_id"])
                totals[lid] = totals.get(lid, 0.0) + float(r.get("amount_paid") or 0.0)
    return totals


def _fetch_individual_balances_batch(
    uow: SupabaseUnitOfWork,
    client_ids: List[str],
) -> tuple[Dict[str, float], bool]:
    """Batch-computes net individual savings balances via SQL RPC with chunked table fallback."""
    balances: Dict[str, float] = {}
    unique_ids = list(dict.fromkeys(str(cid) for cid in client_ids if cid))
    if not unique_ids:
        return balances, True

    try:
        rpc_res = uow.client.rpc("get_individual_savings_balances_batch", {"p_client_ids": unique_ids}).execute()
        rows = getattr(rpc_res, "data", None)
        if isinstance(rows, list) and rows and isinstance(rows[0], dict) and "client_id" in rows[0]:
            for r in rows:
                cid = r.get("client_id")
                if cid:
                    balances[str(cid)] = float(r.get("net_balance") or 0.0)
            return balances, True
    except Exception:
        pass

    try:
        for chunk in _chunked(unique_ids):
            sav_rows = (
                uow.client.table("individual_savings")
                .select("client_id, deposit_amount, withdrawal_amount")
                .in_("client_id", chunk)
                .execute()
                .data
                or []
            )
            for r in sav_rows:
                if isinstance(r, dict) and r.get("client_id"):
                    cid = str(r["client_id"])
                    balances[cid] = balances.get(cid, 0.0) + (
                        float(r.get("deposit_amount") or 0.0) - float(r.get("withdrawal_amount") or 0.0)
                    )
        return balances, True
    except Exception as e:
        logger.warning(f"Batch fetch individual savings failed: {e}")
        return balances, False


router = APIRouter(prefix="/api/v1/co/withdrawals", tags=["CO Withdrawals"])


@router.get("/individual-options", response_model=IndividualOptionsResponse)
def get_individual_options(
    current_user: CurrentUser = Depends(require_role(WR_ALLOWED_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns authorized groups, clients, individual-savings balance, and eligible loans with exact balance metrics.
    1:1 replica of app.py L7325–7492.
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    is_manager = current_user.role in WR_MANAGER_ROLES

    # 1. Query clients scoped by role (CO & BM only)
    query = uow.client.table("clients").select(
        "client_id, client_code, name, status, status_id, client_memberships(group_id, groups(group_id, name, group_number, meeting_day)), client_statuses(name)"
    )
    if is_manager:
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
            if m:
                grp = m.get("groups") or {}
                gid = m.get("group_id") or grp.get("group_id") or grp.get("name")
                if gid:
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
            raw_loans = []
            for chunk in _chunked(client_ids):
                res_l = uow.client.table("loans").select(
                    "loan_id, client_id, loan_amount, active_credit, total_due, product_category, extra_fields, loan_products(name)"
                ).in_("client_id", chunk).in_("status", ["Active", "Approved", "ACTIVE"]).execute()
                raw_loans.extend(res_l.data or [])

            loan_ids = [l["loan_id"] for l in raw_loans if l.get("loan_id")]
            repaid_by_loan = _fetch_repaid_totals_by_loan(uow, loan_ids)

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

    # 4. Batch-fetch individual savings balances without per-client N+1 fallbacks
    bal_by_client, batch_sav_ok = _fetch_individual_balances_batch(uow, client_ids)

    ind_pending, _, _, _ = _fetch_pending_reserved_map(
        uow, current_user.branch_id
    )

    client_options: List[ClientWithdrawalOption] = []
    for c in all_clients:
        cid = c["client_id"]
        sav_bal = max(0.0, bal_by_client.get(cid, 0.0))
        if not batch_sav_ok and sav_bal == 0.0 and hasattr(uow, "individual_savings") and hasattr(uow.individual_savings, "get_total_balance"):
            try:
                repo_bal = uow.individual_savings.get_total_balance(client_id=cid)
                if repo_bal:
                    sav_bal = float(repo_bal)
            except Exception:
                pass
        sav_bal = max(0.0, sav_bal - ind_pending.get(cid, 0.0))

        g_id = None
        g_name = None
        memberships = c.get("client_memberships") or []
        if isinstance(memberships, dict):
            memberships = [memberships]
        for m in memberships:
            if m:
                grp = m.get("groups") or {}
                g_id = m.get("group_id") or grp.get("group_id") or grp.get("name")
                g_name = grp.get("name")
                if g_id:
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
    current_user: CurrentUser = Depends(require_role(WR_ALLOWED_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns authorized groups, group members, group-savings balance, and eligible member loans.
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    is_manager = current_user.role in WR_MANAGER_ROLES
    branch_scope = current_user.branch_id
    _, grp_pending, _, _ = _fetch_pending_reserved_map(uow, branch_scope)

    query = uow.client.table("groups").select("group_id, name, group_number, meeting_day, officer_id")
    if is_manager:
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

    # Batch-fetch group savings balances in chunked queries
    bal_by_group: Dict[str, float] = {}
    if gid_list:
        try:
            for chunk in _chunked(gid_list):
                grp_sav_rows = uow.client.table("group_savings").select("group_id, deposit_amount, withdrawal_amount").in_("group_id", chunk).execute().data or []
                for r in grp_sav_rows:
                    gid = r.get("group_id")
                    if gid:
                        bal_by_group[gid] = bal_by_group.get(gid, 0.0) + (float(r.get("deposit_amount") or 0.0) - float(r.get("withdrawal_amount") or 0.0))
        except Exception as e:
            logger.warning(f"Batch fetch group savings failed: {e}")

    # Batch-fetch memberships for all groups in chunked queries
    members_by_group: Dict[str, List[dict]] = {}
    all_member_client_ids = set()
    if gid_list:
        try:
            for chunk in _chunked(gid_list):
                res_m = uow.client.table("client_memberships").select("group_id, clients(client_id, client_code, name)").in_("group_id", chunk).execute().data or []
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

    # Batch-fetch loans for all members in chunked queries + aggregated repayments
    loans_by_member: Dict[str, List[EligibleLoan]] = {}
    if all_member_client_ids:
        try:
            raw_m_loans = []
            for chunk in _chunked(list(all_member_client_ids)):
                res_l = uow.client.table("loans").select(
                    "loan_id, client_id, loan_amount, active_credit, total_due, product_category, extra_fields, loan_products(name)"
                ).in_("client_id", chunk).in_("status", ["Active", "Approved", "ACTIVE"]).execute().data or []
                raw_m_loans.extend(res_l)

            m_loan_ids = [l["loan_id"] for l in raw_m_loans if l.get("loan_id")]
            repaid_by_m_loan = _fetch_repaid_totals_by_loan(uow, m_loan_ids)

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

        pending_grp = grp_pending[gid] if gid in grp_pending else grp_pending.get(gn, 0.0)
        grp_bal = max(0.0, bal_by_group.get(gid, 0.0) - pending_grp)

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
    current_user: CurrentUser = Depends(require_role(WR_ALLOWED_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns the authorized branch's misc-savings balance with pending reservation and designated CO authorization.
    """
    raw_misc_bal = float(uow.misc_savings.get_total_balance(branch=current_user.branch) or 0.0)
    _, _, _, misc_pending = _fetch_pending_reserved_map(uow, current_user.branch_id)
    misc_bal = max(0.0, raw_misc_bal - misc_pending)

    is_manager = current_user.role in WR_MANAGER_ROLES
    is_designated_misc = _is_designated_misc_officer(uow, current_user)
    can_withdraw = is_manager or is_designated_misc

    if is_manager:
        role_notice = "As Branch Manager/Admin, you can submit or authorize Misc Savings withdrawals."
    elif is_designated_misc:
        role_notice = "As Designated Branch Officer, you can submit Misc Savings requests for Branch Manager approval."
    else:
        role_notice = "Misc Savings is managed by the Branch Manager and the Designated Officer. You can view the balance but cannot submit withdrawals."

    return MiscBalanceResponse(
        branch=current_user.branch,
        misc_balance=misc_bal,
        can_withdraw=can_withdraw,
        role_notice=role_notice
    )


@router.get("/laps-options", response_model=LapsOptionsResponse)
def get_laps_options(
    current_user: CurrentUser = Depends(require_role(WR_ALLOWED_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns branch/officer-scoped LAPS records with positive available balances and joined client details.
    """
    is_manager = current_user.role in WR_MANAGER_ROLES
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    laps_branch_scope = current_user.branch_id
    _, _, laps_pending, _ = _fetch_pending_reserved_map(uow, laps_branch_scope)

    client_map: Dict[str, dict] = {}
    co_client_ids: set = set()
    try:
        c_q = uow.client.table("clients").select("client_id, client_code, name, branch_id, officer_id")
        if current_user.branch_id:
            c_q = c_q.eq("branch_id", current_user.branch_id)
        c_res = c_q.execute()
        if isinstance(c_res.data, list):
            for c in c_res.data:
                if isinstance(c, dict) and c.get("client_id") and c.get("name"):
                    cid = str(c["client_id"])
                    client_map[cid] = c
                    if str(c.get("officer_id") or "") == str(officer_id):
                        co_client_ids.add(cid)
    except Exception as e:
        logger.warning(f"LAPS client lookup failed: {e}")

    l_q = uow.client.table("laps_savings").select("id, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, remarks, created_at")
    if current_user.branch_id:
        l_q = l_q.eq("branch_id", current_user.branch_id)
    res_laps = l_q.execute()
    laps_data: Dict[str, Dict] = {}
    if isinstance(res_laps.data, list):
        for lr in res_laps.data:
            if not isinstance(lr, dict):
                continue
            cid = lr.get("client_id") or lr.get("id")
            if not cid:
                continue
            c_info = client_map.get(str(cid), {})
            eff_branch = str(lr.get("branch_id") or c_info.get("branch_id") or "")
            eff_officer = str(lr.get("officer_id") or c_info.get("officer_id") or "")

            if current_user.branch_id and eff_branch and eff_branch != str(current_user.branch_id):
                continue
            if not is_manager:
                if str(cid) not in co_client_ids and (not eff_officer or eff_officer != str(officer_id)):
                    continue

            if cid not in laps_data:
                laps_data[cid] = {
                    "client_id": cid,
                    "client_name": c_info.get("name") or f"LAPS Client {str(cid)[:8]}",
                    "client_code": c_info.get("client_code") or str(cid)[:8],
                    "balance": 0.0,
                    "remarks": _clean_ui_remarks(lr.get("remarks")) or "",
                }
            laps_data[cid]["balance"] += float(lr.get("deposit_amount") or 0) - float(lr.get("withdrawal_amount") or 0)
            if not laps_data[cid]["remarks"] and lr.get("remarks"):
                laps_data[cid]["remarks"] = _clean_ui_remarks(lr.get("remarks"))

    laps_records = []
    for v in laps_data.values():
        avail_laps = max(0.0, float(v["balance"]) - laps_pending.get(str(v["client_id"]), 0.0))
        if avail_laps > 0:
            laps_records.append(LapsOptionRecord(
                client_id=v["client_id"],
                client_name=v["client_name"],
                client_code=v["client_code"],
                balance=avail_laps,
                remarks=v["remarks"],
            ))

    return LapsOptionsResponse(records=laps_records)


@router.get("/requests", response_model=WithdrawalRequestsResponse)
def get_my_withdrawal_requests(
    current_user: CurrentUser = Depends(require_role(WR_ALLOWED_ROLES)),
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
            operation_type=str(r.get("operation_type") or "Bank Transfer"),
            client_name=str(r.get("client_name") or ""),
            group_name=r.get("group_name"),
            amount=float(r.get("amount") or 0.0),
            payout_method=r.get("payout_method") or "Bank Transfer",
            reference=str(r.get("reference") or ""),
            remarks=_clean_ui_remarks(r.get("remarks")) or None,
            status=str(r.get("status") or "PENDING"),
            rejection_reason=r.get("rejection_reason"),
            created_at=str(r.get("created_at") or "")
        ))

    return WithdrawalRequestsResponse(requests=items)


def _extract_meta_from_payload(payload: CreateWithdrawalRequestInput) -> Dict[str, Optional[str]]:
    raw_remarks = str(payload.remarks or "")
    fee_type = payload.fee_type
    if not fee_type and "[FEE:" in raw_remarks:
        m = re.search(r"\[FEE:([^\]]+)\]", raw_remarks)
        if m:
            fee_type = m.group(1).strip()

    dest_id = payload.destination_id
    if not dest_id and "[DEST_ID:" in raw_remarks:
        m = re.search(r"\[DEST_ID:([^\]]+)\]", raw_remarks)
        if m:
            dest_id = m.group(1).strip()

    dest_name = payload.destination_name
    if not dest_name and "[DEST_NAME:" in raw_remarks:
        m = re.search(r"\[DEST_NAME:([^\]]+)\]", raw_remarks)
        if m:
            dest_name = m.group(1).strip()

    dest_type = payload.destination_type
    if not dest_type and "[DEST_TYPE:" in raw_remarks:
        m = re.search(r"\[DEST_TYPE:([^\]]+)\]", raw_remarks)
        if m:
            dest_type = m.group(1).strip()
    if dest_type in {"Group", "Group Account", "GroupSavings"}:
        dest_type = "GroupSavings"
    elif dest_type in {"Individual", "Individual Member", "Group Member", "IndividualSavings"}:
        dest_type = "IndividualSavings"

    return {
        "fee_type": fee_type,
        "dest_id": dest_id,
        "dest_name": dest_name,
        "dest_type": dest_type,
    }


def _resolve_payout_method(op_type: str, requested_payout: Optional[str]) -> str:
    # Option A: All direct customer savings withdrawals and LAPS payouts route strictly via Bank Transfer
    req_low = str(requested_payout or "").strip().lower()
    if req_low == "cash":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Direct cash payouts from savings/LAPS are disabled. Select Bank Transfer or record physical branch cash payments under Office Expenses.",
        )
    return "Bank Transfer"


def _validate_offset_loan(
    uow: SupabaseUnitOfWork,
    loan_id: str,
    amount: float,
    expected_client_id: Optional[str] = None,
    expected_group_id: Optional[str] = None,
) -> None:
    """Validate that a target loan exists, is Active/Approved, belongs to expected client/group, and covers offset."""
    l_res = uow.client.table("loans").select(
        "loan_id, client_id, status, active_credit, total_due, loan_amount, extra_fields"
    ).eq("loan_id", loan_id).limit(1).execute()
    l_rows = getattr(l_res, "data", None) or []
    if not l_rows or not isinstance(l_rows[0], dict):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target loan not found.")
    l_row = l_rows[0]
    l_status = str(l_row.get("status") or "").strip().lower()
    if l_status not in {"active", "approved"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Only Active or Approved loans can be offset from savings (current status: {l_row.get('status')}).",
        )
    loan_cid = str(l_row.get("client_id") or "")
    if expected_client_id and loan_cid and loan_cid != str(expected_client_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Target loan does not belong to the selected client.",
        )
    if expected_group_id and not expected_client_id and loan_cid:
        m_res = uow.client.table("client_memberships").select("client_id").eq("group_id", expected_group_id).execute()
        m_rows = getattr(m_res, "data", None) or []
        if m_rows and loan_cid not in {str(r.get("client_id") or "") for r in m_rows if isinstance(r, dict)}:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Target loan does not belong to a member of the selected group.",
            )
    rep_rows = uow.client.table("repayments").select("amount_paid").eq("loan_id", loan_id).execute().data or []
    paid_amt = sum(float(r.get("amount_paid") or 0.0) for r in rep_rows if isinstance(r, dict))
    extra_l = l_row.get("extra_fields") or {}
    td_base = float(l_row.get("total_due") or extra_l.get("total_due") or l_row.get("active_credit") or l_row.get("loan_amount") or 0.0)
    outstanding_bal = max(0.0, td_base - paid_amt)
    if amount > outstanding_bal + 0.01:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Offset amount (₦{amount:,.2f}) exceeds remaining loan balance (₦{outstanding_bal:,.2f}).",
        )


@router.post("/request", response_model=CreateWithdrawalRequestResponse)
def create_withdrawal_request(
    payload: CreateWithdrawalRequestInput,
    current_user: CurrentUser = Depends(require_role(WR_ALLOWED_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Creates a withdrawal request for Branch Manager approval, or directly executes atomically
    through SavingsService.execute_approved_withdrawal when BM/Admin requests auto_execute=True.
    """
    # 0. Request-level Idempotency Deduplication
    raw_idem = str(getattr(payload, "idempotency_key", None) or "").strip()
    if raw_idem:
        idem_lookup_key = raw_idem if raw_idem.startswith("WR-REQ-") else f"WR-REQ-{raw_idem}"
        try:
            dup_res = uow.client.table("withdrawal_requests").select(
                "id, reference, status, idempotency_key"
            ).eq("idempotency_key", idem_lookup_key).limit(1).execute()
            dup_rows = getattr(dup_res, "data", None) or []
            if dup_rows and isinstance(dup_rows[0], dict):
                dup = dup_rows[0]
                return CreateWithdrawalRequestResponse(
                    success=True,
                    request_id=str(dup.get("id") or ""),
                    reference=str(dup.get("reference") or ""),
                    status=str(dup.get("status") or "PENDING"),
                    message="Duplicate submission prevented — existing withdrawal request returned."
                )
        except Exception as dup_ex:
            logger.warning(f"Idempotency pre-check warning: {dup_ex}")
    else:
        idem_lookup_key = None

    # 1. Validate Business Date strictly (fail closed on malformed date; resolve branch business date when omitted)
    if payload.operational_date:
        try:
            target_dt = date.fromisoformat(payload.operational_date[:10])
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid operational_date format '{payload.operational_date}'. Expected YYYY-MM-DD."
            )
    else:
        biz_dt = BusinessDateService.get_business_date(uow, current_user.branch_id or current_user.branch)
        target_dt = biz_dt if isinstance(biz_dt, date) else date.today()

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
    is_manager = current_user.role in WR_MANAGER_ROLES
    is_designated_misc = _is_designated_misc_officer(uow, current_user)
    can_auto_exec = bool(payload.auto_execute and is_manager)

    wr_id = str(uuid.uuid4())
    req_idem_key = idem_lookup_key or f"WR-REQ-{wr_id}"
    prefix_code = "WTH" if stype == "Individual" else ("GRP" if stype == "Group" else ("MISC" if stype == "Misc" else "LAPS"))
    ref_code = f"REF-{prefix_code}-{datetime.now().strftime('%Y%m%d%H%M%S')}-{secrets.token_hex(2).upper()}"
    meta_in = _extract_meta_from_payload(payload)
    eff_payout = _resolve_payout_method(op_type, payload.payout_method)
    officer_uuid, _, actor_role_val, _ = SavingsService._resolve_actor_audit_info(uow, current_user.username, current_user.role)
    my_officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    transfer_ops = {"Savings Transfer", "Transfer to Another Savings", "Another Member or Group Savings"}
    loan_offset_ops = {
        "Loan Offset",
        "Asset Downpayment",
        "Loan Repayment / Asset Debt Offset",
        "Loan Repayment / Asset Debt Offset (Member Debt)",
    }

    # 3. Type-specific validation and balance verification
    target_branch_id = current_user.branch_id
    posting_branch = _resolve_branch_name(uow, target_branch_id) or current_user.branch
    resolved_group_id = payload.group_id

    if stype == "Individual":
        if not payload.client_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Client ID is required for Individual withdrawal.")

        res_c = uow.client.table("clients").select("name, branch_id, officer_id").eq("client_id", payload.client_id).execute()
        if not res_c.data:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Client not found.")
        c_row = res_c.data[0]
        target_branch_id = c_row.get("branch_id")
        check_branch_access(current_user, target_branch_id, "request withdrawal for this client")
        if not is_manager and "officer_id" in c_row:
            c_oid = c_row.get("officer_id")
            if not c_oid or (my_officer_id and str(c_oid) != str(my_officer_id)):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied: Client does not belong to your officer portfolio.",
                )
        if target_branch_id and target_branch_id != current_user.branch_id:
            t_open, t_reason = BusinessDateService.is_operational_open(uow, target_branch_id, target_dt)
            if not t_open:
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Operational Activity Suspended ({t_reason})")

        ind_pending, _, _, _ = _fetch_pending_reserved_map(uow, target_branch_id)
        ind_bal_raw = float(uow.individual_savings.get_total_balance(client_id=payload.client_id) or 0.0)
        ind_bal = max(0.0, ind_bal_raw - ind_pending.get(str(payload.client_id), 0.0))
        if payload.amount > (ind_bal + 0.01):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient available balance. Available: ₦{ind_bal:,.2f}"
            )
        if op_type in loan_offset_ops:
            if not payload.loan_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Select an eligible loan for offset."
                )
            _validate_offset_loan(uow, payload.loan_id, float(payload.amount), expected_client_id=payload.client_id)
        if op_type in transfer_ops:
            if not meta_in["dest_id"]:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Select a transfer destination.")
            if (meta_in["dest_type"] or "IndividualSavings") == "IndividualSavings" and meta_in["dest_id"] == payload.client_id:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Source and destination client cannot be the same.")

        client_name = payload.client_name or c_row.get("name") or "Client"
        posting_branch = _resolve_branch_name(uow, target_branch_id) or current_user.branch

        rec = {
            "id": wr_id,
            "savings_type": "Individual",
            "operation_type": op_type,
            "client_id": payload.client_id,
            "client_name": client_name,
            "loan_id": payload.loan_id,
            "branch_id": target_branch_id,
            "requested_by": current_user.username,
            "officer_id": officer_uuid,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "payout_method": eff_payout,
            "reference": ref_code,
            "remarks": _clean_ui_remarks(payload.remarks) or f"{op_type} request for {client_name}",
            "destination_id": meta_in["dest_id"],
            "destination_type": meta_in["dest_type"] or ("Loan" if op_type in loan_offset_ops else None),
            "fee_type": meta_in["fee_type"],
            "idempotency_key": req_idem_key,
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None,
        }

    elif stype == "Group":
        if not payload.group_name and not payload.group_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Group name or Group ID is required for Group withdrawal.")

        resolved_group_name = payload.group_name
        g_row = None
        if payload.group_id:
            res_g = uow.client.table("groups").select("group_id, name, branch_id, officer_id").eq("group_id", payload.group_id).execute()
            if res_g.data:
                g_row = res_g.data[0]
        elif payload.group_name:
            res_g = uow.client.table("groups").select("group_id, name, branch_id, officer_id").eq("name", payload.group_name).execute()
            if res_g.data:
                g_row = res_g.data[0]

        if not g_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Group not found.")

        target_branch_id = g_row.get("branch_id")
        resolved_group_name = resolved_group_name or g_row.get("name")
        resolved_group_id = g_row.get("group_id") or resolved_group_id

        check_branch_access(current_user, target_branch_id, "request group withdrawal")
        if not is_manager and "officer_id" in g_row:
            g_oid = g_row.get("officer_id")
            if not g_oid or (my_officer_id and str(g_oid) != str(my_officer_id)):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Access denied: Group does not belong to your officer portfolio.",
                )
        posting_branch = _resolve_branch_name(uow, target_branch_id) or current_user.branch

        _, grp_pending, _, _ = _fetch_pending_reserved_map(uow, target_branch_id)
        pending_grp = grp_pending[resolved_group_id] if resolved_group_id and resolved_group_id in grp_pending else grp_pending.get(resolved_group_name or "", 0.0)
        grp_bal_raw = float(uow.group_savings.get_total_balance(group_id=resolved_group_id or resolved_group_name) or 0.0)
        grp_bal = max(0.0, grp_bal_raw - pending_grp)
        if payload.amount > (grp_bal + 0.01):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient group balance. Available: ₦{grp_bal:,.2f}"
            )
        if op_type in loan_offset_ops:
            if not payload.loan_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Select an eligible member loan for Group loan offset."
                )
            grp_mem_cid = payload.client_id if (payload.client_id and str(payload.client_id) != str(resolved_group_id)) else None
            _validate_offset_loan(
                uow,
                payload.loan_id,
                float(payload.amount),
                expected_client_id=grp_mem_cid,
                expected_group_id=resolved_group_id,
            )
        if op_type in transfer_ops:
            if not meta_in["dest_id"]:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Select a transfer destination.")
            if (meta_in["dest_type"] or "") == "GroupSavings" and meta_in["dest_id"] in {resolved_group_id, resolved_group_name}:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Source and destination group cannot be the same.")
        if op_type in {"LAPS Transfer", "LAPS Reserve", "LAPS Reserve (Group Closed)"}:
            if not (payload.client_id or meta_in["dest_id"]):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Select a group member beneficiary for the LAPS Reserve transfer."
                )

        clean_member_cid = payload.client_id if (payload.client_id and str(payload.client_id) != str(resolved_group_id)) else None
        rec = {
            "id": wr_id,
            "savings_type": "Group",
            "operation_type": op_type,
            "group_id": resolved_group_id,
            "client_id": clean_member_cid,
            "client_name": payload.client_name or resolved_group_name,
            "group_name": resolved_group_name,
            "loan_id": payload.loan_id,
            "branch_id": target_branch_id,
            "requested_by": current_user.username,
            "officer_id": officer_uuid,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "payout_method": eff_payout,
            "reference": ref_code,
            "remarks": _clean_ui_remarks(payload.remarks) or f"Group {op_type} from {resolved_group_name}",
            "destination_id": meta_in["dest_id"],
            "destination_type": meta_in["dest_type"] or ("Loan" if op_type in loan_offset_ops else None),
            "fee_type": meta_in["fee_type"],
            "idempotency_key": req_idem_key,
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None,
        }

    elif stype == "Misc":
        if not is_manager and not is_designated_misc:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Misc Savings is managed by the Branch Manager and the Designated Officer."
            )
        _, _, _, misc_pending = _fetch_pending_reserved_map(uow, current_user.branch_id)
        misc_bal_raw = float(uow.misc_savings.get_total_balance(branch=posting_branch or current_user.branch) or 0.0)
        misc_bal = max(0.0, misc_bal_raw - misc_pending)
        if payload.amount > (misc_bal + 0.01):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient Misc balance. Available: ₦{misc_bal:,.2f}"
            )

        rec = {
            "id": wr_id,
            "savings_type": "Misc",
            "operation_type": op_type,
            "client_id": None,
            "client_name": f"Branch Misc - {posting_branch or current_user.branch}",
            "branch_id": current_user.branch_id,
            "requested_by": current_user.username,
            "officer_id": officer_uuid,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "payout_method": eff_payout,
            "reference": ref_code,
            "remarks": _clean_ui_remarks(payload.remarks) or f"Misc Savings {op_type} by {current_user.username}",
            "destination_id": meta_in["dest_id"],
            "destination_type": meta_in["dest_type"],
            "fee_type": meta_in["fee_type"],
            "idempotency_key": req_idem_key,
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None,
        }

    elif stype == "LAPS":
        if not payload.client_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="LAPS client ID is required.")

        laps_client_name = payload.client_name
        try:
            res_lc = uow.client.table("clients").select("name, branch_id, officer_id").eq("client_id", payload.client_id).limit(1).execute()
            if isinstance(res_lc.data, list) and res_lc.data:
                lc_row = res_lc.data[0]
                if lc_row.get("branch_id"):
                    target_branch_id = lc_row["branch_id"]
                    check_branch_access(current_user, target_branch_id, "request LAPS withdrawal for this client")
                    posting_branch = _resolve_branch_name(uow, target_branch_id) or current_user.branch
                if not is_manager and "officer_id" in lc_row:
                    lc_oid = lc_row.get("officer_id")
                    if not lc_oid or (my_officer_id and str(lc_oid) != str(my_officer_id)):
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="Access denied: LAPS client does not belong to your officer portfolio.",
                        )
                laps_client_name = laps_client_name or lc_row.get("name")
        except HTTPException:
            raise
        except Exception as ex:
            logger.warning(f"LAPS client lookup warning: {ex}")

        live_laps_bal = SavingsService._get_live_source_balance(
            uow, "LAPS", payload.client_id, None, None, posting_branch
        )
        _, _, laps_pending, _ = _fetch_pending_reserved_map(uow, target_branch_id)
        avail_laps_bal = max(0.0, float(live_laps_bal or 0.0) - laps_pending.get(str(payload.client_id), 0.0)) if live_laps_bal is not None else None
        if avail_laps_bal is not None and payload.amount > (avail_laps_bal + 0.01):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient LAPS balance. Available: ₦{avail_laps_bal:,.2f}"
            )

        is_return_to_savings = (
            op_type in ["Return to Savings", "Return to Client Savings", "LAPS Return to Customer Savings"]
            or (payload.payout_method == "Return to Savings")
        )
        laps_op_name = "LAPS Return to Customer Savings" if is_return_to_savings else "LAPS Payout"
        clean_note = _clean_ui_remarks(payload.remarks)
        laps_client_name = laps_client_name or (clean_note.split("\n")[0][:50] if clean_note else f"LAPS Client {payload.client_id[:8]}")

        rec = {
            "id": wr_id,
            "savings_type": "LAPS",
            "operation_type": laps_op_name,
            "client_id": payload.client_id,
            "client_name": laps_client_name,
            "branch_id": target_branch_id,
            "requested_by": current_user.username,
            "officer_id": officer_uuid,
            "amount": float(payload.amount),
            "operational_date": target_dt.isoformat(),
            "payout_method": "Return to Savings" if is_return_to_savings else eff_payout,
            "reference": ref_code,
            "remarks": clean_note or f"{laps_op_name} for {laps_client_name}",
            "destination_id": meta_in["dest_id"] or (payload.client_id if is_return_to_savings else None),
            "destination_type": "IndividualSavings" if is_return_to_savings else None,
            "fee_type": meta_in["fee_type"],
            "idempotency_key": req_idem_key,
            "status": "APPROVED" if can_auto_exec else "PENDING",
            "approved_by": current_user.username if can_auto_exec else None,
            "approved_at": datetime.now().isoformat() if can_auto_exec else None,
        }
    else:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Unsupported savings type: '{stype}'")

    # 4. Execute atomically with withdrawal_requests persistence or queue as PENDING
    if can_auto_exec:
        exec_item = dict(rec)
        if resolved_group_id:
            exec_item["group_id"] = resolved_group_id
        if meta_in["dest_name"]:
            exec_item["destination_name"] = meta_in["dest_name"]
        try:
            SavingsService.execute_approved_withdrawal(
                uow=uow,
                wr_item=exec_item,
                op_date=target_dt,
                branch=posting_branch,
                actor_username=current_user.username,
                actor_role=actor_role_val,
                extra_operations=[{"type": "insert", "table": "withdrawal_requests", "record": rec}],
                validate_balance=False,
                narration_prefix="[BM DIRECT EXECUTION]",
            )
            inserted_id = wr_id
        except ValueError as ve:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
        except Exception as ex:
            logger.error(f"Direct withdrawal execution failed: {ex}")
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Withdrawal execution failed: {ex}")
    else:
        res_ins = uow.client.table("withdrawal_requests").insert(rec).execute()
        inserted_id = res_ins.data[0]["id"] if res_ins.data else wr_id
        _emit_wr_user_audit(
            uow=uow,
            current_user=current_user,
            action="CREATE",
            entity_id=str(inserted_id),
            display_name=rec["client_name"],
            previous_value="None",
            new_value=f"₦{payload.amount:,.2f} ({rec['operation_type']})",
            status_val="PENDING",
        )

    msg = f"Withdrawal request of ₦{payload.amount:,.2f} submitted for BM approval! (Ref: {ref_code})"
    if can_auto_exec:
        msg = f"Withdrawal of ₦{payload.amount:,.2f} authorized and settled! (Ref: {ref_code})"

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
    current_user: CurrentUser = Depends(require_role(WR_ALLOWED_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live daily withdrawals data across all 4 savings tables (including cross-date reversals),
    Top KPIs, categorized tables, and filtered withdrawal requests history.
    """
    is_manager = current_user.role in WR_MANAGER_ROLES
    is_admin = current_user.role in ("Admin", "Super Admin")
    is_am = current_user.role in ("AM", "Area Manager")
    allowed_bids: List[str] = []
    if is_am:
        try:
            ab_res = uow.client.table("branches").select("branch_id").eq("area_manager_id", current_user.id).execute()
            allowed_bids = [str(b["branch_id"]) for b in (ab_res.data or []) if isinstance(b, dict) and b.get("branch_id")]
        except Exception:
            pass
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    if show_all:
        target_date_str = None
    elif target_date:
        target_date_str = target_date
    else:
        biz_dt = BusinessDateService.get_business_date(uow, current_user.branch_id or current_user.branch)
        target_date_str = (biz_dt if isinstance(biz_dt, date) else date.today()).isoformat()

    # 1. Fetch clients scoped by role (CO & BM only)
    c_q = uow.client.table("clients").select("client_id, client_code, name, nickname, officer_id, branch_id")
    if not is_manager:
        c_q = c_q.eq("officer_id", officer_id)
    elif current_user.branch_id:
        c_q = c_q.eq("branch_id", current_user.branch_id)

    dw_clients = c_q.execute().data or []
    dw_c_map = {c["client_id"]: c for c in dw_clients if isinstance(c, dict) and c.get("client_id")}
    dw_cids = list(dw_c_map.keys())

    # Also build broad branch client map so cross-officer/LAPS names still resolve cleanly
    branch_c_map = dict(dw_c_map)
    if not is_manager and current_user.branch_id:
        try:
            bc_res = uow.client.table("clients").select("client_id, client_code, name, officer_id, branch_id").eq("branch_id", current_user.branch_id).execute()
            for c in (bc_res.data or []):
                if isinstance(c, dict) and c.get("client_id"):
                    branch_c_map[c["client_id"]] = c
        except Exception:
            pass

    # 2. Query withdrawal_requests first (upper-bounded) to accurately classify structured categories
    wr_q = uow.client.table("withdrawal_requests").select("*")
    if not is_manager:
        wr_q = wr_q.eq("requested_by", current_user.username)
    elif current_user.branch_id:
        wr_q = wr_q.eq("branch_id", current_user.branch_id)

    if target_date_str:
        wr_q = wr_q.or_(
            f"operational_date.eq.{target_date_str},"
            f"and(created_at.gte.{target_date_str}T00:00:00,created_at.lte.{target_date_str}T23:59:59.999999)"
        )
    else:
        wr_q = wr_q.order("created_at", desc=True).limit(100)

    dw_reqs = wr_q.execute().data or []
    wr_by_ref: Dict[str, dict] = {}
    for w in dw_reqs:
        if isinstance(w, dict) and w.get("reference"):
            wr_by_ref[str(w["reference"])] = w

    def _scope_table_query(tbl: str, sel: str = "*"):
        q = uow.client.table(tbl).select(sel).neq("withdrawal_amount", 0)
        if target_date_str:
            q = q.eq("posting_date", target_date_str)
        else:
            q = q.order("posting_date", desc=True).limit(500)
        if tbl != "group_savings" and current_user.branch_id:
            q = q.eq("branch_id", current_user.branch_id)
        return q

    raw_ind_w = _scope_table_query("individual_savings").execute().data or []
    raw_grp_w = _scope_table_query("group_savings", "*, groups(name, branch_id, officer_id)").execute().data or []
    try:
        raw_misc_w = _scope_table_query("internal_savings").execute().data or []
    except Exception:
        raw_misc_w = []
    try:
        raw_laps_w = _scope_table_query("laps_savings").execute().data or []
    except Exception:
        raw_laps_w = []

    # Resolve client memberships only for scoped clients present in this branch/result set
    dw_group_map = {}
    scoped_cm_cids = list(dict.fromkeys(
        list(branch_c_map.keys())
        + [r.get("client_id") for r in raw_ind_w if isinstance(r, dict) and r.get("client_id")]
    ))
    if scoped_cm_cids:
        for chunk in _chunked(scoped_cm_cids):
            try:
                dw_cm_res = (
                    uow.client.table("client_memberships")
                    .select("client_id, groups(group_id, name)")
                    .in_("client_id", chunk)
                    .execute()
                )
                for m in (dw_cm_res.data or []):
                    cid = m.get("client_id")
                    if cid and m.get("groups"):
                        dw_group_map[cid] = m["groups"].get("name", "Individual")
            except Exception:
                pass

    def _classify_wr_row(remarks: str, ref: str, table_name: str, wr_row: Optional[dict]) -> tuple:
        r_low = remarks.lower()
        is_upfront = "auto-deducted upfront fees" in r_low or "upfront" in r_low or "downpayment deducted" in r_low
        if is_upfront:
            int_m = re.search(r"Interest:\s*([0-9,.]+)", remarks)
            gap_m = re.search(r"Gap:\s*([0-9,.]+)", remarks)
            loan_m = re.search(r"Loan\s+([A-Za-z0-9\-]+)", remarks)
            u_int = float(int_m.group(1).replace(",", "")) if int_m else 0.0
            u_gap = float(gap_m.group(1).replace(",", "")) if gap_m else 0.0
            l_ref = loan_m.group(1) if loan_m else "Loan"
            return "Loan Fee Deduction", f"Interest: ₦{u_int:,.2f} + Gap: ₦{u_gap:,.2f}", l_ref, u_int, u_gap

        clean_det = _clean_ui_remarks(remarks)
        if wr_row:
            op = str(wr_row.get("operation_type") or "")
            pay_m = str(wr_row.get("payout_method") or "")
            l_ref = str(wr_row.get("loan_id") or "")[:8] or "-"
            if op in {"Loan Offset", "Asset Downpayment", "Loan Repayment / Asset Debt Offset", "Loan Repayment / Asset Debt Offset (Member Debt)"}:
                return "Loan Offset", clean_det or "Loan debt offset from savings", l_ref, 0.0, 0.0
            if "fee" in op.lower():
                return "Fee Payment", clean_det or "Fee payment from savings", "-", 0.0, 0.0
            if op in {"LAPS Transfer", "LAPS Reserve", "LAPS Reserve (Group Closed)"}:
                return "LAPS Reserve", clean_det or "Transferred to LAPS Reserve", "-", 0.0, 0.0
            if "transfer" in op.lower() and "bank" not in op.lower() and op not in {"Bank Transfer", "Client Bank Account (Transfer)", "Group Bank Account (Transfer)"}:
                return "Savings Transfer", clean_det or "Savings internal transfer", "-", 0.0, 0.0
            if "return" in op.lower() and table_name == "laps_savings":
                return "LAPS Return", clean_det or "LAPS returned to savings", "-", 0.0, 0.0
            if table_name == "group_savings":
                if "bank" in op.lower() or "bank" in pay_m.lower():
                    return "Bank Transfer", clean_det or "Group bank transfer payout", "-", 0.0, 0.0
                return "Group Withdrawal", clean_det or "Group communal savings withdrawal", "-", 0.0, 0.0
            if table_name == "internal_savings":
                return "Misc Withdrawal", clean_det or "Branch miscellaneous savings withdrawal", "-", 0.0, 0.0
            if table_name == "laps_savings":
                if "bank" in pay_m.lower() or "bank" in op.lower():
                    return "Bank Transfer", clean_det or "LAPS bank transfer payout", "-", 0.0, 0.0
                return "LAPS Payout", clean_det or "LAPS reserve payout", "-", 0.0, 0.0
            if "bank" in op.lower() or "bank" in pay_m.lower():
                return "Bank Transfer", clean_det or "Bank transfer payout", "-", 0.0, 0.0
            return "Cash Payout", clean_det or "Cash payout to member", "-", 0.0, 0.0

        # Structured-tag / exact-phrase fallback for historical ledger records without withdrawal_requests row
        if "loan offset" in r_low or "debt offset" in r_low or "[loan_offset:" in r_low:
            return "Loan Offset", clean_det or "Loan debt offset from savings", "-", 0.0, 0.0
        if "fee offset" in r_low or "fee payment" in r_low or "[fee:" in r_low:
            return "Fee Payment", clean_det or "Fee payment from savings", "-", 0.0, 0.0
        if "laps transfer" in r_low or "laps reserve" in r_low or "transferred to laps" in r_low:
            return "LAPS Reserve", clean_det or "Transferred to LAPS Reserve", "-", 0.0, 0.0
        if "savings transfer" in r_low or "transferred to" in r_low or "[dest_id:" in r_low:
            return "Savings Transfer", clean_det or "Savings internal transfer", "-", 0.0, 0.0
        if table_name == "group_savings":
            return "Group Withdrawal", clean_det or "Group communal savings withdrawal", "-", 0.0, 0.0
        if table_name == "internal_savings":
            return "Misc Withdrawal", clean_det or "Branch miscellaneous savings withdrawal", "-", 0.0, 0.0
        if table_name == "laps_savings":
            if "return to savings" in r_low or "returned to" in r_low:
                return "LAPS Return", clean_det or "LAPS returned to savings", "-", 0.0, 0.0
            return "LAPS Payout", clean_det or "LAPS reserve payout", "-", 0.0, 0.0
        if "bank transfer" in r_low or "client bank account" in r_low or "bank payout" in r_low:
            return "Bank Transfer", clean_det or "Bank transfer payout", "-", 0.0, 0.0
        return "Cash Payout", clean_det or "Cash payout to member", "-", 0.0, 0.0

    parsed_records: List[Dict[str, Any]] = []
    reversed_keys: set = set()

    # Pre-scan reversals on loaded rows
    for row_list in (raw_ind_w, raw_grp_w, raw_misc_w, raw_laps_w):
        for r in row_list:
            if not isinstance(r, dict):
                continue
            w_amt = float(r.get("withdrawal_amount") or 0.0)
            ref_val = str(r.get("reference") or "")
            if w_amt < 0 or ref_val.startswith("REV-"):
                if ref_val.startswith("REV-"):
                    reversed_keys.add(ref_val[4:])
                idem = str(r.get("idempotency_key") or "")
                if idem.startswith("REV-"):
                    reversed_keys.add(idem[4:])

    # Cross-date reversal lookup so withdrawals posted earlier and reversed on a later date show REVERSED
    if target_date_str:
        for rev_tbl in ("individual_savings", "group_savings", "internal_savings", "laps_savings"):
            try:
                rq = uow.client.table(rev_tbl).select("reference, idempotency_key, withdrawal_amount").lt("withdrawal_amount", 0)
                if rev_tbl != "group_savings" and not is_admin:
                    if is_am and allowed_bids:
                        rq = rq.in_("branch_id", allowed_bids)
                    elif current_user.branch_id:
                        rq = rq.eq("branch_id", current_user.branch_id)
                for rr in (rq.execute().data or []):
                    if not isinstance(rr, dict):
                        continue
                    r_ref = str(rr.get("reference") or "")
                    r_idem = str(rr.get("idempotency_key") or "")
                    if r_ref.startswith("REV-"):
                        reversed_keys.add(r_ref[4:])
                    if r_idem.startswith("REV-"):
                        reversed_keys.add(r_idem[4:])
            except Exception:
                pass

    # Collect individual_savings
    for r in raw_ind_w:
        if not is_manager and r.get("officer_id") != officer_id and r.get("client_id") not in dw_cids:
            continue
        remarks = str(r.get("remarks") or "")
        amt = float(r.get("withdrawal_amount") or 0.0)
        cid = r.get("client_id")
        c_info = branch_c_map.get(cid, {})
        c_name = c_info.get("name") or "Unknown Client"
        c_code = c_info.get("client_code") or (str(cid)[:8] if cid else "-")
        g_name = dw_group_map.get(cid, "Individual")
        ref = str(r.get("reference") or "-")
        orig_ref = ref[4:] if ref.startswith("REV-") else None
        wr_row = wr_by_ref.get(ref) or (wr_by_ref.get(orig_ref) if orig_ref else None)
        category, details, l_ref, u_int, u_gap = _classify_wr_row(remarks, ref, "individual_savings", wr_row)
        is_rev_entry = amt < 0 or ref.startswith("REV-")
        rec_status = "REVERSAL" if is_rev_entry else ("REVERSED" if (ref in reversed_keys or str(r.get("id") or "") in reversed_keys) else "ACTIVE")
        parsed_records.append({
            "id": str(r.get("id") or ""),
            "table_name": "individual_savings",
            "date": str(r.get("posting_date") or "")[:10],
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
            "remarks": remarks,
            "status": rec_status,
        })

    # Collect group_savings (branch-scoped!)
    for gr in raw_grp_w:
        grp = gr.get("groups") or {}
        grp_branch = grp.get("branch_id") or gr.get("branch_id")
        if not is_admin:
            if is_am and allowed_bids and grp_branch and str(grp_branch) not in allowed_bids:
                continue
            if not is_am and current_user.branch_id and grp_branch and str(grp_branch) != str(current_user.branch_id):
                continue
        if not is_manager and grp.get("officer_id") != officer_id and gr.get("officer_id") != officer_id:
            continue
        g_amt = float(gr.get("withdrawal_amount") or 0.0)
        remarks = str(gr.get("remarks") or "")
        ref = str(gr.get("reference") or "-")
        orig_ref = ref[4:] if ref.startswith("REV-") else None
        wr_row = wr_by_ref.get(ref) or (wr_by_ref.get(orig_ref) if orig_ref else None)
        category, details, l_ref, u_int, u_gap = _classify_wr_row(remarks, ref, "group_savings", wr_row)
        is_rev_entry = g_amt < 0 or ref.startswith("REV-")
        rec_status = "REVERSAL" if is_rev_entry else ("REVERSED" if (ref in reversed_keys or str(gr.get("id") or "") in reversed_keys) else "ACTIVE")
        parsed_records.append({
            "id": str(gr.get("id") or ""),
            "table_name": "group_savings",
            "date": str(gr.get("posting_date") or "")[:10],
            "client_name": f"{grp.get('name', 'Group')} (Group Account)",
            "client_code": "-",
            "group": grp.get("name", "Group"),
            "category": category,
            "amount": g_amt,
            "details": details,
            "loan_ref": l_ref,
            "interest": u_int,
            "gap": u_gap,
            "reference": ref,
            "remarks": remarks,
            "status": rec_status,
        })

    # Collect internal_savings (Branch Misc; isolate CO view from BM direct/other-actor Misc postings)
    for mr in raw_misc_w:
        remarks = str(mr.get("remarks") or "")
        ref = str(mr.get("reference") or "-")
        orig_ref = ref[4:] if ref.startswith("REV-") else None
        if not is_manager:
            mr_ref_chk = orig_ref or ref
            in_my_wr = (ref in wr_by_ref) or (mr_ref_chk in wr_by_ref)
            if not in_my_wr:
                if mr.get("officer_id") != officer_id or "[bm " in remarks.lower() or mr_ref_chk.startswith("REF-MISC-"):
                    continue
        m_amt = float(mr.get("withdrawal_amount") or 0.0)
        wr_row = wr_by_ref.get(ref) or (wr_by_ref.get(orig_ref) if orig_ref else None)
        category, details, l_ref, u_int, u_gap = _classify_wr_row(remarks, ref, "internal_savings", wr_row)
        is_rev_entry = m_amt < 0 or ref.startswith("REV-")
        rec_status = "REVERSAL" if is_rev_entry else ("REVERSED" if (ref in reversed_keys or str(mr.get("id") or "") in reversed_keys) else "ACTIVE")
        parsed_records.append({
            "id": str(mr.get("id") or ""),
            "table_name": "internal_savings",
            "date": str(mr.get("posting_date") or "")[:10],
            "client_name": "Branch Misc Reserve",
            "client_code": "MISC",
            "group": "Branch Treasury",
            "category": category,
            "amount": m_amt,
            "details": details,
            "loan_ref": l_ref,
            "interest": u_int,
            "gap": u_gap,
            "reference": ref,
            "remarks": remarks,
            "status": rec_status,
        })

    # Collect laps_savings withdrawals
    for lr in raw_laps_w:
        cid = lr.get("client_id")
        if not is_manager and lr.get("officer_id") != officer_id and cid not in dw_cids:
            continue
        l_amt = float(lr.get("withdrawal_amount") or 0.0)
        c_info = branch_c_map.get(cid, {})
        c_name = c_info.get("name") or (f"LAPS Client {str(cid)[:8]}" if cid else "LAPS Reserve")
        c_code = c_info.get("client_code") or (str(cid)[:8] if cid else "-")
        remarks = str(lr.get("remarks") or "")
        ref = str(lr.get("reference") or "-")
        orig_ref = ref[4:] if ref.startswith("REV-") else None
        wr_row = wr_by_ref.get(ref) or (wr_by_ref.get(orig_ref) if orig_ref else None)
        category, details, l_ref, u_int, u_gap = _classify_wr_row(remarks, ref, "laps_savings", wr_row)
        is_rev_entry = l_amt < 0 or ref.startswith("REV-")
        rec_status = "REVERSAL" if is_rev_entry else ("REVERSED" if (ref in reversed_keys or str(lr.get("id") or "") in reversed_keys) else "ACTIVE")
        parsed_records.append({
            "id": str(lr.get("id") or ""),
            "table_name": "laps_savings",
            "date": str(lr.get("posting_date") or "")[:10],
            "client_name": c_name,
            "client_code": c_code,
            "group": dw_group_map.get(cid, "LAPS"),
            "category": category,
            "amount": l_amt,
            "details": details,
            "loan_ref": l_ref,
            "interest": u_int,
            "gap": u_gap,
            "reference": ref,
            "remarks": remarks,
            "status": rec_status,
        })

    parsed_records.sort(key=lambda x: x["date"], reverse=True)

    # 6. Calculate Top KPIs (netting reversals on date; keeping LAPS Reserve separate from cash payouts)
    total_withdrawn = sum(p["amount"] for p in parsed_records)
    upfront_total = sum(p["amount"] for p in parsed_records if p["category"] == "Loan Fee Deduction")
    payout_total = sum(
        p["amount"] for p in parsed_records
        if p["category"] in ["Cash Payout", "Bank Transfer", "Group Withdrawal", "Misc Withdrawal", "LAPS Payout"]
    )
    offset_total = sum(
        p["amount"] for p in parsed_records
        if p["category"] in ["Loan Offset", "Fee Payment", "Savings Transfer", "LAPS Return"]
    )
    laps_reserved_total = sum(p["amount"] for p in parsed_records if p["category"] == "LAPS Reserve")

    pending_reqs = [r for r in dw_reqs if str(r.get("status") or "").upper() == "PENDING"]
    pending_amt = sum(float(r.get("amount") or 0.0) for r in pending_reqs)

    kpis = DailyWithdrawalsKpis(
        total_withdrawn=total_withdrawn,
        loan_fees_deducted=upfront_total,
        cash_bank_paid=payout_total,
        debt_fee_offsets=offset_total,
        laps_reserved=laps_reserved_total,
        waiting_for_approval_count=len(pending_reqs),
        waiting_for_approval_amount=pending_amt
    )

    # 7. Apply category and search filters
    display_records = parsed_records
    if category_filter and category_filter != "All Types":
        if category_filter == "Loan Fee Deductions":
            display_records = [p for p in display_records if p["category"] == "Loan Fee Deduction"]
        elif category_filter == "Cash & Bank Payouts":
            display_records = [
                p for p in display_records
                if p["category"] in ["Cash Payout", "Bank Transfer", "Group Withdrawal", "LAPS Payout", "Misc Withdrawal"]
            ]
        elif category_filter == "Loan & Fee Offsets":
            display_records = [
                p for p in display_records
                if p["category"] in ["Loan Offset", "Fee Payment", "Savings Transfer", "LAPS Return"]
            ]
        elif category_filter == "Group Withdrawals":
            display_records = [p for p in display_records if p["category"] == "Group Withdrawal"]
        elif category_filter == "Misc & LAPS":
            display_records = [p for p in display_records if p["category"] in ["Misc Withdrawal", "LAPS Payout", "LAPS Return", "LAPS Reserve"]]
        elif category_filter == "LAPS Reserve":
            display_records = [p for p in display_records if p["category"] == "LAPS Reserve"]
        elif category_filter == "Reversals":
            display_records = [p for p in display_records if p["status"] in ("REVERSAL", "REVERSED")]

    if search:
        sk = search.lower().strip()
        display_records = [
            p for p in display_records
            if sk in p["client_name"].lower() or sk in p["client_code"].lower() or sk in p["loan_ref"].lower() or sk in p["reference"].lower() or sk in p["details"].lower()
        ]

    all_records = [
        DailyWithdrawalRecord(
            id=p["id"],
            table_name=p["table_name"],
            date=p["date"],
            client_name=p["client_name"],
            client_code=p["client_code"],
            group=p["group"],
            category=p["category"],
            amount=p["amount"],
            details=p["details"],
            loan_ref=p["loan_ref"],
            reference=p["reference"],
            status=p["status"],
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
        for p in display_records if p["category"] in ["Cash Payout", "Bank Transfer", "Group Withdrawal", "Misc Withdrawal", "LAPS Payout"]
    ]

    filtered_reqs = dw_reqs
    if category_filter and category_filter != "All Types":
        def _req_matches_cat(wr_rec: dict) -> bool:
            st_r = str(wr_rec.get("savings_type") or "")
            op_r = str(wr_rec.get("operation_type") or "").lower()
            pm_r = str(wr_rec.get("payout_method") or "").lower()
            if category_filter == "Loan Fee Deductions":
                return False
            if category_filter == "Cash & Bank Payouts":
                return ("offset" not in op_r and "fee" not in op_r and "laps transfer" not in op_r and "laps reserve" not in op_r and "return" not in op_r and ("transfer" not in op_r or "bank" in op_r or "bank" in pm_r))
            if category_filter == "Loan & Fee Offsets":
                return ("offset" in op_r or "fee" in op_r or ("transfer" in op_r and "bank" not in op_r) or "return" in op_r)
            if category_filter == "Group Withdrawals":
                return st_r == "Group"
            if category_filter == "Misc & LAPS":
                return st_r in ("Misc", "LAPS") or "laps" in op_r
            if category_filter == "LAPS Reserve":
                return "laps transfer" in op_r or "laps reserve" in op_r
            if category_filter == "Reversals":
                return False
            return True
        filtered_reqs = [r for r in filtered_reqs if isinstance(r, dict) and _req_matches_cat(r)]

    if search:
        sk = search.lower().strip()
        filtered_reqs = [
            r for r in filtered_reqs
            if isinstance(r, dict) and (
                sk in str(r.get("client_name") or "").lower()
                or sk in str(r.get("reference") or "").lower()
                or sk in str(r.get("operation_type") or "").lower()
                or sk in str(r.get("savings_type") or "").lower()
                or sk in str(r.get("remarks") or "").lower()
            )
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
            remarks=_clean_ui_remarks(r.get("remarks")) or None,
            rejection_reason=r.get("rejection_reason"),
            approved_by=r.get("approved_by"),
            approved_at=str(r.get("approved_at") or "")[:19] if r.get("approved_at") else None,
            amount=float(r.get("amount") or 0.0),
            status=str(r.get("status") or "PENDING")
        )
        for r in filtered_reqs
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
    current_user: CurrentUser = Depends(require_role(WR_MANAGER_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns pending withdrawal requests for Branch Manager approval queue.
    """
    query = uow.client.table("withdrawal_requests").select("*").eq("status", "PENDING").order("created_at", desc=False)
    if current_user.branch_id:
        query = query.eq("branch_id", current_user.branch_id)

    res = query.execute()
    items = []
    for r in (res.data or []):
        items.append(PendingApprovalItem(
            id=str(r.get("id")),
            client_id=r.get("client_id"),
            client_name=r.get("client_name") or "Unknown",
            savings_type=r.get("savings_type") or "Individual",
            operation_type=r.get("operation_type") or "Bank Transfer",
            group_name=r.get("group_name"),
            loan_id=r.get("loan_id"),
            destination_id=r.get("destination_id"),
            destination_type=r.get("destination_type"),
            fee_type=r.get("fee_type"),
            branch_id=r.get("branch_id") or current_user.branch_id,
            requested_by=r.get("requested_by") or "Officer",
            amount=float(r.get("amount") or 0.0),
            operational_date=str(r.get("operational_date") or str(r.get("created_at") or ""))[:10],
            reference=r.get("reference") or str(r.get("id"))[:8],
            remarks=_clean_ui_remarks(r.get("remarks")) or None,
            payout_method=r.get("payout_method") or "Bank Transfer"
        ))
    return PendingApprovalsResponse(requests=items)


@router.post("/approve", response_model=WithdrawalActionResponse)
def approve_withdrawal(
    payload: ApproveWithdrawalInput,
    current_user: CurrentUser = Depends(require_role(WR_MANAGER_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Approves a PENDING withdrawal request with 4-Eyes segregation, atomic PROCESSING claim,
    business date enforcement, live balance re-verification, and atomic SavingsService posting.
    """
    res = uow.client.table("withdrawal_requests").select("*").eq("id", payload.request_id).execute()
    if not res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Withdrawal request not found.")

    wr = res.data[0]
    wr_branch_id = wr.get("branch_id")
    check_branch_access(current_user, wr_branch_id, "approve withdrawals")
    req_by = str(wr.get("requested_by") or "").strip().lower()
    actor_uname = str(current_user.username or "").strip().lower()
    if req_by and actor_uname and req_by == actor_uname:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="4-Eyes Violation: You cannot approve or reject your own withdrawal request.",
        )
    posting_branch = _resolve_branch_name(uow, wr_branch_id) or current_user.branch

    curr_status = str(wr.get("status") or "").upper()
    if curr_status == "APPROVED":
        return WithdrawalActionResponse(success=True, message="Request has already been approved.")
    if curr_status == "REJECTED":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Cannot approve a rejected withdrawal request.")
    if curr_status == "PROCESSING":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Withdrawal request is currently being processed.")
    if curr_status != "PENDING":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Cannot approve request in status '{curr_status}'.")

    raw_op_date = payload.operational_date or wr.get("operational_date")
    if isinstance(raw_op_date, str) and raw_op_date.strip():
        try:
            effective_op_date = date.fromisoformat(raw_op_date[:10])
        except ValueError:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid operational_date format; expected YYYY-MM-DD.")
    elif isinstance(raw_op_date, date):
        effective_op_date = raw_op_date
    else:
        biz_dt = BusinessDateService.get_business_date(uow, wr_branch_id or current_user.branch_id or posting_branch)
        effective_op_date = biz_dt if isinstance(biz_dt, date) else date.today()

    is_open, open_reason = BusinessDateService.is_operational_open(uow, wr_branch_id or current_user.branch_id, effective_op_date)
    if not is_open:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Operational Activity Suspended ({open_reason}): Approvals blocked for closed branch date."
        )

    # Conditional atomic claim PENDING -> PROCESSING
    now_iso = datetime.now().isoformat()
    claim_res = uow.client.table("withdrawal_requests").update({
        "status": "PROCESSING",
        "approved_by": current_user.username,
        "approved_at": now_iso,
    }).eq("id", payload.request_id).eq("status", "PENDING").execute()

    if not claim_res.data:
        chk = uow.client.table("withdrawal_requests").select("status").eq("id", payload.request_id).execute()
        chk_st = str(chk.data[0].get("status") or "").upper() if chk.data else "UNKNOWN"
        if chk_st == "APPROVED":
            return WithdrawalActionResponse(success=True, message="Request has already been approved.")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Withdrawal request could not be claimed (status: {chk_st}).")

    wr_name = wr.get("client_name") or "Client"
    wr_amt = float(wr.get("amount") or 0.0)
    _, _, actor_role_val, _ = SavingsService._resolve_actor_audit_info(uow, current_user.username, current_user.role)

    wr_update_op = {
        "type": "update",
        "table": "withdrawal_requests",
        "match": {"id": payload.request_id, "status": "PROCESSING"},
        "record": {
            "status": "APPROVED",
            "approved_by": current_user.username,
            "approved_at": now_iso,
            "operational_date": effective_op_date.isoformat(),
        },
    }

    try:
        SavingsService.execute_approved_withdrawal(
            uow=uow,
            wr_item=wr,
            op_date=effective_op_date,
            branch=posting_branch,
            actor_username=current_user.username,
            actor_role=actor_role_val,
            extra_operations=[wr_update_op],
            validate_balance=True,
            narration_prefix="[BM APPROVED]",
        )
        return WithdrawalActionResponse(
            success=True,
            message=f"Withdrawal of ₦{wr_amt:,.2f} for {wr_name} approved and settled!"
        )
    except ValueError as ve:
        try:
            uow.client.table("withdrawal_requests").update({
                "status": "PENDING", "approved_by": None, "approved_at": None
            }).eq("id", payload.request_id).eq("status", "PROCESSING").execute()
        except Exception:
            pass
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except HTTPException:
        try:
            uow.client.table("withdrawal_requests").update({
                "status": "PENDING", "approved_by": None, "approved_at": None
            }).eq("id", payload.request_id).eq("status", "PROCESSING").execute()
        except Exception:
            pass
        raise
    except Exception as ex:
        try:
            uow.client.table("withdrawal_requests").update({
                "status": "PENDING", "approved_by": None, "approved_at": None
            }).eq("id", payload.request_id).eq("status", "PROCESSING").execute()
        except Exception:
            pass
        logger.error(f"Approval execution failed for request {payload.request_id}: {ex}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Approval execution failed: {str(ex)}")


@router.post("/reject", response_model=WithdrawalActionResponse)
def reject_withdrawal(
    payload: RejectWithdrawalInput,
    current_user: CurrentUser = Depends(require_role(WR_MANAGER_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Rejects a PENDING withdrawal request with 4-Eyes segregation, atomic status guard, and audit log emission.
    """
    res = uow.client.table("withdrawal_requests").select(
        "id, branch_id, status, client_name, amount, operation_type, requested_by"
    ).eq("id", payload.request_id).execute()
    if not res.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Withdrawal request not found.")
    wr = res.data[0]
    wr_branch_id = wr.get("branch_id")
    check_branch_access(current_user, wr_branch_id, "reject withdrawals")
    req_by = str(wr.get("requested_by") or "").strip().lower()
    actor_uname = str(current_user.username or "").strip().lower()
    if req_by and actor_uname and req_by == actor_uname:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="4-Eyes Violation: You cannot approve or reject your own withdrawal request.",
        )

    curr_status = str(wr.get("status") or "").upper()
    if curr_status in ("APPROVED", "PROCESSING"):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Cannot reject a withdrawal request that is already {curr_status}."
        )
    if curr_status == "REJECTED":
        return WithdrawalActionResponse(success=True, message="Withdrawal request has already been rejected.")

    reason_text = payload.rejection_reason or "Rejected by Manager"
    upd_res = uow.client.table("withdrawal_requests").update({
        "status": "REJECTED",
        "approved_by": current_user.username,
        "approved_at": datetime.now().isoformat(),
        "rejection_reason": reason_text,
    }).eq("id", payload.request_id).eq("status", "PENDING").execute()

    if not upd_res.data:
        chk = uow.client.table("withdrawal_requests").select("status").eq("id", payload.request_id).execute()
        chk_st = chk.data[0].get("status") if chk.data else "UNKNOWN"
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=f"Withdrawal request could not be rejected (status: {chk_st}).")

    _emit_wr_user_audit(
        uow=uow,
        current_user=current_user,
        action="REJECT",
        entity_id=payload.request_id,
        display_name=str(wr.get("client_name") or "Client"),
        previous_value="PENDING",
        new_value=f"REJECTED ({reason_text})",
        status_val="REJECTED",
    )

    return WithdrawalActionResponse(
        success=True,
        message="Withdrawal request rejected successfully."
    )
