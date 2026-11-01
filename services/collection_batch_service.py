"""
Collection Batch Service.

Domain service responsible for batch field collection processing, pre-flight
caching, idempotency management, and projection lifecycle control.
Decoupled completely from legacy UI frameworks.
"""

import logging
import uuid
import re
from datetime import datetime, date
from typing import List, Dict, Any, Optional, Union
import pandas as pd

from database.repositories import unit_of_work
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.savings_service import SavingsService
from mappers.base_mappers import RepaymentMapper
from services.repayment_service import RepaymentService
from services.schedule_service import ScheduleService
from services.collection_performance_service import CollectionPerformanceService
from services.posting_engine import FinancialPostingEngine
from domain.entities.event_store import DomainEvent

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# UI to Database Column Mappings
# ---------------------------------------------------------------------------
DB_TO_UI_REP = {
    "date": "Date", "branch": "Branch", "client_id": "Client ID", "client_code": "Client Code",
    "client_name": "Client Name", "amount_paid": "Amount Paid", "officer": "Officer", 
    "note": "Note", "transaction_type": "Transaction Type",
    "savings_amount": "Savings Amount", "loan_repayment_amount": "Loan Repayment Amount",
    "processing_fee_paid": "Processing Fee Paid", "markup_paid": "Markup Paid",
    "pass_book_paid": "Pass Book Paid", "recovery_amount": "Recovery Amount",
    "withdrawal_amount": "Withdrawal Amount", "mgt_fee_paid": "Mgt Fee Paid",
    "others_amount": "Others Amount",
    "opening_balance": "Opening Balance", "rep_12_weeks": "Repayment 12 Weeks",
    "rep_24_weeks": "Repayment 24 Weeks", "rep_60_days": "Repayment 60 Days",
    "rep_120_days": "Repayment 120 Days", "rep_monthly": "Monthly",
    "contingency_paid": "Contingency", "bank_withdrawal": "Bank Withdrawal",
    "asset_sales": "Asset Sales", "app_fee": "App Fee",
    "passbook_bonus": "Pass Book Bonus", "daily_11_pct": "Daily 11%",
    "daily_20_pct": "Daily 20%", "weekly_11_pct": "Weekly 11%",
    "weekly_20_pct": "Weekly 20%", "monthly_markup": "Monthly 11%/20%",
    "cash_carry": "Cash Carry", "product_withdrawal": "Product Withdrawal",
    "weekly_active": "Weekly Active", "daily_active": "Daily Active",
    "monthly_active": "Monthly Active", "expenses": "Expenses",
    "bank_deposited": "Bank Deposited", "closing_balance": "Closing Balance",
    "laps_reserved": "Laps Reserved", "laps_transferred": "Laps Transferred",
    "initial_payment": "initial_payment", "group_savings_dep": "Group Savings Deposit", "group_savings_wd": "Group Savings Withdrawal", "misc_fees": "Misc Fees",
    "asset_credit_sales": "Asset Credit Sales", "cash_and_carry": "Cash and Carry", "credit_form": "Credit Form", "credit_form_damage": "Credit Form Damage", "bonus": "Bonus",
    "payment_status": "Payment Status", "expected_amount": "Expected Amount", "overdue_amount": "Overdue Amount",
    "group_id": "Group ID"
}

UI_TO_DB_REP = {v: k for k, v in DB_TO_UI_REP.items()}
UI_TO_DB_REP["Group ID"] = "group_id"
UI_TO_DB_REP["group_id"] = "group_id"
UI_TO_DB_REP["payment_status"] = "payment_status"
UI_TO_DB_REP["expected_amount"] = "expected_amount"
UI_TO_DB_REP["overdue_amount"] = "overdue_amount"
UI_TO_DB_REP["mark_not_paid"] = "mark_not_paid"


def is_valid_uuid(val: Any) -> bool:
    """Checks whether a value is a valid UUID string."""
    try:
        uuid.UUID(str(val))
        return True
    except (ValueError, TypeError, AttributeError):
        return False


