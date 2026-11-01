"""
Authentication schemas for ICARE Core Banking.
Supports standard username/password authentication and RFC 6238 Multi-Factor Authentication.
Strict Zero-Emoji Governance.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str = Field(..., min_length=1, description="Username of the user")
    password: str = Field(..., min_length=1, description="Password")


class UserInfo(BaseModel):
    id: str
    username: str
    full_name: str
    role: str
    branch: str
    branch_id: str
    assigned_branches: List[str] = []
    assigned_branch_ids: List[str] = []
    allowed_products: List[str] = []


class LoginResponse(BaseModel):
    access_token: Optional[str] = None
    token_type: str = "Bearer"
    user: Optional[UserInfo] = None
    mfa_required: bool = False
    mfa_token: Optional[str] = None


class MFASetupResponse(BaseModel):
    secret: str
    otpauth_uri: str
    backup_codes: List[str]


class MFAActivateRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=12, description="6-digit TOTP code from authenticator app")


class MFAChallengeRequest(BaseModel):
    mfa_token: str = Field(..., min_length=1, description="Temporary MFA challenge token issued during initial login")
    code: str = Field(..., min_length=6, max_length=16, description="6-digit TOTP code or backup code")


class MFADisableRequest(BaseModel):
    password: str = Field(..., min_length=1, description="Current account password for identity confirmation")


class MFAResetUserRequest(BaseModel):
    user_id: str = Field(..., min_length=1, description="Target user ID to reset MFA for")


class MFAStatusResponse(BaseModel):
    mfa_enabled: bool
    enrolled_at: Optional[str] = None
    remaining_backup_codes: int = 0


class GenericMFAActionResponse(BaseModel):
    success: bool
    message: str
