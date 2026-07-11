from dataclasses import dataclass
from typing import Optional

@dataclass
class LoanFilter:
    branch: Optional[str] = None
    status: Optional[str] = None
    officer: Optional[str] = None
    client_id: Optional[str] = None
    page: int = 1
    size: int = 50

@dataclass
class RepaymentFilter:
    branch: Optional[str] = None
    officer: Optional[str] = None
    loan_id: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    page: int = 1
    size: int = 50
    
@dataclass
class CashbookFilter:
    branch: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    date: Optional[str] = None
