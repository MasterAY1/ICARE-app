-- ============================================================================
-- Phase 9 Migration: Dedicated Loan Overdue Recovery Records & Audit Logging
-- Authoritative Governance: BR-DASH-004, BR-DASH-005, Invariants 8 & 9
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.loan_overdue_recovery_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repayment_id UUID REFERENCES public.repayments(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(loan_id) ON DELETE CASCADE,
    client_id UUID REFERENCES public.clients(client_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    recovery_date DATE NOT NULL,
    recovery_timestamp TIMESTAMPTZ DEFAULT now(),
    recovered_amount NUMERIC(15, 2) NOT NULL CHECK (recovered_amount > 0),
    overdue_before NUMERIC(15, 2) NOT NULL CHECK (overdue_before >= 0),
    overdue_after NUMERIC(15, 2) NOT NULL CHECK (overdue_after >= 0),
    total_repayment_amount NUMERIC(15, 2) NOT NULL CHECK (total_repayment_amount > 0),
    recovery_type VARCHAR(30) NOT NULL CHECK (recovery_type IN ('FULL_RECOVERY', 'PARTIAL_RECOVERY')),
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Performance Indexes for Collections, Dashboard, Portfolio & Audit Views
CREATE INDEX IF NOT EXISTS idx_lorr_date_branch ON public.loan_overdue_recovery_records(recovery_date, branch_id);
CREATE INDEX IF NOT EXISTS idx_lorr_officer_date ON public.loan_overdue_recovery_records(officer_id, recovery_date);
CREATE INDEX IF NOT EXISTS idx_lorr_loan ON public.loan_overdue_recovery_records(loan_id);
CREATE INDEX IF NOT EXISTS idx_lorr_client ON public.loan_overdue_recovery_records(client_id);
CREATE INDEX IF NOT EXISTS idx_lorr_type ON public.loan_overdue_recovery_records(recovery_type);

-- Audit Schema Integration
CREATE OR REPLACE VIEW audit.loan_overdue_recovery_records AS
SELECT 
    id,
    repayment_id,
    loan_id,
    client_id,
    officer_id,
    branch_id,
    recovery_date,
    recovery_timestamp,
    recovered_amount,
    overdue_before,
    overdue_after,
    total_repayment_amount,
    recovery_type,
    notes,
    created_at
FROM public.loan_overdue_recovery_records;
