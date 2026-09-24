"""
Reports and Export Pydantic Schemas — Phase 11 Parity Migration.
Models for General Ledger Trial Balance, Savings Summary, Repayment Summary,
Portfolio Performance, Area Branch Comparison, and Data Exports.
"""
from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field


# --- METADATA ---

class BranchOption(BaseModel):
    branch_id: Optional[str] = None
    name: str


class OfficerOption(BaseModel):
    user_id: str
    username: str
    full_name: str
    branch_id: Optional[str] = None
    branch_name: Optional[str] = None


class ReportsMetaResponse(BaseModel):
    branches: List[BranchOption]
    products: List[str]
    officers: List[OfficerOption]
    default_branch: Optional[str] = None
    scope_level: str  # "BRANCH", "AREA", "INSTITUTION"


# --- TRIAL BALANCE ---

class TrialBalanceRow(BaseModel):
    account_code: str
    account_name: str
    account_type: str
    normal_balance: str
    gross_debits: float
    gross_credits: float
    debit_balance: float
    credit_balance: float
    net_position: float


class TrialBalanceResponse(BaseModel):
    is_balanced: bool
    status: str
    total_debits: float
    total_credits: float
    total_net_debits: float
    total_net_credits: float
    variance: float
    as_of_date: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    rows: List[TrialBalanceRow]


# --- SAVINGS SUMMARY ---

class SaverRow(BaseModel):
    client_id: str
    client_name: str
    group: str
    branch: str
    officer: str
    total_deposited: float
    total_withdrawn: float
    net_savings_balance: float
    last_transaction_date: Optional[str] = None


class SavingsSummaryResponse(BaseModel):
    total_individual_deposits: float
    total_individual_withdrawals: float
    net_individual_savings: float
    total_group_deposits: float
    total_group_withdrawals: float
    net_group_savings: float
    laps_reserve: float
    total_consolidated_savings: float
    active_savers_count: int
    total_savers_recorded: int
    savers: List[SaverRow]


# --- REPAYMENT SUMMARY ---

class ProductCollectionRow(BaseModel):
    loan_product: str
    collections_ngn: float
    transactions: int
    unique_clients: int


class RepaymentLogRow(BaseModel):
    date: str
    client_code: str
    client_name: str
    loan_product: str
    officer: str
    branch: str
    amount_paid: float
    expected_amount: float
    payment_status: str
    transaction_type: str


class RepaymentSummaryResponse(BaseModel):
    total_collected: float
    total_expected: float
    base_collections: float
    collection_efficiency: float
    total_overdue_collected: float
    full_payoff_amount: float
    full_payoff_count: int
    excess_payment_amount: float
    excess_payment_count: int
    status_counts: Dict[str, int]
    total_transactions: int
    products: List[ProductCollectionRow]
    repayments: List[RepaymentLogRow]


# --- PORTFOLIO & OFFICER PERFORMANCE ---

class OfficerPerformanceRow(BaseModel):
    client_id: str
    client_name: str
    phone: str
    group: str
    product: str
    active_credit: float
    loan_repay: float
    paid_to_loan: float
    loan_balance: float
    savings: float
    overdue: float
    status: str


class PortfolioPerformanceResponse(BaseModel):
    active_loans: int
    total_portfolio: float
    par_percentage: float
    officers_list: List[str]
    officer_records: List[OfficerPerformanceRow]
    risk_distribution: Dict[str, int]


# --- AREA BRANCH COMPARISON (AM EXCLUSIVE) ---

class AreaBranchRow(BaseModel):
    branch: str
    people_on_loan: int
    active_loans: int
    active_savers: int
    total_savings: float
    collections_received: float
    expected_collections: float
    collection_efficiency: float
    outstanding_portfolio: float
    par_percentage: float
    status: str


class AreaComparisonResponse(BaseModel):
    total_branches: int
    total_people_on_loan: int
    total_active_loans: int
    total_active_savers: int
    total_area_collections: float
    total_area_expected: float
    overall_efficiency: float
    total_area_savings: float
    total_area_portfolio: float
    overall_par: float
    rows: List[AreaBranchRow]
