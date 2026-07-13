from dataclasses import dataclass, field
from typing import Optional
from datetime import date, datetime

@dataclass
class Repayment:
    id: str
    loan_id: str
    client_id: str
    amount_paid: float
    savings_amount: float
    loan_repayment_amount: float
    withdrawal_amount: float
    others_amount: float
    recovery_amount: float
    initial_payment: float
    payment_date: Optional[date]
    transaction_type: str
    branch: str
    credit_officer: str
    note: Optional[str] = ""
    created_at: Optional[datetime] = None
    extra_fields: dict = field(default_factory=dict)
