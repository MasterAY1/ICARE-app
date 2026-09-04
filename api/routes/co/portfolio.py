"""
CO Portfolio route adapter.
Reuses PortfolioService.get_portfolio_data_for_scope directly against Supabase schema.
"""
from typing import Optional
from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from api.dependencies import get_uow, get_current_scope, require_role
from api.schemas.portfolio import PortfolioResponse
from services.rbac_scope_service import RBACScope
from services.portfolio_service import PortfolioService

router = APIRouter(prefix="/api/v1/co", tags=["CO Portfolio"])


@router.get("/portfolio", response_model=PortfolioResponse)
def get_co_portfolio(
    group: Optional[str] = Query(None, description="Solidarity group filter"),
    product: Optional[str] = Query(None, description="Loan product filter"),
    start_date_str: Optional[str] = Query(None, alias="start_date"),
    end_date_str: Optional[str] = Query(None, alias="end_date"),
    scope: RBACScope = Depends(get_current_scope),
    uow: SupabaseUnitOfWork = Depends(get_uow)
):
    """
    Returns role-scoped portfolio intelligence for Credit Officer.
    """
    start_date = date.today()
    end_date = date.today()
    if start_date_str:
        try:
            start_date = date.fromisoformat(start_date_str)
        except ValueError:
            pass
    if end_date_str:
        try:
            end_date = date.fromisoformat(end_date_str)
        except ValueError:
            pass

    try:
        portfolio_raw = PortfolioService.get_portfolio_data_for_scope(
            uow=uow,
            scope=scope,
            selected_group=group,
            selected_product=product,
            start_date=start_date,
            end_date=end_date
        )

        metrics = portfolio_raw.get("metrics", {})
        groups = portfolio_raw.get("groups", [])
        clients = portfolio_raw.get("clients", [])

        # Convert DataFrames to dicts if needed
        if hasattr(groups, "to_dict"):
            groups = groups.to_dict(orient="records")
        if hasattr(clients, "to_dict"):
            clients = clients.to_dict(orient="records")

        # Map group items
        group_items = []
        for g in (groups or []):
            group_items.append({
                "group_name": g.get("Group Name") or g.get("group_name") or "Ungrouped",
                "total_clients": int(g.get("Total Clients") or g.get("total_clients") or 0),
                "total_savings_balance": float(g.get("Total Savings Balance") or g.get("total_savings_balance") or 0.0),
                "total_active_loan": float(g.get("Total Active Loan") or g.get("total_active_loan") or 0.0),
                "total_outstanding_balance": float(g.get("Total Outstanding Balance") or g.get("total_outstanding_balance") or 0.0),
                "total_fixed_repayment": float(g.get("Total Fixed Repayment") or g.get("total_fixed_repayment") or 0.0),
                "total_paid": float(g.get("Total Paid") or g.get("total_paid") or 0.0)
            })

        # Map client items
        client_items = []
        for c in (clients or []):
            client_items.append({
                "client_id": str(c.get("Client ID") or c.get("client_id") or ""),
                "client_code": str(c.get("Client Code") or c.get("client_code") or c.get("Client ID") or ""),
                "client_name": str(c.get("Client Name") or c.get("client_name") or c.get("name") or "Unknown"),
                "group_name": str(c.get("Group Name") or c.get("group_name") or "Ungrouped"),
                "savings_balance": float(c.get("Savings Balance") or c.get("savings_balance") or 0.0),
                "active_loan": float(c.get("Active Loan") or c.get("active_loan") or 0.0),
                "outstanding_balance": float(c.get("Outstanding Balance") or c.get("outstanding_balance") or 0.0),
                "status": str(c.get("Status") or c.get("status") or "Active")
            })

        return {
            "metrics": {
                "total_clients": int(metrics.get("total_clients") or 0),
                "total_active_credit": float(metrics.get("total_active_credit") or 0.0),
                "total_outstanding": float(metrics.get("total_outstanding") or 0.0),
                "total_fixed_repayment": float(metrics.get("total_fixed_repayment") or 0.0),
                "total_paid": float(metrics.get("total_paid") or 0.0),
                "collection_rate": float(metrics.get("collection_rate") or 0.0),
                "par_30_amount": float(metrics.get("par_30_amount") or 0.0),
                "par_30_count": int(metrics.get("par_30_count") or 0)
            },
            "groups": group_items,
            "clients": client_items
        }

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch portfolio data: {str(e)}"
        )
