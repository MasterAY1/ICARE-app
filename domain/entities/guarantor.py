from dataclasses import dataclass
from typing import Optional
from datetime import datetime

@dataclass
class Guarantor:
    guarantor_id: str
    name: str
    phone: Optional[str] = None
    address: Optional[str] = None
    occupation: Optional[str] = None
    business_address: Optional[str] = None
    created_at: Optional[datetime] = None

@dataclass
class LoanGuarantor:
    id: str
    loan_id: str
    guarantor_id: str
    relationship: Optional[str] = None
    signature_url: Optional[str] = None
    created_at: Optional[datetime] = None
