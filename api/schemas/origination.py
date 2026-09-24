"""
Loan Origination and Client Registration schemas.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class GroupOption(BaseModel):
    group_id: str
    name: str
    group_number: str
    meeting_day: str
    display_label: str


class ClientSearchItem(BaseModel):
    client_id: str
    client_code: str
    name: str
    group_name: Optional[str] = "Individual (No Group)"
    officer_name: Optional[str] = "Unknown"
    savings_balance: float = 0.0


class GuarantorDetails(BaseModel):
    full_name: str
    nickname: Optional[str] = None
    phone: str
    address: Optional[str] = None
    marital_status: Optional[str] = "Married"
    occupation: Optional[str] = "Trader"
    relationship: Optional[str] = None
    office_address: Optional[str] = None
    id_means: Optional[str] = "National ID (NIN)"
    id_number: Optional[str] = None
    id_card_url: Optional[str] = None
    passport_url: Optional[str] = None


class ClientProfileDetails(BaseModel):
    client_id: str
    client_code: str
    name: str
    nickname: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    marital_status: str = "Single"
    business_type: str = "Trader"
    business_address: Optional[str] = None
    average_monthly_income: float = 0.0
    other_obligations: Optional[str] = None
    id_means: str = "National ID (NIN)"
    id_number: Optional[str] = None
    id_card_url: Optional[str] = None
    passport_url: Optional[str] = None
    branch_name: str = "Unknown"
    group_name: str = "Individual (No Group)"
    officer_name: str = "Unknown"
    savings_balance: float = 0.0
    guarantor: Optional[GuarantorDetails] = None


class GuarantorInput(BaseModel):
    full_name: Optional[str] = None
    nickname: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    occupation: Optional[str] = "Trader"
    relationship: Optional[str] = None
    office_address: Optional[str] = None
    marital_status: Optional[str] = "Single"
    id_means: Optional[str] = "National ID (NIN)"
    id_number: Optional[str] = None


class RegisterClientInput(BaseModel):
    full_name: str = Field(..., min_length=1)
    nickname: Optional[str] = None
    phone: str = Field(..., min_length=1)
    address: Optional[str] = ""
    marital_status: str = "Single"
    business_type: str = "Trader"
    business_address: Optional[str] = None
    average_monthly_income: float = 0.0
    other_obligations: Optional[str] = None
    id_means: str = "National ID (NIN)"
    id_number: Optional[str] = None
    id_card_url: Optional[str] = None
    passport_url: Optional[str] = None
    guarantor_id_card_url: Optional[str] = None
    guarantor_passport_url: Optional[str] = None
    group_mode: str = "Individual (No Group)"  # "Individual (No Group)", "+ Create New Group", or existing group name/label
    group_id: Optional[str] = None
    new_group_name: Optional[str] = None
    new_group_number: Optional[str] = None
    new_group_meeting_day: Optional[str] = "Daily"
    registration_date: Optional[str] = None
    guarantor: Optional[GuarantorInput] = None



class RegisterClientResponse(BaseModel):
    success: bool
    client_id: str
    client_code: str
    message: str


class EligibilityCheckRequest(BaseModel):
    client_id: str = Field(..., min_length=1)
    requested_amount: float = Field(..., gt=0)
    product_type: str = Field("Weekly 12W")
    product_category: str = Field("Finance")


class EligibilityCheckResponse(BaseModel):
    is_eligible: bool
    reasons: List[str]
    warnings: List[str]


class ApplyLoanInput(BaseModel):
    client_id: str = Field(..., min_length=1)
    product_category: str = Field("Finance", description="Finance or Asset")
    product_type: str = Field("Weekly 12W")
    requested_amount: float = Field(..., gt=0)
    downpayment_mode: Optional[str] = "Cash (Physical Payment)"
    cash_downpayment: float = 0.0
    savings_downpayment: float = 0.0
    gap_fee: float = 0.0
    application_date: Optional[str] = None
    notes: Optional[str] = ""


class ApplyLoanResponse(BaseModel):
    success: bool
    loan_id: str
    active_credit: float
    expected_installment: float
    status: str
    message: str


class PendingLoanItem(BaseModel):
    loan_id: str
    client_id: str
    client_name: str
    group_name: str
    date: Optional[str] = None
    credit_officer: str
    loan_amount: float
    loan_product: str


class PendingDisbursementsResponse(BaseModel):
    pending_loans: List[PendingLoanItem]
    can_authorize: bool


class DisburseLoanRequest(BaseModel):
    loan_id: str
    disbursement_date: str  # YYYY-MM-DD


class DisburseLoanResponse(BaseModel):
    success: bool
    message: str
    schedule_adjusted: bool = False
    final_start_date: Optional[str] = None
    shift_reason: Optional[str] = None


class UpdateClientGuarantorInput(BaseModel):
    name: str = Field(..., min_length=1)
    phone: Optional[str] = None
    address: Optional[str] = None
    marital_status: str = "Married"
    business_type: Optional[str] = "Trader"
    average_monthly_income: float = 0.0
    other_obligations: Optional[str] = None
    id_means: str = "National ID (NIN)"
    id_number: Optional[str] = None
    guarantor_name: Optional[str] = None
    guarantor_phone: Optional[str] = None
    guarantor_address: Optional[str] = None
    guarantor_marital_status: Optional[str] = "Married"
    guarantor_occupation: Optional[str] = None
    guarantor_relationship: Optional[str] = None
    guarantor_office_address: Optional[str] = None
    guarantor_id_means: Optional[str] = "None"
    guarantor_id_number: Optional[str] = None


class UpdateClientGuarantorResponse(BaseModel):
    success: bool
    message: str
