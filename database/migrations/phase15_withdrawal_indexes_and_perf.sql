-- ============================================================================
-- PHASE 15: WITHDRAWAL PERFORMANCE INDEXES & BATCH AGGREGATION RPCS
-- Additive performance hardening under BIA-CO-SAV-001 (Option B).
-- Strictly preserves ledger immutability and existing RPC contracts.
-- ============================================================================

-- 1. Missing B-Tree indexes on client_id / group_id for savings & membership lookups
CREATE INDEX IF NOT EXISTS idx_individual_savings_client_id
ON public.individual_savings(client_id);

CREATE INDEX IF NOT EXISTS idx_group_savings_group_id
ON public.group_savings(group_id);

CREATE INDEX IF NOT EXISTS idx_laps_savings_client_id
ON public.laps_savings(client_id);

CREATE INDEX IF NOT EXISTS idx_laps_savings_branch_id
ON public.laps_savings(branch_id);

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_branch_opdate
ON public.withdrawal_requests(branch_id, operational_date);

CREATE INDEX IF NOT EXISTS idx_client_memberships_client_id
ON public.client_memberships(client_id);

-- 2. Batch Individual Savings Net Balance Aggregation RPC
-- Eliminates full row transfer and N+1 get_savings_balance_aggregate loops
CREATE OR REPLACE FUNCTION public.get_individual_savings_balances_batch(
    p_client_ids uuid[]
)
RETURNS TABLE (
    client_id uuid,
    net_balance numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        s.client_id,
        COALESCE(SUM(s.deposit_amount - s.withdrawal_amount), 0.0) AS net_balance
    FROM public.individual_savings s
    WHERE s.client_id = ANY(p_client_ids)
    GROUP BY s.client_id;
$$;

-- 3. Batch Loan Repayments Total Aggregation RPC
-- Eliminates fetching thousands of repayment rows for active loan balance checks
CREATE OR REPLACE FUNCTION public.get_loan_repaid_totals_batch(
    p_loan_ids uuid[]
)
RETURNS TABLE (
    loan_id uuid,
    total_paid numeric
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        r.loan_id,
        COALESCE(SUM(r.amount_paid), 0.0) AS total_paid
    FROM public.repayments r
    WHERE r.loan_id = ANY(p_loan_ids)
    GROUP BY r.loan_id;
$$;

GRANT EXECUTE ON FUNCTION public.get_individual_savings_balances_batch(uuid[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.get_loan_repaid_totals_batch(uuid[]) TO service_role;
