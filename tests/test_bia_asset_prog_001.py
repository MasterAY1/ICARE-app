"""
Tests for BIA-ASSET-PROG-001 (Option A):
- October 2026 Master Asset Price Catalog (540 PDF SKUs + 27 Ogijo legacy SKUs = 567 total SKUs)
- Exact 1.12x (60D/12W/3M) and 1.21x (120D/24W/6M) Easy Buy pricing & repaired PDF anomalies
- Ogijo Branch inventory baseline (242 SKUs, 127 in-stock SKUs, 115 zero-stock SKUs, 205 physical units)
- Stock validation, fail-closed out-of-stock guard, atomic reservation on loan application,
  physical stock deduction on disbursement / Cash & Carry, release on loan rejection, and BM adjustment.
"""
from __future__ import annotations

import uuid
from types import SimpleNamespace
from typing import Any, Dict, List

import pytest

from api.schemas.origination import ApplyLoanInput, SelectedAssetItemInput
from services.asset_inventory_data import (
    MASTER_ASSET_CATALOG_SEED,
    MASTER_ASSET_CATEGORIES,
)
from services.asset_inventory_service import AssetInventoryService
from services.loan_product_engine import LoanProductEngine


class _FakeResult:
    def __init__(self, data: Any):
        self.data = data


class _FakeTableQuery:
    def __init__(self, db: Dict[str, List[Dict[str, Any]]], table_name: str):
        self.db = db
        self.table_name = table_name
        self._filters: List[Any] = []
        self._op = "select"
        self._payload: Any = None
        self._limit: int | None = None
        self._range: tuple[int, int] | None = None

    def select(self, *_args, **_kwargs):
        self._op = "select"
        return self

    def insert(self, payload: Any):
        self._op = "insert"
        self._payload = payload
        return self

    def update(self, payload: Dict[str, Any]):
        self._op = "update"
        self._payload = payload
        return self

    def upsert(self, payload: Any, on_conflict: str = ""):
        self._op = "upsert"
        self._payload = (payload, on_conflict)
        return self

    def eq(self, col: str, val: Any):
        self._filters.append(("eq", col, val))
        return self

    def neq(self, col: str, val: Any):
        self._filters.append(("neq", col, val))
        return self

    def in_(self, col: str, vals: List[Any]):
        self._filters.append(("in", col, set(vals)))
        return self

    def is_(self, col: str, val: Any):
        self._filters.append(("is", col, val))
        return self

    def order(self, *_args, **_kwargs):
        return self

    def limit(self, n: int):
        self._limit = n
        return self

    def range(self, start: int, end: int):
        self._range = (start, end)
        return self

    def _matches(self, row: Dict[str, Any]) -> bool:
        for op, col, val in self._filters:
            rv = row.get(col)
            if op == "eq" and rv != val:
                return False
            if op == "neq" and rv == val:
                return False
            if op == "in" and rv not in val:
                return False
            if op == "is" and val == "null" and rv is not None:
                return False
        return True

    def execute(self):
        if self.table_name not in self.db:
            raise Exception(f"Could not find the table 'public.{self.table_name}' in schema cache (PGRST205)")
        rows = self.db[self.table_name]

        if self._op == "select":
            matched = [dict(r) for r in rows if self._matches(r)]
            if self._range is not None:
                matched = matched[self._range[0] : self._range[1] + 1]
            if self._limit is not None:
                matched = matched[: self._limit]
            return _FakeResult(matched)

        if self._op == "insert":
            items = self._payload if isinstance(self._payload, list) else [self._payload]
            inserted = []
            for item in items:
                rec = dict(item)
                if self.table_name == "branch_asset_inventory" and "inventory_id" not in rec:
                    rec["inventory_id"] = str(uuid.uuid4())
                if self.table_name == "asset_stock_movements" and "movement_id" not in rec:
                    rec["movement_id"] = str(uuid.uuid4())
                rows.append(rec)
                inserted.append(dict(rec))
            return _FakeResult(inserted)

        if self._op == "update":
            updated = []
            for r in rows:
                if self._matches(r):
                    r.update(self._payload)
                    updated.append(dict(r))
            return _FakeResult(updated)

        if self._op == "upsert":
            payload, on_conflict = self._payload
            items = payload if isinstance(payload, list) else [payload]
            conflict_cols = [c.strip() for c in on_conflict.split(",") if c.strip()]
            out = []
            for item in items:
                rec = dict(item)
                existing = None
                if conflict_cols:
                    for r in rows:
                        if all(r.get(c) == rec.get(c) for c in conflict_cols):
                            existing = r
                            break
                if existing is not None:
                    existing.update(rec)
                    out.append(dict(existing))
                else:
                    if self.table_name == "branch_asset_inventory" and "inventory_id" not in rec:
                        rec["inventory_id"] = str(uuid.uuid4())
                    rows.append(rec)
                    out.append(dict(rec))
            return _FakeResult(out)
        return _FakeResult([])


