import uuid
from datetime import datetime, date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.loan import Loan
from domain.entities.event_store import DomainEvent
from domain.enums import LoanStatus, TransactionClassification
from services.posting_engine import FinancialPostingEngine
from services.business_date_service import BusinessDateService
from services.loan_product_engine import LoanProductEngine

class LoanService:
    @staticmethod
    def disburse_loan(uow: SupabaseUnitOfWork, loan: Loan) -> Loan:
        """
        Executes atomic loan disbursement:
        1. Generates correlation reference ID (e.g. TXN-YYYYMMDD-XXXXXX).
        2. Resolves active Business Date.
        3. Updates loan status to Active, start date, expected end date.
        4. Emits LoanDisbursed event to event store & financial posting engine.
        5. Emits upfront deduction & revenue events (MarkupCharged, ContingencyCharged, FeeCharged, GapFeeTransferred).
        """
        # 1. Business Date & Reference ID
        b_date = BusinessDateService.get_business_date(uow, loan.branch)
        b_date_str = b_date.strftime("%Y%m%d")
        ref_id = f"TXN-{b_date_str}-{uuid.uuid4().hex[:6].upper()}"

        # 2. Calculate loan setup pricing parameters
        setup = LoanProductEngine.calculate_loan_setup(loan.amount, loan.product_type, loan.product_category)
        
        # 3. Update Loan status and dates
        loan.status = LoanStatus.ACTIVE if hasattr(LoanStatus, 'ACTIVE') else "Active"
        loan.disbursement_date = b_date
        if not loan.start_date:
            loan.start_date = b_date
        
        if setup.get("duration"):
            schedule = LoanProductEngine.generate_repayment_schedule(loan.start_date, setup["duration"], setup.get("freq", "Daily"))
            if schedule:
                loan.expected_end_date = schedule[-1]
                
        operations = []

        if not loan.id:
            loan.id = str(uuid.uuid4())
            op_type = "insert"
        else:
            op_type = "update_loan"

        loan_record = uow.loans._prepare_db_data(loan)
        if "loan_id" in loan_record and not loan_record["loan_id"]:
            del loan_record["loan_id"]
        if op_type == "insert" and "loan_id" not in loan_record:
            loan_record["loan_id"] = loan.id

        operations.append({
            "type": op_type,
            "table": "loans",
            "record": loan_record
        })

        # 4. Audit Log
        from database.repositories.audit_repository import resolve_officer_id, is_valid_uuid
        user_id = resolve_officer_id(uow.client, loan.credit_officer)
        rec_uuid = loan.id if loan.id and is_valid_uuid(loan.id) else None
        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": user_id,
                "action": "Loan Disbursed",
                "description": f"Role: Credit Officer. Old: None. New: {{'amount': {loan.amount}, 'status': 'Active', 'reference_id': '{ref_id}'}}",
                "table_name": "loans",
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

        # 5. Domain Event 1: LoanDisbursed
        event_disbursed = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=loan.id,
            aggregate_type="Loan",
            event_type="LoanDisbursed",
            payload={
                "branch": loan.branch,
                "officer": loan.credit_officer,
                "amount": loan.amount,
                "date": b_date.isoformat(),
                "reference": ref_id,
                "classification": TransactionClassification.LOAN_DISBURSEMENT.value,
                "product_category": "Asset" if loan.is_asset else "Finance",
                "narration": f"Loan disbursement of {loan.amount:,.2f} for client {loan.client_name}"
            }
        )
        add_event(event_disbursed)

        # 6. Domain Event 2: Upfront Revenue (Markup & Contingency)
        markup_val = setup.get("markup", 0.0)
        cont_val = setup.get("contingency", 0.0)
        
        if markup_val > 0:
            rate = setup.get("rate", 0.12)
            prod_lower = (loan.product_type or "").lower()
            is_20_pct = (rate == 0.21) or "120" in prod_lower or "24" in prod_lower or "6m" in prod_lower or "6 month" in prod_lower
            markup_class = TransactionClassification.MARKUP_20.value if is_20_pct else TransactionClassification.MARKUP_11.value
            
            b_id = uow.markup_11._resolve_branch_id(loan.branch)
            o_id = uow.markup_11._resolve_officer_id(loan.credit_officer)
            fee_table = "markup_20_transactions" if is_20_pct else "markup_11_transactions"

            operations.append({
                "type": "insert",
                "table": fee_table,
                "record": {
                    "fee_id": str(uuid.uuid4()),
                    "branch_id": b_id,
                    "officer_id": o_id,
                    "client_id": loan.client_id,
                    "loan_id": loan.id,
                    "reference": ref_id,
                    "amount": float(markup_val),
                    "posting_date": b_date.isoformat()
                }
            })

            event_markup = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=loan.id,
                aggregate_type="Loan",
                event_type="FeeCharged",
                payload={
                    "branch": loan.branch,
                    "officer": loan.credit_officer,
                    "amount": markup_val,
                    "date": b_date.isoformat(),
                    "reference": ref_id,
                    "classification": markup_class,
                    "narration": f"Upfront Markup Charged ({'20%' if is_20_pct else '11%'}) ({loan.product_type}) for client {loan.client_name}"
                }
            )
            add_event(event_markup)

        if cont_val > 0:
            event_cont = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=loan.id,
                aggregate_type="Loan",
                event_type="FeeCharged",
                payload={
                    "branch": loan.branch,
                    "officer": loan.credit_officer,
                    "amount": cont_val,
                    "date": b_date.isoformat(),
                    "reference": ref_id,
                    "classification": TransactionClassification.CONTINGENCY.value,
                    "narration": f"Upfront Contingency Fee Charged for client {loan.client_name}"
                }
            )
            add_event(event_cont)

        # 7. Domain Event 3: Upfront Savings Deduction / Base Savings
        gap_fee = setup.get("gap_fee", 0.0)
        if gap_fee > 0:
            event_gap = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=loan.id,
                aggregate_type="Loan",
                event_type="SavingsDeposited",
                payload={
                    "branch": loan.branch,
                    "officer": loan.credit_officer,
                    "amount": gap_fee,
                    "date": b_date.isoformat(),
                    "reference": ref_id,
                    "classification": TransactionClassification.AUTOMATIC_DEDUCTION.value,
                    "narration": f"Upfront Gap Fee Base Savings for client {loan.client_name}"
                }
            )
            add_event(event_gap)

        # Execute all accumulated operations atomically
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # Rebuild projection
        try:
            b_id = uow.loans._resolve_branch_id(loan.branch)
            uow.cashbook.rebuild_projection(uow, b_id, b_date)
        except Exception as ex:
            print(f"[SAVINGS TRACE] Deferred cashbook rebuild failed: {ex}")

        return loan
