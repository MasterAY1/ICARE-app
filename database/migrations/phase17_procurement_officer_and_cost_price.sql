-- =============================================================================
-- PHASE 17: PROCUREMENT OFFICER ROLE, COST PRICE READINESS & MULTI-BRANCH ASSET HUB
-- =============================================================================
-- 1. Registers 'Procurement Officer' role in public.roles for strict asset
--    pricing, supplier cost entry, inter-branch transfers, and P&L oversight.
-- 2. Prepares supplier cost price space (unit_cost_price, supplier_name) on
--    public.asset_catalog_items without disrupting existing selling prices.
-- 3. Extends public.asset_stock_movements with cost/selling snapshots,
--    reference codes, counterparty branch tracking, and expanded movement types.
-- 4. Adds covering foreign-key indexes on public.asset_stock_movements.
-- =============================================================================

-- 1. Dedicated Role Registration
INSERT INTO public.roles (role_id, name, description)
VALUES (
    '7b9e4a12-5c38-4d91-9a2e-6f1c8d3b5e70'::uuid,
    'Procurement Officer',
    'Asset & Procurement Officer managing multi-branch stock, supplier cost prices, retail pricing, and asset P&L'
)
ON CONFLICT (role_id) DO NOTHING;

-- 2. Prepare Cost Price & Supplier Space on Master Asset Catalog Items
ALTER TABLE public.asset_catalog_items
    ADD COLUMN IF NOT EXISTS unit_cost_price NUMERIC(15, 2) NOT NULL DEFAULT 0.00 CHECK (unit_cost_price >= 0),
    ADD COLUMN IF NOT EXISTS supplier_name TEXT;

-- 3. Extend Asset Stock Movements with Cost/Selling Snapshot & Transfer Audit Trail
ALTER TABLE public.asset_stock_movements
    ADD COLUMN IF NOT EXISTS unit_cost_price NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS unit_selling_price NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS reference_code TEXT,
    ADD COLUMN IF NOT EXISTS counterparty_branch_id UUID REFERENCES public.branches(branch_id) ON DELETE SET NULL;

ALTER TABLE public.asset_stock_movements
    DROP CONSTRAINT IF EXISTS asset_stock_movements_movement_type_check;

ALTER TABLE public.asset_stock_movements
    ADD CONSTRAINT asset_stock_movements_movement_type_check CHECK (
        movement_type IN (
            'INITIAL_SEED',
            'RESTOCK',
            'RESERVE_ON_APPLY',
            'DEDUCT_ON_DISBURSE',
            'RELEASE_ON_REJECT',
            'ADJUSTMENT',
            'TRANSFER_OUT',
            'TRANSFER_IN',
            'DAMAGE_WRITE_OFF',
            'PRICE_UPDATE'
        )
    );

-- 4. Covering Indexes for Foreign Keys & Reporting Queries
CREATE INDEX IF NOT EXISTS idx_asset_stock_movements_item
    ON public.asset_stock_movements(item_id);
CREATE INDEX IF NOT EXISTS idx_asset_stock_movements_counterparty
    ON public.asset_stock_movements(counterparty_branch_id);
