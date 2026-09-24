"""
BM Dashboard schemas.
Codifies response and action models for Branch Manager Dashboard and Branch Approvals Hub.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class BranchSummary(BaseModel):
    active_clients: int
    active_loans: int
    active_savings: float
    collection_today: float
    par: str


class BranchCashPosition(BaseModel):
    opening_balance: float
    cash_in: float
    cash_out: float
    bank_deposit: float = 0.0
    bank_withdrawal: float = 0.0
    closing_balance: float
    status: str
    difference: float


class OfficerCollectionStatusItem(BaseModel):
    officer: str
    officer_name: str
    groups_scheduled: int
    scheduled_groups: str
    expected: float
    collected: float
    outstanding: float
    compliance_pct: float = Field(..., alias="compliance_pct")
    closing_balance: float
    status: str

    class Config:
        populate_by_name = True


class PendingLoanApprovalItem(BaseModel):
    loan_id: str
    client_name: str
    client_code: str
    officer: str
    loan_product: str
    loan_amount: float
    disbursement_date: Optional[str] = None


class PendingWithdrawalApprovalItem(BaseModel):
    id: str
    client_id: Optional[str] = None
    client_name: str
    group_name: Optional[str] = None
    savings_type: str
    operation_type: str
    amount: float
    requested_by: str
    reference: Optional[str] = None
    remarks: Optional[str] = None
    operational_date: Optional[str] = None
    created_at: Optional[str] = None


class PendingCorrectionApprovalItem(BaseModel):
    id: str
    record_id: str
    record_type: str
    reason: str
    requested_by: str
    created_at: Optional[str] = None


class BmDashboardResponse(BaseModel):
    branch_name: str
    business_date: str
    meeting_day: str
    is_closed: bool = False
    closure_reason: Optional[str] = ""
    branch_summary: BranchSummary
    branch_cash_position: BranchCashPosition
    officer_collection_status: List[OfficerCollectionStatusItem]
    pending_loans: List[PendingLoanApprovalItem]
    pending_withdrawals: List[PendingWithdrawalApprovalItem]
    pending_corrections: List[PendingCorrectionApprovalItem]


# Action Request / Response Schemas
class ApproveLoanRequest(BaseModel):
    loan_id: str
    disbursement_date: str  # YYYY-MM-DD


class RejectLoanRequest(BaseModel):
    loan_id: str
    reason: Optional[str] = "Rejected by BM"


class BatchApproveLoansRequest(BaseModel):
    loan_ids: List[str]
    default_disbursement_date: str
    loan_dates_map: Optional[Dict[str, str]] = None


class ApproveWithdrawalRequest(BaseModel):
    withdrawal_id: str
    operational_date: str  # YYYY-MM-DD


class RejectWithdrawalRequest(BaseModel):
    withdrawal_id: str
    reason: Optional[str] = "Rejected by BM"


class BatchApproveWithdrawalsRequest(BaseModel):
    withdrawal_ids: List[str]
    default_operational_date: str
    withdrawal_dates_map: Optional[Dict[str, str]] = None


class ApproveCorrectionRequest(BaseModel):
    correction_id: str


class RejectCorrectionRequest(BaseModel):
    correction_id: str
    reason: Optional[str] = "Rejected by BM"


class BatchApproveCorrectionsRequest(BaseModel):
    correction_ids: List[str]


class ActionResponse(BaseModel):
    success: bool
    message: str
    details: Optional[Dict[str, Any]] = None