def save_repayment(
    data: Dict[str, Any],
    override_uow: Optional[SupabaseUnitOfWork] = None,
    client_cache: Optional[Dict[str, str]] = None,
    loan_cache: Optional[Dict[Any, str]] = None,
    skip_repayment: bool = False,
    skip_savings: bool = False,
    known_exists: Optional[bool] = None,
    loan_data_cache: Optional[Dict[str, Dict[str, Any]]] = None,
    repayments_cache: Optional[Dict[str, List[Dict[str, Any]]]] = None,
    schedule_cache: Optional[Dict[str, List[Dict[str, Any]]]] = None,
    default_user: Optional[str] = None,
    default_branch: Optional[str] = None
) -> None:
    """
    Save repayment and route savings to respective buckets with idempotency skip support
    and pre-cached lookups.
    """
    try:
        class UOWContext:
            def __enter__(self):
                if override_uow:
                    return override_uow
                self.uow = unit_of_work.SupabaseUnitOfWork()
                return self.uow.__enter__()

            def __exit__(self, exc_type, exc_val, exc_tb):
                if not override_uow:
                    return self.uow.__exit__(exc_type, exc_val, exc_tb)

        with UOWContext() as uow:
            db_data = {UI_TO_DB_REP.get(k, k): v for k, v in data.items()}

            # Map officer and branch with safe fallbacks
            officer = (
                data.get('Officer') or
                data.get('officer') or
                db_data.get('credit_officer') or
                db_data.get('officer') or
                default_user or
                'SYSTEM'
            )
            branch = (
                data.get('Branch') or
                data.get('branch') or
                db_data.get('branch') or
                default_branch or
                'Head Office'
            )

            db_data['officer'] = officer
            db_data['credit_officer'] = officer
            db_data['branch'] = branch

            client_id = db_data.get('client_id', '')

            # Resolve client_code to database UUID if it's not a UUID and not a group/global code
            resolved_client_id = client_id
            clean_client_code = str(client_id).replace('-ASSET', '').strip()
            if client_id and not is_valid_uuid(client_id) and not str(client_id).startswith('GROUP-') and not str(client_id).startswith('GLOBAL-'):
                if client_cache and clean_client_code in client_cache:
                    resolved_client_id = client_cache[clean_client_code]
                elif client_cache and str(client_id).strip() in client_cache:
                    resolved_client_id = client_cache[str(client_id).strip()]
                else:
                    res_c = uow.client.table("clients").select("client_id").eq("client_code", clean_client_code).execute()
                    if res_c.data:
                        resolved_client_id = res_c.data[0]["client_id"]
                        if client_cache is not None:
                            client_cache[clean_client_code] = resolved_client_id
                            client_cache[str(client_id).strip()] = resolved_client_id

            db_data['client_id'] = resolved_client_id
            client_id = resolved_client_id
            client_name = db_data.get('client_name', client_id)

            raw_date = (
                data.get('Date') or
                data.get('date') or
                data.get('Payment Date') or
                db_data.get('date') or
                db_data.get('payment_date')
            )
            p_date_str = str(raw_date).split('T')[0] if raw_date else datetime.now().strftime("%Y-%m-%d")
            p_date = datetime.strptime(p_date_str, "%Y-%m-%d").date()
            db_data['date'] = p_date_str
            db_data['payment_date'] = p_date_str

            # Extract component amounts
            savings_dep = float(db_data.get('savings_amount', 0) or 0)
            savings_wd = float(db_data.get('withdrawal_amount', 0) or 0)
            group_dep = float(db_data.get('group_savings_dep', 0) or 0)
            group_wd = float(db_data.get('group_savings_wd', 0) or 0)
            laps_res = float(db_data.get('laps_reserved', 0) or 0)
            laps_trans = float(db_data.get('laps_transferred', 0) or 0)
            misc_fees = float(db_data.get('misc_fees', 0) or 0)
            loan_repay = float(db_data.get('loan_repayment_amount', 0) or db_data.get('amount_paid', 0) or 0)

            # 1. Route Group Savings
            if not skip_savings and str(client_id).startswith('GROUP-'):
                group_name = str(client_id).replace('GROUP-', '').strip()
                g_id_val = data.get('group_id') or data.get('Group ID') or db_data.get('group_id')

                def is_valid_group_uuid(val):
                    if not val or str(val) == "00000000-0000-0000-0000-000000000000":
                        return False
                    try:
                        u = uuid.UUID(str(val))
                        return u.int != 0
                    except (ValueError, TypeError, AttributeError):
                        return False

                if not is_valid_group_uuid(g_id_val):
                    try:
                        m = re.match(r"^(.+?)\s*\(\s*#(\d+)(?:\s*-\s*[^)]+)?\s*\)$", group_name)
                        if m:
                            base_gname = m.group(1).strip()
                            g_num = m.group(2).strip()
                            res_g = uow.client.table("groups").select("group_id").eq("group_number", g_num).ilike("name", base_gname).execute()
                            if res_g.data:
                                g_id_val = res_g.data[0]["group_id"]
                            if not g_id_val:
                                res_num = uow.client.table("groups").select("group_id").eq("group_number", g_num).execute()
                                if res_num.data:
                                    g_id_val = res_num.data[0]["group_id"]
                        if not is_valid_group_uuid(g_id_val):
                            res_name = uow.client.table("groups").select("group_id").eq("name", group_name).execute()
                            if res_name.data:
                                g_id_val = res_name.data[0]["group_id"]
                            else:
                                res_ci = uow.client.table("groups").select("group_id").ilike("name", group_name).execute()
                                if res_ci.data:
                                    g_id_val = res_ci.data[0]["group_id"]
                    except Exception as ex_resolve:
                        logger.warning(f"[GROUP RESOLVE WARNING] Failed resolving group_id for '{group_name}': {ex_resolve}")

                sav_id_val = data.get('savings_tx_id') or data.get('tx_id')
                SavingsService.post_group_savings(
                    uow,
                    group_name,
                    branch,
                    officer,
                    group_dep,
                    group_wd,
                    remarks=db_data.get('note'),
                    posting_date=p_date,
                    group_id=g_id_val,
                    group_savings_id=sav_id_val
                )
                return

            # 2. Route LAPS
            if not skip_savings and str(client_id).startswith('GLOBAL-LAPS'):
                SavingsService.post_laps_savings(
                    uow,
                    client_id,
                    client_name,
                    branch,
                    officer,
                    laps_res,
                    laps_trans,
                    posting_date=p_date
                )
                return

            # 3. Route Individual Savings
            if not skip_savings and (savings_dep > 0 or savings_wd > 0):
                sav_id_val = data.get('savings_tx_id') or data.get('tx_id')
                SavingsService.post_individual_savings(
                    uow,
                    client_id,
                    client_name,
                    branch,
                    officer,
                    savings_dep,
                    savings_wd,
                    remarks=db_data.get('note'),
                    posting_date=p_date,
                    savings_id=sav_id_val
                )

            # 4. Route Loan Repayment (including explicit NOT_PAID / 0 collection records)
            raw_p_status = str(data.get('Payment Status') or data.get('payment_status') or db_data.get('payment_status') or "PAID").upper()
            is_marked_not_paid = bool(data.get('mark_not_paid') or (raw_p_status == "NOT_PAID" and str(data.get('Transaction Type') or db_data.get('transaction_type')) != "Individual Savings Deposit"))

            if not skip_repayment and (loan_repay > 0 or is_marked_not_paid):
                active_loan_id = data.get('loan_id') or db_data.get('loan_id')
                is_asset_target = str(data.get('Client ID') or '').endswith('-ASSET') or 'asset' in str(data.get('Loan Product') or '').lower()

                if not active_loan_id:
                    if loan_cache:
                        if is_asset_target and (client_id, "Asset") in loan_cache:
                            active_loan_id = loan_cache[(client_id, "Asset")]
                        elif not is_asset_target and (client_id, "Finance") in loan_cache:
                            active_loan_id = loan_cache[(client_id, "Finance")]
                        else:
                            active_loan_id = loan_cache.get(client_id)
                    if not active_loan_id:
                        res_l = uow.client.table("loans").select("loan_id, product_category, active_credit, extra_fields").eq("client_id", client_id).eq("status", "Active").execute()
                        if res_l.data:
                            matching = [
                                l for l in res_l.data if (
                                    (is_asset_target and (l.get('product_category') == 'Asset' or 'asset' in str(l.get('product_category') or '').lower() or (l.get('extra_fields') or {}).get('is_asset'))) or
                                    (not is_asset_target and not (l.get('product_category') == 'Asset' or 'asset' in str(l.get('product_category') or '').lower() or (l.get('extra_fields') or {}).get('is_asset')))
                                )
                            ]
                            active_loan_id = matching[0]["loan_id"] if matching else res_l.data[0]["loan_id"]
                            if loan_cache is not None:
                                loan_cache[(client_id, "Asset" if is_asset_target else "Finance")] = active_loan_id
                                if not is_asset_target:
                                    loan_cache[client_id] = active_loan_id

                exp_amt = float(data.get('Expected Amount') or data.get('expected_amount') or db_data.get('expected_amount') or 0.0)
                if exp_amt <= 0 and active_loan_id:
                    l_cached = loan_data_cache.get(active_loan_id) if loan_data_cache else None
                    if l_cached:
                        exp_amt = float(l_cached.get('loan_repay') or 0.0)
                if exp_amt <= 0:
                    exp_amt = (loan_repay if loan_repay > 0 else 0.0)
                overdue_val = float(data.get('Overdue Amount') or data.get('overdue_amount') or db_data.get('overdue_amount') or (exp_amt if is_marked_not_paid else 0.0))
                final_p_status = "NOT_PAID" if is_marked_not_paid else raw_p_status

                db_data['loan_repayment_amount'] = loan_repay
                db_data['amount_paid'] = loan_repay
                db_data['payment_status'] = final_p_status
                db_data['expected_amount'] = exp_amt
                db_data['overdue_amount'] = overdue_val
                if is_marked_not_paid and not db_data.get('note'):
                    db_data['note'] = "Marked as NOT PAID today"
                if active_loan_id:
                    db_data['loan_id'] = active_loan_id

                rep = RepaymentMapper.to_domain(db_data)
                if data.get('tx_id'):
                    rep.id = data.get('tx_id')
                rep.payment_date = p_date
                rep.credit_officer = officer
                rep.branch = branch
                rep.amount_paid = loan_repay
                rep.loan_repayment_amount = loan_repay
                rep.payment_status = final_p_status
                rep.expected_amount = exp_amt
                rep.overdue_amount = overdue_val
                if active_loan_id:
                    rep.loan_id = active_loan_id

                try:
                    l_data = loan_data_cache.get(active_loan_id) if loan_data_cache else None
                    r_data = repayments_cache.get(active_loan_id) if repayments_cache else None
                    RepaymentService.post_repayment(
                        uow,
                        rep,
                        known_exists=known_exists,
                        preloaded_loan=l_data,
                        preloaded_repayments=r_data
                    )
                except Exception as re:
                    logger.error(f"[ERROR] Error inserting repayment for {client_id}: {re}")
                    raise re

                if active_loan_id and loan_repay > 0:
                    sch_rows = schedule_cache.get(active_loan_id) if schedule_cache else None
                    try:
                        ScheduleService.record_repayment(uow, active_loan_id, loan_repay, p_date, cached_schedule_rows=sch_rows)
                    except TypeError:
                        ScheduleService.record_repayment(uow, active_loan_id, loan_repay, p_date)

                try:
                    off_id = FinancialPostingEngine._resolve_officer_id(uow, officer)
                    CollectionPerformanceService.record_meeting_collection(
                        uow=uow,
                        client_id=client_id,
                        loan_id=active_loan_id or client_id,
                        officer_id=off_id or str(uuid.uuid4()),
                        meeting_date=p_date,
                        expected_amount=exp_amt,
                        amount_paid=loan_repay,
                        remarks=db_data.get('note') or ("Marked as NOT PAID today" if is_marked_not_paid else "Meeting collection repayment")
                    )
                except Exception as ex_cp_rec:
                    logger.info(f"[COLLECTION PERFORMANCE RECORD NOTE]: {ex_cp_rec}")

            if skip_repayment:
                return

            # 5. Route Misc Savings
            if misc_fees > 0:
                SavingsService.post_misc_savings(
                    uow,
                    client_id,
                    client_name,
                    branch,
                    officer,
                    misc_fees,
                    remarks=db_data.get('note'),
                    posting_date=p_date
                )

            # 6. Route EOD / Global Inputs & Cash Flows
            officer_uuid = FinancialPostingEngine._resolve_officer_id(uow, officer)
            branch_uuid = FinancialPostingEngine._resolve_branch_id(uow, branch)
            valid_aggregate_id = str(client_id) if is_valid_uuid(client_id) else (officer_uuid or branch_uuid or str(uuid.uuid4()))

            # Bank Deposited (Field Cash to Bank)
            bdep_amt = float(db_data.get('bank_deposited', 0) or 0)
            if bdep_amt > 0:
                ev_bdep = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Bank",
                    event_type="BankDeposited",
                    payload={
                        "branch": branch,
                        "branch_id": branch_uuid,
                        "officer": officer,
                        "officer_id": officer_uuid,
                        "amount": bdep_amt,
                        "date": p_date_str,
                        "narration": f"End of Day cash deposit to bank by {officer}"
                    }
                )
                uow.event_store.append(ev_bdep)
                FinancialPostingEngine.post_event(uow, ev_bdep)

            # Bank Withdrawal (Bank to Cash)
            bwd_amt = float(db_data.get('bank_withdrawal', 0) or 0)
            if bwd_amt > 0:
                ev_bwd = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Bank",
                    event_type="BankWithdrawn",
                    payload={
                        "branch": branch,
                        "branch_id": branch_uuid,
                        "officer": officer,
                        "officer_id": officer_uuid,
                        "amount": bwd_amt,
                        "date": p_date_str,
                        "narration": f"Bank withdrawal by {officer}"
                    }
                )
                uow.event_store.append(ev_bwd)
                FinancialPostingEngine.post_event(uow, ev_bwd)

            # Office Expenses
            exp_amt = float(db_data.get('expenses', 0) or 0)
            if exp_amt > 0:
                ev_exp = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Expense",
                    event_type="ExpenseRecorded",
                    payload={
                        "branch": branch,
                        "branch_id": branch_uuid,
                        "officer": officer,
                        "officer_id": officer_uuid,
                        "amount": exp_amt,
                        "date": p_date_str,
                        "narration": f"Office expenses paid by {officer}"
                    }
                )
                uow.event_store.append(ev_exp)
                FinancialPostingEngine.post_event(uow, ev_exp)

            # Helper for Fee recording with complete client attribution & persistence in public.fees
            ev_ref = str(data.get('batch_id') or data.get('reference') or str(uuid.uuid4())[:8])
            c_uuid_str = str(client_id) if is_valid_uuid(client_id) else None

            def _record_fee_with_client_attribution(amount_val: float, fee_category: str, narration_str: str) -> None:
                if amount_val <= 0:
                    return
                event_fee = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Fee",
                    event_type="FeeCharged",
                    payload={
                        "branch": branch,
                        "branch_id": branch_uuid,
                        "officer": officer,
                        "officer_id": officer_uuid,
                        "client_id": c_uuid_str,
                        "client_name": str(client_name),
                        "client": str(client_name),
                        "amount": amount_val,
                        "date": p_date_str,
                        "classification": fee_category,
                        "reference": ev_ref,
                        "narration": narration_str
                    }
                )
                uow.event_store.append(event_fee)
                FinancialPostingEngine.post_event(uow, event_fee)
                try:
                    uow.client.table("fees").insert({
                        "posting_date": p_date_str,
                        "client_id": c_uuid_str,
                        "branch_id": branch_uuid,
                        "officer_id": officer_uuid,
                        "fee_type": fee_category,
                        "amount": amount_val,
                        "reference": ev_ref,
                        "remarks": narration_str
                    }).execute()
                except Exception as ex_ins:
                    logger.error(f"[FEES INSERT ERROR - {fee_category}]: {ex_ins}")

            # Passbook Fee / Bonus
            pb_amt = float(db_data.get('passbook_bonus') or db_data.get('pass_book_paid') or db_data.get('passbook') or 0.0)
            if pb_amt > 0:
                _record_fee_with_client_attribution(pb_amt, "PASSBOOK", f"Passbook fee from {client_name}")

            # Bonus
            bon_amt = float(db_data.get('bonus', 0) or 0.0)
            if bon_amt > 0:
                _record_fee_with_client_attribution(bon_amt, "BONUS", f"Bonus fee from {client_name}")

            # Processing Fee / App Fee
            app_fee_amt = float(db_data.get('processing_fee_paid') or db_data.get('app_fee') or 0.0)
            if app_fee_amt > 0:
                _record_fee_with_client_attribution(app_fee_amt, "PROCESSING_FEE", f"Processing Fee from {client_name}")

            # Cash and Carry
            cc_amount = float(db_data.get('cash_and_carry', 0) or 0.0)
            if cc_amount > 0:
                ev_cc = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Asset",
                    event_type="AssetSoldCash",
                    payload={
                        "branch": branch,
                        "branch_id": branch_uuid,
                        "officer": officer,
                        "officer_id": officer_uuid,
                        "amount": cc_amount,
                        "date": p_date_str,
                        "narration": f"Cash & Carry asset sale to {client_name}"
                    }
                )
                uow.event_store.append(ev_cc)
                FinancialPostingEngine.post_event(uow, ev_cc)

            # Credit Form Damage
            cfd_amount = float(db_data.get('credit_form_damage', 0) or 0.0)
            if cfd_amount > 0:
                _record_fee_with_client_attribution(cfd_amount, "CREDIT_FORM_DAMAGE", f"Credit Form Damage fee from {client_name}")

            # Credit Form
            cf_amount = float(db_data.get('credit_form', 0) or 0.0)
            if cf_amount > 0:
                _record_fee_with_client_attribution(cf_amount, "CREDIT_FORM", f"Credit Form fee from {client_name}")

            # Asset Credit Sales
            asset_cr_amount = float(db_data.get('asset_credit_sales', 0) or 0.0)
            if asset_cr_amount > 0:
                ev_as = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=valid_aggregate_id,
                    aggregate_type="Asset",
                    event_type="AssetSoldCash",
                    payload={
                        "branch": branch,
                        "branch_id": branch_uuid,
                        "officer": officer,
                        "officer_id": officer_uuid,
                        "amount": asset_cr_amount,
                        "date": p_date_str,
                        "narration": f"Asset Credit Sales for {client_name}"
                    }
                )
                uow.event_store.append(ev_as)
                FinancialPostingEngine.post_event(uow, ev_as)

            # Route Markup and Contingency
            d11_val = float(db_data.get('daily_11_pct') or 0.0)
            d20_val = float(db_data.get('daily_20_pct') or 0.0)
            w11_val = float(db_data.get('weekly_11_pct') or 0.0)
            w20_val = float(db_data.get('weekly_20_pct') or 0.0)
            mm_val = float(db_data.get('monthly_markup') or 0.0)
            cont_val = float(db_data.get('contingency_paid') or 0.0)

            _record_fee_with_client_attribution(d11_val, "MARKUP_11", f"daily 11% markup fee from {client_name}")
            _record_fee_with_client_attribution(d20_val, "MARKUP_20", f"daily 20% markup fee from {client_name}")
            _record_fee_with_client_attribution(w11_val, "MARKUP_11", f"weekly 11% markup fee from {client_name}")
            _record_fee_with_client_attribution(w20_val, "MARKUP_20", f"weekly 20% markup fee from {client_name}")
            _record_fee_with_client_attribution(mm_val, "MARKUP", f"monthly markup risk premium fee from {client_name}")
            _record_fee_with_client_attribution(cont_val, "CONTINGENCY", f"contingency fee from {client_name}")

    except Exception as e:
        logger.error(f"[ERROR] Error in save_repayment logic: {e}")
        raise e



