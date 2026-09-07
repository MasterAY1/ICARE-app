-- ============================================================================
-- Phase 8.5 Migration: Dedicated Loan Payoff and Excess Payment Records
-- Authoritative Governance: BR-DASH-005, BR-DASH-007, GEMINI Invariant 9
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.loan_payoff_excess_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repayment_id UUID REFERENCES public.repayments(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(loan_id) ON DELETE CASCADE,
    client_id UUID REFERENCES public.clients(client_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    date DATE NOT NULL,
    record_type VARCHAR(30) NOT NULL CHECK (record_type IN ('FULL_PAYOFF', 'EXCESS_PAYMENT', 'FULL_PAYOFF_AND_EXCESS')),
    amount_paid NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
    expected_installment NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (expected_installment >= 0),
    active_credit_settled NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (active_credit_settled >= 0),
    excess_amount NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (excess_amount >= 0),
    remaining_balance_before NUMERIC(15, 2) NOT NULL DEFAULT 0,
    remaining_balance_after NUMERIC(15, 2) NOT NULL DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Performance Indexes for Daily Collections, Dashboard, Portfolio & Audit Views
CREATE INDEX IF NOT EXISTS idx_lper_date_branch ON public.loan_payoff_excess_records(date, branch_id);
CREATE INDEX IF NOT EXISTS idx_lper_officer_date ON public.loan_payoff_excess_records(officer_id, date);
CREATE INDEX IF NOT EXISTS idx_lper_loan ON public.loan_payoff_excess_records(loan_id);
CREATE INDEX IF NOT EXISTS idx_lper_client ON public.loan_payoff_excess_records(client_id);
CREATE INDEX IF NOT EXISTS idx_lper_type ON public.loan_payoff_excess_records(record_type);

-- Audit View Integration
CREATE OR REPLACE VIEW audit.loan_payoff_excess_records AS
SELECT 
    id,
    repayment_id,
    loan_id,
    client_id,
    officer_id,
    branch_id,
    date,
    record_type,
    amount_paid,
    expected_installment,
    active_credit_settled,
    excess_amount,
    remaining_balance_before,
    remaining_balance_after,
    notes,
    created_at
FROM public.loan_payoff_excess_records;
