from dataclasses import dataclass, field
from typing import Set, List

@dataclass
class CurrentUser:
    id: str
    username: str
    role: str
    branch: str
    branch_id: str = ""
    full_name: str = ""
    permissions: Set[str] = field(default_factory=set)
    assigned_branch_ids: List[str] = field(default_factory=list)
    assigned_branches: List[str] = field(default_factory=list)
