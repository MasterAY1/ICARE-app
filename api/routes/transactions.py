"""
api/routes/transactions.py
Authoritative Transaction Status and Recovery API for ICARE Core Banking.
Allows Flutter clients to query and recover in-flight or interrupted financial
operations using their client-assigned idempotency keys without duplicate posting.
Complies with Strict Zero-Emoji Governance.
"""

from typing import Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from api.dependencies import get_uow, get_current_user, require_role, CurrentUser
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.idempotency_service import IdempotencyService

router = APIRouter(prefix="/api/v1/transactions", tags=["Transactions & Idempotency Recovery"])


class TransactionStatusResponse(BaseModel):
    idempotency_key: str = Field(..., description="Unique client transaction key")
    scope: str = Field(..., description="Transaction scope (e.g. batch_collection, single_collection, repayment)")
    status: str = Field(..., description="Standard transaction state: Confirmed, Processing, Failed")
    raw_status: str = Field(..., description="Internal database state (COMMITTED, PROCESSING, FAILED)")
    response_code: Optional[int] = Field(None, description="Committed HTTP response code")
    response_body: Optional[Any] = Field(None, description="Cached server receipt or execution result")
    created_at: Optional[str] = Field(None, description="Creation timestamp")
    locked_at: Optional[str] = Field(None, description="Last lock acquisition timestamp")


STATUS_MAP = {
    "COMMITTED": "Confirmed",
    "PROCESSING": "Processing",
    "FAILED": "Failed"
}


@router.get("/status/{idempotency_key}", response_model=TransactionStatusResponse)
def get_transaction_status(
    idempotency_key: str,
    current_user: CurrentUser = Depends(require_role([
        "CO", "Credit Officer", "Officer",
        "BM", "Branch Manager",
        "AM", "Area Manager",
        "Admin", "Super Admin",
        "Director", "Accountant"
    ])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Authoritative query endpoint for transaction status recovery.
    Mobile clients MUST query this endpoint whenever a network dropout occurs
    before allowing another submission.
    """
    if not idempotency_key or not idempotency_key.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Valid idempotency key is required."
        )

    clean_key = idempotency_key.strip()
    record = IdempotencyService.get_transaction_status(uow, clean_key)

    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Transaction with key '{clean_key}' was not found. Server has no record of this operation."
        )

    raw_status = record.get("status", "PROCESSING")
    friendly_status = STATUS_MAP.get(raw_status, "Processing")

    return TransactionStatusResponse(
        idempotency_key=record.get("key"),
        scope=record.get("scope", "financial_operation"),
        status=friendly_status,
        raw_status=raw_status,
        response_code=record.get("response_code"),
        response_body=record.get("response_body"),
        created_at=str(record.get("created_at")) if record.get("created_at") else None,
        locked_at=str(record.get("locked_at")) if record.get("locked_at") else None
    )
