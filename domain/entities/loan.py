from dataclasses import dataclass
from typing import Optional
from datetime import date, datetime

@dataclass
class Loan:
    id: str
    client_id: str
    client_name: str
    product_type: str
    amount: float
    duration: int
    frequency: str
    gap_fee: float
    expected_installment: float
    total_payable: float
    status: str
    branch: str
    credit_officer: str
    start_date: Optional[date]
    end_date: Optional[date]
    created_at: Optional[datetime]
    group_name: Optional[str]
    is_asset: bool
