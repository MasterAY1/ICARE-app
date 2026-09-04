"""
CO Cashbook schemas.
"""
from typing import Optional
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
