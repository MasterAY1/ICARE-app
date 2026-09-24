"""
CO Collections route adapter.
1:1 Streamlit parity against app.py L4840–7259.
Reuses save_repayments, ScheduleService, RepaymentService, BusinessDateService, and CorrectionService.
"""
from typing import Optional, List, Dict, Any
from datetime import date, datetime, timedelta
import uuid
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.collections import (
    CollectionSheetResponse,
    CollectionSheetMember,
    SingleClientOptionsResponse,
    SingleClientOption,
    SingleClientLoanOption,
    SingleClientSubmitInput,
    SingleClientSubmitResponse,
    CollectionsHistoryResponse,
    GroupSummaryRow,
    RepaymentHistoryRow,
    SavingsHistoryRow,
    ReversedAuditRow,
    EodSummaryData,
    ReversalCandidatesResponse,
    ReversalCandidateItem,
    SubmittedReversalsResponse,
    SubmittedReversalItem,
)
from api.schemas.corrections import ReversalRequestInput, ReversalRequestResponse
from api.schemas.financial_writes import BatchCollectionInput, BatchCollectionResponse
from models.user import CurrentUser
from services.business_date_service import BusinessDateService
from services.schedule_service import ScheduleService
from services.repayment_service import RepaymentService
from services.correction_service import CorrectionService

router = APIRouter(prefix="/api/v1/co/collections", tags=["CO Collections"])


def _short_name_mobile(full_name: str, max_chars: int = 14) -> str:
    if not full_name:
        return "Unknown"
    parts = full_name.strip().split()
    if len(parts) >= 2:
        res = f"{parts[0]} {parts[1][0]}."
    else:
        res = parts[0]
    if len(res) > max_chars:
        res = res[:max_chars - 1] + "…"
    return res


