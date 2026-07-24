from typing import Protocol, Any
from interfaces.loan_repository import LoanRepository
from interfaces.repayment_repository import RepaymentRepository
from interfaces.user_repository import UserRepository
from interfaces.audit_repository import AuditRepository
from interfaces.cashbook_repository import CashbookRepository
from interfaces.branch_closure_repository import BranchClosureRepository
from interfaces.event_store_repository import EventStoreRepository
from interfaces.posting_rules_repository import PostingRulesRepository
from interfaces.ledger_repository import LedgerRepository
from interfaces.client_repository import ClientRepository
from interfaces.guarantor_repository import GuarantorRepository

class UnitOfWork(Protocol):
    loans: LoanRepository
    repayments: RepaymentRepository
    users: UserRepository
    audit: AuditRepository
    cashbook: CashbookRepository
    branch_closures: BranchClosureRepository
    event_store: EventStoreRepository
    posting_rules: PostingRulesRepository
    ledger: LedgerRepository
    clients: ClientRepository
    guarantors: GuarantorRepository
    audit_views: Any


    def __enter__(self) -> 'UnitOfWork': ...
    def __exit__(self, exc_type, exc_val, traceback) -> None: ...
    def commit(self) -> None: ...
    def rollback(self) -> None: ...
