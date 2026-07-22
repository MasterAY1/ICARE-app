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
                
        if not loan.id:
            created_loan = uow.loans.create(loan)
            loan.id = created_loan.id
        else:
            uow.loans.update(loan)

        # 4. Audit Log
        uow.audit.log_action(
            user=loan.credit_officer,
            role="Credit Officer",
            action="Loan Disbursed",
            table_name="loans",
            record_id=loan.id,
            old_value=None,
            new_value={"amount": loan.amount, "status": "Active", "reference_id": ref_id}
        )

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
                "narration": f"Loan disbursement of {loan.amount:,.2f} for client {loan.client_name}"
            }
        )
        uow.event_store.append(event_disbursed)
        FinancialPostingEngine.post_event(uow, event_disbursed)

        # 6. Domain Event 2: Upfront Revenue (Markup & Contingency)
        markup_val = setup.get("markup", 0.0)
        cont_val = setup.get("contingency", 0.0)
        
        if markup_val > 0:
            rate = setup.get("rate", 0.12)
            prod_lower = (loan.product_type or "").lower()
            # 11% Profit Sales: 60 Days, 12 Weeks, 3 Months (rate == 0.12)
            # 20% Profit Sales: 120 Days, 24 Weeks, 6 Months (rate == 0.21)
            is_20_pct = (rate == 0.21) or "120" in prod_lower or "24" in prod_lower or "6m" in prod_lower or "6 month" in prod_lower
            
            markup_class = TransactionClassification.MARKUP_20.value if is_20_pct else TransactionClassification.MARKUP_11.value
            
            # Persist to specialized fee repository
            b_id = uow.markup_11._resolve_branch_id(loan.branch)
            o_id = uow.markup_11._resolve_officer_id(loan.credit_officer)
            if is_20_pct:
                uow.markup_20.create_fee_entry(branch_id=b_id, officer_id=o_id, amount=markup_val, client_id=loan.client_id, loan_id=loan.id, reference=ref_id, posting_date=b_date)
            else:
                uow.markup_11.create_fee_entry(branch_id=b_id, officer_id=o_id, amount=markup_val, client_id=loan.client_id, loan_id=loan.id, reference=ref_id, posting_date=b_date)

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
                    "narration": f"Upfront Markup Charged ({'20%' if is_monthly else '11%'}) ({loan.product_type}) for client {loan.client_name}"
                }
            )
            uow.event_store.append(event_markup)
            FinancialPostingEngine.post_event(uow, event_markup)

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
            uow.event_store.append(event_cont)
            FinancialPostingEngine.post_event(uow, event_cont)

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
            uow.event_store.append(event_gap)
            FinancialPostingEngine.post_event(uow, event_gap)

        return loan
