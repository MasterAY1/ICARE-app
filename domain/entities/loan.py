from dataclasses import dataclass, field
from typing import Optional
from datetime import date, datetime
from domain.enums import LoanStatus, ClientStatus, SavingsStatus

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
    status: LoanStatus
    branch: str
    credit_officer: str
    client_status: ClientStatus = field(default=ClientStatus.ACTIVE)
    savings_status: SavingsStatus = field(default=SavingsStatus.NORMAL)
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    created_at: Optional[datetime] = None
    group_name: Optional[str] = None
    is_asset: bool = False
    officer_id: Optional[str] = None
    branch_id: Optional[str] = None
    extra_fields: dict = field(default_factory=dict)