@router.get("/sheet", response_model=CollectionSheetResponse)
def get_collection_sheet(
    group_name: Optional[str] = Query(None, description="Solidarity group name"),
    date_str: Optional[str] = Query(None, alias="date", description="Collection Date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns live collection sheet for the requested group and officer matching app.py L5522-6000.
    """
    target_date = date.today()
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD.")

    meeting_day = target_date.strftime("%A")
    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, target_date)
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id

    # 1. Fetch all clients and groups for officer to build disambiguated labels (app.py L4995-5064)
    res_c = uow.client.table("clients").select(
        "client_id, client_code, name, status, status_id, group_id, groups(name), client_memberships(group_id, groups(name)), client_statuses(name)"
    ).eq("officer_id", officer_id).execute()
    raw_clients = res_c.data or []

    _all_groups_res = uow.client.table("groups").select("group_id, name, meeting_day, group_number").execute()
    _groups_by_id = {g["group_id"]: g for g in (_all_groups_res.data or [])}
    _group_name_counts = {}
    for _gv in _groups_by_id.values():
        _gn = _gv.get("name", "")
        _group_name_counts[_gn] = _group_name_counts.get(_gn, 0) + 1

    def _make_group_label(g_id):
        gi = _groups_by_id.get(g_id)
        if not gi:
            return "Ungrouped"
        gn = gi.get("name", "Ungrouped")
        if _group_name_counts.get(gn, 1) > 1:
            return f"{gn} (#{gi.get('group_number', '?')} - {gi.get('meeting_day', '?')})"
        return gn

    clients_data = []
    for c in raw_clients:
        c_stat = (c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")
        if c_stat in ["Closed", "Suspended"]:
            continue
        c_group_id = c.get("group_id")
        g_name = (c.get("groups") or {}).get("name") if isinstance(c.get("groups"), dict) else None
        if not g_name:
            m_list = c.get("client_memberships") or []
            if isinstance(m_list, list):
                for m in m_list:
                    if m.get("groups") and m["groups"].get("name"):
                        g_name = m["groups"]["name"]
                        if not c_group_id and m.get("group_id"):
                            c_group_id = m.get("group_id")
                        break
            elif isinstance(m_list, dict):
                if m_list.get("groups") and m_list["groups"].get("name"):
                    g_name = m_list["groups"]["name"]
                    if not c_group_id and m_list.get("group_id"):
                        c_group_id = m_list.get("group_id")

        if not g_name:
            g_name = "Ungrouped"

        g_label = _make_group_label(c_group_id) if c_group_id else g_name
        clients_data.append({
            "client_id": c["client_id"],
            "client_code": c.get("client_code") or str(c["client_id"])[:8],
            "name": c["name"],
            "group_label": g_label,
            "raw_group_name": g_name,
            "group_id": c_group_id
        })

    # Available groups list matching app.py L5528-5533
    active_grps = sorted(list({c["group_label"] for c in clients_data if c["group_label"] != "Ungrouped"}))
    has_ungrouped = any(c["group_label"] == "Ungrouped" for c in clients_data)
    available_groups = active_grps + (["Ungrouped"] if (has_ungrouped or not active_grps) else [])
    if not available_groups:
        available_groups = ["Ungrouped"]

    # Resolve selected group
    selected_group = available_groups[0]
    if group_name and group_name != "All":
        if group_name in available_groups:
            selected_group = group_name
        else:
            matches = [g for g in available_groups if g == group_name or g.startswith(f"{group_name} (") or g.startswith(f"{group_name} #")]
            if matches:
                selected_group = matches[0]

    # Filter clients in selected group
    group_clients = [c for c in clients_data if c["group_label"] == selected_group]

    # Group savings balance matching app.py L5767-5781
    group_savings_balance = 0.0
    if selected_group != "Ungrouped" and group_clients:
        target_gid = group_clients[0].get("group_id")
        if target_gid:
            try:
                gs_res = uow.client.table("group_savings").select("deposit_amount, withdrawal_amount").eq("group_id", target_gid).execute()
                group_savings_balance = sum(float(g.get("deposit_amount") or 0) for g in (gs_res.data or [])) - sum(float(g.get("withdrawal_amount") or 0) for g in (gs_res.data or []))
            except Exception:
                group_savings_balance = 0.0

    # Today's repayments for this officer
    date_iso = target_date.isoformat()
    try:
        today_reps_res = uow.client.table("repayments").select("client_id, loan_id, amount_paid, payment_status, date").gte("date", f"{date_iso} 00:00:00").lte("date", f"{date_iso} 23:59:59").eq("officer_id", officer_id).execute()
        today_reps_data = today_reps_res.data or []
    except Exception:
        today_reps_data = []

    try:
        today_sav_res = uow.client.table("individual_savings").select("client_id, deposit_amount").eq("posting_date", date_iso).eq("officer_id", officer_id).execute()
        today_sav_data = today_sav_res.data or []
    except Exception:
        today_sav_data = []

    today_reps_by_cid = {}
    for r in today_reps_data:
        cid = r.get("client_id")
        if cid:
            today_reps_by_cid[cid] = today_reps_by_cid.get(cid, 0.0) + float(r.get("amount_paid") or 0.0)

    today_sav_by_cid = {}
    for s in today_sav_data:
        cid = s.get("client_id")
        if cid:
            today_sav_by_cid[cid] = today_sav_by_cid.get(cid, 0.0) + float(s.get("deposit_amount") or 0.0)

    # Pre-fetch active loans for these clients
    client_ids = [c["client_id"] for c in group_clients]
    loans_by_client = {}
    if client_ids:
        res_l = uow.client.table("loans").select(
            "loan_id, client_id, loan_amount, active_credit, total_due, product_category, start_date, loan_repay, extra_fields, loan_products(name)"
        ).in_("client_id", client_ids).in_("status", ["Active", "Approved", "ACTIVE"]).execute()
        for l in (res_l.data or []):
            cid = l.get("client_id")
            if cid not in loans_by_client:
                loans_by_client[cid] = []
            loans_by_client[cid].append(l)

    # Pre-fetch individual savings balances
    group_sav_map = {}
    if client_ids:
        try:
            res_bulk_sav = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").in_("client_id", client_ids).execute()
            for s in (res_bulk_sav.data or []):
                cid = s.get("client_id")
                d_amt = float(s.get("deposit_amount") or 0.0)
                w_amt = float(s.get("withdrawal_amount") or 0.0)
                group_sav_map[cid] = group_sav_map.get(cid, 0.0) + (d_amt - w_amt)
        except Exception:
            pass

    members: List[CollectionSheetMember] = []
    for c in group_clients:
        cid = c["client_id"]
        c_loans = loans_by_client.get(cid, [])
        sav_bal = group_sav_map.get(cid, 0.0)

        if not c_loans:
            prev_rep_val = today_reps_by_cid.get(cid, 0.0)
            prev_dep_val = today_sav_by_cid.get(cid, 0.0)
            members.append(CollectionSheetMember(
                client_id=cid,
                client_code=c["client_code"],
                client_name=c["name"],
                loan_id=None,
                loan_product="None",
                active_credit=0.0,
                remaining_balance=0.0,
                expected_repayment=0.0,
                savings_balance=sav_bal,
                is_asset=False,
                has_overdue=False,
                overdue_arrears=0.0,
                current_installment=0.0,
                is_future_loan=False,
                start_date=None,
                prev_rep=prev_rep_val,
                prev_dep=prev_dep_val,
                prev_status="NOT_PAID"
            ))
        else:
            for l_idx, loan_row in enumerate(c_loans):
                is_asset_l = bool(loan_row.get('is_asset') or 'asset' in str(loan_row.get('product_category') or '').lower())
                lid = loan_row.get('id') or loan_row.get('loan_id')
                act_cred = float(loan_row.get('active_credit') or loan_row.get('loan_amount') or 0.0)
                tot_due = float(loan_row.get('total_due') if loan_row.get('total_due') is not None else act_cred)

                # Total paid & remaining balance via ScheduleService (app.py L5684-5694)
                paid_amt, has_sched = ScheduleService.get_total_paid(uow, lid)
                if not has_sched:
                    res_r = uow.client.table("repayments").select("amount_paid").eq("loan_id", lid).execute()
                    paid_amt = sum(float(r.get("amount_paid") or 0.0) for r in (res_r.data or []))
                rem_bal = max(0.0, tot_due - paid_amt)

                lp = loan_row.get('loan_products') or {}
                prod_name = str(lp.get('name') or ("Asset Loan" if is_asset_l else "Daily Loan"))

                # Schedule due breakdown (app.py L5698-5714)
                due_info = ScheduleService.get_loan_due_breakdown(uow, lid, target_date, client_id=cid)
                exp_rep = float(due_info.get("total_due_today") or 0.0)
                has_ov = bool(due_info.get("has_overdue", False))
                ov_arrears = float(due_info.get("overdue_arrears") or 0.0)
                curr_inst = float(due_info.get("current_installment") or 0.0)

                inst_repay = float(loan_row.get('loan_repay') or loan_row.get('expected_installment') or 0.0)
                if exp_rep > 0.0:
                    exp_rep = min(exp_rep, rem_bal) if rem_bal > 0 else 0.0
                    if curr_inst <= 0.0 and not has_ov:
                        curr_inst = min(inst_repay, exp_rep) if inst_repay > 0 else exp_rep
                elif rem_bal > 0:
                    if inst_repay > 0:
                        exp_rep = min(inst_repay, rem_bal)
                    else:
                        dur = float(loan_row.get('duration') or 1)
                        inst_repay = (tot_due / dur) if dur > 0 else tot_due
                        exp_rep = min(inst_repay, rem_bal)
                    curr_inst = exp_rep

                s_date_str = str(loan_row.get('start_date') or '')
                is_future = False
                if s_date_str and s_date_str not in ['None', '']:
                    try:
                        s_dt = date.fromisoformat(s_date_str[:10])
                        if s_dt > target_date:
                            is_future = True
                            exp_rep = 0.0
                    except Exception:
                        pass

                row_cid = cid if l_idx == 0 else f"{cid}-L{l_idx+1}"
                row_cname = c["name"] if l_idx == 0 else f"{c['name']} (LOAN {l_idx+1})"
                row_sav = sav_bal if l_idx == 0 else 0.0

                prev_rep_val = today_reps_by_cid.get(row_cid, 0.0) or (exp_rep if exp_rep > 0 else 0.0)
                prev_dep_val = today_sav_by_cid.get(row_cid, 0.0)

                members.append(CollectionSheetMember(
                    client_id=row_cid,
                    client_code=c["client_code"],
                    client_name=row_cname,
                    loan_id=str(lid),
                    loan_product=prod_name,
                    active_credit=act_cred,
                    remaining_balance=rem_bal,
                    expected_repayment=exp_rep,
                    savings_balance=row_sav,
                    is_asset=is_asset_l,
                    has_overdue=has_ov,
                    overdue_arrears=ov_arrears,
                    current_installment=curr_inst,
                    is_future_loan=is_future,
                    start_date=s_date_str[:10] if s_date_str else None,
                    prev_rep=prev_rep_val,
                    prev_dep=prev_dep_val,
                    prev_status="PAID" if exp_rep > 0 else "NOT_PAID"
                ))

    return CollectionSheetResponse(
        group_name=selected_group,
        date=target_date.isoformat(),
        meeting_day=meeting_day,
        is_open=is_open,
        open_reason=open_reason,
        group_savings_balance=group_savings_balance,
        available_groups=available_groups,
        members=members
    )


@router.get("/single-client-options", response_model=SingleClientOptionsResponse)
def get_single_client_options(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns active clients and their active loans for Single Client Quick Entry (app.py L5252-5333).
    """
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    res_c = uow.client.table("clients").select(
        "client_id, client_code, name, status, group_id, groups(name), client_memberships(group_id, groups(name)), client_statuses(name)"
    ).eq("officer_id", officer_id).execute()

    client_items = []
    all_c = res_c.data or []
    if not all_c:
        return SingleClientOptionsResponse(clients=[])

    client_ids = [c["client_id"] for c in all_c]

    sav_map = {}
    try:
        res_sav = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").in_("client_id", client_ids).execute()
        for s in (res_sav.data or []):
            cid = s.get("client_id")
            d_amt = float(s.get("deposit_amount") or 0.0)
            w_amt = float(s.get("withdrawal_amount") or 0.0)
            sav_map[cid] = sav_map.get(cid, 0.0) + (d_amt - w_amt)
    except Exception:
        pass

    loans_by_cid = {}
    try:
        res_l = uow.client.table("loans").select(
            "loan_id, client_id, loan_amount, active_credit, total_due, loan_repay, extra_fields, loan_products(name)"
        ).in_("client_id", client_ids).in_("status", ["Active", "Approved", "ACTIVE"]).execute()
        for l in (res_l.data or []):
            cid = l.get("client_id")
            if cid not in loans_by_cid:
                loans_by_cid[cid] = []
            loans_by_cid[cid].append(l)
    except Exception:
        pass

    all_grp_ids = list({c.get("group_id") for c in all_c if c.get("group_id")})
    grp_sav_map = {}
    if all_grp_ids:
        try:
            res_gs = uow.client.table("group_savings").select("group_id, deposit_amount, withdrawal_amount").in_("group_id", all_grp_ids).execute()
            for g in (res_gs.data or []):
                gid = g.get("group_id")
                d_amt = float(g.get("deposit_amount") or 0.0)
                w_amt = float(g.get("withdrawal_amount") or 0.0)
                grp_sav_map[gid] = grp_sav_map.get(gid, 0.0) + (d_amt - w_amt)
        except Exception:
            pass

    for c in all_c:
        cid = c["client_id"]
        c_stat = (c.get("client_statuses") or {}).get("name") if isinstance(c.get("client_statuses"), dict) else c.get("status")
        if c_stat in ["Closed", "Suspended"]:
            continue

        c_group_id = c.get("group_id")
        g_name = (c.get("groups") or {}).get("name") if isinstance(c.get("groups"), dict) else None
        if not g_name:
            m_list = c.get("client_memberships") or []
            if isinstance(m_list, list) and m_list:
                g_name = (m_list[0].get("groups") or {}).get("name")
                if not c_group_id: c_group_id = m_list[0].get("group_id")

        is_in_grp = bool(g_name and g_name != "Ungrouped")
        p_sav = sav_map.get(cid, 0.0)
        g_sav = grp_sav_map.get(c_group_id, 0.0) if c_group_id else 0.0

        loan_options = []
        for l in loans_by_cid.get(cid, []):
            lid = l.get("id") or l.get("loan_id")
            act_cred = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
            tot_due = float(l.get("total_due") if l.get("total_due") is not None else act_cred)
            paid_amt, has_sched = ScheduleService.get_total_paid(uow, lid)
            if not has_sched:
                res_r = uow.client.table("repayments").select("amount_paid").eq("loan_id", lid).execute()
                paid_amt = sum(float(r.get("amount_paid") or 0.0) for r in (res_r.data or []))
            rem_bal = max(0.0, tot_due - paid_amt)
            lp = l.get("loan_products") or {}
            p_name = str(lp.get("name") or "Standard Loan")

            dur = float((l.get("extra_fields") or {}).get("duration") or 1)
            inst = float(l.get("loan_repay") or (tot_due / dur if dur > 0 else tot_due))
            exp_rep = min(inst, rem_bal) if rem_bal > 0 else 0.0

            loan_options.append(SingleClientLoanOption(
                loan_id=str(lid),
                label=f"{p_name} — Active Credit: ₦{act_cred:,.0f} (#{str(lid)[:8]})",
                product=p_name,
                active_credit=act_cred,
                remaining_balance=rem_bal,
                expected_repayment=exp_rep
            ))

        client_items.append(SingleClientOption(
            client_id=cid,
            client_code=c.get("client_code") or str(cid)[:8],
            client_name=c["name"],
            group_id=c_group_id,
            group_name=g_name or "Ungrouped",
            raw_group_name=g_name,
            is_in_group=is_in_grp,
            personal_savings_balance=p_sav,
            group_savings_balance=g_sav,
            loans=loan_options
        ))

    return SingleClientOptionsResponse(clients=client_items)


@router.post("/single-submit", response_model=SingleClientSubmitResponse)
def submit_single_client(
    payload: SingleClientSubmitInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Atomically posts an ad-hoc single client collection matching app.py L5377-5521.
    """
    target_date = date.today()
    if payload.date:
        try:
            target_date = date.fromisoformat(payload.date)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD.")

    date_str = target_date.isoformat()
    sc_batch_id = f"COL-SC-{date_str}-{uuid.uuid4().hex[:6].upper()}"

    prod_low = str(payload.loan_product or "60 day").lower()
    rep_12w = rep_24w = rep_60d = rep_120d = rep_mth = 0
    if "12 week" in prod_low or "12w" in prod_low: rep_12w = payload.loan_repayment
    elif "24 week" in prod_low or "24w" in prod_low: rep_24w = payload.loan_repayment
    elif "60 day" in prod_low or "60-day" in prod_low: rep_60d = payload.loan_repayment
    elif "120 day" in prod_low or "120-day" in prod_low: rep_120d = payload.loan_repayment
    elif "month" in prod_low: rep_mth = payload.loan_repayment
    else: rep_60d = payload.loan_repayment

    records_to_insert = []
    if payload.savings_deposit > 0 or payload.loan_repayment > 0 or payload.app_fee > 0 or payload.passbook_fee > 0 or payload.misc_fee > 0 or payload.group_savings_deposit == 0:
        records_to_insert.append({
            "batch_id": sc_batch_id,
            "tx_id": str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{payload.client_id}_rep")),
            "savings_tx_id": str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{payload.client_id}_sav")),
            "Date": date_str,
            "Client ID": payload.client_id,
            "Client Name": payload.client_name,
            "Group Name": payload.group_name or "Ungrouped",
            "Group ID": payload.group_id,
            "group_id": payload.group_id,
            "Officer": current_user.username,
            "Branch": current_user.branch,
            "client_id": payload.client_id,
            "id": payload.client_id,
            "loan_id": payload.loan_id,
            "Amount Paid": payload.loan_repayment,
            "Transaction Type": "Loan" if payload.loan_repayment > 0 else "Individual Savings Deposit",
            "Note": payload.note or "Single Client Collection",
            "Savings Amount": payload.savings_deposit,
            "Withdrawal Amount": 0.0,
            "Loan Repayment Amount": payload.loan_repayment,
            "Repayment 12 Weeks": rep_12w,
            "Repayment 24 Weeks": rep_24w,
            "Repayment 60 Days": rep_60d,
            "Repayment 120 Days": rep_120d,
            "Monthly": rep_mth,
            "App Fee": payload.app_fee,
            "Pass Book Bonus": payload.passbook_fee,
            "Misc Fees": payload.misc_fee,
            "Payment Status": "PAID" if payload.loan_repayment > 0 else "NOT_PAID",
            "Expected Amount": payload.loan_repayment
        })

    if payload.group_savings_deposit > 0 and payload.group_name and payload.group_name != "Ungrouped":
        records_to_insert.append({
            "batch_id": sc_batch_id,
            "tx_id": str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_group_{payload.client_id}_rep")),
            "savings_tx_id": str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_group_{payload.client_id}_sav")),
            "Date": date_str,
            "Client ID": f"GROUP-{payload.group_name}",
            "Client Name": f"{payload.group_name} (Group Savings from {payload.client_name})",
            "Officer": current_user.username,
            "Branch": current_user.branch,
            "Amount Paid": 0.0,
            "Transaction Type": "Group Meeting",
            "Note": f"Group Savings Deposit from {payload.client_name}",
            "Savings Amount": payload.group_savings_deposit,
            "Withdrawal Amount": 0.0,
            "group_id": payload.group_id,
            "Group ID": payload.group_id,
            "Group Savings Deposit": payload.group_savings_deposit,
            "Group Savings Withdrawal": 0.0,
            "Payment Status": "PAID"
        })

    from app import save_repayments
    receipt = save_repayments(records_to_insert, batch_id=sc_batch_id)
    if receipt:
        receipt["group_name"] = f"Single Client: {payload.client_name} ({payload.group_name})" if payload.group_name != "Ungrouped" else f"Single Client: {payload.client_name}"
        receipt["officer"] = current_user.username
        receipt["branch"] = current_user.branch
        receipt["date"] = date_str
        receipt["timestamp"] = datetime.now().strftime("%d %b %Y, %I:%M %p")

    return SingleClientSubmitResponse(
        success=True,
        receipt=receipt,
        message=f"Successfully posted single client collection for {payload.client_name}!"
    )


@router.post("/batch-submit", response_model=BatchCollectionResponse)
def submit_batch_collections(
    payload: BatchCollectionInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Atomically posts group collections and returns receipt matching app.py L6081-6101 & save_repayments.
    """
    target_date = date.today()
    if payload.date:
        try:
            target_date = date.fromisoformat(payload.date)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD.")

    is_open, open_reason = BusinessDateService.is_operational_open(uow, current_user.branch_id, target_date)
    if not is_open:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Cannot submit new collections today ({open_reason}).")

    date_str = target_date.isoformat()
    batch_id = f"COL-{date_str}-{uuid.uuid4().hex[:6].upper()}"
    to_insert = []

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

        cls_res = RepaymentService.classify_repayment(
            amount_paid=0.0 if is_marked_not_paid else rep,
            total_due_today=exp_amt,
            current_installment=exp_amt,
            has_overdue=False
        )
        p_status = "NOT_PAID" if is_marked_not_paid else cls_res["status"]
        overdue_val = exp_amt if is_marked_not_paid else cls_res["overdue_shortfall"]

        if sav == 0 and sav_wd == 0 and rep == 0 and app == 0 and pb == 0 and misc == 0 and asset_cr == 0 and cc == 0 and cfd == 0 and bon == 0:
            if not is_marked_not_paid:
                continue

        prod_low = str(item.loan_product or "60 day").lower()
        rep_12w = rep_24w = rep_60d = rep_120d = rep_mth = 0
        if "12 week" in prod_low or "12w" in prod_low: rep_12w = rep
        elif "24 week" in prod_low or "24w" in prod_low: rep_24w = rep
        elif "60 day" in prod_low or "60-day" in prod_low: rep_60d = rep
        elif "120 day" in prod_low or "120-day" in prod_low: rep_120d = rep
        elif "month" in prod_low: rep_mth = rep
        else: rep_60d = rep

        to_insert.append({
            "batch_id": batch_id,
            "Date": date_str,
            "Client ID": item.client_id,
            "Client Name": item.client_name,
            "Officer": current_user.username,
            "Branch": current_user.branch,
            "Amount Paid": rep,
            "Transaction Type": "Loan",
            "Note": f"Daily Collection - {payload.group_name}" if not is_marked_not_paid else "Marked NOT PAID (₦0 Collection)",
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
            "Overdue Amount": overdue_val,
            "mark_not_paid": is_marked_not_paid
        })

    g_dep = float(payload.group_savings_deposit or 0)
    g_wd = float(payload.group_savings_withdrawal or 0)
    if g_dep > 0 or g_wd > 0:
        to_insert.append({
            "batch_id": batch_id,
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
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No collection entries provided to save.")

    from app import save_repayments
    receipt = save_repayments(to_insert, batch_id=batch_id)
    if receipt:
        receipt["group_name"] = payload.group_name
        receipt["officer"] = current_user.username
        receipt["branch"] = current_user.branch
        receipt["date"] = date_str
        receipt["timestamp"] = datetime.now().strftime("%d %b %Y, %I:%M %p")

    tot_cash_in = float(receipt.get("total_cash", 0.0)) if receipt else 0.0
    tot_rep = float(receipt.get("total_repayment", 0.0)) if receipt else 0.0
    tot_sav = float(receipt.get("total_savings", 0.0)) if receipt else 0.0

    return BatchCollectionResponse(
        success=True,
        total_cash_in=tot_cash_in,
        total_repayments=tot_rep,
        total_savings=tot_sav,
        items_processed=len(to_insert),
        message=f"Successfully posted {len(to_insert)} collection entries for {payload.group_name}! (Total Cash In: ₦{tot_cash_in:,.2f})",
        receipt=receipt
    )


@router.get("/history", response_model=CollectionsHistoryResponse)
def get_collections_history(
    date_str: Optional[str] = Query(None, alias="date"),
    officer: Optional[str] = Query(None, alias="officer"),
    search: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns audit history matching app.py L6401-6978.
    """
    target_date = date.today()
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format.")

    hist_date_str = target_date.isoformat()
    search_term = (search or "").strip().lower()

    is_manager = current_user.role in ["BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"]
    available_officers: List[str] = []

    # Preload group id -> group name map to guarantee bulletproof group resolution (app.py L6457-6464)
    all_groups_map = {}
    try:
        g_res = uow.client.table("groups").select("group_id, name").execute()
        all_groups_map = {g["group_id"]: g["name"] for g in (g_res.data or []) if g.get("group_id") and g.get("name")}
    except Exception:
        pass

    # Preload user map for displaying officer names (app.py L6594-6601)
    hist_user_cache = {}
    try:
        for u in uow.users.find_all():
            u_nm = getattr(u, 'username', '') or ""
            f_nm = getattr(u, 'full_name', '') or ""
            hist_user_cache[u.id] = f"{u_nm} ({f_nm})" if u_nm and f_nm else (f_nm or u_nm or "Officer")
            if u_nm and getattr(u, 'role', '') in ["CO", "Credit Officer", "Officer"] and getattr(u, 'branch_id', None) == current_user.branch_id:
                if u_nm not in available_officers:
                    available_officers.append(u_nm)
    except Exception:
        pass
    available_officers.sort()

    q_reps = uow.client.table("repayments").select(
        "id, client_id, amount_paid, transaction_type, date, created_at, note, officer_id, loan_id, payment_status, expected_amount, overdue_amount, "
        "clients(name, client_code, group_id, groups(name)), loans(loan_amount, active_credit, loan_products(name))"
    )
    q_sav = uow.client.table("individual_savings").select(
        "id, client_id, deposit_amount, withdrawal_amount, posting_date, created_at, reference, remarks, officer_id, "
        "clients(name, client_code, group_id, groups(name))"
    )
    q_gsav = uow.client.table("group_savings").select(
        "id, group_id, deposit_amount, withdrawal_amount, posting_date, created_at, reference, remarks, officer_id, groups(name)"
    )

    if not is_manager:
        officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
        q_reps = q_reps.eq("officer_id", officer_id)
        q_sav = q_sav.eq("officer_id", officer_id)
        q_gsav = q_gsav.eq("officer_id", officer_id)
    else:
        if current_user.role in ["AM", "Area Manager"]:
            assigned_branches = getattr(current_user, "assigned_branches", [current_user.branch_id])
            q_reps = q_reps.in_("branch_id", assigned_branches)
            q_sav = q_sav.in_("branch_id", assigned_branches)
            q_gsav = q_gsav.in_("branch_id", assigned_branches)
        elif current_user.branch_id:
            q_reps = q_reps.eq("branch_id", current_user.branch_id)
            q_sav = q_sav.eq("branch_id", current_user.branch_id)
            q_gsav = q_gsav.eq("branch_id", current_user.branch_id)

        if officer and officer != "All Officers":
            target_uid = uow.loans._resolve_officer_id(officer)
            if target_uid:
                q_reps = q_reps.eq("officer_id", target_uid)
                q_sav = q_sav.eq("officer_id", target_uid)
                q_gsav = q_gsav.eq("officer_id", target_uid)

    res_reps = q_reps.gte("date", f"{hist_date_str}T00:00:00").lte("date", f"{hist_date_str}T23:59:59").order("created_at", desc=True).execute()
    res_sav = q_sav.eq("posting_date", hist_date_str).order("created_at", desc=True).execute()
    res_gsav = q_gsav.eq("posting_date", hist_date_str).order("created_at", desc=True).execute()

    reps_list = res_reps.data or []
    sav_list = res_sav.data or []
    gsav_list = res_gsav.data or []

    approved_reversed_ids = set()
    reversal_entry_ids = set()
    try:
        res_app_corr = uow.client.table("correction_requests").select("record_id").eq("status", "Approved").execute()
        for c in (res_app_corr.data or []):
            if c.get("record_id"): approved_reversed_ids.add(str(c["record_id"]))
    except Exception:
        pass

    try:
        res_neg_sav = uow.client.table("individual_savings").select("id, remarks").lt("deposit_amount", 0).execute()
        for r in (res_neg_sav.data or []):
            reversal_entry_ids.add(str(r["id"]))
            rem = str(r.get("remarks") or "")
            if "REVERSAL of " in rem:
                try:
                    target_id = rem.split("REVERSAL of ")[1].split(".")[0].split(" ")[0].strip()
                    if target_id: approved_reversed_ids.add(target_id)
                except Exception:
                    pass
    except Exception:
        pass

    try:
        res_neg_reps = uow.client.table("repayments").select("id, note").lt("amount_paid", 0).execute()
        for r in (res_neg_reps.data or []):
            reversal_entry_ids.add(str(r["id"]))
            note_text = str(r.get("note") or "")
            if "REVERSAL of " in note_text:
                try:
                    target_id = note_text.split("REVERSAL of ")[1].split(".")[0].split(" ")[0].strip()
                    if target_id: approved_reversed_ids.add(target_id)
                except Exception:
                    pass
    except Exception:
        pass

    clean_reps = []
    reversed_reps = []
    for r in reps_list:
        rid = str(r.get("id") or "")
        amt = float(r.get("amount_paid") or 0.0)
        note = str(r.get("note") or "")
        if rid in approved_reversed_ids or rid in reversal_entry_ids or amt < 0 or "REVERSAL of" in note or "CORRECTION:" in note:
            reversed_reps.append(r)
        else:
            clean_reps.append(r)

    clean_sav = []
    reversed_sav = []
    for s in sav_list:
        sid = str(s.get("id") or "")
        dep = float(s.get("deposit_amount") or 0.0)
        rem = str(s.get("remarks") or "")
        if sid in approved_reversed_ids or sid in reversal_entry_ids or dep <= 0 or "REVERSAL of" in rem or "CORRECTION:" in rem:
            reversed_sav.append(s)
        else:
            clean_sav.append(s)

    clean_gsav = []
    for g in gsav_list:
        gid = str(g.get("id") or "")
        dep = float(g.get("deposit_amount") or 0.0)
        rem = str(g.get("remarks") or "")
        if gid not in approved_reversed_ids and gid not in reversal_entry_ids and dep > 0 and "REVERSAL of" not in rem and "CORRECTION:" not in rem:
            clean_gsav.append(g)

    groups_agg = {}
    for r in clean_reps:
        c_dict = r.get("clients") or {} if isinstance(r.get("clients"), dict) else {}
        g_dict = c_dict.get("groups") or {} if isinstance(c_dict.get("groups"), dict) else {}
        g_name = g_dict.get("name") or all_groups_map.get(c_dict.get("group_id")) or "Ungrouped"
        amt = float(r.get("amount_paid") or 0.0)
        exp_amt = float(r.get("expected_amount") or 0.0)
        cid = str(r.get("client_id") or "")

        if g_name not in groups_agg:
            groups_agg[g_name] = {"tot_rep": 0.0, "mem_sav": 0.0, "grp_sav": 0.0, "paying": set(), "details": []}
        groups_agg[g_name]["tot_rep"] += amt
        if amt > 0 and cid: groups_agg[g_name]["paying"].add(cid)

        c_name = c_dict.get("name") or cid
        c_code = c_dict.get("client_code") or ""
        p_stat = str(r.get("payment_status") or ("PAID" if amt > 0 else "NOT_PAID")).upper()
        l_dict = r.get("loans") or {} if isinstance(r.get("loans"), dict) else {}
        p_dict = l_dict.get("loan_products") or {} if isinstance(l_dict.get("loan_products"), dict) else {}
        p_name = p_dict.get("name") or "Standard Loan"
        off_disp = hist_user_cache.get(r.get("officer_id"), current_user.username)
        t_str = str(r.get("created_at") or r.get("date") or "")[11:16]

        item_row = {
            "client_name": c_name, "client_code": c_code, "type": "Loan Repayment", "product": p_name,
            "expected_amount": exp_amt, "amount_paid": amt, "status": p_stat,
            "time": t_str, "officer": off_disp,
            "Client Name": c_name, "Client Code": c_code, "Type": "Loan Repayment", "Product": p_name,
            "Expected (₦)": exp_amt, "Amount Paid (₦)": amt, "Status": p_stat,
            "Time": t_str, "Officer": off_disp
        }
        groups_agg[g_name]["details"].append(item_row)

    for s in clean_sav:
        c_dict = s.get("clients") or {} if isinstance(s.get("clients"), dict) else {}
        g_dict = c_dict.get("groups") or {} if isinstance(c_dict.get("groups"), dict) else {}
        g_name = g_dict.get("name") or all_groups_map.get(c_dict.get("group_id")) or "Ungrouped"
        amt = float(s.get("deposit_amount") or 0.0)
        cid = str(s.get("client_id") or "")

        if g_name not in groups_agg:
            groups_agg[g_name] = {"tot_rep": 0.0, "mem_sav": 0.0, "grp_sav": 0.0, "paying": set(), "details": []}
        groups_agg[g_name]["mem_sav"] += amt
        if amt > 0 and cid: groups_agg[g_name]["paying"].add(cid)

        c_name = c_dict.get("name") or cid
        c_code = c_dict.get("client_code") or ""
        off_disp = hist_user_cache.get(s.get("officer_id"), current_user.username)
        t_str = str(s.get("created_at") or s.get("posting_date") or "")[11:16]

        item_row = {
            "client_name": c_name, "client_code": c_code, "type": "Member Savings", "product": "Individual Savings",
            "expected_amount": 0.0, "amount_paid": amt, "status": "SAVINGS DEPOSIT",
            "time": t_str, "officer": off_disp,
            "Client Name": c_name, "Client Code": c_code, "Type": "Member Savings", "Product": "Individual Savings",
            "Expected (₦)": 0.0, "Amount Paid (₦)": amt, "Status": "SAVINGS DEPOSIT",
            "Time": t_str, "Officer": off_disp
        }
        groups_agg[g_name]["details"].append(item_row)

    for g in clean_gsav:
        g_dict = g.get("groups") or {} if isinstance(g.get("groups"), dict) else {}
        g_name = g_dict.get("name") or all_groups_map.get(g.get("group_id")) or "Group Communal"
        amt = float(g.get("deposit_amount") or 0.0)

        if g_name not in groups_agg:
            groups_agg[g_name] = {"tot_rep": 0.0, "mem_sav": 0.0, "grp_sav": 0.0, "paying": set(), "details": []}
        groups_agg[g_name]["grp_sav"] += amt
        off_disp = hist_user_cache.get(g.get("officer_id"), current_user.username)
        t_str = str(g.get("created_at") or g.get("posting_date") or "")[11:16]

        item_row = {
            "client_name": f"{g_name} (Communal)", "client_code": "GROUP", "type": "Group Savings", "product": "Group Communal",
            "expected_amount": 0.0, "amount_paid": amt, "status": "GROUP SAVINGS",
            "time": t_str, "officer": off_disp,
            "Client Name": f"{g_name} (Communal)", "Client Code": "GROUP", "Type": "Group Savings", "Product": "Group Communal",
            "Expected (₦)": 0.0, "Amount Paid (₦)": amt, "Status": "GROUP SAVINGS",
            "Time": t_str, "Officer": off_disp
        }
        groups_agg[g_name]["details"].append(item_row)

    group_rows: List[GroupSummaryRow] = []
    for g_name, g_info in sorted(groups_agg.items(), key=lambda x: x[0]):
        tot_rep = g_info["tot_rep"]
        mem_sav = g_info["mem_sav"]
        grp_sav = g_info["grp_sav"]
        tot_sav = mem_sav + grp_sav
        tot_col = tot_rep + tot_sav

        if search_term:
            match_grp = (search_term in g_name.lower()) or any(
                search_term in str(m.get("client_name", "")).lower() or search_term in str(m.get("client_code", "")).lower()
                for m in g_info["details"]
            )
            if not match_grp: continue

        group_rows.append(GroupSummaryRow(
            group_name=g_name,
            total_repayment=tot_rep,
            member_savings=mem_sav,
            group_savings=grp_sav,
            total_savings=tot_sav,
            grand_total=tot_col,
            paying_members_count=len(g_info["paying"]),
            details=g_info["details"],
            items=g_info["details"]
        ))

    repayment_rows: List[RepaymentHistoryRow] = []
    for r in clean_reps:
        c_dict = r.get("clients") or {} if isinstance(r.get("clients"), dict) else {}
        c_name = c_dict.get("name") or "Unknown"
        c_code = c_dict.get("client_code") or ""
        l_dict = r.get("loans") or {} if isinstance(r.get("loans"), dict) else {}
        p_dict = l_dict.get("loan_products") or {} if isinstance(l_dict.get("loan_products"), dict) else {}
        p_name = p_dict.get("name") or "Standard Loan"
        amt = float(r.get("amount_paid") or 0.0)
        exp_amt = float(r.get("expected_amount") or 0.0)
        p_stat = str(r.get("payment_status") or ("PAID" if amt > 0 else "NOT_PAID")).upper()
        ref_id = str(r.get("id") or "")
        off_disp = hist_user_cache.get(r.get("officer_id"), current_user.username)

        if search_term:
            if not (search_term in c_name.lower() or search_term in c_code.lower() or search_term in ref_id.lower() or search_term in p_stat.lower() or search_term in off_disp.lower()):
                continue

        repayment_rows.append(RepaymentHistoryRow(
            time=str(r.get("created_at") or r.get("date") or "")[11:16],
            officer=off_disp,
            client_name=c_name,
            client_code=c_code,
            product=p_name,
            expected_amount=exp_amt,
            amount_paid=amt,
            status=p_stat,
            note=str(r.get("note") or "Loan"),
            ref_id=ref_id[:8]
        ))

    savings_rows: List[SavingsHistoryRow] = []
    for s in clean_sav:
        c_dict = s.get("clients") or {} if isinstance(s.get("clients"), dict) else {}
        c_name = c_dict.get("name") or "Unknown"
        c_code = c_dict.get("client_code") or ""
        amt = float(s.get("deposit_amount") or 0.0)
        ref_id = str(s.get("id") or "")
        rem = str(s.get("remarks") or s.get("reference") or "Individual Deposit")
        off_disp = hist_user_cache.get(s.get("officer_id"), current_user.username)

        if search_term:
            if not (search_term in c_name.lower() or search_term in c_code.lower() or search_term in ref_id.lower() or search_term in rem.lower() or search_term in off_disp.lower()):
                continue

        savings_rows.append(SavingsHistoryRow(
            time=str(s.get("created_at") or s.get("posting_date") or "")[11:16],
            officer=off_disp,
            client_name=c_name,
            client_code=c_code,
            deposit_amount=amt,
            remarks=rem,
            ref_id=ref_id[:8]
        ))

    for g in clean_gsav:
        g_name = (g.get("groups") or {}).get("name") if isinstance(g.get("groups"), dict) else None
        if not g_name and g.get("group_id"):
            g_name = all_groups_map.get(g.get("group_id"))
        if not g_name:
            g_name = "Group Communal"
        c_name = f"{g_name} (Communal)"
        c_code = "GROUP"
        amt = float(g.get("deposit_amount") or 0.0)
        ref_id = str(g.get("id") or "")
        rem = str(g.get("remarks") or "Group Communal Savings")
        off_disp = hist_user_cache.get(g.get("officer_id"), current_user.username)

        if search_term:
            if not (search_term in c_name.lower() or search_term in c_code.lower() or search_term in ref_id.lower() or search_term in rem.lower() or search_term in off_disp.lower()):
                continue

        savings_rows.append(SavingsHistoryRow(
            time=str(g.get("created_at") or g.get("posting_date") or "")[11:16],
            officer=off_disp,
            client_name=c_name,
            client_code=c_code,
            deposit_amount=amt,
            remarks=rem,
            ref_id=ref_id[:8]
        ))

    reversed_rows: List[ReversedAuditRow] = []
    for rr in reversed_reps:
        c_dict = rr.get("clients") or {} if isinstance(rr.get("clients"), dict) else {}
        reversed_rows.append(ReversedAuditRow(
            type="Loan Repayment",
            client=f"{c_dict.get('name', 'Unknown')} ({c_dict.get('client_code', '')})",
            amount=abs(float(rr.get("amount_paid") or 0.0)),
            status="Reversed",
            ref_id=str(rr.get("id") or "")[:8],
            reason=str(rr.get("note") or "Reversed")
        ))
    for rs in reversed_sav:
        c_dict = rs.get("clients") or {} if isinstance(rs.get("clients"), dict) else {}
        reversed_rows.append(ReversedAuditRow(
            type="Savings Deposit",
            client=f"{c_dict.get('name', 'Unknown')} ({c_dict.get('client_code', '')})",
            amount=abs(float(rs.get("deposit_amount") or 0.0)),
            status="Reversed",
            ref_id=str(rs.get("id") or "")[:8],
            reason=str(rs.get("remarks") or "Reversed")
        ))

    eod_data = None
    eod_log = []
    try:
        q_eod = uow.client.table("co_cashbooks").select("*").eq("date", hist_date_str)
        if current_user.branch_id:
            q_eod = q_eod.eq("branch_id", current_user.branch_id)
        if not is_manager:
            officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
            q_eod = q_eod.eq("officer_id", officer_id)
        elif officer and officer != "All Officers":
            t_uid = uow.loans._resolve_officer_id(officer)
            if t_uid: q_eod = q_eod.eq("officer_id", t_uid)

        res_eod = q_eod.execute()
        eod_entries = res_eod.data or []
        if eod_entries:
            eod_data = EodSummaryData(
                opening_cash=sum(float(r.get("opening_balance") or 0.0) for r in eod_entries),
                bank_deposit=sum(float(r.get("bank_deposit") or 0.0) for r in eod_entries),
                office_expenses=sum(float(r.get("office_expenses") or 0.0) for r in eod_entries),
                app_fee=sum(float(r.get("app_fee") or 0.0) for r in eod_entries),
                passbook=sum(float(r.get("passbook") or 0.0) for r in eod_entries),
                misc_fees=sum(float(r.get("misc_fees") or 0.0) for r in eod_entries),
                form_damage=sum(float(r.get("credit_form_damage") or 0.0) for r in eod_entries),
                bonus=sum(float(r.get("bonus") or 0.0) for r in eod_entries)
            )

        q_eod_hist = uow.client.table("co_cashbooks").select("*")
        if current_user.branch_id:
            q_eod_hist = q_eod_hist.eq("branch_id", current_user.branch_id)
        if not is_manager:
            officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
            q_eod_hist = q_eod_hist.eq("officer_id", officer_id)
        elif officer and officer != "All Officers":
            t_uid = uow.loans._resolve_officer_id(officer)
            if t_uid: q_eod_hist = q_eod_hist.eq("officer_id", t_uid)

        res_eod_log = q_eod_hist.order("date", desc=True).limit(30).execute()
        for h in (res_eod_log.data or []):
            eod_log.append({
                "Date": h.get("date"),
                "Officer": hist_user_cache.get(h.get("officer_id"), current_user.username),
                "B/F Cash": float(h.get("opening_balance") or 0.0),
                "Bank Deposit": float(h.get("bank_deposit") or 0.0),
                "Expenses": float(h.get("office_expenses") or 0.0),
                "App Fee": float(h.get("app_fee") or 0.0),
                "Passbook": float(h.get("passbook") or 0.0),
                "Misc Fees": float(h.get("misc_fees") or 0.0),
                "Form Damage": float(h.get("credit_form_damage") or 0.0),
                "Bonus": float(h.get("bonus") or 0.0),
                "Closing Cash": float(h.get("closing_balance") or 0.0)
            })
    except Exception:
        pass

    tot_reps_amt = sum(float(r.get("amount_paid") or 0.0) for r in clean_reps)
    tot_sav_amt = sum(float(s.get("deposit_amount") or 0.0) for s in clean_sav) + sum(float(g.get("deposit_amount") or 0.0) for g in clean_gsav)
    paid_cnt = sum(1 for r in clean_reps if float(r.get("amount_paid") or 0.0) > 0)
    not_paid_cnt = sum(1 for r in clean_reps if float(r.get("amount_paid") or 0.0) == 0)

    return CollectionsHistoryResponse(
        date=hist_date_str,
        total_repayments=tot_reps_amt,
        paid_repayments_count=paid_cnt,
        not_paid_repayments_count=not_paid_cnt,
        total_savings=tot_sav_amt,
        savings_deposits_count=len(clean_sav) + len(clean_gsav),
        grand_total_cash=tot_reps_amt + tot_sav_amt,
        groups=group_rows,
        repayments=repayment_rows,
        savings=savings_rows,
        reversed_records=reversed_rows,
        eod_summary=eod_data,
        eod_log=eod_log,
        available_officers=available_officers
    )


@router.get("/reversal-options", response_model=ReversalCandidatesResponse)
def get_reversal_options(
    category: str = Query("Loan Repayments", description="'Loan Repayments' or 'Savings Deposits'"),
    date_str: Optional[str] = Query(None, alias="date"),
    all_recent: bool = Query(False),
    search: Optional[str] = Query(None),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns transactions available to flag for reversal matching app.py L7074-7186.
    """
    target_date = date.today()
    if date_str:
        try: target_date = date.fromisoformat(date_str)
        except ValueError: pass

    corr_date_str = target_date.isoformat()
    officer_id = uow.loans._resolve_officer_id(current_user.username) or current_user.id
    search_term = (search or "").strip().lower()

    blocked_ids = set()
    try:
        res_reqs = uow.client.table("correction_requests").select("record_id").in_("status", ["Pending", "Approved"]).execute()
        for r in (res_reqs.data or []):
            if r.get("record_id"): blocked_ids.add(str(r["record_id"]))
    except Exception:
        pass

    items = []
    if category == "Loan Repayments":
        q = uow.client.table("repayments").select("id, client_id, amount_paid, expected_amount, date, note, clients(name, client_code)").eq("officer_id", officer_id)
        if not all_recent:
            q = q.gte("date", f"{corr_date_str} 00:00:00").lte("date", f"{corr_date_str} 23:59:59")
        else:
            fourteen_days_ago = (datetime.now().date() - timedelta(days=14)).isoformat()
            q = q.gte("date", f"{fourteen_days_ago} 00:00:00")

        records = q.order("date", desc=True).limit(500).execute().data or []
        for r in records:
            tx_id = str(r.get("id") or "")
            amt = float(r.get("amount_paid") or 0.0)
            note = str(r.get("note") or "")
            if tx_id in blocked_ids or amt <= 0 or "REVERSAL of" in note or "CORRECTION:" in note:
                continue

            c_dict = r.get("clients") or {} if isinstance(r.get("clients"), dict) else {}
            c_name = c_dict.get("name") or str(r.get("client_id") or "Unknown")
            c_code = c_dict.get("client_code") or "NO-CODE"
            tx_date = str(r.get("date", ""))[:10]

            if search_term and not (search_term in c_name.lower() or search_term in c_code.lower() or search_term in tx_id.lower()):
                continue

            short_n = _short_name_mobile(c_name)
            amt_str = f"₦{amt:,.2f}" if (amt % 1 != 0) else f"₦{amt:,.0f}"
            label = f"{amt_str} | {c_code} | {short_n} (#{tx_id[:6]})"

            items.append(ReversalCandidateItem(
                ref_id=tx_id,
                client_name=c_name,
                client_code=c_code,
                amount=amt,
                date=tx_date,
                category="Loan Repayment",
                note=note or "Daily Collection",
                label=label
            ))
    else:
        q = uow.client.table("individual_savings").select("id, client_id, deposit_amount, posting_date, remarks, clients(name, client_code)").eq("officer_id", officer_id).gt("deposit_amount", 0)
        if not all_recent:
            q = q.eq("posting_date", corr_date_str)
        else:
            fourteen_days_ago = (datetime.now().date() - timedelta(days=14)).isoformat()
            q = q.gte("posting_date", fourteen_days_ago)

        records = q.order("posting_date", desc=True).limit(500).execute().data or []
        for s in records:
            tx_id = str(s.get("id") or "")
            amt = float(s.get("deposit_amount") or 0.0)
            rem = str(s.get("remarks") or "")
            if tx_id in blocked_ids or amt <= 0 or "REVERSAL of" in rem or "CORRECTION:" in rem:
                continue

            c_dict = s.get("clients") or {} if isinstance(s.get("clients"), dict) else {}
            c_name = c_dict.get("name") or str(s.get("client_id") or "Unknown")
            c_code = c_dict.get("client_code") or "NO-CODE"
            tx_date = str(s.get("posting_date", ""))[:10]

            if search_term and not (search_term in c_name.lower() or search_term in c_code.lower() or search_term in tx_id.lower()):
                continue

            short_n = _short_name_mobile(c_name)
            amt_str = f"₦{amt:,.2f}" if (amt % 1 != 0) else f"₦{amt:,.0f}"
            label = f"{amt_str} | {c_code} | {short_n} (#{tx_id[:6]})"

            items.append(ReversalCandidateItem(
                ref_id=tx_id,
                client_name=c_name,
                client_code=c_code,
                amount=amt,
                date=tx_date,
                category="Savings Deposit",
                note=rem or "Member Deposit",
                label=label
            ))

    return ReversalCandidatesResponse(category=category, items=items)


@router.get("/reversal-requests", response_model=SubmittedReversalsResponse)
def get_submitted_reversals(
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns history of submitted reversal requests matching app.py L7229-7258.
    """
    try:
        res = uow.client.table("correction_requests").select("*").eq("requested_by", current_user.id).order("created_at", desc=True).limit(20).execute()
        reqs = res.data or []
        if not reqs and current_user.username:
            res2 = uow.client.table("correction_requests").select("*").eq("requested_by", current_user.username).order("created_at", desc=True).limit(20).execute()
            reqs = res2.data or []
    except Exception:
        reqs = []

    items = []
    for r in reqs:
        items.append(SubmittedReversalItem(
            request_id=str(r.get("request_id") or r.get("id") or ""),
            date=str(r.get("created_at", ""))[:16].replace("T", " "),
            record_type=str(r.get("record_type") or "Repayment"),
            record_ref=str(r.get("record_id") or "")[:8],
            reason=str(r.get("reason") or ""),
            status=str(r.get("status") or "Pending"),
            approved_by=r.get("approved_by")
        ))

    return SubmittedReversalsResponse(requests=items)


@router.post("/reversal-request", response_model=ReversalRequestResponse)
def request_repayment_reversal(
    payload: ReversalRequestInput,
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Submits a repayment reversal request for BM approval under Four-Eyes rule BR-ERR-001 (app.py L7204-7223).
    """
    req_id = CorrectionService.request_correction(
        uow=uow,
        record_id=payload.record_id,
        record_type=payload.record_type or "Repayment",
        reason=payload.reason,
        requested_by=current_user.id or current_user.username,
        branch_id=current_user.branch_id
    )

    return ReversalRequestResponse(
        success=True,
        request_id=req_id,
        status="Pending",
        message="Repayment reversal request submitted to Branch Manager for approval."
    )


