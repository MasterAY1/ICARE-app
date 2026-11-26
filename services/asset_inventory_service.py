"""
Asset Inventory & Master Price Catalog Service (BIA-ASSET-PROG-001).

Connects the October 2026 Master Asset Price List (540 SKUs across 19 categories)
and branch-level physical stock (including Ogijo Branch's 242 SKUs / 205 physical units)
to Loan Origination, Disbursement, Rejection, and Branch Stock Management.
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from services.asset_inventory_data import (
    MASTER_ASSET_CATALOG_SEED,
    MASTER_ASSET_CATEGORIES,
)


def _table_missing_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return (
        "pgrst205" in msg
        or "42p01" in msg
        or "does not exist" in msg
        or "could not find the table" in msg
    )


def _is_ogijo_branch(branch_name: Optional[str]) -> bool:
    return "ogijo" in str(branch_name or "").lower()


def _parse_extra_fields(raw: Any) -> Dict[str, Any]:
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str) and raw.strip().startswith("{"):
        try:
            parsed = json.loads(raw)
            if isinstance(parsed, dict):
                return parsed
        except Exception:
            pass
    return {}


def _compute_pricing_metrics(
    cost_price: Any,
    cash_price: Any,
    p60_price: Any = None,
    p120_price: Any = None,
) -> Dict[str, Any]:
    """Computes cost readiness, retail cash margin, and Easy Buy financing markups."""
    cost_val = round(max(0.0, float(cost_price or 0.0)), 2)
    cash_val = round(max(0.0, float(cash_price or 0.0)), 2)
    p60_val = round(float(p60_price or round(cash_val * 1.12, 2)), 2)
    p120_val = round(float(p120_price or round(cash_val * 1.21, 2)), 2)
    has_cost = cost_val > 0.0
    retail_margin = round(cash_val - cost_val, 2) if has_cost else 0.0
    retail_margin_pct = round(((cash_val - cost_val) / cost_val) * 100.0, 2) if has_cost else 0.0
    markup_60d = round(p60_val - cash_val, 2)
    markup_120d = round(p120_val - cash_val, 2)
    total_profit_60d = round(p60_val - cost_val, 2) if has_cost else markup_60d
    total_profit_120d = round(p120_val - cost_val, 2) if has_cost else markup_120d
    return {
        "unit_cost_price": cost_val,
        "has_cost_price": has_cost,
        "cash_and_carry_price": cash_val,
        "easy_buy_60d_price": p60_val,
        "easy_buy_120d_price": p120_val,
        "retail_margin_amount": retail_margin,
        "retail_margin_pct": retail_margin_pct,
        "easy_buy_60d_markup": markup_60d,
        "easy_buy_120d_markup": markup_120d,
        "easy_buy_60d_total_profit": total_profit_60d,
        "easy_buy_120d_total_profit": total_profit_120d,
    }


def _resolve_package_selling_price(
    unit_cash: float,
    unit_60d: float,
    unit_120d: float,
    product_type: Optional[str] = None,
    is_cash_and_carry: bool = False,
) -> float:
    pt = str(product_type or "").lower()
    if is_cash_and_carry or "cash and carry" in pt or "cash & carry" in pt:
        return round(unit_cash, 2)
    if "120" in pt or "24w" in pt or "24 week" in pt or "6m" in pt or "6 month" in pt:
        return round(unit_120d if unit_120d > 0 else unit_cash * 1.21, 2)
    return round(unit_60d if unit_60d > 0 else unit_cash * 1.12, 2)


class AssetInventoryService:
    """Manages Master Asset Catalog pricing and branch physical inventory lifecycle."""

    _SEED_BY_ID: Dict[str, Dict[str, Any]] = {
        row["item_id"]: row for row in MASTER_ASSET_CATALOG_SEED
    }
    _SEED_BY_SKU: Dict[str, Dict[str, Any]] = {
        row["sku_code"]: row for row in MASTER_ASSET_CATALOG_SEED
    }

    @classmethod
    def _fetch_all_rows(
        cls,
        uow: Any,
        table_name: str,
        eq_filters: Optional[Dict[str, Any]] = None,
        orders: Optional[List[str]] = None,
    ) -> List[Dict[str, Any]]:
        rows: List[Dict[str, Any]] = []
        offset = 0
        while True:
            q = uow.client.table(table_name).select("*")
            for col, val in (eq_filters or {}).items():
                q = q.eq(col, val)
            for ord_col in (orders or []):
                q = q.order(ord_col)
            res = q.range(offset, offset + 999).execute()
            batch = getattr(res, "data", None) or []
            rows.extend(batch)
            if len(batch) < 1000:
                break
            offset += 1000
        return rows

    @classmethod
    def _resolve_audit_branch_id(cls, uow: Any, preferred_branch_id: Optional[str] = None) -> Optional[str]:
        if preferred_branch_id:
            return str(preferred_branch_id)
        try:
            branches = cls._fetch_all_rows(uow, "branches")
            for b in branches:
                if "head office" in str(b.get("name") or "").lower():
                    return str(b["branch_id"])
        except Exception:
            pass
        return None

    @classmethod
    def _resolve_branch_meta(
        cls, uow: Any, branch_id: Optional[str], branch_name: Optional[str] = None
    ) -> Tuple[Optional[str], str]:
        bid = str(branch_id).strip() if branch_id else None
        bname = str(branch_name or "").strip()
        try:
            if bid and not bname:
                res = (
                    uow.client.table("branches")
                    .select("branch_id, name")
                    .eq("branch_id", bid)
                    .limit(1)
                    .execute()
                )
                if getattr(res, "data", None):
                    bname = str(res.data[0].get("name") or "")
            elif bname and not bid:
                res = (
                    uow.client.table("branches")
                    .select("branch_id, name")
                    .eq("name", bname)
                    .limit(1)
                    .execute()
                )
                if getattr(res, "data", None):
                    bid = str(res.data[0].get("branch_id") or "")
                    bname = str(res.data[0].get("name") or bname)
        except Exception:
            pass
        return bid, (bname or "Branch")

    @classmethod
    def _ensure_catalog_seeded_in_db(cls, uow: Any) -> bool:
        """
        Ensures asset_catalog_items is populated when the Phase 16 migration tables exist.
        Returns True if DB inventory tables are available, False if migration has not run yet.
        """
        try:
            probe = (
                uow.client.table("asset_catalog_items")
                .select("item_id")
                .limit(1)
                .execute()
            )
            if not getattr(probe, "data", None):
                rows = [
                    {
                        "item_id": r["item_id"],
                        "sku_code": r["sku_code"],
                        "category": r["category"],
                        "item_name": r["item_name"],
                        "cash_and_carry_price": r["cash_and_carry_price"],
                        "easy_buy_60d_price": r["easy_buy_60d_price"],
                        "easy_buy_120d_price": r["easy_buy_120d_price"],
                        "is_custom_price_allowed": bool(r.get("is_custom_price_allowed")),
                        "in_master_pdf": bool(r.get("in_master_pdf", True)),
                        "is_active": True,
                    }
                    for r in MASTER_ASSET_CATALOG_SEED
                ]
                for i in range(0, len(rows), 100):
                    uow.client.table("asset_catalog_items").upsert(
                        rows[i : i + 100], on_conflict="sku_code"
                    ).execute()
            return True
        except Exception as ex:
            if _table_missing_error(ex):
                return False
            return False

    @classmethod
    def _ensure_branch_seeded_in_db(
        cls, uow: Any, branch_id: Optional[str], branch_name: str
    ) -> bool:
        if not branch_id or not cls._ensure_catalog_seeded_in_db(uow):
            return False
        if not _is_ogijo_branch(branch_name):
            return True
        try:
            probe = (
                uow.client.table("branch_asset_inventory")
                .select("inventory_id")
                .eq("branch_id", branch_id)
                .limit(1)
                .execute()
            )
            if not getattr(probe, "data", None):
                inv_rows = [
                    {
                        "branch_id": branch_id,
                        "item_id": r["item_id"],
                        "quantity_on_hand": int(r.get("ogijo_initial_qty") or 0),
                        "quantity_reserved": 0,
                        "branch_item_alias": r.get("ogijo_excel_name"),
                    }
                    for r in MASTER_ASSET_CATALOG_SEED
                    if r.get("ogijo_excel_name") is not None
                ]
                for i in range(0, len(inv_rows), 100):
                    uow.client.table("branch_asset_inventory").upsert(
                        inv_rows[i : i + 100], on_conflict="branch_id,item_id"
                    ).execute()
            return True
        except Exception as ex:
            if _table_missing_error(ex):
                return False
            return False

    @classmethod
    def _load_raw_branch_items(
        cls, uow: Any, branch_id: Optional[str], branch_name: Optional[str] = None
    ) -> Tuple[Optional[str], str, List[Dict[str, Any]], bool]:
        """
        Loads full catalog joined with branch inventory.
        Uses live DB tables when Phase 16 migration is present; otherwise builds
        an authoritative in-memory projection from MASTER_ASSET_CATALOG_SEED + live loan metadata.
        """
        bid, bname = cls._resolve_branch_meta(uow, branch_id, branch_name)
        use_db = cls._ensure_branch_seeded_in_db(uow, bid, bname)

        if use_db and bid:
            try:
                cat_rows = cls._fetch_all_rows(
                    uow,
                    "asset_catalog_items",
                    eq_filters={"is_active": True},
                    orders=["category", "sku_code"],
                )
                inv_rows = cls._fetch_all_rows(
                    uow,
                    "branch_asset_inventory",
                    eq_filters={"branch_id": bid},
                )
                inv_map: Dict[str, Dict[str, Any]] = {
                    str(r["item_id"]): r for r in inv_rows
                }

                merged: List[Dict[str, Any]] = []
                for c in cat_rows:
                    iid = str(c["item_id"])
                    inv = inv_map.get(iid, {})
                    on_hand = int(inv.get("quantity_on_hand") or 0)
                    reserved = int(inv.get("quantity_reserved") or 0)
                    avail = max(0, on_hand - reserved)
                    pricing = _compute_pricing_metrics(
                        c.get("unit_cost_price"),
                        c.get("cash_and_carry_price"),
                        c.get("easy_buy_60d_price"),
                        c.get("easy_buy_120d_price"),
                    )
                    seed_meta = cls._SEED_BY_ID.get(iid, {})
                    merged.append(
                        {
                            "item_id": iid,
                            "sku_code": str(c.get("sku_code") or ""),
                            "category": str(c.get("category") or "UNCATEGORIZED"),
                            "item_name": str(c.get("item_name") or ""),
                            **pricing,
                            "supplier_name": c.get("supplier_name"),
                            "is_custom_price_allowed": bool(c.get("is_custom_price_allowed")),
                            "in_master_pdf": bool(c.get("in_master_pdf", True)),
                            "branch_item_alias": inv.get("branch_item_alias")
                            or seed_meta.get("ogijo_excel_name"),
                            "quantity_on_hand": on_hand,
                            "quantity_reserved": reserved,
                            "quantity_available": avail,
                            "in_stock": avail > 0,
                        }
                    )
                if merged:
                    return bid, bname, merged, True
            except Exception as ex:
                if not _table_missing_error(ex):
                    raise RuntimeError(f"Asset catalog database read failed: {ex}") from ex

        # Fallback projection: MASTER_ASSET_CATALOG_SEED + pending/active/completed loan asset_items
        is_ogijo = _is_ogijo_branch(bname)
        reserved_delta: Dict[str, int] = {}
        disbursed_delta: Dict[str, int] = {}
        try:
            if bid:
                res_loans = (
                    uow.client.table("loans")
                    .select("loan_id, status, product_category, extra_fields, created_at")
                    .eq("branch_id", bid)
                    .eq("product_category", "Asset")
                    .execute()
                )
                for l in (getattr(res_loans, "data", None) or []):
                    st = str(l.get("status") or "").strip().lower()
                    ef = _parse_extra_fields(l.get("extra_fields"))
                    items_meta = ef.get("asset_items") or []
                    if not isinstance(items_meta, list):
                        continue
                    for ai in items_meta:
                        if not isinstance(ai, dict):
                            continue
                        iid = str(ai.get("item_id") or "").strip()
                        qty = int(ai.get("quantity") or 0)
                        if not iid or qty <= 0:
                            continue
                        if st == "pending":
                            reserved_delta[iid] = reserved_delta.get(iid, 0) + qty
                        elif st in ("active", "completed", "disbursed", "approved"):
                            disbursed_delta[iid] = disbursed_delta.get(iid, 0) + qty
        except Exception:
            pass

        fallback_items: List[Dict[str, Any]] = []
        for s in MASTER_ASSET_CATALOG_SEED:
            iid = s["item_id"]
            base_qty = int(s.get("ogijo_initial_qty") or 0) if is_ogijo else 0
            on_hand = max(0, base_qty - disbursed_delta.get(iid, 0))
            reserved = min(on_hand, reserved_delta.get(iid, 0))
            avail = max(0, on_hand - reserved)
            pricing = _compute_pricing_metrics(
                s.get("unit_cost_price", 0.0),
                s["cash_and_carry_price"],
                s["easy_buy_60d_price"],
                s["easy_buy_120d_price"],
            )
            fallback_items.append(
                {
                    "item_id": iid,
                    "sku_code": s["sku_code"],
                    "category": s["category"],
                    "item_name": s["item_name"],
                    **pricing,
                    "supplier_name": s.get("supplier_name"),
                    "is_custom_price_allowed": bool(s.get("is_custom_price_allowed")),
                    "in_master_pdf": bool(s.get("in_master_pdf", True)),
                    "branch_item_alias": s.get("ogijo_excel_name") if is_ogijo else None,
                    "quantity_on_hand": on_hand,
                    "quantity_reserved": reserved,
                    "quantity_available": avail,
                    "in_stock": avail > 0,
                }
            )
        return bid, bname, fallback_items, False

    @classmethod
    def get_branch_asset_catalog(
        cls,
        uow: Any,
        branch_id: Optional[str],
        branch_name: Optional[str] = None,
        category: Optional[str] = None,
        search: Optional[str] = None,
        in_stock_only: bool = False,
    ) -> Dict[str, Any]:
        """Returns branch asset catalog items, category summaries, and valuation metrics."""
        bid, bname, all_items, db_backed = cls._load_raw_branch_items(
            uow, branch_id, branch_name
        )

        # Build category summaries across unfiltered branch items
        cat_stats: Dict[str, Dict[str, Any]] = {
            c: {
                "category": c,
                "catalog_skus": 0,
                "in_stock_skus": 0,
                "units_available": 0,
            }
            for c in MASTER_ASSET_CATEGORIES
        }
        total_on_hand = 0
        total_reserved = 0
        total_avail = 0
        stocked_skus = 0
        val_cash = 0.0
        val_60d = 0.0
        val_120d = 0.0

        for it in all_items:
            cat = it["category"]
            if cat not in cat_stats:
                cat_stats[cat] = {
                    "category": cat,
                    "catalog_skus": 0,
                    "in_stock_skus": 0,
                    "units_available": 0,
                }
            cs = cat_stats[cat]
            cs["catalog_skus"] += 1
            avail = int(it["quantity_available"])
            on_hand = int(it["quantity_on_hand"])
            resv = int(it["quantity_reserved"])

            total_on_hand += on_hand
            total_reserved += resv
            total_avail += avail
            if avail > 0:
                stocked_skus += 1
                cs["in_stock_skus"] += 1
                cs["units_available"] += avail
                val_cash += avail * float(it["cash_and_carry_price"])
                val_60d += avail * float(it["easy_buy_60d_price"])
                val_120d += avail * float(it["easy_buy_120d_price"])

        # Filter returned items
        cat_filter = str(category or "").strip().upper()
        q_filter = str(search or "").strip().lower()
        filtered: List[Dict[str, Any]] = []
        for it in all_items:
            if cat_filter and cat_filter != "ALL" and it["category"].upper() != cat_filter:
                continue
            if in_stock_only and int(it["quantity_available"]) <= 0:
                continue
            if q_filter:
                haystack = " ".join(
                    [
                        it["item_name"],
                        it["sku_code"],
                        it["category"],
                        str(it.get("branch_item_alias") or ""),
                    ]
                ).lower()
                if q_filter not in haystack:
                    continue
            filtered.append(it)

        # Sort in-stock items first inside category order when browsing unfiltered
        cat_order = {c: idx for idx, c in enumerate(MASTER_ASSET_CATEGORIES)}
        filtered.sort(
            key=lambda x: (
                0 if x["quantity_available"] > 0 else 1,
                cat_order.get(x["category"], 999),
                x["item_name"],
            )
        )

        ordered_cats = [
            cat_stats[c]
            for c in MASTER_ASSET_CATEGORIES
            if c in cat_stats and cat_stats[c]["catalog_skus"] > 0
        ] + [
            v
            for k, v in cat_stats.items()
            if k not in MASTER_ASSET_CATEGORIES and v["catalog_skus"] > 0
        ]

        return {
            "branch_id": bid,
            "branch_name": bname,
            "db_backed": db_backed,
            "categories": ordered_cats,
            "items": filtered,
            "summary": {
                "total_catalog_skus": len(all_items),
                "branch_stocked_skus": stocked_skus,
                "total_units_on_hand": total_on_hand,
                "total_units_reserved": total_reserved,
                "total_units_available": total_avail,
                "total_inventory_cash_value": round(val_cash, 2),
                "total_inventory_easy_buy_60d_value": round(val_60d, 2),
                "total_inventory_easy_buy_120d_value": round(val_120d, 2),
            },
        }

    @classmethod
    def validate_selected_assets(
        cls,
        uow: Any,
        branch_id: Optional[str],
        branch_name: Optional[str],
        selected_assets: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Validates stock availability for requested asset line items and computes
        authoritative catalog totals without mutating database state.
        """
        if not selected_assets:
            return {"total_cash_price": 0.0, "asset_items": [], "asset_summary": ""}

        bid, bname, all_items, db_backed = cls._load_raw_branch_items(
            uow, branch_id, branch_name
        )
        by_id = {x["item_id"]: x for x in all_items}
        by_sku = {x["sku_code"]: x for x in all_items}

        # Aggregate quantities per item_id in case UI passes duplicate lines
        qty_by_item: Dict[str, int] = {}
        custom_price_hint: Dict[str, float] = {}
        ordered_ids: List[str] = []

        for raw in selected_assets:
            if hasattr(raw, "model_dump"):
                raw = raw.model_dump()
            iid = str(raw.get("item_id") or "").strip()
            sku = str(raw.get("sku_code") or "").strip()
            item = by_id.get(iid) or by_sku.get(sku)
            if not item:
                raise ValueError(
                    f"Selected asset item '{raw.get('item_name') or iid or sku}' was not found in the Master Asset Catalog."
                )
            resolved_id = item["item_id"]
            qty = int(raw.get("quantity") or 0)
            if qty <= 0:
                raise ValueError(f"Quantity for '{item['item_name']}' must be at least 1.")
            if resolved_id not in qty_by_item:
                qty_by_item[resolved_id] = 0
                ordered_ids.append(resolved_id)
            qty_by_item[resolved_id] += qty
            if raw.get("unit_cash_price") is not None:
                custom_price_hint[resolved_id] = float(raw["unit_cash_price"])

        resolved_lines: List[Dict[str, Any]] = []
        total_cash = 0.0
        total_60d = 0.0
        total_120d = 0.0

        for iid in ordered_ids:
            item = by_id[iid]
            req_qty = qty_by_item[iid]
            avail = int(item["quantity_available"])
            if req_qty > avail:
                raise ValueError(
                    f"Insufficient branch stock for '{item['item_name']}' at {bname}: requested {req_qty}, available {avail}."
                )

            catalog_cash = float(item["cash_and_carry_price"] or 0.0)
            if catalog_cash > 0.0:
                unit_cash = round(catalog_cash, 2)
                unit_60d = round(float(item["easy_buy_60d_price"]), 2)
                unit_120d = round(float(item["easy_buy_120d_price"]), 2)
            else:
                # Legacy Ogijo SKU without a fixed Master PDF price yet
                hinted = float(custom_price_hint.get(iid) or 0.0)
                if hinted <= 0.0:
                    raise ValueError(
                        f"'{item['item_name']}' does not yet have an approved Cash & Carry price configured. Please have the Procurement Officer or Admin set its price or provide an approved unit price."
                    )
                unit_cash = round(hinted, 2)
                unit_60d = round(unit_cash * 1.12, 2)
                unit_120d = round(unit_cash * 1.21, 2)

            line_cash = round(unit_cash * req_qty, 2)
            total_cash += line_cash
            total_60d += round(unit_60d * req_qty, 2)
            total_120d += round(unit_120d * req_qty, 2)

            resolved_lines.append(
                {
                    "item_id": iid,
                    "sku_code": item["sku_code"],
                    "category": item["category"],
                    "item_name": item["item_name"],
                    "quantity": req_qty,
                    "unit_cost_price": round(float(item.get("unit_cost_price") or 0.0), 2),
                    "unit_cash_price": unit_cash,
                    "unit_easy_buy_60d_price": unit_60d,
                    "unit_easy_buy_120d_price": unit_120d,
                    "line_cash_total": line_cash,
                }
            )

        summary_str = ", ".join(f"{ln['quantity']}x {ln['item_name']}" for ln in resolved_lines)
        return {
            "branch_id": bid,
            "branch_name": bname,
            "db_backed": db_backed,
            "total_cash_price": round(total_cash, 2),
            "total_easy_buy_60d_price": round(total_60d, 2),
            "total_easy_buy_120d_price": round(total_120d, 2),
            "asset_items": resolved_lines,
            "asset_summary": summary_str,
        }

    @classmethod
    def reserve_stock_for_loan(
        cls,
        uow: Any,
        branch_id: Optional[str],
        loan_id: str,
        asset_items: List[Dict[str, Any]],
        performed_by: Optional[str] = None,
    ) -> None:
        """Reserves stock in branch_asset_inventory on pending loan submission (if DB tables exist)."""
        if not branch_id or not asset_items:
            return
        try:
            for ln in asset_items:
                iid = str(ln.get("item_id") or "")
                qty = int(ln.get("quantity") or 0)
                if not iid or qty <= 0:
                    continue
                res_inv = (
                    uow.client.table("branch_asset_inventory")
                    .select("inventory_id, quantity_on_hand, quantity_reserved")
                    .eq("branch_id", branch_id)
                    .eq("item_id", iid)
                    .limit(1)
                    .execute()
                )
                if not getattr(res_inv, "data", None):
                    continue
                inv = res_inv.data[0]
                on_hand = int(inv.get("quantity_on_hand") or 0)
                curr_resv = int(inv.get("quantity_reserved") or 0)
                new_resv = min(on_hand, curr_resv + qty)
                uow.client.table("branch_asset_inventory").update(
                    {
                        "quantity_reserved": new_resv,
                        "updated_at": datetime.now(timezone.utc).isoformat(),
                    }
                ).eq("inventory_id", inv["inventory_id"]).execute()

                uow.client.table("asset_stock_movements").insert(
                    {
                        "branch_id": branch_id,
                        "item_id": iid,
                        "loan_id": loan_id,
                        "movement_type": "RESERVE_ON_APPLY",
                        "quantity_delta": 0,
                        "reserved_delta": qty,
                        "balance_after": on_hand,
                        "unit_cash_price": float(ln.get("unit_cash_price") or 0.0),
                        "performed_by": performed_by or "SYSTEM",
                        "remarks": f"Reserved {qty} unit(s) on loan application {loan_id[:8]}",
                    }
                ).execute()
        except Exception as ex:
            if not _table_missing_error(ex):
                print(f"[ASSET CATALOG] Stock reservation warning: {ex}")

    @classmethod
    def commit_disbursed_stock(
        cls,
        uow: Any,
        loan_id: str,
        branch_id: Optional[str],
        extra_fields: Optional[Dict[str, Any]],
        performed_by: Optional[str] = None,
        is_cash_and_carry: bool = False,
        product_type: Optional[str] = None,
    ) -> None:
        """Deducts physical stock on loan disbursement or Cash & Carry sale completion."""
        ef = _parse_extra_fields(extra_fields)
        asset_items = ef.get("asset_items") or []
        if not branch_id or not isinstance(asset_items, list) or not asset_items:
            return
        eff_product_type = product_type or ef.get("product_type")
        try:
            for ln in asset_items:
                if not isinstance(ln, dict):
                    continue
                iid = str(ln.get("item_id") or "")
                qty = int(ln.get("quantity") or 0)
                if not iid or qty <= 0:
                    continue
                res_inv = (
                    uow.client.table("branch_asset_inventory")
                    .select("inventory_id, quantity_on_hand, quantity_reserved")
                    .eq("branch_id", branch_id)
                    .eq("item_id", iid)
                    .limit(1)
                    .execute()
                )
                if not getattr(res_inv, "data", None):
                    continue
                inv = res_inv.data[0]
                on_hand = int(inv.get("quantity_on_hand") or 0)
                curr_resv = int(inv.get("quantity_reserved") or 0)
                new_on_hand = max(0, on_hand - qty)
                new_resv = min(new_on_hand, max(0, curr_resv - qty))
                uow.client.table("branch_asset_inventory").update(
                    {
                        "quantity_on_hand": new_on_hand,
                        "quantity_reserved": new_resv,
                        "updated_at": datetime.now(timezone.utc).isoformat(),
                    }
                ).eq("inventory_id", inv["inventory_id"]).execute()

                unit_cash = round(float(ln.get("unit_cash_price") or 0.0), 2)
                unit_60d = round(float(ln.get("unit_easy_buy_60d_price") or (unit_cash * 1.12)), 2)
                unit_120d = round(float(ln.get("unit_easy_buy_120d_price") or (unit_cash * 1.21)), 2)
                unit_cost = round(float(ln.get("unit_cost_price") or 0.0), 2)
                if unit_cost <= 0.0:
                    try:
                        res_cat = (
                            uow.client.table("asset_catalog_items")
                            .select("unit_cost_price")
                            .eq("item_id", iid)
                            .limit(1)
                            .execute()
                        )
                        if getattr(res_cat, "data", None):
                            unit_cost = round(float(res_cat.data[0].get("unit_cost_price") or 0.0), 2)
                    except Exception:
                        pass
                unit_sell = _resolve_package_selling_price(
                    unit_cash,
                    unit_60d,
                    unit_120d,
                    product_type=eff_product_type,
                    is_cash_and_carry=is_cash_and_carry,
                )

                uow.client.table("asset_stock_movements").insert(
                    {
                        "branch_id": branch_id,
                        "item_id": iid,
                        "loan_id": loan_id,
                        "movement_type": "DEDUCT_ON_DISBURSE",
                        "quantity_delta": -qty,
                        "reserved_delta": -min(curr_resv, qty),
                        "balance_after": new_on_hand,
                        "unit_cost_price": unit_cost,
                        "unit_cash_price": unit_cash,
                        "unit_selling_price": unit_sell,
                        "reference_code": loan_id[:8],
                        "performed_by": performed_by or "SYSTEM",
                        "remarks": (
                            f"Cash & Carry sale of {qty} unit(s)"
                            if is_cash_and_carry
                            else f"Asset loan disbursement ({loan_id[:8]}) of {qty} unit(s)"
                        ),
                    }
                ).execute()
        except Exception as ex:
            if not _table_missing_error(ex):
                print(f"[ASSET CATALOG] Stock disbursement deduction warning: {ex}")

    @classmethod
    def release_reserved_stock(
        cls,
        uow: Any,
        loan_id: str,
        branch_id: Optional[str],
        extra_fields: Optional[Dict[str, Any]],
        performed_by: Optional[str] = None,
        reason: str = "",
    ) -> None:
        """Releases reserved branch stock back to available inventory when a pending loan is rejected."""
        ef = _parse_extra_fields(extra_fields)
        asset_items = ef.get("asset_items") or []
        if not branch_id or not isinstance(asset_items, list) or not asset_items:
            return
        try:
            for ln in asset_items:
                if not isinstance(ln, dict):
                    continue
                iid = str(ln.get("item_id") or "")
                qty = int(ln.get("quantity") or 0)
                if not iid or qty <= 0:
                    continue
                res_inv = (
                    uow.client.table("branch_asset_inventory")
                    .select("inventory_id, quantity_on_hand, quantity_reserved")
                    .eq("branch_id", branch_id)
                    .eq("item_id", iid)
                    .limit(1)
                    .execute()
                )
                if not getattr(res_inv, "data", None):
                    continue
                inv = res_inv.data[0]
                on_hand = int(inv.get("quantity_on_hand") or 0)
                curr_resv = int(inv.get("quantity_reserved") or 0)
                released = min(curr_resv, qty)
                new_resv = max(0, curr_resv - qty)
                uow.client.table("branch_asset_inventory").update(
                    {
                        "quantity_reserved": new_resv,
                        "updated_at": datetime.now(timezone.utc).isoformat(),
                    }
                ).eq("inventory_id", inv["inventory_id"]).execute()

                uow.client.table("asset_stock_movements").insert(
                    {
                        "branch_id": branch_id,
                        "item_id": iid,
                        "loan_id": loan_id,
                        "movement_type": "RELEASE_ON_REJECT",
                        "quantity_delta": 0,
                        "reserved_delta": -released,
                        "balance_after": on_hand,
                        "unit_cash_price": float(ln.get("unit_cash_price") or 0.0),
                        "performed_by": performed_by or "SYSTEM",
                        "remarks": f"Released {released} unit(s) after loan rejection: {reason or 'Not approved'}",
                    }
                ).execute()
        except Exception as ex:
            if not _table_missing_error(ex):
                print(f"[ASSET CATALOG] Stock release warning: {ex}")

    @classmethod
    def adjust_branch_inventory(
        cls,
        uow: Any,
        branch_id: Optional[str],
        branch_name: Optional[str],
        item_id: str,
        quantity_delta: int = 0,
        new_cash_price: Optional[float] = None,
        new_cost_price: Optional[float] = None,
        supplier_name: Optional[str] = None,
        reference_code: Optional[str] = None,
        remarks: str = "",
        performed_by: str = "SYSTEM",
    ) -> Dict[str, Any]:
        """Allows Procurement Officer / Admin to restock physical units, adjust counts, or update cost & selling prices."""
        bid, bname, all_items, db_backed = cls._load_raw_branch_items(
            uow, branch_id, branch_name
        )
        if not bid:
            raise ValueError("Target branch ID is required to adjust asset inventory.")

        target = next(
            (x for x in all_items if x["item_id"] == item_id or x["sku_code"] == item_id),
            None,
        )
        if not target:
            raise ValueError(f"Asset item '{item_id}' not found in catalog.")

        curr_on_hand = int(target["quantity_on_hand"])
        curr_resv = int(target["quantity_reserved"])
        new_on_hand = curr_on_hand + int(quantity_delta)
        if new_on_hand < 0:
            raise ValueError(
                f"Cannot reduce stock of '{target['item_name']}' below 0 (current on hand: {curr_on_hand})."
            )
        if new_on_hand < curr_resv:
            raise ValueError(
                f"Cannot set on-hand stock ({new_on_hand}) below currently reserved units ({curr_resv}) for pending loans."
            )

        updated_cost = float(target.get("unit_cost_price") or 0.0)
        if new_cost_price is not None:
            if float(new_cost_price) < 0:
                raise ValueError("Unit cost price cannot be negative.")
            updated_cost = round(float(new_cost_price), 2)

        updated_cash = float(target["cash_and_carry_price"])
        updated_60d = float(target["easy_buy_60d_price"])
        updated_120d = float(target["easy_buy_120d_price"])
        if new_cash_price is not None:
            if float(new_cash_price) < 0:
                raise ValueError("Cash and Carry price cannot be negative.")
            updated_cash = round(float(new_cash_price), 2)
            updated_60d = round(updated_cash * 1.12, 2)
            updated_120d = round(updated_cash * 1.21, 2)

        updated_supplier = (
            supplier_name.strip() if isinstance(supplier_name, str) and supplier_name.strip() else target.get("supplier_name")
        )

        if not db_backed:
            raise RuntimeError(
                "Asset inventory tables are not yet initialized in Supabase. Please execute database/migrations/phase16_asset_catalog_and_branch_inventory.sql first."
            )

        now_iso = datetime.now(timezone.utc).isoformat()
        cat_patch: Dict[str, Any] = {}
        if new_cash_price is not None:
            cat_patch["cash_and_carry_price"] = updated_cash
            cat_patch["easy_buy_60d_price"] = updated_60d
            cat_patch["easy_buy_120d_price"] = updated_120d
        if new_cost_price is not None:
            cat_patch["unit_cost_price"] = updated_cost
        if supplier_name is not None:
            cat_patch["supplier_name"] = updated_supplier
        if cat_patch:
            cat_patch["updated_at"] = now_iso
            uow.client.table("asset_catalog_items").update(cat_patch).eq(
                "item_id", target["item_id"]
            ).execute()

        if quantity_delta != 0 or new_cost_price is not None or new_cash_price is not None:
            uow.client.table("branch_asset_inventory").upsert(
                {
                    "branch_id": bid,
                    "item_id": target["item_id"],
                    "quantity_on_hand": new_on_hand,
                    "quantity_reserved": curr_resv,
                    "branch_item_alias": target.get("branch_item_alias"),
                    "updated_at": now_iso,
                },
                on_conflict="branch_id,item_id",
            ).execute()

        if quantity_delta != 0 or new_cash_price is not None or new_cost_price is not None:
            if quantity_delta > 0:
                m_type = "RESTOCK"
            elif quantity_delta == 0 and (new_cash_price is not None or new_cost_price is not None):
                m_type = "PRICE_UPDATE"
            else:
                m_type = "ADJUSTMENT"
            uow.client.table("asset_stock_movements").insert(
                {
                    "branch_id": bid,
                    "item_id": target["item_id"],
                    "movement_type": m_type,
                    "quantity_delta": int(quantity_delta),
                    "reserved_delta": 0,
                    "balance_after": new_on_hand,
                    "unit_cost_price": updated_cost,
                    "unit_cash_price": updated_cash,
                    "unit_selling_price": updated_cash,
                    "reference_code": (reference_code or "").strip() or None,
                    "performed_by": performed_by,
                    "remarks": remarks
                    or (
                        f"Updated pricing (Cost ₦{updated_cost:,.2f}, Cash ₦{updated_cash:,.2f})"
                        if m_type == "PRICE_UPDATE"
                        else f"Stock adjusted by {quantity_delta:+d} ({bname})"
                    ),
                }
            ).execute()

        pricing = _compute_pricing_metrics(updated_cost, updated_cash, updated_60d, updated_120d)
        return {
            **target,
            **pricing,
            "supplier_name": updated_supplier,
            "quantity_on_hand": new_on_hand,
            "quantity_reserved": curr_resv,
            "quantity_available": max(0, new_on_hand - curr_resv),
            "in_stock": (new_on_hand - curr_resv) > 0,
        }

    # =========================================================================
    # PROCUREMENT OFFICER & ASSET MANAGER INSTITUTION-WIDE HUB METHODS
    # =========================================================================

    @classmethod
    def _load_institution_snapshot(
        cls, uow: Any
    ) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]], List[Dict[str, Any]], bool]:
        """Loads active branches, catalog items, all branch inventories, and movements."""
        branches_raw = cls._fetch_all_rows(uow, "branches")
        branches = [
            {"branch_id": str(b["branch_id"]), "name": str(b.get("name") or "Branch")}
            for b in branches_raw
            if b.get("branch_id") and b.get("is_active", True) is not False
        ]
        branches.sort(key=lambda b: (1 if "head" in b["name"].lower() else 0, b["name"]))

        db_backed = cls._ensure_catalog_seeded_in_db(uow)
        if db_backed:
            for b in branches:
                if _is_ogijo_branch(b["name"]):
                    cls._ensure_branch_seeded_in_db(uow, b["branch_id"], b["name"])

            cat_rows = cls._fetch_all_rows(
                uow, "asset_catalog_items", eq_filters={"is_active": True}, orders=["category", "sku_code"]
            )
            inv_rows = cls._fetch_all_rows(uow, "branch_asset_inventory")
            mov_rows = cls._fetch_all_rows(uow, "asset_stock_movements")
            return branches, cat_rows, inv_rows, mov_rows, True

        # Fallback read-only projection if asset tables are absent
        ogijo_b = next((b for b in branches if _is_ogijo_branch(b["name"])), None)
        cat_rows = []
        inv_rows = []
        for s in MASTER_ASSET_CATALOG_SEED:
            cat_rows.append(
                {
                    "item_id": s["item_id"],
                    "sku_code": s["sku_code"],
                    "category": s["category"],
                    "item_name": s["item_name"],
                    "unit_cost_price": float(s.get("unit_cost_price") or 0.0),
                    "cash_and_carry_price": float(s["cash_and_carry_price"]),
                    "easy_buy_60d_price": float(s["easy_buy_60d_price"]),
                    "easy_buy_120d_price": float(s["easy_buy_120d_price"]),
                    "supplier_name": s.get("supplier_name"),
                    "is_custom_price_allowed": bool(s.get("is_custom_price_allowed")),
                    "in_master_pdf": bool(s.get("in_master_pdf", True)),
                    "is_active": True,
                }
            )
            if ogijo_b and s.get("ogijo_excel_name") is not None:
                inv_rows.append(
                    {
                        "branch_id": ogijo_b["branch_id"],
                        "item_id": s["item_id"],
                        "quantity_on_hand": int(s.get("ogijo_initial_qty") or 0),
                        "quantity_reserved": 0,
                        "branch_item_alias": s.get("ogijo_excel_name"),
                    }
                )
        return branches, cat_rows, inv_rows, [], False

    @classmethod
    def get_procurement_overview(
        cls, uow: Any, branch_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Returns institution-wide or branch-filtered inventory valuation, cost readiness, and P&L analytics."""
        branches, cat_rows, inv_rows, mov_rows, db_backed = cls._load_institution_snapshot(uow)
        branch_map = {b["branch_id"]: b["name"] for b in branches}
        cat_map: Dict[str, Dict[str, Any]] = {}
        cost_configured_skus = 0
        cost_pending_skus = 0
        custom_price_skus = 0
        categories_set: List[str] = []

        for c in cat_rows:
            iid = str(c["item_id"])
            pricing = _compute_pricing_metrics(
                c.get("unit_cost_price"),
                c.get("cash_and_carry_price"),
                c.get("easy_buy_60d_price"),
                c.get("easy_buy_120d_price"),
            )
            cat_name = str(c.get("category") or "UNCATEGORIZED")
            if cat_name not in categories_set:
                categories_set.append(cat_name)
            if pricing["has_cost_price"]:
                cost_configured_skus += 1
            else:
                cost_pending_skus += 1
            if bool(c.get("is_custom_price_allowed")):
                custom_price_skus += 1
            cat_map[iid] = {
                "item_id": iid,
                "sku_code": str(c.get("sku_code") or ""),
                "category": cat_name,
                "item_name": str(c.get("item_name") or ""),
                "supplier_name": c.get("supplier_name"),
                **pricing,
            }

        target_bid = str(branch_id).strip() if branch_id and str(branch_id).strip().upper() != "ALL" else None

        # Per-branch inventory valuation & stock counts
        branch_acc: Dict[str, Dict[str, Any]] = {
            b["branch_id"]: {
                "branch_id": b["branch_id"],
                "branch_name": b["name"],
                "stocked_skus": 0,
                "units_on_hand": 0,
                "units_reserved": 0,
                "units_available": 0,
                "inventory_cost_value": 0.0,
                "inventory_cash_value": 0.0,
                "inventory_60d_value": 0.0,
                "projected_retail_profit": 0.0,
                "cost_configured_units": 0,
                "cost_pending_units": 0,
            }
            for b in branches
        }

        item_stock_acc: Dict[str, Dict[str, int]] = {}
        for inv in inv_rows:
            bid = str(inv.get("branch_id") or "")
            iid = str(inv.get("item_id") or "")
            c_meta = cat_map.get(iid)
            if not c_meta or bid not in branch_acc:
                continue
            on_hand = int(inv.get("quantity_on_hand") or 0)
            reserved = int(inv.get("quantity_reserved") or 0)
            avail = max(0, on_hand - reserved)

            ba = branch_acc[bid]
            if on_hand > 0:
                ba["stocked_skus"] += 1
            ba["units_on_hand"] += on_hand
            ba["units_reserved"] += reserved
            ba["units_available"] += avail
            ba["inventory_cost_value"] += on_hand * c_meta["unit_cost_price"]
            ba["inventory_cash_value"] += on_hand * c_meta["cash_and_carry_price"]
            ba["inventory_60d_value"] += on_hand * c_meta["easy_buy_60d_price"]
            if c_meta["has_cost_price"]:
                ba["cost_configured_units"] += on_hand
                ba["projected_retail_profit"] += on_hand * (
                    c_meta["cash_and_carry_price"] - c_meta["unit_cost_price"]
                )
            else:
                ba["cost_pending_units"] += on_hand

            if target_bid is None or bid == target_bid:
                acc = item_stock_acc.setdefault(iid, {"on_hand": 0, "reserved": 0, "available": 0})
                acc["on_hand"] += on_hand
                acc["reserved"] += reserved
                acc["available"] += avail

        for ba in branch_acc.values():
            ba["inventory_cost_value"] = round(ba["inventory_cost_value"], 2)
            ba["inventory_cash_value"] = round(ba["inventory_cash_value"], 2)
            ba["inventory_60d_value"] = round(ba["inventory_60d_value"], 2)
            ba["projected_retail_profit"] = round(ba["projected_retail_profit"], 2)

        scoped_branches = (
            [branch_acc[target_bid]] if target_bid and target_bid in branch_acc else list(branch_acc.values())
        )
        inv_summary = {
            "stocked_skus": sum(x["stocked_skus"] for x in scoped_branches),
            "units_on_hand": sum(x["units_on_hand"] for x in scoped_branches),
            "units_reserved": sum(x["units_reserved"] for x in scoped_branches),
            "units_available": sum(x["units_available"] for x in scoped_branches),
            "inventory_cost_value": round(sum(x["inventory_cost_value"] for x in scoped_branches), 2),
            "inventory_cash_value": round(sum(x["inventory_cash_value"] for x in scoped_branches), 2),
            "inventory_60d_value": round(sum(x["inventory_60d_value"] for x in scoped_branches), 2),
            "projected_retail_profit": round(sum(x["projected_retail_profit"] for x in scoped_branches), 2),
            "cost_configured_units": sum(x["cost_configured_units"] for x in scoped_branches),
            "cost_pending_units": sum(x["cost_pending_units"] for x in scoped_branches),
        }

        # Realized Sales & P&L Calculations from Movements
        units_sold = 0
        units_restocked = 0
        units_transferred = 0
        write_off_units = 0
        realized_cash_base_rev = 0.0
        realized_pkg_rev = 0.0
        realized_financing_markup = 0.0
        realized_cogs = 0.0
        realized_trading_profit = 0.0
        realized_costed_units = 0
        realized_uncosted_units = 0
        write_off_cost_loss = 0.0
        write_off_retail_loss = 0.0

        item_pnl_acc: Dict[str, Dict[str, Any]] = {}

        for m in mov_rows:
            mbid = str(m.get("branch_id") or "")
            if target_bid and mbid != target_bid:
                continue
            iid = str(m.get("item_id") or "")
            c_meta = cat_map.get(iid)
            m_type = str(m.get("movement_type") or "")
            q_delta = int(m.get("quantity_delta") or 0)
            qty_abs = abs(q_delta)

            if m_type == "RESTOCK" and q_delta > 0:
                units_restocked += q_delta
            elif m_type in ("TRANSFER_OUT", "TRANSFER_IN"):
                units_transferred += qty_abs
            elif m_type == "DEDUCT_ON_DISBURSE" and qty_abs > 0:
                m_cost = float(m.get("unit_cost_price") or (c_meta["unit_cost_price"] if c_meta else 0.0) or 0.0)
                m_cash = float(m.get("unit_cash_price") or (c_meta["cash_and_carry_price"] if c_meta else 0.0) or 0.0)
                m_sell = float(m.get("unit_selling_price") or m_cash or 0.0)

                units_sold += qty_abs
                cash_rev = m_cash * qty_abs
                pkg_rev = m_sell * qty_abs
                fin_markup = max(0.0, pkg_rev - cash_rev)
                realized_cash_base_rev += cash_rev
                realized_pkg_rev += pkg_rev
                realized_financing_markup += fin_markup

                ip = item_pnl_acc.setdefault(
                    iid,
                    {
                        "units_sold": 0,
                        "write_off_units": 0,
                        "realized_package_revenue": 0.0,
                        "realized_cogs": 0.0,
                        "realized_trading_profit": 0.0,
                        "realized_financing_markup": 0.0,
                        "write_off_loss": 0.0,
                    },
                )
                ip["units_sold"] += qty_abs
                ip["realized_package_revenue"] += pkg_rev
                ip["realized_financing_markup"] += fin_markup

                if m_cost > 0:
                    cogs_line = m_cost * qty_abs
                    trade_prof_line = cash_rev - cogs_line
                    realized_cogs += cogs_line
                    realized_trading_profit += trade_prof_line
                    realized_costed_units += qty_abs
                    ip["realized_cogs"] += cogs_line
                    ip["realized_trading_profit"] += trade_prof_line
                else:
                    realized_uncosted_units += qty_abs

            elif m_type == "DAMAGE_WRITE_OFF" and qty_abs > 0:
                w_cost = float(m.get("unit_cost_price") or (c_meta["unit_cost_price"] if c_meta else 0.0) or 0.0)
                w_cash = float(m.get("unit_cash_price") or (c_meta["cash_and_carry_price"] if c_meta else 0.0) or 0.0)
                write_off_units += qty_abs
                write_off_cost_loss += w_cost * qty_abs
                write_off_retail_loss += w_cash * qty_abs

                ip = item_pnl_acc.setdefault(
                    iid,
                    {
                        "units_sold": 0,
                        "write_off_units": 0,
                        "realized_package_revenue": 0.0,
                        "realized_cogs": 0.0,
                        "realized_trading_profit": 0.0,
                        "realized_financing_markup": 0.0,
                        "write_off_loss": 0.0,
                    },
                )
                ip["write_off_units"] += qty_abs
                ip["write_off_loss"] += w_cost * qty_abs

        gross_profit = round(realized_trading_profit + realized_financing_markup, 2)
        net_realized_profit = round(gross_profit - write_off_cost_loss, 2)
        margin_pct = (
            round((net_realized_profit / realized_pkg_rev) * 100.0, 2)
            if realized_pkg_rev > 0 and realized_costed_units > 0
            else 0.0
        )

        # Build per-item breakdown (include sold, written-off, costed, or in-stock items)
        profit_breakdown: List[Dict[str, Any]] = []
        for iid, c_meta in cat_map.items():
            stk = item_stock_acc.get(iid, {"on_hand": 0, "reserved": 0, "available": 0})
            ip = item_pnl_acc.get(iid)
            if not ip and not c_meta["has_cost_price"] and stk["on_hand"] <= 0:
                continue
            ip_sold = ip["units_sold"] if ip else 0
            ip_wo = ip["write_off_units"] if ip else 0
            ip_rev = round(ip["realized_package_revenue"], 2) if ip else 0.0
            ip_cogs = round(ip["realized_cogs"], 2) if ip else 0.0
            ip_net = round(
                (ip["realized_trading_profit"] + ip["realized_financing_markup"] - ip["write_off_loss"])
                if ip
                else 0.0,
                2,
            )
            profit_breakdown.append(
                {
                    "item_id": iid,
                    "sku_code": c_meta["sku_code"],
                    "item_name": c_meta["item_name"],
                    "category": c_meta["category"],
                    "supplier_name": c_meta["supplier_name"],
                    "unit_cost_price": c_meta["unit_cost_price"],
                    "has_cost_price": c_meta["has_cost_price"],
                    "cash_and_carry_price": c_meta["cash_and_carry_price"],
                    "easy_buy_60d_price": c_meta["easy_buy_60d_price"],
                    "easy_buy_120d_price": c_meta["easy_buy_120d_price"],
                    "retail_margin_amount": c_meta["retail_margin_amount"],
                    "retail_margin_pct": c_meta["retail_margin_pct"],
                    "on_hand": stk["on_hand"],
                    "available": stk["available"],
                    "units_sold": ip_sold,
                    "write_off_units": ip_wo,
                    "realized_package_revenue": ip_rev,
                    "realized_cogs": ip_cogs,
                    "realized_net_profit": ip_net,
                }
            )
        profit_breakdown.sort(
            key=lambda x: (-x["units_sold"], -x["on_hand"], x["item_name"])
        )

        # Latest 60 movements sorted descending
        filtered_movs = [
            m for m in mov_rows if target_bid is None or str(m.get("branch_id") or "") == target_bid
        ]
        filtered_movs.sort(key=lambda m: str(m.get("created_at") or ""), reverse=True)
        recent_movements: List[Dict[str, Any]] = []
        for m in filtered_movs[:60]:
            iid = str(m.get("item_id") or "")
            c_meta = cat_map.get(iid, {})
            cp_bid = str(m.get("counterparty_branch_id") or "")
            recent_movements.append(
                {
                    "movement_id": str(m.get("movement_id") or ""),
                    "created_at": str(m.get("created_at") or ""),
                    "branch_id": str(m.get("branch_id") or ""),
                    "branch_name": branch_map.get(str(m.get("branch_id") or ""), "Branch"),
                    "counterparty_branch_name": branch_map.get(cp_bid) if cp_bid else None,
                    "item_id": iid,
                    "sku_code": c_meta.get("sku_code", ""),
                    "item_name": c_meta.get("item_name", iid),
                    "category": c_meta.get("category", ""),
                    "movement_type": str(m.get("movement_type") or ""),
                    "quantity_delta": int(m.get("quantity_delta") or 0),
                    "reserved_delta": int(m.get("reserved_delta") or 0),
                    "balance_after": int(m.get("balance_after") or 0),
                    "unit_cost_price": round(float(m.get("unit_cost_price") or 0.0), 2),
                    "unit_cash_price": round(float(m.get("unit_cash_price") or 0.0), 2),
                    "unit_selling_price": round(float(m.get("unit_selling_price") or m.get("unit_cash_price") or 0.0), 2),
                    "reference_code": m.get("reference_code"),
                    "performed_by": str(m.get("performed_by") or "SYSTEM"),
                    "remarks": str(m.get("remarks") or ""),
                }
            )

        ordered_cats = [c for c in MASTER_ASSET_CATEGORIES if c in categories_set] + [
            c for c in categories_set if c not in MASTER_ASSET_CATEGORIES
        ]
        return {
            "db_backed": db_backed,
            "selected_branch_id": target_bid,
            "branches": branches,
            "categories": ordered_cats,
            "catalog_readiness": {
                "total_catalog_skus": len(cat_map),
                "cost_configured_skus": cost_configured_skus,
                "cost_pending_skus": cost_pending_skus,
                "custom_price_skus": custom_price_skus,
            },
            "inventory_summary": inv_summary,
            "branch_summaries": list(branch_acc.values()),
            "pnl_summary": {
                "units_sold": units_sold,
                "units_restocked": units_restocked,
                "units_transferred": units_transferred,
                "write_off_units": write_off_units,
                "realized_costed_units": realized_costed_units,
                "realized_uncosted_units": realized_uncosted_units,
                "realized_cash_base_revenue": round(realized_cash_base_rev, 2),
                "realized_package_revenue": round(realized_pkg_rev, 2),
                "realized_financing_markup": round(realized_financing_markup, 2),
                "realized_cogs": round(realized_cogs, 2),
                "realized_trading_profit": round(realized_trading_profit, 2),
                "gross_profit": gross_profit,
                "write_off_cost_loss": round(write_off_cost_loss, 2),
                "write_off_retail_loss": round(write_off_retail_loss, 2),
                "net_realized_profit": net_realized_profit,
                "net_margin_pct": margin_pct,
            },
            "profit_breakdown_by_item": profit_breakdown,
            "recent_movements": recent_movements,
        }

    @classmethod
    def get_multi_branch_stock_matrix(
        cls,
        uow: Any,
        category: Optional[str] = None,
        search: Optional[str] = None,
        in_stock_only: bool = False,
    ) -> Dict[str, Any]:
        """Returns SKU-by-branch matrix across all active branches for procurement control."""
        branches, cat_rows, inv_rows, _, db_backed = cls._load_institution_snapshot(uow)
        inv_by_item_branch: Dict[Tuple[str, str], Dict[str, Any]] = {}
        for inv in inv_rows:
            inv_by_item_branch[(str(inv["item_id"]), str(inv["branch_id"]))] = inv

        cat_filter = str(category or "").strip().upper()
        q_filter = str(search or "").strip().lower()
        cat_order = {c: idx for idx, c in enumerate(MASTER_ASSET_CATEGORIES)}

        items_out: List[Dict[str, Any]] = []
        categories_set: List[str] = []

        for c in cat_rows:
            iid = str(c["item_id"])
            cat_name = str(c.get("category") or "UNCATEGORIZED")
            if cat_name not in categories_set:
                categories_set.append(cat_name)
            pricing = _compute_pricing_metrics(
                c.get("unit_cost_price"),
                c.get("cash_and_carry_price"),
                c.get("easy_buy_60d_price"),
                c.get("easy_buy_120d_price"),
            )

            branch_stocks: Dict[str, Dict[str, Any]] = {}
            tot_on_hand = 0
            tot_resv = 0
            tot_avail = 0
            for b in branches:
                bid = b["branch_id"]
                inv = inv_by_item_branch.get((iid, bid), {})
                oh = int(inv.get("quantity_on_hand") or 0)
                rsv = int(inv.get("quantity_reserved") or 0)
                av = max(0, oh - rsv)
                tot_on_hand += oh
                tot_resv += rsv
                tot_avail += av
                branch_stocks[bid] = {
                    "quantity_on_hand": oh,
                    "quantity_reserved": rsv,
                    "quantity_available": av,
                }

            if cat_filter and cat_filter != "ALL" and cat_name.upper() != cat_filter:
                continue
            if in_stock_only and tot_avail <= 0:
                continue
            if q_filter:
                hay = f"{c.get('item_name', '')} {c.get('sku_code', '')} {cat_name} {c.get('supplier_name') or ''}".lower()
                if q_filter not in hay:
                    continue

            items_out.append(
                {
                    "item_id": iid,
                    "sku_code": str(c.get("sku_code") or ""),
                    "category": cat_name,
                    "item_name": str(c.get("item_name") or ""),
                    "supplier_name": c.get("supplier_name"),
                    "is_custom_price_allowed": bool(c.get("is_custom_price_allowed")),
                    "in_master_pdf": bool(c.get("in_master_pdf", True)),
                    **pricing,
                    "total_on_hand": tot_on_hand,
                    "total_reserved": tot_resv,
                    "total_available": tot_avail,
                    "branch_stocks": branch_stocks,
                }
            )

        items_out.sort(
            key=lambda x: (
                0 if x["total_available"] > 0 else 1,
                cat_order.get(x["category"], 999),
                x["item_name"],
            )
        )
        ordered_cats = [c for c in MASTER_ASSET_CATEGORIES if c in categories_set] + [
            c for c in categories_set if c not in MASTER_ASSET_CATEGORIES
        ]
        return {
            "db_backed": db_backed,
            "branches": branches,
            "categories": ordered_cats,
            "items": items_out,
        }

    @classmethod
    def receive_stock_batch(
        cls,
        uow: Any,
        branch_id: str,
        items: List[Dict[str, Any]],
        reference_code: str = "",
        supplier_name: str = "",
        remarks: str = "",
        performed_by: str = "SYSTEM",
    ) -> Dict[str, Any]:
        """Records a multi-item supplier GRN delivery, updates Weighted Average Cost, and logs RESTOCK movements."""
        if not branch_id:
            raise ValueError("Destination branch_id is required.")
        if not items:
            raise ValueError("At least one asset item must be included in the stock receipt.")

        bid, bname = cls._resolve_branch_meta(uow, branch_id)
        branches, cat_rows, inv_rows, _, db_backed = cls._load_institution_snapshot(uow)
        if not db_backed:
            raise RuntimeError("Asset inventory tables are not initialized in Supabase.")
        if bid not in {b["branch_id"] for b in branches}:
            raise ValueError(f"Destination branch '{branch_id}' was not found.")

        cat_by_id = {str(c["item_id"]): c for c in cat_rows}
        cat_by_sku = {str(c["sku_code"]): c for c in cat_rows}
        total_oh_by_item: Dict[str, int] = {}
        branch_inv_by_item: Dict[str, Dict[str, Any]] = {}
        for inv in inv_rows:
            iid = str(inv["item_id"])
            total_oh_by_item[iid] = total_oh_by_item.get(iid, 0) + int(inv.get("quantity_on_hand") or 0)
            if str(inv.get("branch_id") or "") == bid:
                branch_inv_by_item[iid] = inv

        now_iso = datetime.now(timezone.utc).isoformat()
        clean_ref = (reference_code or "").strip() or None
        clean_supplier = (supplier_name or "").strip() or None
        processed: List[Dict[str, Any]] = []
        total_units_received = 0
        total_cost_value = 0.0

        for line in items:
            key = str(line.get("item_id") or line.get("sku_code") or "").strip()
            cat = cat_by_id.get(key) or cat_by_sku.get(key)
            if not cat:
                raise ValueError(f"Catalog item '{key}' was not found.")
            iid = str(cat["item_id"])
            qty_rec = int(line.get("quantity_received") or 0)
            if qty_rec <= 0:
                raise ValueError(f"Quantity received for '{cat['item_name']}' must be greater than 0.")

            in_cost = line.get("unit_cost_price")
            in_cash = line.get("new_cash_price")
            existing_cost = float(cat.get("unit_cost_price") or 0.0)
            existing_oh_all = int(total_oh_by_item.get(iid, 0))

            if in_cost is not None and float(in_cost) < 0:
                raise ValueError("Unit cost price cannot be negative.")
            if in_cash is not None and float(in_cash) < 0:
                raise ValueError("Cash & Carry selling price cannot be negative.")

            updated_cost = existing_cost
            if in_cost is not None and float(in_cost) > 0:
                c_val = float(in_cost)
                if existing_cost > 0 and existing_oh_all > 0:
                    updated_cost = round(
                        ((existing_oh_all * existing_cost) + (qty_rec * c_val))
                        / (existing_oh_all + qty_rec),
                        2,
                    )
                else:
                    updated_cost = round(c_val, 2)

            updated_cash = float(cat.get("cash_and_carry_price") or 0.0)
            updated_60d = float(cat.get("easy_buy_60d_price") or round(updated_cash * 1.12, 2))
            updated_120d = float(cat.get("easy_buy_120d_price") or round(updated_cash * 1.21, 2))
            if in_cash is not None and float(in_cash) > 0:
                updated_cash = round(float(in_cash), 2)
                updated_60d = round(updated_cash * 1.12, 2)
                updated_120d = round(updated_cash * 1.21, 2)

            line_supplier = clean_supplier or cat.get("supplier_name")
            cat_patch: Dict[str, Any] = {}
            if updated_cost != existing_cost:
                cat_patch["unit_cost_price"] = updated_cost
            if in_cash is not None and float(in_cash) > 0:
                cat_patch["cash_and_carry_price"] = updated_cash
                cat_patch["easy_buy_60d_price"] = updated_60d
                cat_patch["easy_buy_120d_price"] = updated_120d
            if line_supplier and line_supplier != cat.get("supplier_name"):
                cat_patch["supplier_name"] = line_supplier
            if cat_patch:
                cat_patch["updated_at"] = now_iso
                uow.client.table("asset_catalog_items").update(cat_patch).eq("item_id", iid).execute()
                cat["unit_cost_price"] = updated_cost
                cat["cash_and_carry_price"] = updated_cash
                cat["easy_buy_60d_price"] = updated_60d
                cat["easy_buy_120d_price"] = updated_120d

            cur_b_inv = branch_inv_by_item.get(iid, {})
            cur_b_oh = int(cur_b_inv.get("quantity_on_hand") or 0)
            cur_b_rsv = int(cur_b_inv.get("quantity_reserved") or 0)
            new_b_oh = cur_b_oh + qty_rec
            total_oh_by_item[iid] = existing_oh_all + qty_rec

            uow.client.table("branch_asset_inventory").upsert(
                {
                    "branch_id": bid,
                    "item_id": iid,
                    "quantity_on_hand": new_b_oh,
                    "quantity_reserved": cur_b_rsv,
                    "branch_item_alias": cur_b_inv.get("branch_item_alias"),
                    "updated_at": now_iso,
                },
                on_conflict="branch_id,item_id",
            ).execute()
            branch_inv_by_item[iid] = {
                "branch_id": bid,
                "item_id": iid,
                "quantity_on_hand": new_b_oh,
                "quantity_reserved": cur_b_rsv,
                "branch_item_alias": cur_b_inv.get("branch_item_alias"),
            }

            line_cost_for_mov = round(float(in_cost), 2) if (in_cost is not None and float(in_cost) > 0) else updated_cost
            uow.client.table("asset_stock_movements").insert(
                {
                    "branch_id": bid,
                    "item_id": iid,
                    "movement_type": "RESTOCK",
                    "quantity_delta": qty_rec,
                    "reserved_delta": 0,
                    "balance_after": new_b_oh,
                    "unit_cost_price": line_cost_for_mov,
                    "unit_cash_price": updated_cash,
                    "unit_selling_price": updated_cash,
                    "reference_code": clean_ref,
                    "performed_by": performed_by,
                    "remarks": (remarks or "").strip()
                    or f"Received {qty_rec} unit(s) at {bname}" + (f" from {line_supplier}" if line_supplier else ""),
                }
            ).execute()

            total_units_received += qty_rec
            total_cost_value += qty_rec * line_cost_for_mov
            processed.append(
                {
                    "item_id": iid,
                    "sku_code": cat["sku_code"],
                    "item_name": cat["item_name"],
                    "quantity_received": qty_rec,
                    "new_on_hand": new_b_oh,
                    "unit_cost_price": updated_cost,
                    "cash_and_carry_price": updated_cash,
                }
            )

        return {
            "success": True,
            "branch_id": bid,
            "branch_name": bname,
            "reference_code": clean_ref,
            "total_lines": len(processed),
            "total_units_received": total_units_received,
            "total_received_cost_value": round(total_cost_value, 2),
            "items": processed,
        }

    @classmethod
    def transfer_stock_between_branches(
        cls,
        uow: Any,
        from_branch_id: str,
        to_branch_id: str,
        item_id: str,
        quantity: int,
        reference_code: str = "",
        remarks: str = "",
        performed_by: str = "SYSTEM",
    ) -> Dict[str, Any]:
        """Atomically transfers available physical units from source branch to destination branch."""
        qty = int(quantity or 0)
        if not from_branch_id or not to_branch_id:
            raise ValueError("Source and destination branch IDs are required.")
        if from_branch_id == to_branch_id:
            raise ValueError("Source and destination branches must be different.")
        if qty <= 0:
            raise ValueError("Transfer quantity must be greater than 0.")

        src_bid, src_bname, src_items, db_backed = cls._load_raw_branch_items(uow, from_branch_id)
        dst_bid, dst_bname, dst_items, _ = cls._load_raw_branch_items(uow, to_branch_id)
        if not db_backed:
            raise RuntimeError("Asset inventory tables are not initialized in Supabase.")

        src_item = next((x for x in src_items if x["item_id"] == item_id or x["sku_code"] == item_id), None)
        if not src_item:
            raise ValueError(f"Asset item '{item_id}' not found in catalog.")
        dst_item = next((x for x in dst_items if x["item_id"] == src_item["item_id"]), src_item)

        src_oh = int(src_item["quantity_on_hand"])
        src_rsv = int(src_item["quantity_reserved"])
        src_avail = int(src_item["quantity_available"])
        if qty > src_avail:
            raise ValueError(
                f"Insufficient available stock of '{src_item['item_name']}' at {src_bname}: available {src_avail}, requested {qty}."
            )

        dst_oh = int(dst_item["quantity_on_hand"])
        dst_rsv = int(dst_item["quantity_reserved"])
        new_src_oh = src_oh - qty
        new_dst_oh = dst_oh + qty
        now_iso = datetime.now(timezone.utc).isoformat()
        clean_ref = (reference_code or "").strip() or f"TRF-{uuid.uuid4().hex[:6].upper()}"
        note = (remarks or "").strip()

        uow.client.table("branch_asset_inventory").upsert(
            {
                "branch_id": src_bid,
                "item_id": src_item["item_id"],
                "quantity_on_hand": new_src_oh,
                "quantity_reserved": src_rsv,
                "branch_item_alias": src_item.get("branch_item_alias"),
                "updated_at": now_iso,
            },
            on_conflict="branch_id,item_id",
        ).execute()

        uow.client.table("branch_asset_inventory").upsert(
            {
                "branch_id": dst_bid,
                "item_id": src_item["item_id"],
                "quantity_on_hand": new_dst_oh,
                "quantity_reserved": dst_rsv,
                "branch_item_alias": dst_item.get("branch_item_alias"),
                "updated_at": now_iso,
            },
            on_conflict="branch_id,item_id",
        ).execute()

        cost_p = float(src_item.get("unit_cost_price") or 0.0)
        cash_p = float(src_item.get("cash_and_carry_price") or 0.0)
        uow.client.table("asset_stock_movements").insert(
            {
                "branch_id": src_bid,
                "counterparty_branch_id": dst_bid,
                "item_id": src_item["item_id"],
                "movement_type": "TRANSFER_OUT",
                "quantity_delta": -qty,
                "reserved_delta": 0,
                "balance_after": new_src_oh,
                "unit_cost_price": cost_p,
                "unit_cash_price": cash_p,
                "unit_selling_price": cash_p,
                "reference_code": clean_ref,
                "performed_by": performed_by,
                "remarks": note or f"Transferred {qty} unit(s) from {src_bname} to {dst_bname}",
            }
        ).execute()

        uow.client.table("asset_stock_movements").insert(
            {
                "branch_id": dst_bid,
                "counterparty_branch_id": src_bid,
                "item_id": src_item["item_id"],
                "movement_type": "TRANSFER_IN",
                "quantity_delta": qty,
                "reserved_delta": 0,
                "balance_after": new_dst_oh,
                "unit_cost_price": cost_p,
                "unit_cash_price": cash_p,
                "unit_selling_price": cash_p,
                "reference_code": clean_ref,
                "performed_by": performed_by,
                "remarks": note or f"Received {qty} unit(s) transferred from {src_bname} to {dst_bname}",
            }
        ).execute()

        return {
            "success": True,
            "reference_code": clean_ref,
            "item_id": src_item["item_id"],
            "sku_code": src_item["sku_code"],
            "item_name": src_item["item_name"],
            "quantity": qty,
            "from_branch_id": src_bid,
            "from_branch_name": src_bname,
            "from_branch_new_on_hand": new_src_oh,
            "to_branch_id": dst_bid,
            "to_branch_name": dst_bname,
            "to_branch_new_on_hand": new_dst_oh,
        }

    @classmethod
    def record_stock_write_off(
        cls,
        uow: Any,
        branch_id: str,
        item_id: str,
        quantity: int,
        reason: str,
        reference_code: str = "",
        performed_by: str = "SYSTEM",
    ) -> Dict[str, Any]:
        """Deducts damaged/lost units and records a DAMAGE_WRITE_OFF P&L loss movement."""
        qty = int(quantity or 0)
        if not branch_id:
            raise ValueError("Branch ID is required.")
        if qty <= 0:
            raise ValueError("Write-off quantity must be greater than 0.")
        clean_reason = (reason or "").strip()
        if not clean_reason:
            raise ValueError("Write-off reason is required.")

        bid, bname, all_items, db_backed = cls._load_raw_branch_items(uow, branch_id)
        if not db_backed:
            raise RuntimeError("Asset inventory tables are not initialized in Supabase.")

        target = next((x for x in all_items if x["item_id"] == item_id or x["sku_code"] == item_id), None)
        if not target:
            raise ValueError(f"Asset item '{item_id}' not found in catalog.")

        oh = int(target["quantity_on_hand"])
        rsv = int(target["quantity_reserved"])
        avail = int(target["quantity_available"])
        if qty > avail:
            raise ValueError(
                f"Cannot write off {qty} unit(s) of '{target['item_name']}' at {bname}: only {avail} available (reserved: {rsv})."
            )

        new_oh = oh - qty
        now_iso = datetime.now(timezone.utc).isoformat()
        clean_ref = (reference_code or "").strip() or f"WO-{uuid.uuid4().hex[:6].upper()}"
        cost_p = float(target.get("unit_cost_price") or 0.0)
        cash_p = float(target.get("cash_and_carry_price") or 0.0)

        uow.client.table("branch_asset_inventory").upsert(
            {
                "branch_id": bid,
                "item_id": target["item_id"],
                "quantity_on_hand": new_oh,
                "quantity_reserved": rsv,
                "branch_item_alias": target.get("branch_item_alias"),
                "updated_at": now_iso,
            },
            on_conflict="branch_id,item_id",
        ).execute()

        uow.client.table("asset_stock_movements").insert(
            {
                "branch_id": bid,
                "item_id": target["item_id"],
                "movement_type": "DAMAGE_WRITE_OFF",
                "quantity_delta": -qty,
                "reserved_delta": 0,
                "balance_after": new_oh,
                "unit_cost_price": cost_p,
                "unit_cash_price": cash_p,
                "unit_selling_price": cash_p,
                "reference_code": clean_ref,
                "performed_by": performed_by,
                "remarks": clean_reason,
            }
        ).execute()

        return {
            "success": True,
            "reference_code": clean_ref,
            "branch_id": bid,
            "branch_name": bname,
            "item_id": target["item_id"],
            "sku_code": target["sku_code"],
            "item_name": target["item_name"],
            "quantity_written_off": qty,
            "new_on_hand": new_oh,
            "cost_loss": round(cost_p * qty, 2),
        }

    @classmethod
    def upsert_catalog_item(
        cls,
        uow: Any,
        item_id: Optional[str],
        sku_code: Optional[str],
        category: str,
        item_name: str,
        cash_and_carry_price: float,
        unit_cost_price: float = 0.0,
        easy_buy_60d_price: Optional[float] = None,
        easy_buy_120d_price: Optional[float] = None,
        supplier_name: Optional[str] = None,
        initial_branch_id: Optional[str] = None,
        initial_quantity: int = 0,
        performed_by: str = "SYSTEM",
    ) -> Dict[str, Any]:
        """Creates a new SKU or updates an existing SKU's master cost/selling pricing and metadata."""
        clean_cat = (category or "").strip().upper()
        clean_name = (item_name or "").strip()
        if not clean_cat:
            raise ValueError("Category is required.")
        if not clean_name:
            raise ValueError("Item name is required.")
        cash_val = round(float(cash_and_carry_price or 0.0), 2)
        cost_val = round(float(unit_cost_price or 0.0), 2)
        if cash_val < 0 or cost_val < 0:
            raise ValueError("Cost price and selling price cannot be negative.")
        p60_val = round(float(easy_buy_60d_price), 2) if easy_buy_60d_price and float(easy_buy_60d_price) > 0 else round(cash_val * 1.12, 2)
        p120_val = round(float(easy_buy_120d_price), 2) if easy_buy_120d_price and float(easy_buy_120d_price) > 0 else round(cash_val * 1.21, 2)

        if not cls._ensure_catalog_seeded_in_db(uow):
            raise RuntimeError("Asset catalog table is not initialized in Supabase.")

        cat_rows = cls._fetch_all_rows(uow, "asset_catalog_items")
        clean_sku = (sku_code or "").strip().upper()
        existing = None
        if item_id:
            existing = next((c for c in cat_rows if str(c["item_id"]) == str(item_id).strip()), None)
        if not existing and clean_sku:
            existing = next((c for c in cat_rows if str(c.get("sku_code") or "").upper() == clean_sku), None)

        now_iso = datetime.now(timezone.utc).isoformat()
        clean_supplier = supplier_name.strip() if isinstance(supplier_name, str) and supplier_name.strip() else None

        if existing:
            resolved_id = str(existing["item_id"])
            resolved_sku = clean_sku or str(existing["sku_code"])
            uow.client.table("asset_catalog_items").update(
                {
                    "sku_code": resolved_sku,
                    "category": clean_cat,
                    "item_name": clean_name,
                    "unit_cost_price": cost_val,
                    "cash_and_carry_price": cash_val,
                    "easy_buy_60d_price": p60_val,
                    "easy_buy_120d_price": p120_val,
                    "supplier_name": clean_supplier,
                    "is_custom_price_allowed": cash_val <= 0.0,
                    "updated_at": now_iso,
                }
            ).eq("item_id", resolved_id).execute()
            created = False
        else:
            if not clean_sku:
                prefix = "".join(ch for ch in clean_cat if ch.isalnum())[:4] or "AST"
                existing_skus = {str(c.get("sku_code") or "").upper() for c in cat_rows}
                seq = len(cat_rows) + 1
                while f"{prefix}-N{seq:03d}" in existing_skus:
                    seq += 1
                clean_sku = f"{prefix}-N{seq:03d}"
            resolved_sku = clean_sku
            resolved_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"icare-asset-sku-{resolved_sku}"))
            uow.client.table("asset_catalog_items").insert(
                {
                    "item_id": resolved_id,
                    "sku_code": resolved_sku,
                    "category": clean_cat,
                    "item_name": clean_name,
                    "unit_cost_price": cost_val,
                    "cash_and_carry_price": cash_val,
                    "easy_buy_60d_price": p60_val,
                    "easy_buy_120d_price": p120_val,
                    "supplier_name": clean_supplier,
                    "is_custom_price_allowed": cash_val <= 0.0,
                    "in_master_pdf": False,
                    "is_active": True,
                    "created_at": now_iso,
                    "updated_at": now_iso,
                }
            ).execute()
            created = True

        init_qty = max(0, int(initial_quantity or 0))
        if initial_branch_id and init_qty > 0:
            res_inv = (
                uow.client.table("branch_asset_inventory")
                .select("*")
                .eq("branch_id", initial_branch_id)
                .eq("item_id", resolved_id)
                .limit(1)
                .execute()
            )
            cur_oh = int(res_inv.data[0].get("quantity_on_hand") or 0) if getattr(res_inv, "data", None) else 0
            cur_rsv = int(res_inv.data[0].get("quantity_reserved") or 0) if getattr(res_inv, "data", None) else 0
            new_oh = cur_oh + init_qty
            uow.client.table("branch_asset_inventory").upsert(
                {
                    "branch_id": initial_branch_id,
                    "item_id": resolved_id,
                    "quantity_on_hand": new_oh,
                    "quantity_reserved": cur_rsv,
                    "updated_at": now_iso,
                },
                on_conflict="branch_id,item_id",
            ).execute()
            uow.client.table("asset_stock_movements").insert(
                {
                    "branch_id": initial_branch_id,
                    "item_id": resolved_id,
                    "movement_type": "INITIAL_SEED" if created else "RESTOCK",
                    "quantity_delta": init_qty,
                    "reserved_delta": 0,
                    "balance_after": new_oh,
                    "unit_cost_price": cost_val,
                    "unit_cash_price": cash_val,
                    "unit_selling_price": cash_val,
                    "performed_by": performed_by,
                    "remarks": f"Initial stock on catalog {'creation' if created else 'update'} ({resolved_sku})",
                }
            ).execute()
        else:
            audit_bid = cls._resolve_audit_branch_id(uow, initial_branch_id)
            if audit_bid:
                uow.client.table("asset_stock_movements").insert(
                    {
                        "branch_id": audit_bid,
                        "item_id": resolved_id,
                        "movement_type": "PRICE_UPDATE",
                        "quantity_delta": 0,
                        "reserved_delta": 0,
                        "balance_after": 0,
                        "unit_cost_price": cost_val,
                        "unit_cash_price": cash_val,
                        "unit_selling_price": cash_val,
                        "performed_by": performed_by,
                        "remarks": f"Catalog {'created' if created else 'updated'}: {clean_name} (Cost ₦{cost_val:,.2f}, Cash ₦{cash_val:,.2f})",
                    }
                ).execute()

        pricing = _compute_pricing_metrics(cost_val, cash_val, p60_val, p120_val)
        return {
            "success": True,
            "created": created,
            "item": {
                "item_id": resolved_id,
                "sku_code": resolved_sku,
                "category": clean_cat,
                "item_name": clean_name,
                "supplier_name": clean_supplier,
                **pricing,
            },
        }

    @classmethod
    def bulk_update_catalog_prices(
        cls,
        uow: Any,
        updates: List[Dict[str, Any]],
        performed_by: str = "SYSTEM",
    ) -> Dict[str, Any]:
        """Batch-updates unit cost prices and/or retail selling prices across catalog SKUs."""
        if not updates:
            raise ValueError("At least one SKU price update is required.")
        if not cls._ensure_catalog_seeded_in_db(uow):
            raise RuntimeError("Asset catalog table is not initialized in Supabase.")

        cat_rows = cls._fetch_all_rows(uow, "asset_catalog_items")
        by_id = {str(c["item_id"]): c for c in cat_rows}
        by_sku = {str(c["sku_code"]).upper(): c for c in cat_rows}
        audit_bid = cls._resolve_audit_branch_id(uow)
        now_iso = datetime.now(timezone.utc).isoformat()
        updated_items: List[Dict[str, Any]] = []

        for upd in updates:
            key = str(upd.get("item_id") or upd.get("sku_code") or "").strip()
            cat = by_id.get(key) or by_sku.get(key.upper())
            if not cat:
                raise ValueError(f"Catalog item '{key}' not found.")

            cost_val = (
                round(float(upd["unit_cost_price"]), 2)
                if upd.get("unit_cost_price") is not None
                else round(float(cat.get("unit_cost_price") or 0.0), 2)
            )
            if cost_val < 0:
                raise ValueError(f"Unit cost price cannot be negative for '{cat['item_name']}'.")

            cash_val = (
                round(float(upd["cash_and_carry_price"]), 2)
                if upd.get("cash_and_carry_price") is not None
                else round(float(cat.get("cash_and_carry_price") or 0.0), 2)
            )
            if cash_val < 0:
                raise ValueError(f"Cash & Carry price cannot be negative for '{cat['item_name']}'.")

            p60_val = (
                round(float(upd["easy_buy_60d_price"]), 2)
                if upd.get("easy_buy_60d_price") is not None
                else round(cash_val * 1.12, 2)
            )
            p120_val = (
                round(float(upd["easy_buy_120d_price"]), 2)
                if upd.get("easy_buy_120d_price") is not None
                else round(cash_val * 1.21, 2)
            )
            supplier_val = (
                str(upd["supplier_name"]).strip() or None
                if upd.get("supplier_name") is not None
                else cat.get("supplier_name")
            )

            uow.client.table("asset_catalog_items").update(
                {
                    "unit_cost_price": cost_val,
                    "cash_and_carry_price": cash_val,
                    "easy_buy_60d_price": p60_val,
                    "easy_buy_120d_price": p120_val,
                    "supplier_name": supplier_val,
                    "is_custom_price_allowed": cash_val <= 0.0,
                    "updated_at": now_iso,
                }
            ).eq("item_id", cat["item_id"]).execute()

            if audit_bid:
                uow.client.table("asset_stock_movements").insert(
                    {
                        "branch_id": audit_bid,
                        "item_id": cat["item_id"],
                        "movement_type": "PRICE_UPDATE",
                        "quantity_delta": 0,
                        "reserved_delta": 0,
                        "balance_after": 0,
                        "unit_cost_price": cost_val,
                        "unit_cash_price": cash_val,
                        "unit_selling_price": cash_val,
                        "performed_by": performed_by,
                        "remarks": f"Bulk price update: Cost ₦{cost_val:,.2f}, Cash ₦{cash_val:,.2f}",
                    }
                ).execute()

            pricing = _compute_pricing_metrics(cost_val, cash_val, p60_val, p120_val)
            updated_items.append(
                {
                    "item_id": str(cat["item_id"]),
                    "sku_code": str(cat["sku_code"]),
                    "category": str(cat["category"]),
                    "item_name": str(cat["item_name"]),
                    "supplier_name": supplier_val,
                    **pricing,
                }
            )

        return {"success": True, "updated_count": len(updated_items), "items": updated_items}
