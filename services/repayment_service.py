import uuid
from datetime import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.repayment import Repayment
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine

class RepaymentService:
    @staticmethod
    def post_repayment(uow: SupabaseUnitOfWork, repayment: Repayment) -> Repayment:
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
                    "metadata": evt.metadata,
                    "status": "Posted"
                }
            })
            tx_id, post_op = FinancialPostingEngine.post_event(uow, evt, defer_commit=True)
            operations.append(post_op)

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
                    "narration": repayment.note or f"Loan repayment of {repayment.loan_repayment_amount} received."
                }
            )
            add_event(event)

        # 4. Process extra fees and input from EOD collection
        extra = repayment.extra_fields or {}
        # Mapping of dict key -> (Event Type, Narration)
        fee_mapping = {
            "App Fee": ("FeeCharged", "Processing / Application Fee"),
            "Pass Book Bonus": ("FeeCharged", "Passbook"),
            "Misc Fees": ("FeeCharged", "Misc Fee"),
            "Asset Credit Sales": ("AssetSoldCash", "Asset Credit Sales"),
            "Cash and Carry": ("AssetSoldCash", "Cash and Carry"),
            "Contingency": ("FeeCharged", "Contingency"),
            "Daily 11%": ("FeeCharged", "11% markup"),
            "Daily 20%": ("FeeCharged", "20% markup"),
            "Weekly 11%": ("FeeCharged", "11% weekly"),
            "Weekly 20%": ("FeeCharged", "20% weekly"),
            "Bank Deposited": ("BankDeposited", "Bank Deposited"),
            "Bank Withdrawal": ("BankWithdrawn", "Bank Withdrawn"),
            "Product Withdrawal": ("ProductWithdrawn", "Product Withdrawal"),
            "Credit Form": ("FeeCharged", "Credit Form"),
            "Credit Form Damage": ("FeeCharged", "Credit Form Damage"),
            "Bonus": ("FeeCharged", "Bonus")
        }

        for k, (e_type, narr) in fee_mapping.items():
            amt = extra.get(k)
            try:
                amt = float(amt) if amt else 0.0
            except ValueError:
                amt = 0.0
            if amt > 0:
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
                        "narration": narr
                    }
                )
                add_event(ev)

        # Execute all accumulated operations atomically
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # Rebuild projection
        try:
            b_id = uow.repayments._resolve_branch_id(repayment.branch)
            from datetime import date
            uow.cashbook.rebuild_projection(uow, b_id, date.today())
        except Exception as ex:
            print(f"[SAVINGS TRACE] Deferred cashbook rebuild failed: {ex}")

        return repayment