class _FakeClient:
    def __init__(self, db: Dict[str, List[Dict[str, Any]]]):
        self.db = db

    def table(self, name: str):
        return _FakeTableQuery(self.db, name)


def _make_ogijo_uow(with_phase16_tables: bool = True):
    ogijo_branch_id = "11111111-1111-1111-1111-111111111111"
    other_branch_id = "22222222-2222-2222-2222-222222222222"
    db: Dict[str, List[Dict[str, Any]]] = {
        "branches": [
            {"branch_id": ogijo_branch_id, "name": "Ogijo"},
            {"branch_id": other_branch_id, "name": "Ikorodu"},
        ],
        "loans": [],
    }
    if with_phase16_tables:
        db["asset_catalog_items"] = []
        db["branch_asset_inventory"] = []
        db["asset_stock_movements"] = []
    return SimpleNamespace(client=_FakeClient(db)), db, ogijo_branch_id, other_branch_id


def test_master_catalog_census_and_math():
    assert len(MASTER_ASSET_CATEGORIES) == 19
    pdf_items = [x for x in MASTER_ASSET_CATALOG_SEED if x["in_master_pdf"]]
    legacy_items = [x for x in MASTER_ASSET_CATALOG_SEED if not x["in_master_pdf"]]
    assert len(pdf_items) == 540
    assert len(legacy_items) == 27
    assert len(MASTER_ASSET_CATALOG_SEED) == 567

    # Every Master PDF SKU satisfies 1.12x and 1.21x exact rounding & anomalies are fixed
    by_name = {x["item_name"]: x for x in MASTER_ASSET_CATALOG_SEED}
    for it in pdf_items:
        cash = it["cash_and_carry_price"]
        assert cash > 0
        assert it["easy_buy_60d_price"] == round(cash * 1.12, 2)
        assert it["easy_buy_120d_price"] == round(cash * 1.21, 2)

    # Check repaired PDF anomalies explicitly
    assert by_name["ITEL 2580FBS BLUETOOTH SPEAKER"]["easy_buy_120d_price"] == 41140.00
    assert by_name["UFM SVI SOLAR POWER CHARGING PHONE"]["easy_buy_60d_price"] == 21840.00
    assert by_name["UFM SVI SOLAR POWER CHARGING PHONE"]["easy_buy_120d_price"] == 23595.00
    assert by_name["HISENSE 20L MICROWAVE"]["easy_buy_60d_price"] == 106400.00
    assert by_name["HISENSE 20L MICROWAVE"]["easy_buy_120d_price"] == 114950.00
    assert by_name["D-ZIRE SET 7 POT"]["easy_buy_60d_price"] == 62720.00
    assert by_name["LUNCH BOX"]["easy_buy_120d_price"] == 9680.00


def test_ogijo_branch_seed_totals_exact():
    ogijo_rows = [x for x in MASTER_ASSET_CATALOG_SEED if x["ogijo_excel_name"] is not None]
    in_stock = [x for x in ogijo_rows if x["ogijo_initial_qty"] > 0]
    zero_stock = [x for x in ogijo_rows if x["ogijo_initial_qty"] == 0]
    total_units = sum(x["ogijo_initial_qty"] for x in ogijo_rows)

    assert len(ogijo_rows) == 242
    assert len(in_stock) == 127
    assert len(zero_stock) == 115
    assert total_units == 205


