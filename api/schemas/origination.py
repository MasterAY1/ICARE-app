"""
Loan Origination and Client Registration schemas.
"""
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field


class GuarantorInput(BaseModel):
    full_name: str = Field(..., min_length=1)
    nickname: Optional[str] = None
    phone: str = Field(..., min_length=1)
    address: str = Field(..., min_length=1)
    occupation: str = Field("Trader")
    relationship: str = Field(..., min_length=1)
    office_address: Optional[str] = None
    marital_status: Optional[str] = "Married"
    id_means: Optional[str] = "National ID (NIN)"
    id_number: Optional[str] = None


class RegisterClientInput(BaseModel):
    full_name: str = Field(..., min_length=1)
    nickname: Optional[str] = None
    phone: str = Field(..., min_length=1)
    address: str = Field(..., min_length=1)
    marital_status: str = "Single"
    business_type: str = "Trader"
    business_address: Optional[str] = None
    daily_income: float = 0.0
    other_obligations: Optional[str] = None
    id_means: str = "National ID (NIN)"
    id_number: str = Field(..., min_length=1)
    group_id: Optional[str] = None
    group_name: Optional[str] = None
    guarantor: GuarantorInput


class RegisterClientResponse(BaseModel):
    success: bool
    client_id: str
    client_code: str
    message: str


class ApplyLoanInput(BaseModel):
    client_id: str = Field(..., min_length=1)
    product_category: str = Field("Finance", description="Finance or Asset")
    product_name: str = Field("Daily 60 Days")
    requested_amount: float = Field(..., gt=0)
    cash_downpayment: float = 0.0
    savings_downpayment: float = 0.0
    gap_fee: float = 0.0
    notes: Optional[str] = ""


class ApplyLoanResponse(BaseModel):
    success: bool
    loan_id: str
    active_credit: float
    expected_installment: float
    status: str
    message: str
