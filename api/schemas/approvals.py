"""
api/schemas/approvals.py
Pydantic Schemas for BM Four-Eyes Approvals and Automated Operations.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field


class PendingClientUpdateItem(BaseModel):
    request_id: str
    client_id: str
    client_name: str
    client_code: str
    branch_id: str
    branch_name: str
    requested_by_name: str
    proposed_changes: Dict[str, Any]
    previous_values: Dict[str, Any]
    created_at: Optional[str] = None


class RejectClientUpdateRequest(BaseModel):
    reason: str = Field(..., min_length=2, description="Justification for rejecting client profile update")


class ApprovalActionResponse(BaseModel):
    success: bool
    status: str
    message: str
    request_id: Optional[str] = None


class LapsSweepPreviewItem(BaseModel):
    client_id: str
    client_name: str
    client_code: str
    branch_name: str
    officer_name: str
    status: str
    days_in_status: int
    savings_balance: float


class LapsSweepResponse(BaseModel):
    success: bool
    swept_count: int
    total_amount: float
    details: List[Dict[str, Any]]
    message: str


class DefaulterEvaluationResponse(BaseModel):
    success: bool
    evaluated_count: int
    new_defaulters_count: int
    defaulters: List[Dict[str, Any]]
    message: str
