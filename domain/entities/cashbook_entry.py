from dataclasses import dataclass
from typing import Optional
from datetime import date

@dataclass
class CashbookEntry:
    id: Optional[int]
    date: date
    branch: str
    opening_balance: float = 0.0
    rep_daily: float = 0.0
    rep_12_weeks: float = 0.0
    rep_24_weeks: float = 0.0
    rep_monthly: float = 0.0
    savings_deposit: float = 0.0
    laps_reserve: float = 0.0
    funds_received_ho: float = 0.0
    funds_received_other_branch: float = 0.0
    loan_received_asset: float = 0.0
    loan_received_finance: float = 0.0
    daily_11_pct: float = 0.0
    weekly_11_pct: float = 0.0
    savings_adj_no: float = 0.0
    savings_adj_amount: float = 0.0
    risk_premium_returns: float = 0.0
    passbook: float = 0.0
    app_fee: float = 0.0
    asset_credit_sales: float = 0.0
    cash_and_carry: float = 0.0
    contingency: float = 0.0
    credit_form: float = 0.0
    credit_form_damage: float = 0.0
    bonus: float = 0.0
    misc_fees: float = 0.0
    fund_transferred_other_branch: float = 0.0
    fund_transferred_ho: float = 0.0
    fund_to_other_area: float = 0.0
    fund_to_asset_program: float = 0.0
    fund_to_product_finance: float = 0.0
    savings_withdrawal: float = 0.0
    staff_salaries: float = 0.0
    office_expenses: float = 0.0
    laps_returns: float = 0.0
    bank_deposit: float = 0.0
    bank_withdrawal: float = 0.0
    product_withdrawal: float = 0.0
    total_inflows: float = 0.0
    total_outflows: float = 0.0
    closing_balance: float = 0.0
    adjustment_in: float = 0.0
    adjustment_out: float = 0.0
    adjustment_reason: str = ""
