"""
Pydantic Schemas for Phase 10: User Management.
Covers User CRUD, Activation/Deactivation, Password Resets, Officer Turnover,
Product Assignments, AM Branch Assignments, Branch Closures, Audit Logs, and Login History.
"""
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


# -----------------------------------------------------------------------------
# User Listing & CRUD
# -----------------------------------------------------------------------------
class UserListItem(BaseModel):
    id: str
    username: str
    full_name: str
    role: str
    branch_name: Optional[str] = None
    branch_id: Optional[str] = None
    is_active: bool = True
    created_at: Optional[str] = None
    last_login: Optional[str] = None
    extra_fields: Optional[Dict[str, Any]] = None


class UserListResponse(BaseModel):
    users: List[UserListItem]
    total_count: int


class CreateUserRequest(BaseModel):
    username: str = Field(..., min_length=2, max_length=50)
    full_name: str = Field(..., min_length=2, max_length=100)
    password: str = Field(..., min_length=4)
    role: str
    branch_name: Optional[str] = None


class CreateUserResponse(BaseModel):
    success: bool
    message: str
    user: Optional[UserListItem] = None


class UserStatusToggleRequest(BaseModel):
    activate: bool


class GenericActionResponse(BaseModel):
    success: bool
    message: str


# -----------------------------------------------------------------------------
# Password Reset & Turnover
# -----------------------------------------------------------------------------
class PasswordResetRequest(BaseModel):
    username: str
    new_password: str = Field(..., min_length=4)


class OfficerTurnoverRequest(BaseModel):
    username: str
    new_name: str = Field(..., min_length=2, max_length=100)


# -----------------------------------------------------------------------------
# Product Assignment
# -----------------------------------------------------------------------------
class CreditOfficerProductMeta(BaseModel):
    id: str
    username: str
    full_name: str
    allowed_products: List[str] = []


class ProductAssignmentMetaResponse(BaseModel):
    available_products: List[str]
    credit_officers: List[CreditOfficerProductMeta]


class AssignProductsRequest(BaseModel):
    username: str
    user_id: Optional[str] = None
    allowed_products: List[str] = []


# -----------------------------------------------------------------------------
# AM Branch Assignments
# -----------------------------------------------------------------------------
class BranchOptionItem(BaseModel):
    branch_id: str
    name: str


class AMAssignmentItem(BaseModel):
    user_id: str
    username: str
    full_name: str
    assigned_branch_ids: List[str] = []
    assigned_branch_names: List[str] = []


class AMAssignmentsResponse(BaseModel):
    area_managers: List[AMAssignmentItem]
    all_branches: List[BranchOptionItem]


class SaveAMAssignmentsRequest(BaseModel):
    am_id: str
    branch_ids: List[str]


# -----------------------------------------------------------------------------
# Branch Closures & Settings
# -----------------------------------------------------------------------------
class BranchClosureItem(BaseModel):
    id: str
    start_date: str
    end_date: str
    reason: str
    branch_id: Optional[str] = None
    branch_name: Optional[str] = None


class BranchClosuresResponse(BaseModel):
    closures: List[BranchClosureItem]


class CreateBranchClosureRequest(BaseModel):
    start_date: str
    end_date: str
    reason: str
    branch_id: Optional[str] = None


class CreateBranchClosureResponse(BaseModel):
    success: bool
    message: str
    rescheduled_loans: int = 0


# -----------------------------------------------------------------------------
# System Audit Logs & Login History
# -----------------------------------------------------------------------------
class UserAuditLogItem(BaseModel):
    id: Optional[str] = None
    timestamp: str
    username: str
    role: Optional[str] = None
    branch: Optional[str] = None
    action: str
    module: Optional[str] = None
    entity_type: Optional[str] = None
    display_name: Optional[str] = None
    status: Optional[str] = None


class UserAuditLogsResponse(BaseModel):
    logs: List[UserAuditLogItem]
    total_count: int


class LoginHistoryItem(BaseModel):
    id: Optional[str] = None
    login_time: str
    username: str
    status: str
    session_id: Optional[str] = None
    logout_time: Optional[str] = None
    failed_attempts: Optional[int] = 0


class LoginHistoryResponse(BaseModel):
    history: List[LoginHistoryItem]
    total_count: int
