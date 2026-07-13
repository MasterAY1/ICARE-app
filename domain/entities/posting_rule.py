from dataclasses import dataclass
from datetime import date, datetime
from typing import Optional

@dataclass
class PostingRule:
    id: Optional[str]
    event_type: str
    debit_account: str
    credit_account: str
    version: int = 1
    effective_from: Optional[date] = None
    effective_to: Optional[date] = None
    enabled: bool = True
    created_at: Optional[datetime] = None
