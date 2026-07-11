from typing import Protocol
from interfaces.loan_repository import LoanRepository
from interfaces.repayment_repository import RepaymentRepository
from interfaces.user_repository import UserRepository
from interfaces.audit_repository import AuditRepository
from interfaces.cashbook_repository import CashbookRepository
from interfaces.branch_closure_repository import BranchClosureRepository

class UnitOfWork(Protocol):
    loans: LoanRepository
    repayments: RepaymentRepository
    users: UserRepository
    audit: AuditRepository
    cashbook: CashbookRepository
    branch_closures: BranchClosureRepository

    def __enter__(self) -> 'UnitOfWork': ...
    def __exit__(self, exc_type, exc_val, traceback) -> None: ...
    def commit(self) -> None: ...
    def rollback(self) -> None: ...
