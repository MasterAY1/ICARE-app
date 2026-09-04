"""
Error correction and reversal request schemas (Four-Eyes BR-ERR-001).
"""
from pydantic import BaseModel, Field


class ReversalRequestInput(BaseModel):
    record_id: str = Field(..., min_length=1, description="ID of the record to flag for reversal")
    record_type: str = Field(..., description="Repayment, Cashbook, Savings, Treasury, Fee")
    reason: str = Field(..., min_length=3, description="Justification for reversal")


class ReversalRequestResponse(BaseModel):
    success: bool
    request_id: str
    status: str
    message: str
