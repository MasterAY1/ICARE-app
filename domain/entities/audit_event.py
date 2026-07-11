from dataclasses import dataclass
from typing import Optional
from datetime import datetime

@dataclass
class AuditEvent:
    id: Optional[int]
    user: str
    branch: str
    action: str
    old_value: Optional[str]
    new_value: Optional[str]
    timestamp: Optional[datetime]
