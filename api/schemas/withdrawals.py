"""
Withdrawal operations schemas.
Authoritative models for Phase 3 — Withdrawal Operations (app.py L7260–8801).
"""
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class EligibleLoan(BaseModel):
    loan_id: str
    active_credit: float
    is_asset: bool = False
    loan_amount: float = 0.0
    total_due: float = 0.0
    total_repaid: float = 0.0
    balance: float = 0.0
    label: str = ""
    product_name: str = ""


class ClientWithdrawalOption(BaseModel):
    client_id: str
    client_code: str
    name: str
    group_id: Optional[str] = None
    group_name: Optional[str] = None
    savings_balance: float
    eligible_loans: List[EligibleLoan] = []


class IndividualOptionsResponse(BaseModel):
    groups: List[str]
    clients: List[ClientWithdrawalOption]
    all_groups: List[Dict[str, Any]] = []


class GroupMemberOption(BaseModel):
    client_id: str
    client_code: str
    name: str
    eligible_loans: List[EligibleLoan] = []


class GroupWithdrawalOption(BaseModel):
    group_id: str
    name: str
    savings_balance: float
    members: List[GroupMemberOption] = []


class GroupOptionsResponse(BaseModel):
    groups: List[GroupWithdrawalOption]
    all_groups: List[Dict[str, Any]] = []


class MiscBalanceResponse(BaseModel):
    branch: str
    misc_balance: float
    can_withdraw: bool
    role_notice: str


class LapsOptionRecord(BaseModel):
    client_id: str
    balance: float
    remarks: str


class LapsOptionsResponse(BaseModel):
    records: List[LapsOptionRecord]


class WithdrawalRequestItem(BaseModel):
    id: str
    savings_type: str
    operation_type: str
    client_name: str
    group_name: Optional[str] = None
    amount: float
    payout_method: Optional[str] = None
    reference: str
    remarks: Optional[str] = None
    status: str
    rejection_reason: Optional[str] = None
    created_at: str


class WithdrawalRequestsResponse(BaseModel):
    requests: List[WithdrawalRequestItem]


class CreateWithdrawalRequestInput(BaseModel):
    savings_type: str = Field(..., description="Individual, Group, Misc, or LAPS")
    operation_type: str = Field(..., description="Operation type matching exact allowed options")
    client_id: Optional[str] = None
    client_name: Optional[str] = None
    group_name: Optional[str] = None
    loan_id: Optional[str] = None
    amount: float = Field(..., gt=0, description="Positive withdrawal amount")
    operational_date: Optional[str] = None
    payout_method: Optional[str] = Field("Cash", description="Cash or Bank Transfer")
    remarks: Optional[str] = Field("", description="Reason/description for withdrawal")
    auto_execute: Optional[bool] = Field(False, description="Direct BM/Admin execution")


class CreateWithdrawalRequestResponse(BaseModel):
    success: bool
    request_id: str
    reference: str
    status: str
    message: str


# ==========================================
# DAILY WITHDRAWALS TAB SCHEMAS (app.py L8460-8800)
# ==========================================

class DailyWithdrawalRecord(BaseModel):
    date: str
    client_name: str
    client_code: str
    group: str
    category: str
    amount: float
    details: str
    loan_ref: str
    reference: str


class LoanFeeDeductionRecord(BaseModel):
    date: str
    client_name: str
    client_code: str
    loan_ref: str
    interest_deducted: float
    gap_fee_deducted: float
    total_deducted: float
    status: str = "Auto-deducted on Disbursement"


class CashBankPayoutRecord(BaseModel):
    date: str
    client_name: str
    group: str
    payment_type: str
    amount: float
    approval_notes: str
    reference: str


class MyRequestStatusRecord(BaseModel):
    id: str
    client_name: str
    savings_type: str
    operation_type: str
    reference: str
    requested_by: str
    operational_date: str
    remarks: Optional[str] = None
    rejection_reason: Optional[str] = None
    approved_by: Optional[str] = None
    approved_at: Optional[str] = None
    amount: float
    status: str


class DailyWithdrawalsKpis(BaseModel):
    total_withdrawn: float
    loan_fees_deducted: float
    cash_bank_paid: float
    debt_fee_offsets: float
    waiting_for_approval_count: int
    waiting_for_approval_amount: float


class DailyWithdrawalsResponse(BaseModel):
    kpis: DailyWithdrawalsKpis
    all_records: List[DailyWithdrawalRecord] = []
    loan_fee_deductions: List[LoanFeeDeductionRecord] = []
    cash_bank_payouts: List[CashBankPayoutRecord] = []
    my_requests: List[MyRequestStatusRecord] = []


# ==========================================
# PENDING APPROVALS QUEUE (BM ONLY)
# ==========================================

class PendingApprovalItem(BaseModel):
    id: str
    client_id: Optional[str] = None
    client_name: str
    savings_type: str
    operation_type: str
    group_name: Optional[str] = None
    loan_id: Optional[str] = None
    branch_id: str
    requested_by: str
    amount: float
    operational_date: str
    reference: str
    remarks: Optional[str] = None
    payout_method: Optional[str] = "Cash"


class PendingApprovalsResponse(BaseModel):
    requests: List[PendingApprovalItem] = []


class ApproveWithdrawalInput(BaseModel):
    request_id: str
    operational_date: Optional[str] = None


class RejectWithdrawalInput(BaseModel):
    request_id: str
    rejection_reason: str


class WithdrawalActionResponse(BaseModel):
    success: bool
    message: str
