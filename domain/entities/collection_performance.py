from dataclasses import dataclass, field
from typing import Optional
from datetime import date, datetime
from uuid import uuid4

@dataclass
class CollectionPerformance:
    id: Optional[str] = None
    client_id: str = ""
    loan_id: str = ""
    officer_id: str = ""
    meeting_date: Optional[date] = None
    expected_amount: float = 0.0
    amount_paid: float = 0.0
    status: str = "NOT_PAID"  # Derived: PAID, PART_PAYMENT, NOT_PAID
    remarks: Optional[str] = None
    created_at: Optional[datetime] = None

    def derive_status(self) -> str:
        """Derive status from expected_amount and amount_paid."""
        if self.expected_amount <= 0:
            return "PAID"  # No amount expected
        if self.amount_paid >= self.expected_amount:
            return "PAID"
        elif self.amount_paid > 0:
            return "PART_PAYMENT"
        else:
            return "NOT_PAID"

    def __post_init__(self):
        if not self.id:
            self.id = str(uuid4())
        self.status = self.derive_status()

    @property
    def excess_amount(self) -> float:
        """Amount paid above expected."""
        return max(0.0, self.amount_paid - self.expected_amount)

    @property
    def shortfall_amount(self) -> float:
        """Amount below expected."""
        return max(0.0, self.expected_amount - self.amount_paid)
