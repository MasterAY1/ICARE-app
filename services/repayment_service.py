import uuid
from datetime import datetime, date
from typing import Optional, Any
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.repayment import Repayment
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine

class RepaymentService:
    @staticmethod
    def post_repayment(uow: SupabaseUnitOfWork, repayment: Repayment) -> Repayment:
        # Check Business Date Freeze & Working Day (BR-DATE-002)
        from services.business_date_service import BusinessDateService
        rep_date = getattr(repayment, 'payment_date', None) or getattr(repayment, 'date', None)
        if rep_date:
            is_open, reason = BusinessDateService.is_operational_open(uow, repayment.branch, rep_date)
            if not is_open:
                raise ValueError(f"Operational Restriction: Cannot post repayment. {reason}.")

        operations = []

        # 1. Persist operational data
        exists = False
        if repayment.id:
            try:
                check_res = uow.client.table("repayments").select("id").eq("id", repayment.id).execute()
                if check_res.data:
                    exists = True
            except Exception:
                pass

        if not repayment.id:
            repayment.id = str(uuid.uuid4())
            op_type = "insert"
        elif exists:
            op_type = "update"
        else:
            op_type = "insert"
            
        rep_record = uow.repayments._prepare_db_data(repayment)
        if "id" in rep_record and not rep_record["id"]:
            del rep_record["id"]
        if op_type == "insert" and "id" not in rep_record:
            rep_record["id"] = repayment.id
            
        operations.append({
            "type": op_type,
            "table": "repayments",
            "record": rep_record
        })
        
        # 2. Audit log
        from database.repositories.audit_repository import resolve_officer_id, is_valid_uuid
        user_id = resolve_officer_id(uow.client, repayment.credit_officer)
        rec_uuid = repayment.id if repayment.id and is_valid_uuid(repayment.id) else None
        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": user_id,
                "action": "Loan Repayment Received",
                "description": f"Role: Credit Officer. Old: None. New: {{'amount': {repayment.amount_paid}}}",
                "table_name": "repayments",
                "record_id": rec_uuid
            }
        })

        def add_event(evt: DomainEvent):
            operations.append({
                "type": "insert",
                "table": "event_store",
                "record": {
                    "event_id": evt.event_id,
                    "aggregate_id": evt.aggregate_id,
                    "aggregate_type": evt.aggregate_type,
                    "event_type": evt.event_type,
                    "version": evt.version,
                    "payload": evt.payload,
                    "metadata": getattr(evt, "metadata", {}) or {},
                    "status": "Completed"
                }
            })
            tx_id, post_op = FinancialPostingEngine.post_event(uow, evt, defer_commit=True)
            operations.append(post_op)

        # 2.5 Resolve loan_id if needed
        resolved_loan_id = repayment.loan_id
        if not resolved_loan_id or resolved_loan_id == repayment.client_id:
            resolved_loan_id = uow.repayments._resolve_loan_id(repayment.client_id)
        if resolved_loan_id:
            repayment.loan_id = resolved_loan_id

        # 3. Create Event & Post (Only for actual loan repayment component)
        if repayment.loan_repayment_amount > 0:
            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=repayment.id,
                aggregate_type="Repayment",
                event_type="RepaymentReceived",
                payload={
                    "branch": repayment.branch,
                    "officer": repayment.credit_officer,
                    "amount": repayment.loan_repayment_amount,
                    "reference": repayment.id,
                    "loan_id": repayment.loan_id,
                    "date": repayment.payment_date.isoformat() if repayment.payment_date else None,
                    "narration": repayment.note or f"Loan repayment of {repayment.loan_repayment_amount} received."
                }
            )
            add_event(event)

        # 4. Process extra fees and input from EOD collection
        extra = repayment.extra_fields or {}
        # Mapping of dict key -> (Event Type, Narration)
        fee_mapping = {
            "App Fee": ("FeeCharged", "Processing / Application Fee"),
            "app_fee": ("FeeCharged", "Processing / Application Fee"),
            "processing_fee_paid": ("FeeCharged", "Processing / Application Fee"),
            "Pass Book Bonus": ("FeeCharged", "Passbook"),
            "passbook_bonus": ("FeeCharged", "Passbook"),
            "pass_book_paid": ("FeeCharged", "Passbook"),
            "Misc Fees": ("FeeCharged", "Misc Fee"),
            "misc_fees": ("FeeCharged", "Misc Fee"),
            "Asset Credit Sales": ("AssetSoldCash", "Asset Credit Sales"),
            "asset_credit_sales": ("AssetSoldCash", "Asset Credit Sales"),
            "Cash and Carry": ("AssetSoldCash", "Cash and Carry"),
            "cash_and_carry": ("AssetSoldCash", "Cash and Carry"),
            "Contingency": ("FeeCharged", "Contingency"),
            "contingency_paid": ("FeeCharged", "Contingency"),
            "Daily 11%": ("FeeCharged", "11% markup"),
            "daily_11_pct": ("FeeCharged", "11% markup"),
            "Daily 20%": ("FeeCharged", "20% markup"),
            "daily_20_pct": ("FeeCharged", "20% markup"),
            "Weekly 11%": ("FeeCharged", "11% weekly"),
            "weekly_11_pct": ("FeeCharged", "11% weekly"),
            "Weekly 20%": ("FeeCharged", "20% weekly"),
            "weekly_20_pct": ("FeeCharged", "20% weekly"),
            "Bank Deposited": ("BankDeposited", "Bank Deposited"),
            "bank_deposited": ("BankDeposited", "Bank Deposited"),
            "Bank Withdrawal": ("BankWithdrawn", "Bank Withdrawn"),
            "bank_withdrawal": ("BankWithdrawn", "Bank Withdrawn"),
            "Product Withdrawal": ("ProductWithdrawn", "Product Withdrawal"),
            "product_withdrawal": ("ProductWithdrawn", "Product Withdrawal"),
            "Credit Form": ("FeeCharged", "Credit Form"),
            "credit_form": ("FeeCharged", "Credit Form"),
            "Credit Form Damage": ("FeeCharged", "Credit Form Damage"),
            "credit_form_damage": ("FeeCharged", "Credit Form Damage"),
            "Bonus": ("FeeCharged", "Bonus"),
            "bonus": ("FeeCharged", "Bonus"),
            "Expenses": ("ExpenseRecorded", "Office Expenses"),
            "expenses": ("ExpenseRecorded", "Office Expenses")
        }

        handled_keys = set()
        for k, (e_type, narr) in fee_mapping.items():
            if k.lower() in handled_keys:
                continue
            amt = extra.get(k)
            if (amt is None or amt == 0) and any(x.lower() == k.lower() for x in extra.keys()):
                matched_k = next(x for x in extra.keys() if x.lower() == k.lower())
                amt = extra.get(matched_k)
            try:
                amt = float(amt) if amt else 0.0
            except (ValueError, TypeError):
                amt = 0.0
            if amt > 0:
                handled_keys.add(k.lower())
                ev = DomainEvent(
                    event_id=str(uuid.uuid4()),
                    aggregate_id=repayment.id,
                    aggregate_type="Repayment",
                    event_type=e_type,
                    payload={
                        "branch": repayment.branch,
                        "officer": repayment.credit_officer,
                        "amount": amt,
                        "reference": repayment.id,
                        "loan_id": repayment.loan_id,
                        "date": repayment.payment_date.isoformat() if repayment.payment_date else None,
                        "narration": narr
                    }
                )
                add_event(ev)

        # Execute all accumulated operations atomically
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # Check for loan full payment completion and transition client lifecycle status (BR-CLI-003.3 & BR-CLI-005)
        try:
            if repayment.client_id and repayment.loan_id:
                from services.client_status_service import ClientStatusService
                ClientStatusService.on_loan_repayment_check(uow, repayment.client_id, repayment.loan_id)
        except Exception as ex:
            print(f"[REPAYMENT TRACE] Client status lifecycle check failed: {ex}")

        # Check and record Full Payoff and Excess Payment in dedicated table (BR-DASH-005, BR-DASH-007)
        try:
            if repayment.loan_id and repayment.loan_repayment_amount > 0:
                cls._record_payoff_and_excess_if_applicable(uow, repayment)
        except Exception as ex_pe:
            print(f"[REPAYMENT TRACE] Payoff/excess recording failed: {ex_pe}")

        # Rebuild projection (only if not deferred during batch execution)
        if not getattr(FinancialPostingEngine, 'defer_projections', False):
            try:
                b_id = uow.repayments._resolve_branch_id(repayment.branch)
                from datetime import date
                p_rebuild_date = repayment.payment_date if repayment.payment_date else date.today()
                uow.cashbook.rebuild_projection(b_id, p_rebuild_date)
            except Exception as ex:
                print(f"[REPAYMENT TRACE] Cashbook rebuild failed: {ex}")
        else:
            print(f"[REPAYMENT TRACE] Cashbook projection rebuild deferred for batch execution.")

        return repayment

    @staticmethod
    def reverse_repayment(uow: SupabaseUnitOfWork, original_repayment_id: str, reason: str, reversed_by: str, reversal_date: Optional[Any] = None):
        """
        Executes a compensating negative repayment to reverse an error (BR-ERR-002).
        """
        # Fetch the original repayment
        res = uow.client.table("repayments").select("*").eq("id", original_repayment_id).execute()
        if not res.data:
            raise ValueError(f"Repayment {original_repayment_id} not found.")
        orig = res.data[0]

        operations = []

        # 1. Operational data: Compensating negative record
        new_id = str(uuid.uuid4())
        comp_record = orig.copy()
        comp_record["id"] = new_id
        
        orig_amount = float(comp_record.get("amount_paid") or 0.0)
        comp_record["amount_paid"] = -abs(orig_amount)
        
        if comp_record.get("savings_amount"):
            comp_record["savings_amount"] = -abs(float(comp_record["savings_amount"]))
        if comp_record.get("withdrawal_amount"):
            comp_record["withdrawal_amount"] = -abs(float(comp_record["withdrawal_amount"]))
            
        comp_record["note"] = f"REVERSAL of {original_repayment_id}. Reason: {reason}"
        comp_record["created_at"] = datetime.now().isoformat()

        rev_dt = reversal_date if reversal_date else datetime.now()
        rev_dt_str = rev_dt.isoformat() if hasattr(rev_dt, 'isoformat') else str(rev_dt)
        if "payment_date" in comp_record:
            comp_record["payment_date"] = rev_dt_str[:10]
        if "date" in comp_record:
            comp_record["date"] = rev_dt_str
        
        operations.append({
            "type": "insert",
            "table": "repayments",
            "record": comp_record
        })

        # 2. Reversal Domain Event
        # Ensure we pass POSITIVE amount to posting engine because the Rule swaps Debits/Credits
        event_payload = {
            "branch": orig.get("branch_id"),
            "officer": orig.get("officer_id"),
            "amount": abs(orig_amount),
            "reference": new_id,
            "loan_id": orig.get("loan_id"),
            "narration": f"Reversal of repayment {original_repayment_id}",
            "date": rev_dt_str
        }
        
        ev = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=new_id,
            aggregate_type="Repayment",
            event_type="RepaymentReversed",
            payload=event_payload
        )

        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": ev.event_id,
                "aggregate_id": ev.aggregate_id,
                "aggregate_type": ev.aggregate_type,
                "event_type": ev.event_type,
                "version": ev.version,
                "payload": ev.payload,
                "status": "Posted"
            }
        })

        tx_id, post_op = FinancialPostingEngine.post_event(uow, ev, defer_commit=True)
        operations.append(post_op)

        # 3. Execute all accumulated operations atomically
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # Delete any associated payoff_excess record
        try:
            if hasattr(uow, 'payoff_excess'):
                uow.payoff_excess.delete_by_repayment_id(original_repayment_id)
            else:
                uow.client.table("loan_payoff_excess_records").delete().eq("repayment_id", original_repayment_id).execute()
        except Exception as ex_del:
            print(f"[REPAYMENT REVERSAL] Cleanup payoff/excess record failed: {ex_del}")

        # 4. Rebuild projection
        try:
            branch_val = orig.get("branch_id")
            rebuild_date = rev_dt.date() if hasattr(rev_dt, 'date') and callable(rev_dt.date) else (date.fromisoformat(str(rev_dt)[:10]) if rev_dt else date.today())
            uow.cashbook.rebuild_projection(uow, branch_val, rebuild_date)

            orig_raw_date = orig.get("payment_date") or orig.get("date")
            if orig_raw_date:
                orig_date = date.fromisoformat(str(orig_raw_date)[:10])
                if orig_date != rebuild_date:
                    uow.cashbook.rebuild_projection(uow, branch_val, orig_date)
        except Exception as ex:
            print(f"Deferred cashbook rebuild failed during reversal: {ex}")

    @staticmethod
    def classify_repayment(
        amount_paid: float,
        total_due_today: float,
        current_installment: float = 0.0,
        has_overdue: bool = False
    ) -> dict:
        """
        Authoritative classification of loan repayment per BR-DASH-007.
        Distinguishes between:
        - NOT_PAID: ₦0 collection
        - PAID: Exactly meets total_due_today (or base installment when on-schedule)
        - PART_PAID: Amount > 0 but less than total_due_today
        - EXCESS: Amount > total_due_today (surplus cash goes to principal prepayment)
        """
        amt = float(amount_paid or 0.0)
        due = float(total_due_today or 0.0)

        if amt <= 0.0:
            return {
                "status": "NOT_PAID",
                "status_badge": "❌ NOT PAID",
                "overdue_shortfall": due,
                "true_excess": 0.0,
                "arrears_recovered": 0.0,
                "is_arrears_cleared": False
            }

        if due <= 0.0:
            # If nothing was currently due (e.g. advance prepayment)
            return {
                "status": "EXCESS",
                "status_badge": "🔵 EXCESS",
                "overdue_shortfall": 0.0,
                "true_excess": amt,
                "arrears_recovered": 0.0,
                "is_arrears_cleared": False
            }

        diff = amt - due
        if abs(diff) < 0.01:
            badge = "✅ PAID (ARREARS CLEARED)" if has_overdue else "✅ PAID"
            return {
                "status": "PAID",
                "status_badge": badge,
                "overdue_shortfall": 0.0,
                "true_excess": 0.0,
                "arrears_recovered": max(0.0, due - current_installment) if has_overdue else 0.0,
                "is_arrears_cleared": has_overdue
            }
        elif diff > 0.01:
            return {
                "status": "EXCESS",
                "status_badge": "🔵 EXCESS",
                "overdue_shortfall": 0.0,
                "true_excess": round(diff, 2),
                "arrears_recovered": max(0.0, due - current_installment) if has_overdue else 0.0,
                "is_arrears_cleared": has_overdue
            }
        else: # amt < due
            return {
                "status": "PART_PAID",
                "status_badge": "⚠️ PART PAID",
                "overdue_shortfall": round(due - amt, 2),
                "true_excess": 0.0,
                "arrears_recovered": min(amt, max(0.0, due - current_installment)) if has_overdue else 0.0,
                "is_arrears_cleared": False
            }

    @classmethod
    def _record_payoff_and_excess_if_applicable(cls, uow: SupabaseUnitOfWork, repayment: Repayment):
        """
        Determines if a repayment triggers a Full Payoff (outstanding balance = 0)
        and/or an Excess Payment (amount_paid > expected_installment), and persists
        the authoritative record in public.loan_payoff_excess_records (BR-DASH-005).
        """
        from domain.entities.payoff_excess_record import LoanPayoffExcessRecord
        from services.posting_engine import FinancialPostingEngine

        l_res = uow.client.table("loans").select("loan_id, client_id, active_credit, total_due, loan_amount, loan_repay, branch_id, officer_id, status").eq("loan_id", repayment.loan_id).execute()
        if not l_res.data:
            return
        loan = l_res.data[0]

        act_cred = float(loan.get("active_credit") or loan.get("loan_amount") or 0.0)
        tot_due_base = float(loan.get("total_due") if loan.get("total_due") is not None else act_cred)
        loan_repay = float(loan.get("loan_repay") or 0.0)
        exp_inst = float(getattr(repayment, 'expected_amount', 0.0) or 0.0)
        if exp_inst <= 0:
            exp_inst = loan_repay

        # Query all repayments for this loan to determine lifetime total paid
        rep_res = uow.client.table("repayments").select("id, amount_paid").eq("loan_id", repayment.loan_id).execute()
        all_reps = rep_res.data or []
        tot_paid_all = sum(float(r.get("amount_paid") or 0.0) for r in all_reps)

        paid_amt = float(repayment.loan_repayment_amount or repayment.amount_paid or 0.0)
        prior_paid = max(0.0, tot_paid_all - paid_amt)
        rem_before = max(0.0, tot_due_base - prior_paid)
        rem_after = max(0.0, tot_due_base - tot_paid_all)

        is_payoff = (rem_after <= 0.0 and rem_before > 0.0 and act_cred > 0)
        is_excess = (exp_inst > 0 and paid_amt > exp_inst)

        if not is_payoff and not is_excess:
            return

        # Resolve client UUID
        c_id = loan.get("client_id") or repayment.client_id
        try:
            import uuid
            uuid.UUID(str(c_id))
        except Exception:
            c_res = uow.client.table("clients").select("client_id").eq("client_code", str(c_id)).execute()
            if c_res.data:
                c_id = c_res.data[0]["client_id"]

        b_id = loan.get("branch_id")
        if not b_id and repayment.branch:
            try:
                b_id = FinancialPostingEngine._resolve_branch_id(uow, repayment.branch)
            except Exception:
                pass

        o_id = loan.get("officer_id")
        if not o_id and repayment.credit_officer:
            try:
                o_id = FinancialPostingEngine._resolve_officer_id(uow, repayment.credit_officer)
            except Exception:
                pass

        if is_payoff and is_excess:
            rec_type = "FULL_PAYOFF_AND_EXCESS"
            active_settled = act_cred
            excess_amt = round(paid_amt - exp_inst, 2)
        elif is_payoff:
            rec_type = "FULL_PAYOFF"
            active_settled = act_cred
            excess_amt = 0.0
        else:
            rec_type = "EXCESS_PAYMENT"
            active_settled = 0.0
            excess_amt = round(paid_amt - exp_inst, 2)

        rep_date = repayment.payment_date if repayment.payment_date else date.today()
        if hasattr(rep_date, 'date') and callable(rep_date.date):
            rep_date = rep_date.date()
        elif isinstance(rep_date, str):
            rep_date = date.fromisoformat(rep_date[:10])

        rec = LoanPayoffExcessRecord(
            repayment_id=repayment.id,
            loan_id=repayment.loan_id,
            client_id=str(c_id),
            officer_id=o_id,
            branch_id=b_id,
            date=rep_date,
            record_type=rec_type,
            amount_paid=paid_amt,
            expected_installment=exp_inst,
            active_credit_settled=active_settled,
            excess_amount=excess_amt,
            remaining_balance_before=round(rem_before, 2),
            remaining_balance_after=round(rem_after, 2),
            notes=repayment.note or f"Automatic payoff/excess record ({rec_type})"
        )

        if hasattr(uow, 'payoff_excess'):
            uow.payoff_excess.record_event(rec)
        else:
            uow.client.table("loan_payoff_excess_records").insert({
                "id": rec.id,
                "repayment_id": rec.repayment_id,
                "loan_id": rec.loan_id,
                "client_id": rec.client_id,
                "officer_id": rec.officer_id,
                "branch_id": rec.branch_id,
                "date": rep_date.isoformat(),
                "record_type": rec_type,
                "amount_paid": paid_amt,
                "expected_installment": exp_inst,
                "active_credit_settled": active_settled,
                "excess_amount": excess_amt,
                "remaining_balance_before": round(rem_before, 2),
                "remaining_balance_after": round(rem_after, 2),
                "notes": rec.notes
            }).execute()

