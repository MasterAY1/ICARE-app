"""
api/schemas/am_dashboard.py
Pydantic Schemas for Area Manager Dashboard, Regional Supervision, and Governance Hub.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class RegionalSummary(BaseModel):
    area_name: str = "Area 1"
    business_date: str
    branches_count: int
    open_branches_count: int
    active_clients: int
    active_credit: float
    outstanding_portfolio: float
    total_savings: float
    today_expected: float
    today_collected: float
    compliance_pct: float
    vault_cash_acct_1000: float
    par: str
    defaulters_count: int
    assigned_branches: List[str]


class BranchPerformanceItem(BaseModel):
    branch_id: str
    branch_name: str
    bm_name: str
    is_closed: bool
    closure_reason: Optional[str] = None
    expected_collection: float
    collected: float
    outstanding_today: float
    compliance_pct: float
    vault_cash_acct_1000: float
    par: str
    defaulters_count: int
    cash_variance: float
    eod_status: str
    operational_status: str


class PendingHighValueLoanItem(BaseModel):
    loan_id: str
    branch_id: str
    branch_name: str
    client_id: str
    client_name: str
    client_code: str
    officer: str
    loan_product: str
    loan_amount: float
    application_date: str
    escalation_reason: str


class PendingBranchTransferItem(BaseModel):
    transfer_id: str
    client_id: str
    client_name: str
    client_code: str
    source_branch_id: str
    source_branch_name: str
    dest_branch_id: str
    dest_branch_name: str
    outstanding_balance: float
    savings_balance: float
    reason: str
    requested_at: str


class PendingBranchEodItem(BaseModel):
    branch_id: str
    branch_name: str
    closure_date: str
    master_cashbook_status: str
    cash_variance: float
    vault_cash: float
    is_confirmed: bool
    status: str
    confirmed_by: Optional[str] = None
    confirmed_at: Optional[str] = None
    notes: Optional[str] = None


class AreaApprovalsHub(BaseModel):
    pending_high_value_loans: List[PendingHighValueLoanItem] = []
    pending_branch_transfers: List[PendingBranchTransferItem] = []
    pending_branch_eods: List[PendingBranchEodItem] = []
    can_lock_area: bool = False


class AvailableHandoverReport(BaseModel):
    title: str
    format: str
    report_type: str
    description: str
    is_ready: bool


class BranchHandoverSummary(BaseModel):
    branch_id: str
    branch_name: str
    bm_name: str
    target_date: str
    is_cashbook_closed: bool
    cash_variance: float
    available_reports: List[AvailableHandoverReport]


class AmDashboardResponse(BaseModel):
    regional_summary: RegionalSummary
    branch_performance: List[BranchPerformanceItem]
    approvals_hub: AreaApprovalsHub


class ConfirmBranchEodRequest(BaseModel):
    branch_id: str
    closure_date: str
    notes: Optional[str] = None


class RejectBranchEodRequest(BaseModel):
    branch_id: str
    closure_date: str
    reason: str


class ConfirmAreaClosureRequest(BaseModel):
    area_name: str = "Area 1"
    closure_date: str


class ApproveLoanRequest(BaseModel):
    loan_id: str
    disbursement_date: str


class RejectLoanRequest(BaseModel):
    loan_id: str
    reason: Optional[str] = "Rejected by Area Manager"


class SignOffTransferRequest(BaseModel):
    transfer_id: str
    notes: Optional[str] = None


class RejectTransferRequest(BaseModel):
    transfer_id: str
    reason: str


class AmActionResponse(BaseModel):
    success: bool
    message: str
    details: Optional[Dict[str, Any]] = None
