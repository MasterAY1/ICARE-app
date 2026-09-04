"""
CO Dashboard route adapter.
Reuses DashboardService.get_co_dashboard_data directly against Supabase schema.
"""
from typing import Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_user, require_role
from api.schemas.dashboard import CoDashboardResponse
from models.user import CurrentUser
from services.dashboard_service import DashboardService

router = APIRouter(prefix="/api/v1/co", tags=["CO Dashboard"])


@router.get("/dashboard", response_model=CoDashboardResponse)
def get_co_dashboard(
    date_str: Optional[str] = Query(None, alias="date", description="Target ISO date (YYYY-MM-DD)"),
    current_user: CurrentUser = Depends(require_role(["CO", "Credit Officer", "Officer", "BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin"])),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns presentation-ready CO Dashboard dataset for the authenticated officer.
    """
    target_date = date.today()
    if date_str:
        try:
            target_date = date.fromisoformat(date_str)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid date format. Use YYYY-MM-DD."
            )

    try:
        data = DashboardService.get_co_dashboard_data(
            uow=uow,
            branch_name=current_user.branch,
            officer_name=current_user.username,
            officer_id=current_user.id,
            branch_id=current_user.branch_id,
            target_date=target_date
        )

        # Convert DataFrames to serializable dicts if present
        meeting_portfolio = data.get("meeting_portfolio")
        if hasattr(meeting_portfolio, "to_dict"):
            data["meeting_portfolio"] = meeting_portfolio.fillna("").to_dict(orient="records")
        elif not isinstance(meeting_portfolio, list):
            data["meeting_portfolio"] = []

        attention_list = data.get("attention_list")
        if hasattr(attention_list, "to_dict"):
            data["attention_list"] = attention_list.fillna("").to_dict(orient="records")
        elif not isinstance(attention_list, list):
            data["attention_list"] = []

        return data

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate CO dashboard: {str(e)}"
        )
