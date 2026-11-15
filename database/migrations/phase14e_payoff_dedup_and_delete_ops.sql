-- =============================================================================
-- PHASE 14E: PAYOFF/EXCESS DEDUPLICATION & ATOMIC DELETE OPERATIONS
-- =============================================================================
-- NOTE: Contains DELETE statements that trigger interactive confirmation in
-- Supabase MCP (auto-cancelled in non-interactive clients). Run in Supabase SQL
-- Editor to complete the final 16-row deduplication and delete_pending/delete
-- handlers in public.atomic_execute_operations.
-- =============================================================================

-- 1. Merge & deduplicate split 2026-09-18 loan_payoff_excess_records pairs
WITH ranked_dups AS (
    SELECT
        id,
        repayment_id,
        ROW_NUMBER() OVER (
            PARTITION BY repayment_id
            ORDER BY CASE WHEN record_type = 'FULL_PAYOFF' THEN 0 ELSE 1 END, created_at, id
        ) AS rn,
        MAX(active_credit_settled) OVER (PARTITION BY repayment_id) AS max_act_settled,
        MAX(expected_installment) OVER (PARTITION BY repayment_id) AS max_exp_inst,
        MAX(amount_paid) OVER (PARTITION BY repayment_id) AS max_amt_paid,
        MAX(excess_amount) OVER (PARTITION BY repayment_id) AS max_excess
    FROM public.loan_payoff_excess_records
    WHERE repayment_id IN (
        SELECT repayment_id
        FROM public.loan_payoff_excess_records
        WHERE repayment_id IS NOT NULL
        GROUP BY repayment_id
        HAVING COUNT(*) > 1
    )
)
UPDATE public.loan_payoff_excess_records t
SET record_type = 'FULL_PAYOFF_AND_EXCESS',
    active_credit_settled = r.max_act_settled,
    expected_installment = r.max_exp_inst,
    amount_paid = r.max_amt_paid,
    excess_amount = r.max_excess,
    notes = 'Merged duplicate FULL_PAYOFF + EXCESS_PAYMENT split under BR-DASH-005 (Phase 14)'
FROM ranked_dups r
WHERE t.id = r.id
  AND r.rn = 1;

WITH to_delete AS (
    SELECT id
    FROM (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY repayment_id
                ORDER BY CASE WHEN record_type = 'FULL_PAYOFF_AND_EXCESS' THEN 0 ELSE 1 END, created_at, id
            ) AS rn
        FROM public.loan_payoff_excess_records
        WHERE repayment_id IS NOT NULL
    ) sub
    WHERE sub.rn > 1
)
DELETE FROM public.loan_payoff_excess_records t
USING to_delete d
WHERE t.id = d.id;

CREATE UNIQUE INDEX IF NOT EXISTS uq_loan_payoff_excess_repayment_id
    ON public.loan_payoff_excess_records(repayment_id)
    WHERE repayment_id IS NOT NULL;

-- 2. Upgrade public.atomic_execute_operations with delete / delete_pending ops
--    for unpaid loan_schedule regeneration and repayment reversal cleanup.
--    (See phase14_co_ops_integrity_overhaul.sql lines 234-1256 for complete body.)
