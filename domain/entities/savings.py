from dataclasses import dataclass, field
from typing import Optional
from datetime import date, datetime

@dataclass
class IndividualSavings:
    client_id: str
    client_name: str
    branch: str
    officer: str
    deposit_amount: float = 0.0
    withdrawal_amount: float = 0.0
    balance: float = 0.0
    reference: Optional[str] = None
    remarks: Optional[str] = None
    date: Optional[datetime] = None
    id: Optional[str] = None

@dataclass
class GroupSavings:
    group_name: str
    branch: str
    officer: str
    deposit_amount: float = 0.0
    withdrawal_amount: float = 0.0
    balance: float = 0.0
    reference: Optional[str] = None
    remarks: Optional[str] = None
    date: Optional[datetime] = None
    id: Optional[str] = None

@dataclass
class MiscSavings:
    client_id: str
    client_name: str
    branch: str
    officer: str
    deposit_amount: float = 0.0
    withdrawal_amount: float = 0.0
    balance: float = 0.0
    reference: Optional[str] = None
    remarks: Optional[str] = None
    date: Optional[datetime] = None
    id: Optional[str] = None

@dataclass
class LapsSavings:
    client_id: str
    client_name: str
    branch: str
    officer: str
    deposit_amount: float = 0.0
    withdrawal_amount: float = 0.0
    balance: float = 0.0
    reference: Optional[str] = None
    remarks: Optional[str] = None
    date: Optional[datetime] = None
    id: Optional[str] = None
