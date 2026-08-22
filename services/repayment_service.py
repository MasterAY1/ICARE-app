import uuid
from datetime import datetime
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
        if not repayment.id:
            repayment.id = str(uuid.uuid4())
            op_type = "insert"
        else:
            op_type = "update"
            
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

        # Rebuild projection
        try:
            b_id = uow.repayments._resolve_branch_id(repayment.branch)
            from datetime import date
            p_rebuild_date = repayment.payment_date if repayment.payment_date else date.today()
            uow.cashbook.rebuild_projection(b_id, p_rebuild_date)
        except Exception as ex:
            print(f"[SAVINGS TRACE] Deferred cashbook rebuild failed: {ex}")

        return repayment

    @staticmethod
    def reverse_repayment(uow: SupabaseUnitOfWork, original_repayment_id: str, reason: str, reversed_by: str):
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
            "narration": f"Reversal of repayment {original_repayment_id}"
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

        # 4. Rebuild projection
        try:
            from datetime import date
            uow.cashbook.rebuild_projection(uow, orig.get("branch_id"), date.today())
        except Exception as ex:
            print(f"Deferred cashbook rebuild failed during reversal: {ex}")
