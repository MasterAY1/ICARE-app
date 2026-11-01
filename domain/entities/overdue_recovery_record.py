"""
LoanOverdueRecoveryRecord Domain Entity
Governance: BR-DASH-004, BR-DASH-005, Invariants 8 & 9
Represents an authoritative record of an overdue arrears recovery event.
"""
from dataclasses import dataclass
from typing import Optional
from datetime import date, datetime
from uuid import uuid4


@dataclass
class LoanOverdueRecoveryRecord:
    id: Optional[str] = None
    repayment_id: Optional[str] = None
    loan_id: str = ""
    client_id: str = ""
    officer_id: Optional[str] = None
    branch_id: Optional[str] = None
    recovery_date: Optional[date] = None
    recovery_timestamp: Optional[datetime] = None
    recovered_amount: float = 0.0
    overdue_before: float = 0.0
    overdue_after: float = 0.0
    total_repayment_amount: float = 0.0
    recovery_type: str = "PARTIAL_RECOVERY"  # 'FULL_RECOVERY' or 'PARTIAL_RECOVERY'
    notes: Optional[str] = None
    created_at: Optional[datetime] = None

    def __post_init__(self):
        if not self.id:
            self.id = str(uuid4())
        if not self.recovery_date:
            self.recovery_date = date.today()
        if not self.recovery_timestamp:
            self.recovery_timestamp = datetime.now()
