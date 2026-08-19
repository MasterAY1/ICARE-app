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
    def disburse_loan(uow: SupabaseUnitOfWork, loan: Loan, disbursement_date: Optional[date] = None) -> Loan:
        """
        Executes atomic loan disbursement:
        1. Generates correlation reference ID (e.g. TXN-YYYYMMDD-XXXXXX).
        2. Resolves active Business Date or custom disbursement_date.
        3. Updates loan status to Active, start date, expected end date.
        4. Emits LoanDisbursed event to event store & financial posting engine.
        5. Emits upfront deduction & revenue events (MarkupCharged, ContingencyCharged, FeeCharged, GapFeeTransferred).
        """
        # 1. Business Date & Reference ID
        b_date = disbursement_date or BusinessDateService.get_business_date(uow, loan.branch)
        b_date_str = b_date.strftime("%Y%m%d")
        ref_id = f"TXN-{b_date_str}-{uuid.uuid4().hex[:6].upper()}"

        # 2. Calculate loan setup pricing parameters
        prod_cat = getattr(loan, 'product_category', None) or loan.extra_fields.get("product_category") or ("Asset" if getattr(loan, 'is_asset', False) else "Finance")
        setup = LoanProductEngine.calculate_loan_setup(loan.amount, loan.product_type, prod_cat)
        
        is_cash_and_carry = bool(loan.product_type and ("cash and carry" in str(loan.product_type).lower() or "cash & carry" in str(loan.product_type).lower()))
        
        # 3. Update Loan status and dates
        if is_cash_and_carry:
            loan.status = LoanStatus.COMPLETED if hasattr(LoanStatus, 'COMPLETED') else "Completed"
            loan.start_date = b_date
            loan.expected_end_date = b_date
        else:
            loan.status = LoanStatus.ACTIVE if hasattr(LoanStatus, 'ACTIVE') else "Active"
            # Calculate meeting day if weekly
            meeting_day = None
            try:
                res_m = uow.client.table("client_memberships").select("groups(meeting_day)").eq("client_id", loan.client_id).execute()
                if res_m.data and res_m.data[0].get("groups"):
                    meeting_day = res_m.data[0]["groups"].get("meeting_day")
            except Exception:
                pass

            freq = setup.get("freq", "Daily")
            duration = setup.get("duration", 60)
            schedule = LoanProductEngine.generate_repayment_schedule(
                b_date, duration, freq, meeting_day=meeting_day
            )
            if schedule:
                loan.start_date = schedule[0]
                loan.expected_end_date = schedule[-1]
            else:
                loan.start_date = b_date
                loan.expected_end_date = b_date
                
        loan.disbursement_date = b_date
                
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
                "action": "Cash and Carry Sold" if is_cash_and_carry else "Loan Disbursed",
                "description": f"Role: Credit Officer. Old: None. New: {{'amount': {loan.amount}, 'status': '{loan.status}', 'reference_id': '{ref_id}'}}",
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

        # 5. Domain Event 1: LoanDisbursed or AssetSoldCash
        if is_cash_and_carry:
            event_cc = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=loan.id,
                aggregate_type="Asset",
                event_type="AssetSoldCash",
                payload={
                    "branch": loan.branch,
                    "officer": loan.credit_officer,
                    "amount": loan.amount,
                    "date": b_date.isoformat(),
                    "reference": ref_id,
                    "classification": "Cash and Carry",
                    "product_category": "Asset",
                    "narration": f"Cash & Carry asset sale of {loan.amount:,.2f} for client {loan.client_name}"
                }
            )
            add_event(event_cc)
        else:
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

            # 7. Domain Event 3: Upfront Savings Deduction / Base Savings (Finance loans only)
            if not loan.is_asset:
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

        # 7b. Update client lifecycle status to 'On Loan' (BR-CLI-003.2)
        try:
            from services.client_status_service import ClientStatusService
            ClientStatusService.on_loan_disbursed(uow, loan.client_id, loan.id, getattr(loan, "officer_id", None))
        except Exception as st_err:
            print(f"[LOAN TRACE] Failed to transition client status on disbursement: {st_err}")

        # 8. Generate Amortization Schedule in database
        try:
            from services.schedule_service import ScheduleService
            ScheduleService.generate_schedule(uow, loan, loan.disbursement_date)
        except Exception as se:
            print(f"[ERROR] Error generating amortization schedule for loan {loan.id}: {se}")

        # Rebuild projection
        try:
            b_id = uow.loans._resolve_branch_id(loan.branch)
            uow.cashbook.rebuild_projection(b_id, b_date)
        except Exception as ex:
            print(f"[SAVINGS TRACE] Deferred cashbook rebuild failed: {ex}")

        return loan

    @staticmethod
    def approve_and_disburse_loan(uow: SupabaseUnitOfWork, loan_id: str, approved_by: str, disbursement_date: Optional[date] = None) -> Loan:
        """
        BM approves and disburses a pending loan application:
        1. Loads the pending Loan domain entity.
        2. Executes atomic disbursement via disburse_loan(uow, loan, disbursement_date=disbursement_date).
        """
        loan = uow.loans.get_by_id(loan_id)
        if not loan:
            res = uow.client.table("loans").select("*, clients(name, client_code), loan_products(name), branches(name), app_users(username)").eq("loan_id", loan_id).execute()
            if res.data:
                from mappers.base_mappers import LoanMapper
                loan = LoanMapper.to_domain(res.data[0])
            else:
                raise ValueError(f"Loan application with ID {loan_id} not found.")

        return LoanService.disburse_loan(uow, loan, disbursement_date=disbursement_date)

    @staticmethod
    def reject_loan(uow: SupabaseUnitOfWork, loan_id: str, rejected_by: str, reason: str = "") -> None:
        """
        BM rejects a pending loan application:
        1. Updates loans table status to 'Rejected'.
        2. Transitions client lifecycle status back to 'Registered'.
        """
        uow.loans.reject(loan_id)

        res = uow.client.table("loans").select("client_id").eq("loan_id", loan_id).execute()
        if res.data and res.data[0].get("client_id"):
            cid = res.data[0]["client_id"]
            try:
                from services.client_status_service import ClientStatusService
                ClientStatusService.transition_status(
                    uow=uow,
                    client_id=cid,
                    new_status_name="Registered",
                    changed_by=rejected_by,
                    reason=f"Loan application rejected by BM: {reason or 'Not approved'}",
                    trigger_type="MANUAL"
                )
            except Exception as st_err:
                print(f"[LOAN TRACE] Failed to update client status on rejection: {st_err}")
