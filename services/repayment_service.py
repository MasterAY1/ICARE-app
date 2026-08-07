import uuid
from datetime import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.repayment import Repayment
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine

class RepaymentService:
    @staticmethod
    def post_repayment(uow: SupabaseUnitOfWork, repayment: Repayment) -> Repayment:
        # 1. Persist operational data
        created_rep = uow.repayments.create(repayment)
        
        # 2. Audit log
        uow.audit.log_action(
            user=repayment.credit_officer,
            role="Credit Officer",
            action="Loan Repayment Received",
            table_name="repayments",
            record_id=created_rep.id,
            old_value=None,
            new_value={"amount": repayment.amount_paid}
        )

        # 3. Create Event & Post (Only for actual loan repayment component)
        if repayment.loan_repayment_amount > 0:
            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=created_rep.id,
                aggregate_type="Repayment",
                event_type="RepaymentReceived",
                payload={
                    "branch": repayment.branch,
                    "officer": repayment.credit_officer,
                    "amount": repayment.loan_repayment_amount,
                    "reference": created_rep.id,
                    "loan_id": repayment.loan_id,
                    "narration": repayment.note or f"Loan repayment of {repayment.loan_repayment_amount} received."
                }
            )
            uow.event_store.append(event)
            FinancialPostingEngine.post_event(uow, event)

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
                    aggregate_id=created_rep.id,
                    aggregate_type="Repayment",
                    event_type=e_type,
                    payload={
                        "branch": repayment.branch,
                        "officer": repayment.credit_officer,
                        "amount": amt,
                        "reference": created_rep.id,
                        "loan_id": repayment.loan_id,
                        "narration": narr
                    }
                )
                uow.event_store.append(ev)
                FinancialPostingEngine.post_event(uow, ev)

        return created_rep
