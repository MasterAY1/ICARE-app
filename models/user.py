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

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "role": self.role,
            "branch": self.branch,
            "branch_id": self.branch_id,
            "full_name": self.full_name,
            "assigned_branch_ids": self.assigned_branch_ids,
            "assigned_branches": self.assigned_branches,
        }


