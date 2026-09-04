"""
Withdrawal operations schemas.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class EligibleLoan(BaseModel):
    loan_id: str
    active_credit: float
    is_asset: bool = False
    loan_amount: float = 0.0


class ClientWithdrawalOption(BaseModel):
    client_id: str
    client_code: str
    name: str
    group_name: Optional[str] = None
    savings_balance: float
    eligible_loans: List[EligibleLoan] = []


class IndividualOptionsResponse(BaseModel):
    groups: List[str]
    clients: List[ClientWithdrawalOption]


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
    group_name: Optional[str] = None
    loan_id: Optional[str] = None
    amount: float = Field(..., gt=0, description="Positive withdrawal amount")
    payout_method: Optional[str] = Field("Cash", description="Cash or Bank Transfer")
    remarks: Optional[str] = Field("", description="Reason/description for withdrawal")


class CreateWithdrawalRequestResponse(BaseModel):
    success: bool
    request_id: str
    reference: str
    status: str
    message: str