def test_ogijo_inventory_lifecycle_reserve_disburse_reject_and_adjust():
    uow, db, ogijo_id, _ = _make_ogijo_uow(with_phase16_tables=True)

    # 1. Auto-seed on first catalog fetch
    catalog_res = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id)
    assert catalog_res["db_backed"] is True
    assert catalog_res["branch_name"] == "Ogijo"
    assert catalog_res["summary"]["total_catalog_skus"] == 567
    assert catalog_res["summary"]["branch_stocked_skus"] == 127
    assert catalog_res["summary"]["total_units_available"] == 205

    # Pick 6KG CYLINDER (5 units in Ogijo @ N26,000 Cash & Carry)
    cyl = next(x for x in catalog_res["items"] if x["item_name"] == "6KG CYLINDER")
    assert cyl["quantity_available"] == 5
    assert cyl["cash_and_carry_price"] == 26000.00
    assert cyl["easy_buy_60d_price"] == 29120.00
    assert cyl["easy_buy_120d_price"] == 31460.00

    # Verify LoanProductEngine + origination total_cost formula matches Easy Buy PDF prices
    setup_60 = LoanProductEngine.calculate_loan_setup(cyl["cash_and_carry_price"], "60-Day Asset", "Asset")
    assert cyl["cash_and_carry_price"] + setup_60["interest"] == cyl["easy_buy_60d_price"]
    assert setup_60["loan_repayment"] * setup_60["duration"] == pytest.approx(cyl["easy_buy_60d_price"])
    setup_120 = LoanProductEngine.calculate_loan_setup(cyl["cash_and_carry_price"], "120-Day Asset", "Asset")
    assert cyl["cash_and_carry_price"] + setup_120["interest"] == cyl["easy_buy_120d_price"]
    assert setup_120["loan_repayment"] * setup_120["duration"] == pytest.approx(cyl["easy_buy_120d_price"])

    # 2. Fail-closed check when requesting more than available
    with pytest.raises(ValueError, match="Insufficient branch stock"):
        AssetInventoryService.validate_selected_assets(
            uow,
            branch_id=ogijo_id,
            branch_name="Ogijo",
            selected_assets=[{"item_id": cyl["item_id"], "quantity": 6}],
        )

    # 3. Validate & reserve 2 units on pending loan L1
    loan1_id = str(uuid.uuid4())
    check1 = AssetInventoryService.validate_selected_assets(
        uow,
        branch_id=ogijo_id,
        branch_name="Ogijo",
        selected_assets=[{"item_id": cyl["item_id"], "quantity": 2}],
    )
    assert check1["total_cash_price"] == 52000.00
    assert check1["asset_summary"] == "2x 6KG CYLINDER"
    AssetInventoryService.reserve_stock_for_loan(
        uow, branch_id=ogijo_id, loan_id=loan1_id, asset_items=check1["asset_items"], performed_by="co1"
    )

    after_rsv = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id, search="6KG CYLINDER")
    assert after_rsv["items"][0]["quantity_on_hand"] == 5
    assert after_rsv["items"][0]["quantity_reserved"] == 2
    assert after_rsv["items"][0]["quantity_available"] == 3
    assert after_rsv["summary"]["total_units_available"] == 203

    # 4. Disburse loan L1 -> on_hand drops 5 -> 3, reserved drops 2 -> 0
    AssetInventoryService.commit_disbursed_stock(
        uow,
        loan_id=loan1_id,
        branch_id=ogijo_id,
        extra_fields={"asset_items": check1["asset_items"]},
        performed_by="bm1",
    )
    after_disb = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id, search="6KG CYLINDER")
    assert after_disb["items"][0]["quantity_on_hand"] == 3
    assert after_disb["items"][0]["quantity_reserved"] == 0
    assert after_disb["items"][0]["quantity_available"] == 3
    assert after_disb["summary"]["total_units_on_hand"] == 203

    # 5. Reserve 1 unit for loan L2, then reject L2 -> returns available from 2 back to 3
    loan2_id = str(uuid.uuid4())
    check2 = AssetInventoryService.validate_selected_assets(
        uow,
        branch_id=ogijo_id,
        branch_name="Ogijo",
        selected_assets=[{"item_id": cyl["item_id"], "quantity": 1}],
    )
    AssetInventoryService.reserve_stock_for_loan(
        uow, branch_id=ogijo_id, loan_id=loan2_id, asset_items=check2["asset_items"], performed_by="co1"
    )
    mid_resv = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id, search="6KG CYLINDER")
    assert mid_resv["items"][0]["quantity_available"] == 2

    AssetInventoryService.release_reserved_stock(
        uow,
        loan_id=loan2_id,
        branch_id=ogijo_id,
        extra_fields={"asset_items": check2["asset_items"]},
        performed_by="bm1",
        reason="Cancelled by client",
    )
    after_rel = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id, search="6KG CYLINDER")
    assert after_rel["items"][0]["quantity_on_hand"] == 3
    assert after_rel["items"][0]["quantity_reserved"] == 0
    assert after_rel["items"][0]["quantity_available"] == 3

    # 6. BM restock +4 units & price update
    updated = AssetInventoryService.adjust_branch_inventory(
        uow,
        branch_id=ogijo_id,
        branch_name="Ogijo",
        item_id=cyl["item_id"],
        quantity_delta=4,
        new_cash_price=28000.00,
        remarks="October replenishment",
        performed_by="bm_ogijo",
    )
    assert updated["quantity_on_hand"] == 7
    assert updated["cash_and_carry_price"] == 28000.00
    assert updated["easy_buy_60d_price"] == round(28000.00 * 1.12, 2)
    assert updated["easy_buy_120d_price"] == round(28000.00 * 1.21, 2)


