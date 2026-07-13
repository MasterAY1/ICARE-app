import uuid
from datetime import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.loan import Loan
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine

class LoanService:
    @staticmethod
    def disburse_loan(uow: SupabaseUnitOfWork, loan: Loan) -> Loan:
        # 1. Persist operational data
        created_loan = uow.loans.create(loan)
        
        # 2. Audit log
        uow.audit.log_action(
            user=loan.credit_officer,
            role="Credit Officer",
            action="Loan Disbursed",
            table_name="loans",
            record_id=created_loan.id,
            old_value=None,
            new_value={"amount": loan.amount}
        )

        # 3. Create Event & Post
        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=created_loan.id,
            aggregate_type="Loan",
            event_type="LoanDisbursed",
            payload={
                "branch": loan.branch,
                "officer": loan.credit_officer,
                "amount": loan.amount,
                "reference": created_loan.id,
                "narration": f"Loan disbursement of {loan.amount} to client {loan.client_name}"
            }
        )
        uow.event_store.append(event)
        FinancialPostingEngine.post_event(uow, event)

        return created_loan
