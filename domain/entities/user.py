from dataclasses import dataclass
from typing import Optional
from datetime import datetime

@dataclass
class User:
    id: str
    username: str
    full_name: str
    role: str
    branch_name: str
    password_hash: str
    created_at: Optional[datetime]
    branch_id: str = ""
    is_active: bool = True
    last_login: Optional[datetime] = None
    last_activity: Optional[datetime] = None
