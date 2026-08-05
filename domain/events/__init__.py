from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, Dict, Any

@dataclass
class DomainEvent:
    occurred_on: datetime = field(default_factory=datetime.now)

@dataclass(kw_only=True)
class LoanApprovedEvent(DomainEvent):
    loan_id: str
    approved_by: str
    branch: str
    
@dataclass(kw_only=True)
class LoanCreatedEvent(DomainEvent):
    loan_id: str
    client_id: str
    created_by: str
    branch: str

@dataclass(kw_only=True)
class RepaymentReceivedEvent(DomainEvent):
    repayment_id: str
    loan_id: str
    amount: float
    received_by: str
    branch: str

# Event Type Constants
EVENT_LOAN_OFFSET_FROM_SAVINGS = "LoanOffsetFromSavings"
EVENT_LAPS_TRANSFERRED = "LapsTransferred"
EVENT_LAPS_PAID_OUT = "LapsPaidOut"

@dataclass(kw_only=True)
class LoanOffsetFromSavingsEvent(DomainEvent):
    event_id: str
    client_id: str
    loan_id: str
    source_savings_type: str
    amount: float
    branch: str
    officer: str
    business_date: str
    reference: str
    branch_id: Optional[str] = None
    officer_id: Optional[str] = None
    classification: str = "LOAN_OFFSET"
    narration: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

@dataclass(kw_only=True)
class LapsTransferredEvent(DomainEvent):
    event_id: str
    client_id: str
    source_savings_type: str
    amount: float
    destination: str = "LAPS"
    branch: str
    officer: str
    business_date: str
    reference: str
    branch_id: Optional[str] = None
    officer_id: Optional[str] = None
    classification: str = "LAPS_TRANSFER"
    narration: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None

@dataclass(kw_only=True)
class LapsPaidOutEvent(DomainEvent):
    event_id: str
    client_id: str
    amount: float
    branch: str
    officer: str
    business_date: str
    reference: str
    cash_paid: bool
    branch_id: Optional[str] = None
    officer_id: Optional[str] = None
    classification: str = "LAPS_PAYOUT"
    narration: Optional[str] = None
    metadata: Optional[Dict[str, Any]] = None


