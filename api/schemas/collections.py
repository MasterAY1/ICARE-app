"""
Collections schemas for Phase 2 1:1 Parity.
"""
from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field


class CollectionSheetMember(BaseModel):
    client_id: str
    client_code: str
    client_name: str
    loan_id: Optional[str] = None
    loan_product: str
    active_credit: float
    remaining_balance: float
    expected_repayment: float
    savings_balance: float
    is_asset: bool = False
    has_overdue: bool = False
    overdue_arrears: float = 0.0
    current_installment: float = 0.0
    is_future_loan: bool = False
    start_date: Optional[str] = None
    prev_rep: Optional[float] = None
    prev_dep: Optional[float] = None
    prev_status: Optional[str] = None


class CollectionSheetResponse(BaseModel):
    group_name: str
    date: str
    meeting_day: str
    is_open: bool
    open_reason: str
    group_savings_balance: float = 0.0
    available_groups: List[str] = []
    members: List[CollectionSheetMember] = []


# Single Client Quick Entry Models
class SingleClientLoanOption(BaseModel):
    loan_id: str
    label: str
    product: str
    active_credit: float
    remaining_balance: float
    expected_repayment: float


class SingleClientOption(BaseModel):
    client_id: str
    client_code: str
    client_name: str
    group_id: Optional[str] = None
    group_name: str
    raw_group_name: Optional[str] = None
    is_in_group: bool
    personal_savings_balance: float
    group_savings_balance: float
    loans: List[SingleClientLoanOption] = []


class SingleClientOptionsResponse(BaseModel):
    clients: List[SingleClientOption] = []


class SingleClientSubmitInput(BaseModel):
    client_id: str = Field(..., min_length=1)
    client_code: Optional[str] = None
    client_name: str = Field(..., min_length=1)
    group_name: Optional[str] = None
    group_id: Optional[str] = None
    loan_id: Optional[str] = None
    loan_product: Optional[str] = "Loan"
    savings_deposit: float = 0.0
    group_savings_deposit: float = 0.0
    loan_repayment: float = 0.0
    app_fee: float = 0.0
    passbook_fee: float = 0.0
    misc_fee: float = 0.0
    note: Optional[str] = "Single Client Collection"
    date: Optional[str] = None


class SingleClientSubmitResponse(BaseModel):
    success: bool
    receipt: Optional[Dict[str, Any]] = None
    message: str


# Collection History & Audit Models
class GroupSummaryRow(BaseModel):
    group_name: str
    total_repayment: float
    member_savings: float
    group_savings: float
    total_savings: float
    grand_total: float
    paying_members_count: int
    details: List[Dict[str, Any]] = []
    items: List[Dict[str, Any]] = []


class RepaymentHistoryRow(BaseModel):
    time: str
    officer: str
    client_name: str
    client_code: str
    product: str
    expected_amount: float
    amount_paid: float
    status: str
    note: str
    ref_id: str


class SavingsHistoryRow(BaseModel):
    time: str
    officer: str
    client_name: str
    client_code: str
    deposit_amount: float
    remarks: str
    ref_id: str


class ReversedAuditRow(BaseModel):
    type: str
    client: str
    amount: float
    status: str
    ref_id: str
    reason: str


class EodSummaryData(BaseModel):
    opening_cash: float = 0.0
    bank_deposit: float = 0.0
    office_expenses: float = 0.0
    app_fee: float = 0.0
    passbook: float = 0.0
    misc_fees: float = 0.0
    form_damage: float = 0.0
    bonus: float = 0.0


class CollectionsHistoryResponse(BaseModel):
    date: str
    total_repayments: float
    paid_repayments_count: int
    not_paid_repayments_count: int
    total_savings: float
    savings_deposits_count: int
    grand_total_cash: float
    groups: List[GroupSummaryRow] = []
    repayments: List[RepaymentHistoryRow] = []
    savings: List[SavingsHistoryRow] = []
    reversed_records: List[ReversedAuditRow] = []
    eod_summary: Optional[EodSummaryData] = None
    eod_log: List[Dict[str, Any]] = []
    available_officers: List[str] = []


# Error Correction & Reversals Hub Models
class ReversalCandidateItem(BaseModel):
    ref_id: str
    client_name: str
    client_code: str
    amount: float
    date: str
    category: str
    note: str
    label: str


class ReversalCandidatesResponse(BaseModel):
    category: str
    items: List[ReversalCandidateItem] = []


class SubmittedReversalItem(BaseModel):
    request_id: str
    date: str
    record_type: str
    record_ref: str
    reason: str
    status: str
    approved_by: Optional[str] = None


class SubmittedReversalsResponse(BaseModel):
    requests: List[SubmittedReversalItem] = []

