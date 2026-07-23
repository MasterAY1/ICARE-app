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
    FundTransferRepository,
    StaffSalaryRepository,
    HeadOfficeTransferRepository,
    BranchTransferRepository,
    OtherAreaTransferRepository,
    AssetProgramRepository,
    ProductFinanceRepository,
    CashbookAdjustmentRepository
)
from database.repositories.collection_performance_repository import SupabaseCollectionPerformanceRepository
from database.repositories.audit_view_repository import SupabaseAuditViewRepository
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
        
        # ================================================================
        # PHASE 8: 19 Audit Ledger Repositories (STI-backed)
        # ================================================================
        
        # --- Fee-type Audit Ledgers (backed by public.fees) ---
        self.processing_fees = ProcessingFeeRepository(self.client)
        self.passbook_fees = PassbookRepository(self.client)
        self.credit_forms = CreditFormRepository(self.client)
        self.credit_form_damage = CreditFormDamageRepository(self.client)
        self.bonus_transactions = BonusRepository(self.client)
        self.misc_fees = MiscFeeRepository(self.client)
        self.contingency_transactions = ContingencyRepository(self.client)
        self.markup_11_transactions = Markup11Repository(self.client)
        self.markup_20_transactions = Markup20Repository(self.client)
        
        # --- Treasury-type Audit Ledgers (backed by public.treasury_transactions) ---
        self.treasury = TreasuryTransactionRepository(self.client)
        self.bank_deposits = BankDepositRepository(self.client)
        self.bank_withdrawals = BankWithdrawalRepository(self.client)
        self.office_expenses = OfficeExpenseRepository(self.client)
        self.staff_salary_transactions = StaffSalaryRepository(self.client)
        self.head_office_transfers = HeadOfficeTransferRepository(self.client)
        self.branch_transfers = BranchTransferRepository(self.client)
        self.other_area_transfers = OtherAreaTransferRepository(self.client)
        self.asset_program_transactions = AssetProgramRepository(self.client)
        self.product_finance_transactions = ProductFinanceRepository(self.client)
        self.cashbook_adjustments = CashbookAdjustmentRepository(self.client)
        
        # --- Fund Transfer (legacy, retained for backward compatibility) ---
        self.fund_transfer = FundTransferRepository(self.client)
        
        # ================================================================
        # PHASE 8: Collection Performance & Credit Intelligence
        # ================================================================
        self.collection_performance = SupabaseCollectionPerformanceRepository(self.client)
        
        # ================================================================
        # PHASE 8.1: Audit View Repository
        # ================================================================
        self.audit_views = SupabaseAuditViewRepository(self.client)

        # ================================================================
        # Backward-compatible aliases (Phase 7 names → Phase 8 standard names)
        # ================================================================

        self.processing_fee = self.processing_fees
        self.passbook = self.passbook_fees
        self.credit_form = self.credit_forms
        self.bonus = self.bonus_transactions
        self.misc_fee = self.misc_fees
        self.contingency = self.contingency_transactions
        self.markup_11 = self.markup_11_transactions
        self.markup_20 = self.markup_20_transactions
        self.bank_deposit = self.bank_deposits
        self.bank_withdrawal = self.bank_withdrawals
        self.office_expense = self.office_expenses

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