def test_fallback_projection_works_when_migration_tables_missing():
    uow, db, ogijo_id, _ = _make_ogijo_uow(with_phase16_tables=False)
    res0 = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id)
    assert res0["db_backed"] is False
    assert res0["summary"]["total_units_available"] == 205

    cyl = next(x for x in res0["items"] if x["item_name"] == "6KG CYLINDER")
    # Simulate one Pending loan and one Active loan in loans table
    db["loans"].append({
        "loan_id": str(uuid.uuid4()),
        "branch_id": ogijo_id,
        "status": "Pending",
        "product_category": "Asset",
        "extra_fields": {"asset_items": [{"item_id": cyl["item_id"], "quantity": 1}]},
    })
    db["loans"].append({
        "loan_id": str(uuid.uuid4()),
        "branch_id": ogijo_id,
        "status": "Active",
        "product_category": "Asset",
        "extra_fields": {"asset_items": [{"item_id": cyl["item_id"], "quantity": 2}]},
    })
    res1 = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id, search="6KG CYLINDER")
    row = res1["items"][0]
    assert row["quantity_on_hand"] == 3
    assert row["quantity_reserved"] == 1
    assert row["quantity_available"] == 2


def test_apply_loan_input_backward_compatibility():
    legacy_payload = ApplyLoanInput(
        client_id="c-1",
        product_category="Finance",
        product_type="Weekly 12W",
        requested_amount=50000.0,
    )
    assert legacy_payload.selected_assets is None

    asset_payload = ApplyLoanInput(
        client_id="c-2",
        product_category="Asset",
        product_type="60-Day Asset",
        requested_amount=26000.0,
        selected_assets=[SelectedAssetItemInput(item_id="id-1", quantity=1)],
    )
    assert len(asset_payload.selected_assets) == 1


def test_procurement_officer_rbac_scope_and_aliases():
    from services.rbac_scope_service import RBACScopeService

    for alias in ("Procurement Officer", "PROCUREMENT_OFFICER", "Asset Manager", "asset_manager", "PO"):
        assert RBACScopeService.normalize_role(alias) == "Procurement Officer"

    scope = RBACScopeService.resolve_scope({
        "id": "proc-1",
        "username": "proc_officer",
        "role": "Asset Manager",
        "branch": "Head Office",
        "branch_id": "ho-branch",
    })
    assert scope.role == "Procurement Officer"
    assert scope.scope_level == "INSTITUTION"
    assert scope.is_read_only() is False
    assert RBACScopeService.is_page_permitted("Procurement Officer", "Asset & Procurement") is True
    assert RBACScopeService.is_page_permitted("Procurement Officer", "Collections") is False


