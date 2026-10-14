-- =========================================================================
-- Phase 8.7: Area EOD Confirmations & Regional Governance Schema
-- Authoritative tracking for Area Manager (AM) two-tier EOD sign-offs,
-- regional daily closures, and Account 1000 vault cash verification.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.area_eod_confirmations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    area_name VARCHAR(100) NOT NULL DEFAULT 'Area 1',
    branch_id UUID NOT NULL REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    closure_date DATE NOT NULL,
    status VARCHAR(50) NOT NULL CHECK (status IN ('PENDING', 'BRANCH_CONFIRMED', 'AREA_LOCKED', 'REJECTED')),
    confirmed_by VARCHAR(100),
    acct_1000_balance NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    cash_variance NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    confirmed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT uq_branch_date_eod UNIQUE (branch_id, closure_date)
);

CREATE INDEX IF NOT EXISTS idx_area_eod_date ON public.area_eod_confirmations(closure_date);
CREATE INDEX IF NOT EXISTS idx_area_eod_branch ON public.area_eod_confirmations(branch_id);
