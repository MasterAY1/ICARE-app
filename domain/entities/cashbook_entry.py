from dataclasses import dataclass
from typing import Optional
from datetime import date

@dataclass
class CashbookEntry:
    id: Optional[int]
    date: date
    branch: str
    opening_balance: float
    savings_deposit: float
    loan_recovery: float
    disbursement: float
    savings_withdrawal: float
    office_expenses: float
    bank_deposit: float
    staff_salary: float
    closing_balance: float
    shortage: float
    excess: float
    is_balanced: bool
    status: str
