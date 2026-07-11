from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

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
