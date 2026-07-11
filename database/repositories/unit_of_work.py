from interfaces.unit_of_work import UnitOfWork
from database.repositories.loan_repository import SupabaseLoanRepository
from database.repositories.repayment_repository import SupabaseRepaymentRepository
from database.repositories.user_repository import SupabaseUserRepository
from database.repositories.audit_repository import SupabaseAuditRepository
from database.repositories.cashbook_repository import SupabaseCashbookRepository
from database.repositories.branch_closure_repository import SupabaseBranchClosureRepository
from database.connection import supabase

class SupabaseUnitOfWork(UnitOfWork):
    def __init__(self):
        self.client = supabase
        self.loans = SupabaseLoanRepository(self.client)
        self.repayments = SupabaseRepaymentRepository(self.client)
        self.users = SupabaseUserRepository(self.client)
        self.audit = SupabaseAuditRepository(self.client)
        self.cashbook = SupabaseCashbookRepository(self.client)
        self.branch_closures = SupabaseBranchClosureRepository(self.client)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, traceback):
        if exc_type:
            self.rollback()
        else:
            self.commit()

    def commit(self):
        # Supabase REST does not support manual transactions
        pass

    def rollback(self):
        raise NotImplementedError("Rollback is not supported with the current Supabase REST backend.")
