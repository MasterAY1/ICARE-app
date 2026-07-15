from interfaces.unit_of_work import UnitOfWork
from database.repositories.loan_repository import SupabaseLoanRepository
from database.repositories.repayment_repository import SupabaseRepaymentRepository
from database.repositories.user_repository import SupabaseUserRepository
from database.repositories.audit_repository import SupabaseAuditRepository
from database.repositories.cashbook_repository import SupabaseCashbookRepository
from database.repositories.branch_closure_repository import SupabaseBranchClosureRepository
from database.repositories.event_store_repository import SupabaseEventStoreRepository
from database.repositories.posting_rules_repository import SupabasePostingRulesRepository
from database.repositories.ledger_repository import SupabaseLedgerRepository
from database.repositories.client_repository import SupabaseClientRepository
from database.repositories.guarantor_repository import SupabaseGuarantorRepository
from database.repositories.savings_repository import (
    SupabaseIndividualSavingsRepository,
    SupabaseGroupSavingsRepository,
    SupabaseMiscSavingsRepository,
    SupabaseLapsSavingsRepository
)
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
        self.individual_savings = SupabaseIndividualSavingsRepository(self.client)
        self.group_savings = SupabaseGroupSavingsRepository(self.client)
        self.misc_savings = SupabaseMiscSavingsRepository(self.client)
        self.laps_savings = SupabaseLapsSavingsRepository(self.client)
        self.event_store = SupabaseEventStoreRepository(self.client)
        self.posting_rules = SupabasePostingRulesRepository(self.client)
        self.ledger = SupabaseLedgerRepository(self.client)
        self.clients = SupabaseClientRepository(self.client)
        self.guarantors = SupabaseGuarantorRepository(self.client)

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
        # Supabase REST does not support manual rollbacks. 
        # We pass to ensure the original exception propagates up.
        pass
