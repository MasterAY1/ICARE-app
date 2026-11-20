from dataclasses import dataclass, field
from typing import Set, List, Dict, Any, Optional

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
    allowed_products: List[str] = field(default_factory=list)
    phone: str = ""
    email: str = ""
    avatar_url: str = ""
    bio: str = ""
    mfa_enabled: bool = False
    is_misc_savings_manager: bool = False
    preferences: Dict[str, Any] = field(default_factory=dict)
    created_at: Optional[str] = None
    last_login: Optional[str] = None

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
            "allowed_products": self.allowed_products,
            "phone": self.phone,
            "email": self.email,
            "avatar_url": self.avatar_url,
            "bio": self.bio,
            "mfa_enabled": self.mfa_enabled,
            "is_misc_savings_manager": self.is_misc_savings_manager,
            "preferences": self.preferences,
            "created_at": self.created_at,
            "last_login": self.last_login,
        }


