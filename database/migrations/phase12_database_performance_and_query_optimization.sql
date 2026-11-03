-- ============================================================================
-- PHASE 12: DATABASE PERFORMANCE & QUERY OPTIMIZATION MIGRATION
-- Authoritative indexing, composite lookups, and server-side aggregation
-- Strictly adheres to Zero-Emoji Governance & Core Banking Invariants
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. COMPOSITE INDEXES FOR ACCOUNT 1000 & FINANCIAL LEDGER
-- Optimized for instant Vault Cash (Account 1000) and EOD position lookups
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_fle_branch_acct_created
ON public.financial_ledger_entries(branch_id, account_code, created_at);

CREATE INDEX IF NOT EXISTS idx_fle_acct_created
ON public.financial_ledger_entries(account_code, created_at);

-- ----------------------------------------------------------------------------
-- 2. LOANS & LOAN SCHEDULE COMPOSITE INDEXES
-- Optimizes active loan filtering, officer dashboards, and payment scheduling
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_loans_branch_status
ON public.loans(branch_id, status);

CREATE INDEX IF NOT EXISTS idx_loans_officer_status
ON public.loans(officer_id, status);

CREATE INDEX IF NOT EXISTS idx_loans_branch_disb_date
ON public.loans(branch_id, disbursement_date);

CREATE INDEX IF NOT EXISTS idx_loan_schedule_loan_due
ON public.loan_schedule(loan_id, due_date);

-- ----------------------------------------------------------------------------
-- 3. REPAYMENTS COMPOSITE INDEXES
-- Optimizes daily officer collection rollups and lifetime repayment queries
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_repayments_officer_date
ON public.repayments(officer_id, date);

CREATE INDEX IF NOT EXISTS idx_repayments_loan_date
ON public.repayments(loan_id, date);

-- ----------------------------------------------------------------------------
-- 4. SAVINGS TRANSACTION COMPOSITE INDEXES
-- Optimizes daily savings rollups across all savings products
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_ind_sav_branch_date
ON public.individual_savings(branch_id, posting_date);

CREATE INDEX IF NOT EXISTS idx_ind_sav_officer_date
ON public.individual_savings(officer_id, posting_date);

CREATE INDEX IF NOT EXISTS idx_grp_sav_branch_date
ON public.group_savings(branch_id, posting_date);

CREATE INDEX IF NOT EXISTS idx_grp_sav_officer_date
ON public.group_savings(officer_id, posting_date);

-- ----------------------------------------------------------------------------
-- 5. MEMBERSHIP, CLIENT & APPROVAL QUEUE COVERING INDEXES
-- Optimizes client lookups, BM approval queues, and error correction queues
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_client_memberships_officer_client
ON public.client_memberships(officer_id, client_id);

CREATE INDEX IF NOT EXISTS idx_clients_branch
ON public.clients(branch_id);

CREATE INDEX IF NOT EXISTS idx_clients_status
ON public.clients(status_id);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_branch_status
ON public.withdrawal_requests(branch_id, status);

CREATE INDEX IF NOT EXISTS idx_correction_requests_branch_status
ON public.correction_requests(branch_id, status);

-- ----------------------------------------------------------------------------
-- 6. SERVER-SIDE AGGREGATION RPC: SAVINGS BALANCES
-- Computes net active savings balances directly inside PostgreSQL
-- Eliminates client-side data transfer of thousands of rows
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_savings_balance_aggregate(
    p_table text,
    p_branch_id uuid DEFAULT NULL,
    p_officer_id uuid DEFAULT NULL,
    p_client_id uuid DEFAULT NULL,
    p_group_id uuid DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total numeric := 0.0;
    v_sql text;
    v_where text := '1=1';
BEGIN
    -- Validate table name to prevent SQL injection
    IF p_table NOT IN ('individual_savings', 'group_savings', 'misc_savings', 'laps_savings', 'internal_savings') THEN
        RAISE EXCEPTION 'Invalid savings table: %', p_table;
    END IF;

    -- Build dynamic filter conditions safely
    IF p_branch_id IS NOT NULL THEN
        v_where := v_where || format(' AND branch_id = %L', p_branch_id);
    END IF;

    IF p_officer_id IS NOT NULL THEN
        v_where := v_where || format(' AND officer_id = %L', p_officer_id);
    END IF;

    IF p_client_id IS NOT NULL AND p_table IN ('individual_savings', 'misc_savings', 'laps_savings', 'internal_savings') THEN
        v_where := v_where || format(' AND client_id = %L', p_client_id);
    END IF;

    IF p_group_id IS NOT NULL AND p_table = 'group_savings' THEN
        v_where := v_where || format(' AND group_id = %L', p_group_id);
    END IF;

    v_sql := format(
        'SELECT COALESCE(SUM(deposit_amount - withdrawal_amount), 0.0) FROM public.%I WHERE %s',
        p_table,
        v_where
    );

    EXECUTE v_sql INTO v_total;
    RETURN COALESCE(v_total, 0.0);
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. SERVER-SIDE AGGREGATION RPC: ACCOUNT 1000 PHYSICAL VAULT CASH
-- Dynamically derives physical vault cash from Account 1000 ledger entries
-- Strictly enforces Core Non-Negotiable Invariant #1
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_account_1000_vault_cash(
    p_branch_id uuid DEFAULT NULL,
    p_cutoff_timestamp timestamptz DEFAULT NULL
)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_balance numeric := 0.0;
BEGIN
    SELECT COALESCE(
        SUM(
            CASE 
                WHEN side = 'Debit' THEN amount 
                WHEN side = 'Credit' THEN -amount 
                ELSE 0.0 
            END
        ), 
        0.0
    )
    INTO v_balance
    FROM public.financial_ledger_entries
    WHERE account_code = '1000'
      AND (p_branch_id IS NULL OR branch_id = p_branch_id)
      AND (p_cutoff_timestamp IS NULL OR created_at <= p_cutoff_timestamp);

    RETURN GREATEST(0.0, v_balance);
END;
$$;

-- Grant execution to internal service_role
GRANT EXECUTE ON FUNCTION public.get_savings_balance_aggregate(text, uuid, uuid, uuid, uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_account_1000_vault_cash(uuid, timestamptz) TO service_role;
