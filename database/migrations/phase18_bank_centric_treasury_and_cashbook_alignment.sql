-- =============================================================================
-- PHASE 18: BANK-CENTRIC TREASURY, LOAN DISBURSEMENT & CASHBOOK ALIGNMENT
-- =============================================================================
-- 1. Account 1000 (Vault Cash) tracks physical cash collected in the field,
--    Vault cash sweeps to Bank (BankDeposited), Bank-to-Safe cash refills
--    (BankWithdrawn), explicit physical vault adjustments (VaultAdjusted_In),
--    and physical cash expenses paid at the branch (ExpenseRecorded).
-- 2. Account 1050 (Bank) handles Finance Loan Disbursements, Corporate /
--    Inter-Branch / Inter-Area / Asset Program Transfers, Staff Salaries,
--    and all direct Customer Savings Withdrawals & LAPS Payouts (Option A).
-- 3. Upfront Finance Loan deductions (Markup, Contingency, Gap Fee) settle
--    non-cash directly from Savings (FeeOffsetFromSavings, GapFeeOffsetFromSavings)
--    so Vault Cash (1000) never leaks and Loan Portfolio (1200) equals
--    contractual active_credit.
-- =============================================================================

INSERT INTO public.posting_rules (event_type, debit_account, credit_account, version, effective_from, enabled)
VALUES
    -- Bank-routed operational & treasury postings (Account 1050)
    ('LoanDisbursed',                  '1200', '1050', 1, '2026-01-01', TRUE),
    ('CashTransferred_HO_In',          '1050', '3100', 1, '2026-01-01', TRUE),
    ('CashTransferred_HO_In_Reversed', '3100', '1050', 1, '2026-01-01', TRUE),
    ('CashTransferred_HO_Out',         '3100', '1050', 1, '2026-01-01', TRUE),
    ('CashTransferred_HO_Out_Reversed','1050', '3100', 1, '2026-01-01', TRUE),
    ('SalaryPaid',                     '4100', '1050', 1, '2026-01-01', TRUE),
    ('SalaryReversed',                 '1050', '4100', 1, '2026-01-01', TRUE),
    ('SavingsWithdrawn',               '2000', '1050', 1, '2026-01-01', TRUE),
    ('SavingsWithdrawalReversed',      '1050', '2000', 1, '2026-01-01', TRUE),
    ('LapsPaidOut',                    '2030', '1050', 1, '2026-01-01', TRUE),
    ('LapsPaidOutReversed',            '1050', '2030', 1, '2026-01-01', TRUE),

    -- Non-cash loan origination upfront deductions from savings
    ('FeeOffsetFromSavings',           '2000', '3000', 1, '2026-01-01', TRUE),
    ('GapFeeOffsetFromSavings',        '2000', '1200', 1, '2026-01-01', TRUE),

    -- Explicit physical vault float adjustments (separate from Bank HO Transfers)
    ('VaultAdjusted_In',               '1000', '3100', 1, '2026-01-01', TRUE),
    ('VaultAdjusted_In_Reversed',      '3100', '1000', 1, '2026-01-01', TRUE)
ON CONFLICT (event_type, version) DO UPDATE SET
    debit_account = EXCLUDED.debit_account,
    credit_account = EXCLUDED.credit_account,
    enabled = EXCLUDED.enabled;

-- ---------------------------------------------------------------------------
-- Server-side Bank Balance RPC (Account 1050 Net Position)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_account_1050_bank_balance(
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
    WHERE account_code = '1050'
      AND (p_branch_id IS NULL OR branch_id = p_branch_id)
      AND (p_cutoff_timestamp IS NULL OR created_at <= p_cutoff_timestamp);

    RETURN v_balance;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_account_1050_bank_balance(uuid, timestamptz) TO service_role;