def test_cost_price_pnl_grn_transfer_writeoff_and_new_sku():
    uow, db, ogijo_id, ikorodu_id = _make_ogijo_uow(with_phase16_tables=True)
    # 1. Seed initial catalog & Ogijo inventory; cost prices initially pending (0.00)
    ov0 = AssetInventoryService.get_procurement_overview(uow)
    assert ov0["catalog_readiness"]["total_catalog_skus"] == 567
    assert ov0["catalog_readiness"]["cost_pending_skus"] == 567
    assert ov0["catalog_readiness"]["cost_configured_skus"] == 0
    assert ov0["inventory_summary"]["units_on_hand"] == 205

    matrix0 = AssetInventoryService.get_multi_branch_stock_matrix(uow, search="6KG CYLINDER")
    cyl = next(x for x in matrix0["items"] if x["item_name"] == "6KG CYLINDER")
    assert cyl["unit_cost_price"] == 0.0
    assert cyl["has_cost_price"] is False
    assert cyl["branch_stocks"][ogijo_id]["quantity_available"] == 5
    assert cyl["branch_stocks"][ikorodu_id]["quantity_available"] == 0

    # 2. Configure initial cost price (N20,000) and then receive +5 units at N22,000 -> WAC = (5*20000 + 5*22000)/10 = 21000
    AssetInventoryService.bulk_update_catalog_prices(
        uow,
        updates=[{"item_id": cyl["item_id"], "unit_cost_price": 20000.0}],
        performed_by="proc_1",
    )
    grn = AssetInventoryService.receive_stock_batch(
        uow,
        branch_id=ikorodu_id,
        reference_code="GRN-001",
        supplier_name="Prime Gas Ltd",
        items=[{
            "item_id": cyl["item_id"],
            "quantity_received": 5,
            "unit_cost_price": 22000.0,
        }],
        performed_by="proc_1",
    )
    assert grn["total_units_received"] == 5
    assert grn["items"][0]["unit_cost_price"] == 21000.0
    assert grn["items"][0]["new_on_hand"] == 5

    # 3. Disburse 2 units on 60-Day Asset loan at Ikorodu -> Revenue 2 * 29,120 = 58,240; COGS 2 * 21,000 = 42,000; Gross Profit = 16,240
    loan_id = str(uuid.uuid4())
    AssetInventoryService.commit_disbursed_stock(
        uow,
        loan_id=loan_id,
        branch_id=ikorodu_id,
        extra_fields={
            "product_type": "60-Day Asset",
            "asset_items": [{
                "item_id": cyl["item_id"],
                "quantity": 2,
                "unit_cost_price": 21000.0,
                "unit_cash_price": 26000.0,
                "unit_easy_buy_60d_price": 29120.0,
                "unit_easy_buy_120d_price": 31460.0,
            }],
        },
        performed_by="bm_ikorodu",
        is_cash_and_carry=False,
        product_type="60-Day Asset",
    )

    # 4. Transfer 2 units from Ogijo -> Ikorodu
    trf = AssetInventoryService.transfer_stock_between_branches(
        uow,
        from_branch_id=ogijo_id,
        to_branch_id=ikorodu_id,
        item_id=cyl["item_id"],
        quantity=2,
        reference_code="WAY-101",
        performed_by="proc_1",
    )
    assert trf["from_branch_new_on_hand"] == 3
    assert trf["to_branch_new_on_hand"] == 5  # 5 received - 2 disbursed + 2 transferred = 5

    # 5. Record 1 damaged write-off at Ogijo -> loss = 21,000; Net profit across institution = 16,240 - 21,000 = -4,760
    wo = AssetInventoryService.record_stock_write_off(
        uow,
        branch_id=ogijo_id,
        item_id=cyl["item_id"],
        quantity=1,
        reason="Cylinder valve damaged in transit",
        reference_code="WO-01",
        performed_by="proc_1",
    )
    assert wo["new_on_hand"] == 2
    assert wo["cost_loss"] == 21000.0

    # 6. Create brand new SKU with opening stock at Ikorodu
    created = AssetInventoryService.upsert_catalog_item(
        uow,
        item_id=None,
        sku_code="SOL-NEW1",
        category="SOLAR SYSTEM",
        item_name="SUNKING PRO 600 KIT",
        unit_cost_price=48000.0,
        cash_and_carry_price=60000.0,
        supplier_name="SunKing Wholesale",
        initial_branch_id=ikorodu_id,
        initial_quantity=3,
        performed_by="proc_1",
    )
    assert created["created"] is True
    assert created["item"]["easy_buy_60d_price"] == round(60000.0 * 1.12, 2)
    assert created["item"]["retail_margin_amount"] == 12000.0

    ov_final = AssetInventoryService.get_procurement_overview(uow)
    assert ov_final["catalog_readiness"]["total_catalog_skus"] == 568
    assert ov_final["catalog_readiness"]["cost_configured_skus"] == 2
    assert ov_final["pnl_summary"]["units_sold"] == 2
    assert ov_final["pnl_summary"]["realized_package_revenue"] == 58240.0
    assert ov_final["pnl_summary"]["realized_cogs"] == 42000.0
    assert ov_final["pnl_summary"]["realized_trading_profit"] == 10000.0
    assert ov_final["pnl_summary"]["realized_financing_markup"] == 6240.0
    assert ov_final["pnl_summary"]["write_off_cost_loss"] == 21000.0
    assert ov_final["pnl_summary"]["net_realized_profit"] == -4760.0