def _get_save_repayment_fn():
    import sys
    app_mod = sys.modules.get('app')
    if app_mod and hasattr(app_mod, 'save_repayment'):
        if app_mod.save_repayment is not save_repayment:
            return app_mod.save_repayment
    return save_repayment

def save_repayments(
    data_list: Optional[Union[List[Dict[str, Any]], pd.DataFrame]],
    batch_id: Optional[str] = None
) -> Optional[Dict[str, Any]]:
    """
    Save multiple repayments to database with batch-scoped idempotency,
    pre-flight caching, and deferred projections.
    """
    if data_list is None:
        return None
    if isinstance(data_list, pd.DataFrame):
        data_list = data_list.to_dict('records')
    if not data_list:
        return None

    # Extract or generate batch_id
    if not batch_id:
        batch_id = data_list[0].get('batch_id') if (data_list and data_list[0].get('batch_id')) else f"COL-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:6].upper()}"

    # Ensure every item has deterministic UUIDs tied to this batch
    for idx, d in enumerate(data_list):
        if not d.get('batch_id'):
            d['batch_id'] = batch_id
        cid = str(d.get('Client ID') or d.get('client_id') or idx)
        if not d.get('tx_id'):
            d['tx_id'] = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{batch_id}_{cid}_{idx}_rep"))
        if not d.get('savings_tx_id'):
            d['savings_tx_id'] = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{batch_id}_{cid}_{idx}_sav"))

    report = {
        "batch_id": batch_id,
        "total_submitted": len(data_list),
        "new_processed": 0,
        "already_saved": 0,
        "total_cash": 0.0,
        "total_repayment": 0.0,
        "total_savings": 0.0,
        "items": []
    }

    # 1. Enable deferred projections globally for this batch
    original_defer = getattr(FinancialPostingEngine, 'defer_projections', False)
    FinancialPostingEngine.defer_projections = True

    branch_id_to_rebuild = None
    date_to_rebuild = None
    any_new_records = False

    try:
        with unit_of_work.SupabaseUnitOfWork() as uow:
            # 1. Pre-flight Batch Lookups: Client IDs & Active Loans in bulk
            client_cache = {}
            clean_codes = []
            for d in data_list:
                cid = d.get('Client ID') or d.get('client_id')
                if cid and not is_valid_uuid(cid) and not str(cid).startswith('GROUP-') and not str(cid).startswith('GLOBAL-'):
                    clean_code = str(cid).replace('-ASSET', '').strip()
                    clean_codes.append(clean_code)
            if clean_codes:
                try:
                    res_c = uow.client.table("clients").select("client_id, client_code").in_("client_code", list(set(clean_codes))).execute()
                    for row in (res_c.data or []):
                        client_cache[row["client_code"]] = row["client_id"]
                        client_cache[f"{row['client_code']}-ASSET"] = row["client_id"]
                except Exception as ex_c:
                    logger.debug(f"Pre-flight client lookup notice: {ex_c}")

            loan_cache = {}
            loan_data_cache = {}
            all_resolved_cids = []
            for d in data_list:
                cid = d.get('Client ID') or d.get('client_id')
                resolved = client_cache.get(str(cid).strip(), client_cache.get(str(cid).replace('-ASSET', '').strip(), cid))
                if resolved and is_valid_uuid(resolved):
                    all_resolved_cids.append(str(resolved))
            if all_resolved_cids:
                try:
                    res_l = uow.client.table("loans").select("loan_id, client_id, product_category, active_credit, total_due, loan_amount, loan_repay, branch_id, officer_id, status, extra_fields").in_("client_id", list(set(all_resolved_cids))).eq("status", "Active").execute()
                    for row in (res_l.data or []):
                        is_asset_l = bool(row.get('product_category') == 'Asset' or 'asset' in str(row.get('product_category') or '').lower() or (row.get('extra_fields') or {}).get('is_asset'))
                        cat_key = "Asset" if is_asset_l else "Finance"
                        loan_cache[(row["client_id"], cat_key)] = row["loan_id"]
                        loan_cache[f"{row['client_id']}-ASSET" if is_asset_l else row["client_id"]] = row["loan_id"]
                        if not is_asset_l:
                            loan_cache[row["client_id"]] = row["loan_id"]
                        loan_data_cache[row["loan_id"]] = row
                except Exception as ex_l:
                    logger.debug(f"Pre-flight loan lookup notice: {ex_l}")

            # Pre-fetch loan schedules and repayments in batch for all active loans
            explicit_lids = [d.get('loan_id') for d in data_list if d.get('loan_id')]
            all_active_loan_ids = list(set([lid for lid in loan_cache.values() if isinstance(lid, str)] + explicit_lids))
            schedule_cache = {}
            repayments_cache = {}
            if all_active_loan_ids:
                try:
                    res_sch = uow.client.table("loan_schedule").select("*").in_("loan_id", all_active_loan_ids).order("installment_number").execute()
                    for s_row in (res_sch.data or []):
                        lid = s_row["loan_id"]
                        schedule_cache.setdefault(lid, []).append(s_row)
                except Exception as ex_sch:
                    logger.debug(f"Pre-flight schedule lookup notice: {ex_sch}")
                try:
                    res_pr = uow.client.table("repayments").select("loan_id, id, amount_paid").in_("loan_id", all_active_loan_ids).execute()
                    for r_row in (res_pr.data or []):
                        lid = r_row["loan_id"]
                        repayments_cache.setdefault(lid, []).append(r_row)
                except Exception as ex_pr:
                    logger.debug(f"Pre-flight repayments lookup notice: {ex_pr}")

            # 2. Idempotency Check: Pre-fetch existing records
            all_tx_ids = [d['tx_id'] for d in data_list if d.get('tx_id') and is_valid_uuid(d['tx_id'])]
            all_sav_ids = [d['savings_tx_id'] for d in data_list if d.get('savings_tx_id') and is_valid_uuid(d['savings_tx_id'])]

            existing_rep_ids = set()
            if all_tx_ids:
                try:
                    res_ex_rep = uow.client.table("repayments").select("id").in_("id", all_tx_ids).execute()
                    existing_rep_ids = {r["id"] for r in (res_ex_rep.data or [])}
                except Exception as e:
                    logger.warning(f"[IDEMPOTENCY] Error checking existing repayments: {e}")

            existing_sav_ids = set()
            if all_sav_ids:
                try:
                    res_ex_sav = uow.client.table("individual_savings").select("id").in_("id", all_sav_ids).execute()
                    existing_sav_ids.update({s["id"] for s in (res_ex_sav.data or [])})
                except Exception as e:
                    logger.warning(f"[IDEMPOTENCY] Error checking existing individual savings: {e}")
                try:
                    res_ex_gsav = uow.client.table("group_savings").select("id").in_("id", all_sav_ids).execute()
                    existing_sav_ids.update({s["id"] for s in (res_ex_gsav.data or [])})
                except Exception as e:
                    logger.warning(f"[IDEMPOTENCY] Error checking existing group savings: {e}")

            # 3. Iterate through batch using in-memory caches and idempotency skips
            for data in data_list:
                rep_tx_id = data.get('tx_id')
                sav_tx_id = data.get('savings_tx_id')

                l_rep = float(data.get('Loan Repayment Amount') or data.get('amount_paid') or 0.0)
                s_dep = float(data.get('Savings Amount') or data.get('savings_amount') or 0.0)
                p_status_val = str(data.get('Payment Status') or data.get('payment_status') or "PAID").upper()
                is_not_paid_mark = bool(data.get('mark_not_paid') or (p_status_val == "NOT_PAID" and str(data.get('Transaction Type')) != "Individual Savings Deposit"))

                is_rep_done = bool(rep_tx_id and rep_tx_id in existing_rep_ids)
                is_sav_done = bool(sav_tx_id and sav_tx_id in existing_sav_ids)

                c_name = data.get('Client Name') or data.get('client_name') or data.get('Client ID') or 'Unknown'

                rep_needed = (l_rep > 0 or is_not_paid_mark)
                sav_needed = (s_dep > 0)

                already_saved_fully = (
                    (not rep_needed or is_rep_done) and
                    (not sav_needed or is_sav_done) and
                    (is_rep_done or is_sav_done)
                )

                if already_saved_fully:
                    report["already_saved"] += 1
                    report["items"].append({
                        "client": c_name,
                        "repayment": l_rep,
                        "savings": s_dep,
                        "status": "Recovered (Already Saved)"
                    })
                else:
                    _save_fn = _get_save_repayment_fn()
                    _save_fn(
                        data,
                        override_uow=uow,
                        client_cache=client_cache,
                        loan_cache=loan_cache,
                        skip_repayment=is_rep_done,
                        skip_savings=is_sav_done,
                        known_exists=is_rep_done,
                        loan_data_cache=loan_data_cache,
                        repayments_cache=repayments_cache,
                        schedule_cache=schedule_cache
                    )
                    any_new_records = True
                    report["new_processed"] += 1
                    if repayments_cache is not None and not is_rep_done and l_rep > 0:
                        cid_raw = data.get('Client ID') or data.get('client_id')
                        c_uuid = client_cache.get(str(cid_raw).strip(), cid_raw) if client_cache else cid_raw
                        a_lid = loan_cache.get(c_uuid) if loan_cache else None
                        if a_lid:
                            repayments_cache.setdefault(a_lid, []).append({
                                'id': data.get('tx_id'),
                                'amount_paid': l_rep,
                                'loan_id': a_lid
                            })
                    status_lbl = "Recorded (NOT PAID)" if (is_not_paid_mark and l_rep == 0) else "Processed"
                    if (is_rep_done or is_sav_done) and not (is_not_paid_mark and l_rep == 0):
                        status_lbl = "Completed (Partial Recovery)"
                    report["items"].append({
                        "client": c_name,
                        "repayment": l_rep,
                        "savings": s_dep,
                        "status": status_lbl
                    })

                report["total_repayment"] += l_rep
                report["total_savings"] += s_dep
                report["total_cash"] += (l_rep + s_dep)

                # capture branch and date for final rebuild
                if not branch_id_to_rebuild and ('Branch' in data or 'branch' in data):
                    branch_name = data.get('Branch') or data.get('branch')
                    try:
                        branch_id_to_rebuild = FinancialPostingEngine._resolve_branch_id(uow, branch_name)
                    except Exception:
                        pass

                if not date_to_rebuild:
                    date_to_rebuild = data.get('Date') or data.get('date')

            # 4. Trigger ONE projection rebuild only if any new records were processed
            if any_new_records and branch_id_to_rebuild and date_to_rebuild:
                try:
                    p_date = date.fromisoformat(str(date_to_rebuild).split("T")[0])
                    uow.cashbook.rebuild_projection(branch_id_to_rebuild, p_date)
                    logger.info("[COLLECTIONS] Batch Cashbook projection rebuilt successfully.")
                except Exception as e:
                    logger.error(f"[COLLECTIONS] Error in batch projection rebuild: {e}")

    finally:
        FinancialPostingEngine.defer_projections = original_defer

    return report
