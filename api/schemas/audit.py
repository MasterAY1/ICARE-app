"""
Pydantic Schemas for Phase 9: Audit Ledger & Audit Center.
Covers 6-Way Integrity Verification, Virtual Audit Ledgers, 15 Exception Reports,
360° Universal Explorer, Performance Insights, and Reconciliation Wizard.
"""
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field


class BranchOption(BaseModel):
    branch_id: str
    name: str
    code: Optional[str] = None


class OfficerOption(BaseModel):
    id: str
    username: str
    full_name: str
    display_name: str
    role: Optional[str] = None


class ProductOption(BaseModel):
    product_id: str
    name: str
    code: Optional[str] = None


class AuditMetaResponse(BaseModel):
    branches: List[BranchOption]
    officers: List[OfficerOption]
    products: List[ProductOption]


class VarianceItem(BaseModel):
    source: str
    expected: float
    actual: float
    variance: float
    cause: str


class Integrity6WayResponse(BaseModel):
    branch_id: str
    posting_date: str
    is_balanced: bool
    status_text: str
    status_badge: str  # Institutional status description (e.g. "PERFECT_MATCH", "MISMATCH")
    ledger_total: float
    audit_views_total: float
    co_cashbooks_total: float
    master_cashbook_total: float
    dashboard_total: float
    reports_total: float
    variances: List[VarianceItem] = Field(default_factory=list)


class AuditSummaryMetrics(BaseModel):
    total_amount: float
    total_count: int
    average_amount: float
    last_transaction_date: str
    highest_amount: float


class FeeLedgerResponse(BaseModel):
    metrics: AuditSummaryMetrics
    records: List[Dict[str, Any]] = Field(default_factory=list)


class TreasuryLedgerResponse(BaseModel):
    metrics: AuditSummaryMetrics
    records: List[Dict[str, Any]] = Field(default_factory=list)


class SavingsSummaryMetrics(BaseModel):
    total_deposits: float
    total_withdrawals: float
    net_savings_movement: float
    transactions_count: int
    active_accounts_count: int


class SavingsLedgerResponse(BaseModel):
    metrics: SavingsSummaryMetrics
    records: List[Dict[str, Any]] = Field(default_factory=list)


class LoanDisbursementMetrics(BaseModel):
    total_principal_disbursed: float
    loans_disbursed: int
    average_principal: float
    borrowers_count: int
    active_portfolio: float


class LoanRepaymentMetrics(BaseModel):
    total_repayments_collected: float
    repayment_count: int
    average_repayment: float
    active_paying_clients: int


class LoanLedgerResponse(BaseModel):
    view_type: str  # "Loan Disbursements" or "Repayments"
    disbursement_metrics: Optional[LoanDisbursementMetrics] = None
    repayment_metrics: Optional[LoanRepaymentMetrics] = None
    records: List[Dict[str, Any]] = Field(default_factory=list)


class CollectionPerformanceMetrics(BaseModel):
    expected_collections: float
    actual_collections: float
    collection_variance: float
    meeting_compliance_ratio: float
    meetings_audited: int
    paid_count: int


class CollectionPerformanceResponse(BaseModel):
    metrics: CollectionPerformanceMetrics
    records: List[Dict[str, Any]] = Field(default_factory=list)


class ExceptionReportsResponse(BaseModel):
    total_exceptions: int
    exception_rules_evaluated: int
    details: Dict[str, List[Dict[str, Any]]] = Field(default_factory=dict)


class UniversalExplorerResponse(BaseModel):
    query: str
    found: bool
    loans: List[Dict[str, Any]] = Field(default_factory=list)
    repayments: List[Dict[str, Any]] = Field(default_factory=list)
    savings: List[Dict[str, Any]] = Field(default_factory=list)
    fees: List[Dict[str, Any]] = Field(default_factory=list)
    treasury_transactions: List[Dict[str, Any]] = Field(default_factory=list)
    ledger_transactions: List[Dict[str, Any]] = Field(default_factory=list)
    audit_logs: List[Dict[str, Any]] = Field(default_factory=list)


class LoanTimelineResponse(BaseModel):
    loan_id: str
    timeline: List[Dict[str, Any]] = Field(default_factory=list)


class RiskDistributionResponse(BaseModel):
    branch_id: str
    distribution: Dict[str, int] = Field(default_factory=dict)


class ReconciliationRepairRequest(BaseModel):
    branch_id: str
    reconciliation_date: str


class ReconciliationRepairResponse(BaseModel):
    rebuilt_officer_count: int
    master_cashbook_rebuilt: bool
    verification_after_repair: Integrity6WayResponse