def test_price_and_procurement_routes_enforce_strict_role_lock():
    from fastapi.testclient import TestClient
    from api.main import app
    from api.dependencies import get_current_user, get_uow
    from models.user import CurrentUser

    uow, _, ogijo_id, _ = _make_ogijo_uow(with_phase16_tables=True)
    cat = AssetInventoryService.get_branch_asset_catalog(uow, branch_id=ogijo_id)
    cyl_id = next(x["item_id"] for x in cat["items"] if x["item_name"] == "6KG CYLINDER")

    active_user_holder: Dict[str, CurrentUser] = {}

    def _override_user():
        return active_user_holder["user"]

    def _override_uow():
        yield uow

    app.dependency_overrides[get_current_user] = _override_user
    app.dependency_overrides[get_uow] = _override_uow
    client = TestClient(app)

    try:
        # 1. Branch Manager MUST be rejected (403) when attempting to adjust prices/stock or open procurement hub
        active_user_holder["user"] = CurrentUser(
            id="bm-1",
            username="bm_ogijo",
            role="Branch Manager",
            branch="Ogijo",
            branch_id=ogijo_id,
        )
        res_bm_adj = client.post(
            "/api/v1/co/origination/branch-inventory/adjust",
            json={"item_id": cyl_id, "quantity_delta": 1, "new_cash_price": 30000.0},
        )
        assert res_bm_adj.status_code == 403

        res_bm_proc = client.get("/api/v1/procurement/overview")
        assert res_bm_proc.status_code == 403

        # 2. Procurement Officer MUST be allowed (200) across branches and can update cost/selling prices
        active_user_holder["user"] = CurrentUser(
            id="po-1",
            username="proc_officer",
            role="Procurement Officer",
            branch="Head Office",
            branch_id="ho-uuid",
        )
        res_po_adj = client.post(
            "/api/v1/co/origination/branch-inventory/adjust",
            json={
                "branch_id": ogijo_id,
                "item_id": cyl_id,
                "quantity_delta": 2,
                "new_cash_price": 27000.0,
                "new_cost_price": 21500.0,
                "remarks": "Approved Q4 pricing",
            },
        )
        assert res_po_adj.status_code == 200
        body_adj = res_po_adj.json()
        assert body_adj["item"]["cash_and_carry_price"] == 27000.0
        assert body_adj["item"]["unit_cost_price"] == 21500.0
        assert body_adj["item"]["quantity_on_hand"] == 7

        res_po_ov = client.get("/api/v1/procurement/overview")
        assert res_po_ov.status_code == 200
        assert res_po_ov.json()["catalog_readiness"]["cost_configured_skus"] == 1
    finally:
        app.dependency_overrides.clear()
