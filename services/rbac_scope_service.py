"""
RBACScopeService — Phase 8.6.1
Centralized Enterprise RBAC Scope Engine for ICARE Core Banking Platform.
Single source of truth for navigation permissions, data visibility, search scope, and export scope.
"""
from typing import Dict, Any, List, Optional
from dataclasses import dataclass, field
import pandas as pd


@dataclass
class RBACScope:
    user_id: Optional[str] = None
    username: str = ""
    role: str = "CO"
    branch_id: Optional[str] = None
    branch_name: str = ""
    assigned_branch_ids: List[str] = field(default_factory=list)
    assigned_branch_names: List[str] = field(default_factory=list)
    scope_level: str = "OFFICER"  # OFFICER, BRANCH, REGION, INSTITUTION
    is_director: bool = False

    def is_read_only(self) -> bool:
        return self.is_director or self.role in ["Director", "DIRECTOR", "Board Director"]


class RBACScopeService:

    ROLE_NAVIGATION = {
        "CO": [
            "Dashboard", "Loan Origination", "Collections", "Withdrawal Operations", "Portfolio",
            "Audit Ledger", "CO Cashbook"
        ],
        "Branch Manager": [
            "Dashboard", "Portfolio", "Loan Origination", "Collections", "Withdrawal Operations",
            "Master Cashbook", "Audit Ledger", "Reports & Export"
        ],
        "Area Manager": [
            "Dashboard", "Portfolio", "Audit Ledger", "Reports & Export"
        ],
        "Admin": [
            "Dashboard", "Portfolio", "Loan Origination", "Collections", "Withdrawal Operations", "Legacy LAPS Migration", "CO Cashbook",
            "Master Cashbook", "User Management", "Audit Ledger",
            "Reports & Export"
        ],
        "Director": [
            "Dashboard", "Portfolio", "Audit Ledger", "Reports & Export"
        ]
    }

    # Standardize legacy role strings to standard role keys
    ROLE_ALIASES = {
        "CO": "CO",
        "CREDIT_OFFICER": "CO",
        "CREDIT OFFICER": "CO",
        "OFFICER": "CO",
        "BM": "Branch Manager",
        "BRANCH_MANAGER": "Branch Manager",
        "BRANCH MANAGER": "Branch Manager",
        "AM": "Area Manager",
        "AREA_MANAGER": "Area Manager",
        "AREA MANAGER": "Area Manager",
        "ADMIN": "Admin",
        "ADMINISTRATOR": "Admin",
        "SUPER_ADMIN": "Admin",
        "GLOBAL_ADMIN": "Admin",
        "DIRECTOR": "Director",
        "BOARD_DIRECTOR": "Director",
        "BOARD DIRECTOR": "Director",
        "EXECUTIVE": "Director"
    }

    @classmethod
    def normalize_role(cls, role: Optional[str]) -> str:
        if not role:
            return "CO"
        clean = str(role).strip().upper()
        return cls.ROLE_ALIASES.get(clean, cls.ROLE_ALIASES.get(str(role).strip(), "CO"))

    @classmethod
    def resolve_scope(cls, current_user: Dict[str, Any]) -> RBACScope:
        """
        Resolves the RBACScope object for an authenticated user session.
        """
        if not current_user:
            return RBACScope()

        raw_role = current_user.get("role") or current_user.get("user_role") or "CO"
        norm_role = cls.normalize_role(raw_role)

        u_id = current_user.get("id") or current_user.get("user_id")
        u_name = current_user.get("username") or current_user.get("name") or ""
        b_id = current_user.get("branch_id")
        b_name = current_user.get("branch") or current_user.get("branch_name") or ""

        assigned_names = current_user.get("assigned_branches") or []
        if isinstance(assigned_names, str):
            assigned_names = [assigned_names]
        if not assigned_names and b_name:
            assigned_names = [b_name]

        assigned_ids = current_user.get("assigned_branch_ids") or []
        if isinstance(assigned_ids, str):
            assigned_ids = [assigned_ids]
        if not assigned_ids and b_id:
            assigned_ids = [b_id]

        if norm_role == "CO":
            level = "OFFICER"
        elif norm_role == "Branch Manager":
            level = "BRANCH"
        elif norm_role == "Area Manager":
            level = "REGION"
        elif norm_role == "Director":
            level = "INSTITUTION"
        else:
            level = "INSTITUTION"

        is_dir = (norm_role == "Director")

        return RBACScope(
            user_id=u_id,
            username=u_name,
            role=norm_role,
            branch_id=b_id,
            branch_name=b_name,
            assigned_branch_ids=assigned_ids,
            assigned_branch_names=assigned_names,
            scope_level=level,
            is_director=is_dir
        )

    @classmethod
    def get_permitted_menu_items(cls, role: str) -> List[str]:
        norm = cls.normalize_role(role)
        return cls.ROLE_NAVIGATION.get(norm, cls.ROLE_NAVIGATION["CO"])

    @classmethod
    def is_page_permitted(cls, role: str, page_name: str) -> bool:
        norm = cls.normalize_role(role)
        permitted = cls.get_permitted_menu_items(norm)
        
        # Always allow Profile & Logout
        if page_name in ["Profile", "Logout"]:
            return True

        # Loose matching for sub-pages or legacy names
        for item in permitted:
            if item.lower() in page_name.lower() or page_name.lower() in item.lower():
                return True
        return False

    @classmethod
    def filter_dataframe(
        cls,
        df: pd.DataFrame,
        scope: RBACScope,
        branch_col: str = "branch",
        officer_col: str = "officer",
        selected_branch: Optional[str] = None,
        selected_officer: Optional[str] = None
    ) -> pd.DataFrame:
        """
        Filter a pandas DataFrame in memory based on RBACScope and active toolbar selections.
        """
        if df.empty:
            return df

        cols = [c.lower() for c in df.columns]
        b_col_matched = next((c for c in df.columns if c.lower() in [branch_col.lower(), "branch", "branch_name"]), None)
        o_col_matched = next((c for c in df.columns if c.lower() in [officer_col.lower(), "officer", "officer_name", "credit_officer"]), None)

        filtered = df.copy()

        # 1. Scope Level Constraints
        if scope.scope_level == "OFFICER":
            if o_col_matched and scope.username:
                filtered = filtered[filtered[o_col_matched].astype(str).str.lower() == scope.username.lower()]
        elif scope.scope_level == "BRANCH":
            if b_col_matched and scope.branch_name:
                filtered = filtered[filtered[b_col_matched].astype(str).str.lower() == scope.branch_name.lower()]
        elif scope.scope_level == "REGION":
            if b_col_matched and scope.assigned_branch_names:
                assigned_lower = [b.lower() for b in scope.assigned_branch_names]
                filtered = filtered[filtered[b_col_matched].astype(str).str.lower().isin(assigned_lower)]

        # 2. Dynamic Toolbar Selection Filters (BM, AM, Admin)
        if selected_branch and selected_branch != "All" and b_col_matched:
            filtered = filtered[filtered[b_col_matched].astype(str).str.lower() == selected_branch.lower()]

        if selected_officer and selected_officer != "All" and o_col_matched:
            filtered = filtered[filtered[o_col_matched].astype(str).str.lower() == selected_officer.lower()]

        return filtered
