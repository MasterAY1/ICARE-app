"""
LoanPayoffExcessRecord Domain Entity
Governance: BR-DASH-005, BR-DASH-007, GEMINI Invariant 9
Represents an authoritative record of a loan full payoff and/or excess repayment event.
"""
from dataclasses import dataclass
from typing import Optional
from datetime import date, datetime
from uuid import uuid4


@dataclass
class LoanPayoffExcessRecord:
    id: Optional[str] = None
    repayment_id: Optional[str] = None
    loan_id: str = ""
    client_id: str = ""
    officer_id: Optional[str] = None
    branch_id: Optional[str] = None
    date: Optional[date] = None
    record_type: str = "EXCESS_PAYMENT"  # 'FULL_PAYOFF', 'EXCESS_PAYMENT', 'FULL_PAYOFF_AND_EXCESS'
    amount_paid: float = 0.0
    expected_installment: float = 0.0
    active_credit_settled: float = 0.0
    excess_amount: float = 0.0
    remaining_balance_before: float = 0.0
    remaining_balance_after: float = 0.0
    notes: Optional[str] = None
    created_at: Optional[datetime] = None

    def __post_init__(self):
        if not self.id:
            self.id = str(uuid4())
        if not self.date:
            self.date = date.today()
