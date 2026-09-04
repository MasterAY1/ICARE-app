"""
Schemas for Phase 3 Atomic Financial Writes & Ledger Postings.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class BatchCollectionItem(BaseModel):
    client_id: str = Field(..., min_length=1)
    client_name: str = Field(..., min_length=1)
    loan_product: Optional[str] = "Daily 60 Days"
    loan_repayment_amount: float = 0.0
    savings_deposit_amount: float = 0.0
    savings_withdrawal_amount: float = 0.0
    app_fee: float = 0.0
    passbook_bonus: float = 0.0
    misc_fees: float = 0.0
    asset_credit_sales: float = 0.0
    cash_and_carry: float = 0.0
    credit_form_damage: float = 0.0
    bonus: float = 0.0
    mark_not_paid: bool = False
    expected_amount: float = 0.0


class BatchCollectionInput(BaseModel):
    group_name: str = Field(..., min_length=1)
    date: Optional[str] = Field(None, description="ISO Date (YYYY-MM-DD)")
    collections: List[BatchCollectionItem]
    group_savings_deposit: float = 0.0
    group_savings_withdrawal: float = 0.0


class BatchCollectionResponse(BaseModel):
    success: bool
    total_cash_in: float
    total_repayments: float
    total_savings: float
    items_processed: int
    message: str


class EodAdjustmentsInput(BaseModel):
    date: Optional[str] = Field(None, description="ISO Date (YYYY-MM-DD)")
    opening_balance: Optional[float] = 0.0
    office_expenses: Optional[float] = 0.0
    bank_deposit: Optional[float] = 0.0
    app_fee: Optional[float] = 0.0
    passbook: Optional[float] = 0.0
    misc_fee: Optional[float] = 0.0
    credit_form_damage: Optional[float] = 0.0
    bonus: Optional[float] = 0.0


class EodAdjustmentsResponse(BaseModel):
    success: bool
    date: str
    message: str
