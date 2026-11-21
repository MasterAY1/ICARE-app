"""
Asset & Procurement Hub API Routes (BIA-ASSET-PROC-001).

Provides institution-wide stock visibility, multi-branch transfers,
supplier stock receipt (GRN), write-offs, cost/selling pricing management,
and asset program Profit & Loss analytics.
"""
from __future__ import annotations

import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from api.dependencies import get_uow, require_role
from database.repositories.unit_of_work import SupabaseUnitOfWork
from models.user import CurrentUser
from services.asset_inventory_service import AssetInventoryService

router = APIRouter(prefix="/api/v1/procurement", tags=["Asset & Procurement"])

_READ_ROLES = [
    "Procurement Officer",
    "Asset Manager",
    "Admin",
    "Super Admin",
    "Director",
]
_WRITE_ROLES = [
    "Procurement Officer",
    "Asset Manager",
    "Admin",
    "Super Admin",
]


class ReceiveStockLineInput(BaseModel):
    item_id: str = Field(..., min_length=1)
    quantity_received: int = Field(..., gt=0)
    unit_cost_price: Optional[float] = Field(None, ge=0)
    new_cash_price: Optional[float] = Field(None, ge=0)


class ReceiveStockBatchInput(BaseModel):
    branch_id: str = Field(..., min_length=1)
    reference_code: Optional[str] = ""
    supplier_name: Optional[str] = ""
    remarks: Optional[str] = ""
    items: List[ReceiveStockLineInput] = Field(..., min_length=1)


class TransferStockInput(BaseModel):
    from_branch_id: str = Field(..., min_length=1)
    to_branch_id: str = Field(..., min_length=1)
    item_id: str = Field(..., min_length=1)
    quantity: int = Field(..., gt=0)
    reference_code: Optional[str] = ""
    remarks: Optional[str] = ""


class WriteOffStockInput(BaseModel):
    branch_id: str = Field(..., min_length=1)
    item_id: str = Field(..., min_length=1)
    quantity: int = Field(..., gt=0)
    reason: str = Field(..., min_length=2)
    reference_code: Optional[str] = ""


class UpsertCatalogItemInput(BaseModel):
    item_id: Optional[str] = None
    sku_code: Optional[str] = None
    category: str = Field(..., min_length=1)
    item_name: str = Field(..., min_length=1)
    cash_and_carry_price: float = Field(..., ge=0)
    unit_cost_price: float = Field(0.0, ge=0)
    easy_buy_60d_price: Optional[float] = Field(None, ge=0)
    easy_buy_120d_price: Optional[float] = Field(None, ge=0)
    supplier_name: Optional[str] = None
    initial_branch_id: Optional[str] = None
    initial_quantity: int = Field(0, ge=0)


class BulkPriceUpdateItemInput(BaseModel):
    item_id: Optional[str] = None
    sku_code: Optional[str] = None
    unit_cost_price: Optional[float] = Field(None, ge=0)
    cash_and_carry_price: Optional[float] = Field(None, ge=0)
    easy_buy_60d_price: Optional[float] = Field(None, ge=0)
    easy_buy_120d_price: Optional[float] = Field(None, ge=0)
    supplier_name: Optional[str] = None


class BulkPriceUpdateInput(BaseModel):
    updates: List[BulkPriceUpdateItemInput] = Field(..., min_length=1)


def _record_audit(
    uow: SupabaseUnitOfWork,
    user: CurrentUser,
    action: str,
    description: str,
    table_name: str,
    record_id: str,
) -> None:
    try:
        uow.client.table("audit_logs").insert(
            {
                "id": str(uuid.uuid4()),
                "user_id": user.id,
                "action": action,
                "description": description,
                "table_name": table_name,
                "record_id": record_id,
            }
        ).execute()
    except Exception:
        pass


