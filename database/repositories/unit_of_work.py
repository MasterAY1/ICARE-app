from interfaces.unit_of_work import UnitOfWork
from database.repositories.loan_repository import SupabaseLoanRepository
from database.repositories.repayment_repository import SupabaseRepaymentRepository
from database.repositories.user_repository import SupabaseUserRepository
from database.repositories.audit_repository import SupabaseAuditRepository
from database.repositories.cashbook_repository import SupabaseCashbookRepository
from database.repositories.branch_closure_repository import SupabaseBranchClosureRepository
from database.repositories.event_store_repository import SupabaseEventStoreRepository
from database.repositories.posting_rules_repository import SupabasePostingRulesRepository
from database.repositories.user_audit_log_repository import SupabaseUserAuditLogRepository
from database.repositories.login_history_repository import SupabaseLoginHistoryRepository
from database.repositories.ledger_repository import SupabaseLedgerRepository
from database.repositories.client_repository import SupabaseClientRepository
from database.repositories.guarantor_repository import SupabaseGuarantorRepository
from database.repositories.savings_repository import (
    SupabaseIndividualSavingsRepository,
    SupabaseGroupSavingsRepository,
    SupabaseMiscSavingsRepository,
    SupabaseLapsSavingsRepository
)
from database.repositories.fee_repositories import (
    ProcessingFeeRepository,
    PassbookRepository,
    CreditFormRepository,
    CreditFormDamageRepository,
    BonusRepository,
    MiscFeeRepository,
    ContingencyRepository,
    Markup11Repository,
    Markup20Repository
)
from database.repositories.treasury_repository import (
    TreasuryTransactionRepository,
    BankDepositRepository,
    BankWithdrawalRepository,
    OfficeExpenseRepository,
    FundTransferRepository
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
        self.user_audit_logs = SupabaseUserAuditLogRepository(self.client)
        self.login_history = SupabaseLoginHistoryRepository(self.client)
        
        # Specialized Fee Repositories
        self.processing_fee = ProcessingFeeRepository(self.client)
        self.passbook = PassbookRepository(self.client)
        self.credit_form = CreditFormRepository(self.client)
        self.credit_form_damage = CreditFormDamageRepository(self.client)
        self.bonus = BonusRepository(self.client)
        self.misc_fee = MiscFeeRepository(self.client)
        self.contingency = ContingencyRepository(self.client)
        self.markup_11 = Markup11Repository(self.client)
        self.markup_20 = Markup20Repository(self.client)
        
        # Branch Treasury Repositories
        self.treasury = TreasuryTransactionRepository(self.client)
        self.bank_deposit = BankDepositRepository(self.client)
        self.bank_withdrawal = BankWithdrawalRepository(self.client)
        self.office_expense = OfficeExpenseRepository(self.client)
        self.fund_transfer = FundTransferRepository(self.client)

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
