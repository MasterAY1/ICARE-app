-- =========================================================================
-- Phase 8.9: Monthly Report Verification, Submission & Archival Workflow Schema
-- Supports three-tier month-end sign-offs:
-- Tier 1: Branch Manager (BM) Verification & Submission
-- Tier 2: Area Manager (AM) Supervisory Endorsement & Regional Package Seal
-- Tier 3: Executive Admin Institutional Archival & Period Lock
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.monthly_report_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID NOT NULL REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    area_name VARCHAR(100) NOT NULL DEFAULT 'Area 1',
    year INT NOT NULL,
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    status VARCHAR(50) NOT NULL CHECK (
        status IN ('DRAFT', 'BM_SUBMITTED', 'RETURNED_FOR_CORRECTION', 'AM_VERIFIED', 'AREA_SEALED', 'ADMIN_LOCKED')
    ) DEFAULT 'DRAFT',
    
    -- Financial Snapshot at Submission (Rules 1, 4 & 8)
    disbursed_principal NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    upfront_fees NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    net_active_credit NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    collections NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    closing_credit NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    closing_savings NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    vault_cash_acct_1000 NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    bank_deposits_acct_1050 NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    is_gl_balanced BOOLEAN NOT NULL DEFAULT FALSE,
    gl_variance NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    snapshot_payload JSONB DEFAULT '{}'::jsonb,

    -- Tier 1: Branch Manager Submission
    bm_user_id UUID REFERENCES public.app_users(id),
    bm_name VARCHAR(150),
    bm_notes TEXT,
    bm_submitted_at TIMESTAMP WITH TIME ZONE,

    -- Tier 2: Area Manager Supervisory Endorsement
    am_user_id UUID REFERENCES public.app_users(id),
    am_name VARCHAR(150),
    am_notes TEXT,
    am_endorsed_at TIMESTAMP WITH TIME ZONE,
    am_query_notes TEXT,

    -- Tier 3: Admin Final Archival & Lock
    admin_user_id UUID REFERENCES public.app_users(id),
    admin_name VARCHAR(150),
    admin_notes TEXT,
    admin_locked_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT uq_branch_year_month_submission UNIQUE (branch_id, year, month)
);

CREATE INDEX IF NOT EXISTS idx_monthly_rep_sub_year_month ON public.monthly_report_submissions(year, month);
CREATE INDEX IF NOT EXISTS idx_monthly_rep_sub_branch ON public.monthly_report_submissions(branch_id);
CREATE INDEX IF NOT EXISTS idx_monthly_rep_sub_status ON public.monthly_report_submissions(status);