@router.get("/overview")
def get_procurement_overview(
    branch_id: Optional[str] = Query(None, description="Optional branch filter or ALL"),
    current_user: CurrentUser = Depends(require_role(_READ_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow),
) -> Dict[str, Any]:
    """Returns institution-wide inventory valuation, cost readiness, and asset P&L."""
    return AssetInventoryService.get_procurement_overview(uow=uow, branch_id=branch_id)


@router.get("/stock-matrix")
def get_multi_branch_stock_matrix(
    category: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    in_stock_only: bool = Query(False),
    current_user: CurrentUser = Depends(require_role(_READ_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow),
) -> Dict[str, Any]:
    """Returns SKU-level physical stock across all branches side-by-side."""
    return AssetInventoryService.get_multi_branch_stock_matrix(
        uow=uow,
        category=category,
        search=search,
        in_stock_only=in_stock_only,
    )


@router.post("/receive-stock")
def receive_stock_batch(
    payload: ReceiveStockBatchInput,
    current_user: CurrentUser = Depends(require_role(_WRITE_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow),
) -> Dict[str, Any]:
    """Records supplier GRN stock receipts and updates Weighted Average Cost."""
    try:
        res = AssetInventoryService.receive_stock_batch(
            uow=uow,
            branch_id=payload.branch_id,
            items=[ln.model_dump() for ln in payload.items],
            reference_code=payload.reference_code or "",
            supplier_name=payload.supplier_name or "",
            remarks=payload.remarks or "",
            performed_by=current_user.username,
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except RuntimeError as re_err:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(re_err))

    _record_audit(
        uow,
        current_user,
        "PROCUREMENT_RECEIVE_STOCK",
        f"Received {res['total_units_received']} unit(s) across {res['total_lines']} SKU(s) at {res['branch_name']} (Ref: {res.get('reference_code') or 'N/A'})",
        "branch_asset_inventory",
        res["branch_id"],
    )
    return res


@router.post("/transfer-stock")
def transfer_stock_between_branches(
    payload: TransferStockInput,
    current_user: CurrentUser = Depends(require_role(_WRITE_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow),
) -> Dict[str, Any]:
    """Transfers available physical stock from one branch to another."""
    try:
        res = AssetInventoryService.transfer_stock_between_branches(
            uow=uow,
            from_branch_id=payload.from_branch_id,
            to_branch_id=payload.to_branch_id,
            item_id=payload.item_id,
            quantity=payload.quantity,
            reference_code=payload.reference_code or "",
            remarks=payload.remarks or "",
            performed_by=current_user.username,
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except RuntimeError as re_err:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(re_err))

    _record_audit(
        uow,
        current_user,
        "PROCUREMENT_TRANSFER_STOCK",
        f"Transferred {res['quantity']}x {res['item_name']} ({res['sku_code']}) from {res['from_branch_name']} to {res['to_branch_name']} (Ref: {res['reference_code']})",
        "asset_stock_movements",
        res["item_id"],
    )
    return res


@router.post("/write-off")
def record_stock_write_off(
    payload: WriteOffStockInput,
    current_user: CurrentUser = Depends(require_role(_WRITE_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow),
) -> Dict[str, Any]:
    """Records damaged or lost physical stock write-offs for P&L loss tracking."""
    try:
        res = AssetInventoryService.record_stock_write_off(
            uow=uow,
            branch_id=payload.branch_id,
            item_id=payload.item_id,
            quantity=payload.quantity,
            reason=payload.reason,
            reference_code=payload.reference_code or "",
            performed_by=current_user.username,
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except RuntimeError as re_err:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(re_err))

    _record_audit(
        uow,
        current_user,
        "PROCUREMENT_WRITE_OFF",
        f"Wrote off {res['quantity_written_off']}x {res['item_name']} ({res['sku_code']}) at {res['branch_name']} (Ref: {res['reference_code']})",
        "asset_stock_movements",
        res["item_id"],
    )
    return res


@router.post("/catalog-item")
def upsert_catalog_item(
    payload: UpsertCatalogItemInput,
    current_user: CurrentUser = Depends(require_role(_WRITE_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow),
) -> Dict[str, Any]:
    """Creates a new asset SKU or updates master cost/selling prices for an existing SKU."""
    try:
        res = AssetInventoryService.upsert_catalog_item(
            uow=uow,
            item_id=payload.item_id,
            sku_code=payload.sku_code,
            category=payload.category,
            item_name=payload.item_name,
            cash_and_carry_price=payload.cash_and_carry_price,
            unit_cost_price=payload.unit_cost_price,
            easy_buy_60d_price=payload.easy_buy_60d_price,
            easy_buy_120d_price=payload.easy_buy_120d_price,
            supplier_name=payload.supplier_name,
            initial_branch_id=payload.initial_branch_id,
            initial_quantity=payload.initial_quantity,
            performed_by=current_user.username,
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except RuntimeError as re_err:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(re_err))

    it = res["item"]
    _record_audit(
        uow,
        current_user,
        "PROCUREMENT_CATALOG_CREATE" if res["created"] else "PROCUREMENT_CATALOG_UPDATE",
        f"{'Created' if res['created'] else 'Updated'} {it['item_name']} ({it['sku_code']}): Cost=₦{it['unit_cost_price']:,.2f}, Cash=₦{it['cash_and_carry_price']:,.2f}",
        "asset_catalog_items",
        it["item_id"],
    )
    return res


@router.post("/catalog-prices/bulk")
def bulk_update_catalog_prices(
    payload: BulkPriceUpdateInput,
    current_user: CurrentUser = Depends(require_role(_WRITE_ROLES)),
    uow: SupabaseUnitOfWork = Depends(get_uow),
) -> Dict[str, Any]:
    """Batch-updates supplier cost prices and/or retail selling prices across catalog SKUs."""
    try:
        res = AssetInventoryService.bulk_update_catalog_prices(
            uow=uow,
            updates=[u.model_dump() for u in payload.updates],
            performed_by=current_user.username,
        )
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(ve))
    except RuntimeError as re_err:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(re_err))

    _record_audit(
        uow,
        current_user,
        "PROCUREMENT_BULK_PRICE_UPDATE",
        f"Bulk updated pricing/cost metadata for {res['updated_count']} catalog SKU(s)",
        "asset_catalog_items",
        "BULK",
    )
    return res
