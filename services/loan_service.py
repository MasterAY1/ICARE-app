from typing import Optional, List, Dict, Any, Union
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
    def disburse_loan(uow: SupabaseUnitOfWork, loan: Loan, disbursement_date: Optional[date] = None, idempotency_key: Optional[str] = None) -> Loan:
        # Concurrency & Idempotency Guard: Disallow re-disbursing an active loan
        if str(getattr(loan, "status", "")).lower() == "active":
            raise ValueError(f"Loan #{loan.id[:8] if loan.id else ''} has already been activated and disbursed.")
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
        
        # Check Business Date Freeze & Working Day (BR-DATE-002)
        is_open, reason = BusinessDateService.is_operational_open(uow, loan.branch, b_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot disburse loan. {reason}.")

        b_date_str = b_date.strftime("%Y%m%d")
        ref_id = f"TXN-{b_date_str}-{uuid.uuid4().hex[:6].upper()}"

        # 2. Calculate loan setup pricing parameters
        is_asset_loan = bool(getattr(loan, 'is_asset', False) or getattr(loan, 'product_category', None) == "Asset" or loan.extra_fields.get("product_category") == "Asset" or "asset" in str(loan.product_type or "").lower())
        prod_cat = "Asset" if is_asset_loan else "Finance"
        setup = LoanProductEngine.calculate_loan_setup(loan.amount, loan.product_type, prod_cat)
        
        is_cash_and_carry = bool(loan.product_type and ("cash and carry" in str(loan.product_type).lower() or "cash & carry" in str(loan.product_type).lower()))
        
        # 3. Update Loan status and dates
        if not isinstance(loan.extra_fields, dict):
            loan.extra_fields = {}

        if is_cash_and_carry:
            loan.status = LoanStatus.COMPLETED if hasattr(LoanStatus, 'COMPLETED') else "Completed"
            loan.start_date = b_date
            loan.end_date = b_date
            loan.expected_end_date = b_date
        else:
            loan.status = LoanStatus.ACTIVE if hasattr(LoanStatus, 'ACTIVE') else "Active"
            # Calculate meeting day if weekly
            meeting_day = None
            try:
                res_m = uow.client.table("client_memberships").select("groups(meeting_day)").eq("client_id", loan.client_id).is_("end_date", "null").execute()
                if res_m.data and res_m.data[0].get("groups"):
                    meeting_day = res_m.data[0]["groups"].get("meeting_day")
            except Exception:
                pass

            closures = BusinessDateService.get_branch_closures(uow, getattr(loan, "branch_id", None) or loan.branch)
            closed_dates = BusinessDateService.expand_closure_dates(closures)

            freq = setup.get("freq", "Daily")
            duration = setup.get("duration", 60)
            schedule = LoanProductEngine.generate_repayment_schedule(
                b_date, duration, freq, meeting_day=meeting_day, closed_dates=closed_dates
            )
            if schedule:
                loan.start_date = schedule[0]
                loan.end_date = schedule[-1]
                loan.expected_end_date = schedule[-1]
            else:
                loan.start_date = b_date
                loan.end_date = b_date
                loan.expected_end_date = b_date
                
        loan.disbursement_date = b_date
        loan.extra_fields["disbursement_date"] = b_date.isoformat()
        loan.extra_fields["date"] = b_date.isoformat()
                
        operations = []

        if not loan.id:
            loan.id = str(uuid.uuid4())
            op_type = "insert"
        else:
            op_type = "update_loan"

        loan_record = uow.loans._prepare_db_data(loan)
        loan_record["date"] = b_date.isoformat()
        loan_record["disbursement_date"] = b_date.isoformat()
        if loan.end_date:
            loan_record["expected_end_date"] = loan.end_date.isoformat()
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
        b_uuid_resolved = FinancialPostingEngine._resolve_branch_id(uow, loan.branch)
        c_uuid_valid = loan.client_id if is_valid_uuid(loan.client_id) else None
        extra = loan.extra_fields or {}

        if is_cash_and_carry:
            event_cc = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=loan.id,
                aggregate_type="Asset",
                event_type="AssetSoldCash",
                payload={
                    "branch": loan.branch,
                    "branch_id": b_uuid_resolved,
                    "officer": loan.credit_officer,
                    "officer_id": user_id,
                    "client_id": c_uuid_valid,
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
            act_cr_val = float(extra.get("active_credit") if extra.get("active_credit") is not None else (loan.total_payable or loan.amount))
            # For Asset loans, LoanDisbursed tracks active_credit financed while downpayments post via AssetSoldCash/LoanOffsetFromSavings
            disb_amt = act_cr_val if is_asset_loan else float(loan.amount)
            event_disbursed = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=loan.id,
                aggregate_type="Loan",
                event_type="LoanDisbursed",
                payload={
                    "branch": loan.branch,
                    "branch_id": b_uuid_resolved,
                    "officer": loan.credit_officer,
                    "officer_id": user_id,
                    "client_id": c_uuid_valid,
                    "amount": disb_amt,
                    "active_credit": act_cr_val,
                    "product_type": loan.product_type,
                    "repayment_cycle": setup.get("freq", "Daily"),
                    "duration": setup.get("duration", loan.duration or 60),
                    "date": b_date.isoformat(),
                    "reference": ref_id,
                    "classification": TransactionClassification.LOAN_DISBURSEMENT.value,
                    "product_category": prod_cat,
                    "narration": f"Loan disbursement of {disb_amt:,.2f} ({loan.product_type}) for client {loan.client_name}"
                }
            )
            add_event(event_disbursed)

            # 6. Domain Event 2: Upfront Revenue (Finance loans only - Asset margin is baked into total_cost)
            if not is_asset_loan:
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
                            "branch_id": b_uuid_resolved,
                            "officer": loan.credit_officer,
                            "officer_id": user_id,
                            "client_id": c_uuid_valid,
                            "client_name": str(loan.client_name or ""),
                            "client": str(loan.client_name or ""),
                            "amount": markup_val,
                            "date": b_date.isoformat(),
                            "reference": ref_id,
                            "classification": markup_class,
                            "narration": f"Upfront Markup Charged ({'20%' if is_20_pct else '11%'}) ({loan.product_type}) for client {loan.client_name}"
                        }
                    )
                    add_event(event_markup)
                    operations.append({
                        "type": "insert",
                        "table": "fees",
                        "record": {
                            "id": str(uuid.uuid4()),
                            "posting_date": b_date.isoformat(),
                            "client_id": c_uuid_valid,
                            "branch_id": b_uuid_resolved,
                            "officer_id": user_id,
                            "fee_type": markup_class,
                            "amount": markup_val,
                            "reference": ref_id,
                            "remarks": f"Upfront Markup Charged ({'20%' if is_20_pct else '11%'}) ({loan.product_type}) for client {loan.client_name}"
                        }
                    })

                if cont_val > 0:
                    event_cont = DomainEvent(
                        event_id=str(uuid.uuid4()),
                        aggregate_id=loan.id,
                        aggregate_type="Loan",
                        event_type="FeeCharged",
                        payload={
                            "branch": loan.branch,
                            "branch_id": b_uuid_resolved,
                            "officer": loan.credit_officer,
                            "officer_id": user_id,
                            "client_id": c_uuid_valid,
                            "client_name": str(loan.client_name or ""),
                            "client": str(loan.client_name or ""),
                            "amount": cont_val,
                            "date": b_date.isoformat(),
                            "reference": ref_id,
                            "classification": TransactionClassification.CONTINGENCY.value,
                            "narration": f"Upfront Contingency Fee Charged for client {loan.client_name}"
                        }
                    )
                    add_event(event_cont)
                    operations.append({
                        "type": "insert",
                        "table": "fees",
                        "record": {
                            "id": str(uuid.uuid4()),
                            "posting_date": b_date.isoformat(),
                            "client_id": c_uuid_valid,
                            "branch_id": b_uuid_resolved,
                            "officer_id": user_id,
                            "fee_type": "CONTINGENCY",
                            "amount": cont_val,
                            "reference": ref_id,
                            "remarks": f"Upfront Contingency Fee Charged for client {loan.client_name}"
                        }
                    })

                # 7a-Finance: Auto-deduct Upfront Fees / Gap Fee from Individual Savings atomically
                total_upfront = float(extra.get("total_upfront_required") or 0.0)
                upfront_interest = float(extra.get("upfront_interest") or 0.0)
                gap_fee = float(loan.gap_fee or extra.get("gap_fee") or 0.0)
                if total_upfront <= 0 and (upfront_interest > 0 or gap_fee > 0):
                    total_upfront = upfront_interest + gap_fee

                if total_upfront > 0:
                    from services.savings_service import SavingsService
                    SavingsService.post_individual_savings(
                        uow,
                        client_id=loan.client_id,
                        client_name=loan.client_name,
                        branch=loan.branch,
                        officer=loan.credit_officer,
                        deposit_amount=0.0,
                        withdrawal_amount=total_upfront,
                        reference=f"UPF-{loan.id[:8]}",
                        remarks=f"Auto-deducted Upfront Fees (Interest: {upfront_interest:,.2f}, Gap: {gap_fee:,.2f}) for Loan {loan.id[:8]}",
                        posting_date=b_date,
                        defer_operations=operations,
                    )
            else:
                # 7a-Asset: Cash Downpayment -> AssetSoldCash (DR 1000 / CR 3200); Savings Downpayment -> LoanOffsetFromSavings without duplicate repayment row
                asset_cash_dp = float(extra.get("downpayment_cash") or 0.0)
                if asset_cash_dp > 0:
                    event_asset_cash_dp = DomainEvent(
                        event_id=str(uuid.uuid4()),
                        aggregate_id=loan.id,
                        aggregate_type="Asset",
                        event_type="AssetSoldCash",
                        payload={
                            "branch": loan.branch,
                            "branch_id": b_uuid_resolved,
                            "officer": loan.credit_officer,
                            "officer_id": user_id,
                            "client_id": c_uuid_valid,
                            "amount": asset_cash_dp,
                            "date": b_date.isoformat(),
                            "reference": f"ADP-CASH-{loan.id[:8]}",
                            "classification": "Asset Cash Downpayment",
                            "product_category": "Asset",
                            "narration": f"Asset credit sale cash downpayment of {asset_cash_dp:,.2f} for client {loan.client_name} ({loan.product_type})"
                        }
                    )
                    add_event(event_asset_cash_dp)

                asset_sav_dp = float(extra.get("downpayment_savings") or 0.0)
                if asset_sav_dp > 0:
                    from services.savings_service import SavingsService
                    SavingsService.post_loan_offset_from_savings(
                        uow,
                        client_id=loan.client_id,
                        client_name=loan.client_name,
                        loan_id=loan.id,
                        source_savings_type="IndividualSavings",
                        branch=loan.branch,
                        officer=loan.credit_officer,
                        amount=asset_sav_dp,
                        reference=f"ADP-SAV-{loan.id[:8]}",
                        remarks=f"Asset Downpayment deducted from Savings for loan {loan.id[:8]}",
                        posting_date=b_date,
                        defer_operations=operations,
                        skip_repayment=True,
                    )

        # 7b. Client Lifecycle Status + 8. Amortization Schedule (all inside ONE atomic transaction)
        from services.client_status_service import ClientStatusService
        if is_cash_and_carry:
            try:
                other_act = uow.client.table("loans").select("loan_id").eq("client_id", loan.client_id).in_("status", ["Active", "ACTIVE", "Disbursed"]).neq("loan_id", loan.id).execute().data
            except Exception:
                other_act = []
            if not other_act:
                ClientStatusService.transition_status(
                    uow=uow,
                    client_id=loan.client_id,
                    new_status_name="Completed",
                    changed_by=getattr(loan, "officer_id", None) or user_id,
                    reason=f"Cash and Carry purchase completed ({loan.id[:8]})",
                    trigger_type="SYSTEM",
                    trigger_reference=loan.id,
                    defer_operations=operations,
                )
        else:
            ClientStatusService.on_loan_disbursed(
                uow,
                loan.client_id,
                loan.id,
                getattr(loan, "officer_id", None) or user_id,
                defer_operations=operations,
            )
            from services.schedule_service import ScheduleService
            ScheduleService.generate_schedule(uow, loan, loan.disbursement_date, defer_operations=operations)

        # Execute all accumulated operations atomically (fail-closed if any leg errors)
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # Commit physical stock deduction for Asset / Cash & Carry disbursements
        if is_asset_loan or is_cash_and_carry or (isinstance(extra, dict) and extra.get("asset_items")):
            from services.asset_inventory_service import AssetInventoryService
            AssetInventoryService.commit_disbursed_stock(
                uow,
                loan_id=loan.id,
                branch_id=b_uuid_resolved,
                extra_fields=extra,
                performed_by=user_id or loan.credit_officer,
                is_cash_and_carry=is_cash_and_carry,
                product_type=loan.product_type,
            )

        # Rebuild projection
        try:
            b_id = uow.loans._resolve_branch_id(loan.branch)
            uow.cashbook.rebuild_projection(b_id, b_date)
        except Exception as ex:
            print(f"[SAVINGS TRACE] Deferred cashbook rebuild failed: {ex}")

        return loan

    @staticmethod
    def approve_and_disburse_loan(uow: SupabaseUnitOfWork, loan_id: str, approved_by: str, disbursement_date: Optional[date] = None, idempotency_key: Optional[str] = None) -> Loan:
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

        return LoanService.disburse_loan(uow, loan, disbursement_date=disbursement_date, idempotency_key=idempotency_key)

    @staticmethod
    def reject_loan(uow: SupabaseUnitOfWork, loan_id: str, rejected_by: str, reason: str = "") -> None:
        """
        BM rejects a pending loan application atomically:
        1. Updates loans table status to 'Rejected'.
        2. Transitions client lifecycle status back to Registered / On Loan / Completed.
        3. Releases any reserved Asset Program branch stock.
        """
        from services.client_status_service import ClientStatusService

        res = uow.client.table("loans").select("loan_id, client_id, branch_id, status, extra_fields").eq("loan_id", loan_id).execute()
        if not res.data:
            raise ValueError(f"Loan application {loan_id} not found.")
        loan_row = res.data[0]
        if str(loan_row.get("status") or "") != "Pending":
            raise ValueError(f"Loan application {loan_id} is '{loan_row.get('status')}', not Pending.")

        existing_extra = loan_row.get("extra_fields") or {}
        if not isinstance(existing_extra, dict):
            existing_extra = {}
        updated_extra = dict(existing_extra)
        updated_extra.update({
            "lifecycle_status": "Rejected",
            "rejected_by": rejected_by,
            "rejection_reason": reason or "Not approved",
        })

        operations: List[Dict[str, Any]] = [
            {
                "type": "update",
                "table": "loans",
                "match": {"loan_id": loan_id},
                "record": {
                    "status": "Rejected",
                    "extra_fields": updated_extra,
                },
            }
        ]

        cid = loan_row.get("client_id")
        if cid:
            target_status = "Registered"
            act_loans = uow.client.table("loans").select("loan_id").eq("client_id", cid).in_("status", ["Active", "ACTIVE", "Approved"]).neq("loan_id", loan_id).execute().data
            if act_loans:
                target_status = "On Loan"
            else:
                comp_loans = uow.client.table("loans").select("loan_id").eq("client_id", cid).eq("status", "Completed").execute().data
                if comp_loans:
                    target_status = "Completed"

            ClientStatusService.transition_status(
                uow=uow,
                client_id=cid,
                new_status_name=target_status,
                changed_by=rejected_by,
                reason=f"Loan application rejected: {reason or 'Not approved'}",
                trigger_type="MANUAL",
                trigger_reference=loan_id,
                defer_operations=operations,
            )

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # Release reserved branch stock back into available branch pool
        if existing_extra.get("asset_items"):
            from services.asset_inventory_service import AssetInventoryService
            AssetInventoryService.release_reserved_stock(
                uow,
                loan_id=loan_id,
                branch_id=loan_row.get("branch_id"),
                extra_fields=existing_extra,
                performed_by=rejected_by,
                reason=reason,
            )
