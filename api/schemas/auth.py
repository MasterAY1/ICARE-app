"""
Authentication schemas.
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


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "Bearer"
    user: UserInfo
