from dataclasses import dataclass, field
from typing import Optional
from datetime import date, datetime

@dataclass
class Client:
    id: str
    name: str
    client_code: str
    nickname: Optional[str] = None
    phone: Optional[str] = None
    address: Optional[str] = None
    business_address: Optional[str] = None
    dob: Optional[date] = None
    gender: Optional[str] = None
    marital_status: Optional[str] = None
    occupation: Optional[str] = None
    business_type: Optional[str] = None
    id_means: Optional[str] = None
    next_of_kin: Optional[str] = None
    passport_url: Optional[str] = None
    signature_url: Optional[str] = None
    registration_date: Optional[date] = None
    branch_id: Optional[str] = None
    group_id: Optional[str] = None
    officer_id: Optional[str] = None
    status: str = "Active"
    average_monthly_income: float = 0.0
    other_obligations: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
