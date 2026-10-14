"""
ICARE Core Banking — Branch Onboarding & Digital Ingestion REST API Router.
Exposes tokenized endpoints for public field onboarding entry and
RBAC-protected administrative endpoints for review, approval, and atomic commitment.
"""
from typing import Dict, Any, Optional, List
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Body, status
from pydantic import BaseModel, Field

from api.dependencies import get_uow, get_current_user
from database.repositories.unit_of_work import SupabaseUnitOfWork
from models.user import CurrentUser
from services.onboarding_service import OnboardingService

router = APIRouter(prefix="/api/v1/onboarding", tags=["Branch Onboarding"])


# ============================================================================
# Pydantic Request / Response Schemas
# ============================================================================

class CreateSessionRequest(BaseModel):
    branch_name: str = Field(..., description="Full branch name, e.g. 'Sagamu Branch'")
    branch_code: str = Field(..., description="Short 2-4 letter branch code, e.g. 'SAG'")
    contact_person: Optional[str] = Field(None, description="Branch Manager or coordinator name")
    contact_phone: Optional[str] = Field(None, description="Contact phone number")


class SaveDraftRequest(BaseModel):
    payload: Dict[str, Any] = Field(..., description="Onboarding payload containing officers, groups, and members")


class ApproveSessionRequest(BaseModel):
    approval_notes: Optional[str] = Field(None, description="Optional sign-off notes or audit comment")


class RejectSessionRequest(BaseModel):
    rejection_reason: str = Field(..., description="Feedback or required revision instructions for branch")


# ============================================================================
# 1. PUBLIC TOKENIZED ENDPOINTS (Zero Login Required for Branch Field Link)
# ============================================================================

@router.get("/session/{token}", summary="Retrieve onboarding session by token")
def get_onboarding_session(
    token: str,
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Public token-gated endpoint to load branch metadata, reference product catalogs,
    and current draft progress into the Branch Onboarding Web Portal.
    """
    try:
        return OnboardingService.get_session_by_token(uow, token)
    except ValueError as e:
        err_msg = str(e)
        if "expired" in err_msg.lower():
            raise HTTPException(status_code=status.HTTP_410_GONE, detail=err_msg)
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=err_msg)


@router.put("/session/{token}/save-draft", summary="Auto-save onboarding draft progress")
def save_onboarding_draft(
    token: str,
    req: SaveDraftRequest,
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Saves intermediate progress from the interactive grid or excel uploader.
    Automatically extends link validity by 14 days from active edit time.
    """
    try:
        return OnboardingService.save_draft(uow, token, req.payload)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/session/{token}/upload-excel", summary="Upload and parse onboarding Excel template")
async def upload_onboarding_excel(
    token: str,
    file: UploadFile = File(...),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Direct in-browser Excel parser for icare-group-member-onboarding-template.xlsx.
    Parses Groups and Members sheets into structured JSON and auto-saves to draft staging.
    """
    if not file.filename.endswith((".xlsx", ".xls")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file format. Please upload an Excel workbook (.xlsx)."
        )

    try:
        contents = await file.read()
        parsed_payload = OnboardingService.parse_excel_bytes(contents, uow)
        # Automatically persist as draft
        draft_res = OnboardingService.save_draft(uow, token, parsed_payload)
        return {
            "status": "success",
            "message": f"Successfully parsed {len(parsed_payload['groups'])} groups and {len(parsed_payload['members'])} members.",
            "payload": parsed_payload,
            "aggregates": draft_res["aggregates"],
            "validation_summary": draft_res["validation_summary"]
        }
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to parse Excel file: {str(e)}")


@router.post("/session/{token}/submit", summary="Submit onboarding package for administrative sign-off")
def submit_onboarding_session(
    token: str,
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Transitions session status to 'submitted' once all validation checks pass.
    Notifies Head of Operations and Area Manager for sign-off.
    """
    try:
        return OnboardingService.submit_session(uow, token)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


# ============================================================================
# 2. ADMINISTRATIVE MANAGEMENT ENDPOINTS (RBAC-Protected)
# ============================================================================

@router.post("/admin/sessions/create", summary="Generate a new branch onboarding token link")
def create_onboarding_session(
    req: CreateSessionRequest,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Generates a secure onboarding session link for a new branch."""
    if current_user.role not in ("Admin", "Director", "Super Admin", "Area Manager"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only Admins and Area Managers can generate onboarding links.")

    session = OnboardingService.create_session(
        uow=uow,
        branch_name=req.branch_name,
        branch_code=req.branch_code,
        contact_person=req.contact_person,
        contact_phone=req.contact_phone,
        created_by_id=current_user.id
    )
    return {
        "status": "success",
        "session": session,
        "onboarding_url": f"/#/onboarding?token={session['token']}"
    }


@router.get("/admin/sessions", summary="List all branch onboarding sessions")
def list_onboarding_sessions(
    status_filter: Optional[str] = None,
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """Lists pending, draft, or approved branch onboarding sessions."""
    if current_user.role not in ("Admin", "Director", "Super Admin", "Area Manager", "Auditor"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Access denied.")

    query = uow.client.table("branch_onboarding_sessions").select(
        "id, branch_id, branch_name, branch_code, token, status, contact_person, contact_phone, total_groups, total_members, total_savings, total_active_credit, total_current_balance, expires_at, created_at, submitted_at, approved_at, approval_notes"
    ).order("created_at", desc=True)

    if status_filter:
        query = query.eq("status", status_filter)

    res = query.execute()
    return {"sessions": res.data or []}


@router.post("/admin/sessions/{session_id}/approve", summary="Approve and atomically commit branch into core banking")
def approve_onboarding_session(
    session_id: str,
    req: ApproveSessionRequest = Body(default=ApproveSessionRequest()),
    current_user: CurrentUser = Depends(get_current_user),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Executes atomic migration of all groups, clients, memberships, savings,
    loans, and repayment schedules into live core banking tables.
    """
    if current_user.role not in ("Admin", "Director", "Super Admin"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only Admins and Directors can execute final onboarding activation.")

    try:
        return OnboardingService.commit_session(
            uow=uow,
            session_id=session_id,
            approved_by_id=current_user.id,
            approval_notes=req.approval_notes
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
