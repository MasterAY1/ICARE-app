"""
CO Cashbook schemas.
"""
from typing import List, Optional, Dict, Any
from pydantic import BaseModel


class CashbookInflows(BaseModel):
    opening_balance: float = 0.0
    savings_deposit: float = 0.0
    laps_reserve: float = 0.0
    rep_daily: float = 0.0
    rep_12_weeks: float = 0.0
    rep_24_weeks: float = 0.0
    rep_monthly: float = 0.0
    daily_11_pct: float = 0.0
    weekly_11_pct: float = 0.0
    weekly_20_pct: float = 0.0
    risk_premium_returns: float = 0.0
    contingency: float = 0.0
    app_fee: float = 0.0
    credit_form_damage: float = 0.0
    passbook: float = 0.0
    bonus: float = 0.0
    cash_and_carry: float = 0.0
    asset_credit_sales: float = 0.0
    bank_withdrawal: float = 0.0


class CashbookOutflows(BaseModel):
    active_loan_daily: float = 0.0
    active_loan_12w: float = 0.0
    active_loan_24w: float = 0.0
    active_loan_monthly: float = 0.0
    product_withdrawal: float = 0.0
    office_expenses: float = 0.0
    bank_deposit: float = 0.0
    laps_returns: float = 0.0


class TallyNotPaidClient(BaseModel):
    name: str
    code: str
    expected: float
    shortfall: float
    is_partial: bool = False


class CollectionArrearsTally(BaseModel):
    scheduled_expected: float = 0.0
    not_paid_amount: float = 0.0
    not_paid_count: int = 0
    not_paid_clients: List[TallyNotPaidClient] = []
    excess_amount: float = 0.0
    excess_count: int = 0
    actual_repayments: float = 0.0
    actual_savings: float = 0.0
    actual_cash_collected: float = 0.0
    bank_deposited: float = 0.0
    closing_cash_balance: float = 0.0
    is_cash_balanced: bool = True
    arrears_float: float = 0.0
    total_reps_count: int = 0


class OfficerOption(BaseModel):
    username: str
    full_name: str
    display: str


class ReversalOption(BaseModel):
    label: str
    record_type: str
    record_id: str


class SubmittedReversalRequest(BaseModel):
    date: str
    record_type: str
    record_id: str
    reason: str
    status: str
    approved_by: Optional[str] = None


class CoCashbookResponse(BaseModel):
    date: str
    branch: str
    officer: str
    is_open: bool
    open_reason: str = "Working Day"
    inflows: CashbookInflows
    outflows: CashbookOutflows
    total_inflows: float
    total_outflows: float
    closing_balance: float
    tally: Optional[CollectionArrearsTally] = None
    officers: List[OfficerOption] = []
    can_select_officer: bool = False
    reversal_options: List[ReversalOption] = []
    submitted_reversals: List[SubmittedReversalRequest] = []
    active_loan_breakdown: Optional[Dict[str, float]] = None
