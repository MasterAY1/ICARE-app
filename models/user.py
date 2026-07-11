from dataclasses import dataclass, field
from typing import Set

@dataclass
class CurrentUser:
    id: str
    username: str
    role: str
    branch: str
    permissions: Set[str] = field(default_factory=set)
