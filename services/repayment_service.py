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

        # 3. Create Event & Post
        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=created_rep.id,
            aggregate_type="Repayment",
            event_type="RepaymentReceived",
            payload={
                "branch": repayment.branch,
                "officer": repayment.credit_officer,
                "amount": repayment.amount_paid,
                "reference": created_rep.id,
                "narration": repayment.note or f"Loan repayment of {repayment.amount_paid} received."
            }
        )
        uow.event_store.append(event)
        FinancialPostingEngine.post_event(uow, event)

        return created_rep
