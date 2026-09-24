"""
Master Cashbook Pydantic Schemas.
Faithfully mirrors Streamlit app.py L11187-12191 and official Excel Credit_Cash_Book_Ledger.xlsx (Columns A-AS).
"""
from typing import List, Optional, Dict, Any
from pydantic import BaseModel


class MasterCashbookInflows(BaseModel):
    opening_balance: float = 0.0
    savings_deposit: float = 0.0
    rep_daily: float = 0.0
    rep_120_days: float = 0.0
    rep_12_weeks: float = 0.0
    rep_24_weeks: float = 0.0
    rep_monthly: float = 0.0
    laps_reserve: float = 0.0
    funds_received_ho: float = 0.0
    funds_received_other_branch: float = 0.0
    funds_received_other_area: float = 0.0
    asset_credit_sales: float = 0.0
    cash_and_carry: float = 0.0
    loan_received_finance: float = 0.0
    daily_11_pct: float = 0.0
    daily_20_pct: float = 0.0
    weekly_11_pct: float = 0.0
    weekly_20_pct: float = 0.0
    risk_premium_returns: float = 0.0
    contingency: float = 0.0
    credit_form_damage: float = 0.0
    bonus: float = 0.0
    app_fee: float = 0.0
    passbook: float = 0.0
    bank_withdrawal: float = 0.0
    adjustment_in: float = 0.0


class MasterCashbookOutflows(BaseModel):
    disb_60d: float = 0.0
    disb_120d: float = 0.0
    disb_12w: float = 0.0
    disb_24w: float = 0.0
    disb_mth: float = 0.0
    fund_transferred_other_branch: float = 0.0
    fund_transferred_ho: float = 0.0
    fund_to_other_area: float = 0.0
    fund_to_asset_program: float = 0.0
    fund_to_product_finance: float = 0.0
    product_withdrawal: float = 0.0
    savings_withdrawal: float = 0.0
    staff_salaries: float = 0.0
    office_expenses: float = 0.0
    laps_returns: float = 0.0
    bank_deposit: float = 0.0
    adjustment_out: float = 0.0


class TallyNotPaidClient(BaseModel):
    name: str
    code: str
    expected: float = 0.0
    shortfall: float = 0.0
    is_partial: bool = False


class BranchReconciliationTally(BaseModel):
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


class PendingReversalItem(BaseModel):
    id: str
    record_id: str
    record_type: str
    reason: str
    requested_by: str
    requested_by_name: str
    created_at: str
    status: str


class TreasuryTransactionOption(BaseModel):
    id: str
    transaction_type: str
    amount: float
    posting_date: str
    remarks: str
    label: str


class MasterCashbookDailyResponse(BaseModel):
    date: str
    branch: str
    is_open: bool
    open_reason: str = "Working Day"
    inflows: MasterCashbookInflows
    outflows: MasterCashbookOutflows
    total_inflows: float
    total_outflows: float
    closing_balance: float
    tally: Optional[BranchReconciliationTally] = None
    pending_reversals: List[PendingReversalItem] = []
    treasury_transactions: List[TreasuryTransactionOption] = []
    adjustment_reason: Optional[str] = None


class MasterCashbookManualInputsRequest(BaseModel):
    date: str
    funds_received_ho: float = 0.0
    funds_received_other_branch: float = 0.0
    funds_received_other_area: float = 0.0
    fund_transferred_other_branch: float = 0.0
    fund_transferred_ho: float = 0.0
    fund_to_other_area: float = 0.0
    staff_salaries: float = 0.0
    adjustment_in: float = 0.0
    adjustment_out: float = 0.0
    adjustment_reason: Optional[str] = None


class OfficerOption(BaseModel):
    username: str
    full_name: str
    display: str


class CoAggregationResponse(BaseModel):
    date: str
    branch: str
    officer: str
    officers: List[OfficerOption] = []
    opening_balance: float = 0.0
    inflows: Dict[str, float] = {}
    outflows: Dict[str, float] = {}
    total_inflows: float = 0.0
    total_outflows: float = 0.0
    closing_balance: float = 0.0
    is_open: bool = True
    open_reason: str = "Working Day"
    can_close_day: bool = True


class EodCloseRequest(BaseModel):
    date: str


class MonthlyLedgerRow(BaseModel):
    date: str
    opening_balance: float = 0.0
    savings_deposit: float = 0.0
    rep_daily: float = 0.0
    rep_120_days: float = 0.0
    rep_12_weeks: float = 0.0
    rep_24_weeks: float = 0.0
    rep_monthly: float = 0.0
    laps_reserve: float = 0.0
    funds_received_ho: float = 0.0
    funds_received_other_branch: float = 0.0
    funds_received_other_area: float = 0.0
    asset_credit_sales: float = 0.0
    cash_and_carry: float = 0.0
    loan_received_finance: float = 0.0
    daily_11_pct: float = 0.0
    daily_20_pct: float = 0.0
    weekly_11_pct: float = 0.0
    weekly_20_pct: float = 0.0
    risk_premium_returns: float = 0.0
    contingency: float = 0.0
    credit_form_damage: float = 0.0
    bonus: float = 0.0
    app_fee: float = 0.0
    passbook: float = 0.0
    bank_withdrawal: float = 0.0
    adjustment_in: float = 0.0
    total_inflows: float = 0.0
    disb_60d: float = 0.0
    disb_120d: float = 0.0
    disb_12w: float = 0.0
    disb_24w: float = 0.0
    disb_mth: float = 0.0
    fund_transferred_other_branch: float = 0.0
    fund_transferred_ho: float = 0.0
    fund_to_other_area: float = 0.0
    fund_to_asset_program: float = 0.0
    fund_to_product_finance: float = 0.0
    product_withdrawal: float = 0.0
    staff_salaries: float = 0.0
    office_expenses: float = 0.0
    laps_returns: float = 0.0
    bank_deposit: float = 0.0
    adjustment_out: float = 0.0
    total_outflows: float = 0.0
    closing_balance: float = 0.0


class MonthlyLedgerResponse(BaseModel):
    month: int
    year: int
    branch: str
    rows: List[MonthlyLedgerRow] = []
    month_opening: float = 0.0
    total_month_inflows: float = 0.0
    total_month_outflows: float = 0.0
    month_closing: float = 0.0
    available_branches: List[str] = []


class ReversalActionRequest(BaseModel):
    request_id: str


class TreasuryReversalRequestInput(BaseModel):
    transaction_id: str
    reason: str
