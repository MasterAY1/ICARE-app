"""
CO Dashboard schemas directly matching DashboardService.get_co_dashboard_data.
"""
from typing import List, Dict, Any, Optional
from pydantic import BaseModel, ConfigDict, Field


class WelcomeInfo(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    officer_name: str = Field(..., alias="officer_name")
    branch_name: str = Field(..., alias="branch_name")
    date_str: str = Field(..., alias="date_str")
    meeting_day: str = Field(..., alias="meeting_day")
    time_str: str = Field(..., alias="time_str")


class BranchClosureInfo(BaseModel):
    is_closed: bool
    reason: Optional[str] = None


class RepaymentSummary(BaseModel):
    rep_12_weeks_amt: float = 0.0
    rep_12_weeks_clients: int = 0
    rep_24_weeks_amt: float = 0.0
    rep_24_weeks_clients: int = 0
    rep_daily_amt: float = 0.0
    rep_daily_clients: int = 0
    rep_monthly_amt: float = 0.0
    rep_monthly_clients: int = 0
    total_collected_today: float = 0.0


class SavingsSummary(BaseModel):
    deposited_amt: float = 0.0
    deposited_clients: int = 0
    withdrawn_amt: float = 0.0
    withdrawn_clients: int = 0
    net_savings: float = 0.0


class PaymentStatusBucket(BaseModel):
    count: int = 0
    amount: float = 0.0


class RepaymentStatus(BaseModel):
    full_payment: PaymentStatusBucket = Field(default_factory=PaymentStatusBucket)
    part_payment: PaymentStatusBucket = Field(default_factory=PaymentStatusBucket)
    excess_payment: PaymentStatusBucket = Field(default_factory=PaymentStatusBucket)
    not_paid: PaymentStatusBucket = Field(default_factory=PaymentStatusBucket)


class CashPosition(BaseModel):
    opening_balance: float = 0.0
    cash_in: float = 0.0
    cash_out: float = 0.0
    closing_balance: float = 0.0
    status: str = "Balanced"
    difference: float = 0.0


class CoDashboardResponse(BaseModel):
    welcome: WelcomeInfo
    branch_closure: BranchClosureInfo
    repayment_summary: RepaymentSummary
    meeting_portfolio: List[Dict[str, Any]] = Field(default_factory=list)
    savings: SavingsSummary
    repayment_status: RepaymentStatus
    cash_position: CashPosition
    attention_list: List[Dict[str, Any]] = Field(default_factory=list)
