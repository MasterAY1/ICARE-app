from dataclasses import dataclass
from datetime import date, datetime
from typing import Optional

@dataclass
class FinancialTransaction:
    transaction_id: Optional[str]
    event_id: Optional[str]
    posting_date: date
    branch_id: str
    officer_id: Optional[str]
    narration: Optional[str]
    reference: Optional[str]
    status: str = "Posted"  # Pending, Processing, Posted, Reversed, Cancelled, Failed
    reversal_of: Optional[str] = None
    currency_code: str = "NGN"
    created_at: Optional[datetime] = None

@dataclass
class LedgerEntry:
    entry_id: Optional[str]
    transaction_id: str
    branch_id: str
    account_code: str
    side: str  # Debit, Credit
    amount: float
    aggregate_type: str
    aggregate_id: str
    created_at: Optional[datetime] = None
