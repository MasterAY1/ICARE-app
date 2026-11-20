"""
Authentication schemas for ICARE Core Banking.
Supports standard username/password authentication and RFC 6238 Multi-Factor Authentication.
Strict Zero-Emoji Governance.
"""
from typing import Any, Dict, List, Optional
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
    phone: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    mfa_enabled: bool = False
    is_misc_savings_manager: bool = False
    created_at: Optional[str] = None
    last_login: Optional[str] = None
    preferences: Dict[str, Any] = {}


class LoginResponse(BaseModel):
    access_token: Optional[str] = None
    token_type: str = "Bearer"
    user: Optional[UserInfo] = None
    mfa_required: bool = False
    mfa_token: Optional[str] = None
    password_change_required: bool = False
    temp_token: Optional[str] = None
    csrf_token: Optional[str] = None
    message: Optional[str] = None


class SessionMeResponse(BaseModel):
    authenticated: bool = True
    user: UserInfo
    csrf_token: Optional[str] = None


class ChangeInitialPasswordRequest(BaseModel):
    temp_token: str = Field(..., min_length=1, description="Temporary password change token issued during first-time login")
    current_password: str = Field(..., min_length=1, description="Current temporary or default password")
    new_password: str = Field(..., min_length=8, description="New strong password of user choice (min 8 characters)")


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


class UserPreferencesPayload(BaseModel):
    theme_mode: Optional[str] = Field(None, description="UI brightness preference: system, light, or dark")
    accent_preset: Optional[str] = Field(None, description="Brand palette preset: emerald, sapphire, teal, or indigo")
    compact_density: Optional[bool] = None
    reduce_motion: Optional[bool] = None
    haptics_enabled: Optional[bool] = None


class ProfileUpdateRequest(BaseModel):
    phone: Optional[str] = Field(None, max_length=30, description="Staff contact phone number")
    email: Optional[str] = Field(None, max_length=120, description="Staff email address")
    bio: Optional[str] = Field(None, max_length=280, description="Short personal role bio or desk note")
    emergency_contact: Optional[str] = Field(None, max_length=120, description="Emergency contact name & phone")
    preferences: Optional[UserPreferencesPayload] = None


class ProfileLoginActivityItem(BaseModel):
    login_time: str
    status: str
    device_name: Optional[str] = None
    browser: Optional[str] = None
    operating_system: Optional[str] = None


class ProfileResponse(BaseModel):
    user: UserInfo
    emergency_contact: Optional[str] = None
    can_self_change_password: bool = False
    remaining_backup_codes: int = 0
    mfa_enrolled_at: Optional[str] = None
    recent_activity: List[ProfileLoginActivityItem] = []


class ProfileUpdateResponse(BaseModel):
    success: bool
    message: str
    user: UserInfo
    emergency_contact: Optional[str] = None


class AvatarUploadResponse(BaseModel):
    success: bool
    message: str
    avatar_url: str
    size_kb: float = 0.0


class ChangeOwnPasswordRequest(BaseModel):
    current_password: str = Field(..., min_length=1, description="Current account password")
    new_password: str = Field(..., min_length=8, description="New strong password (minimum 8 characters)")


class ChangeOwnPasswordResponse(BaseModel):
    success: bool
    message: str
    access_token: Optional[str] = None
    csrf_token: Optional[str] = None
