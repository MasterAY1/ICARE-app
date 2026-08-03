from typing import Optional
from dataclasses import dataclass
from datetime import date

@dataclass
class BranchClosure:
    id: Optional[str]
    start_date: date
    end_date: date
    reason: str
    branch_id: Optional[str] = None
