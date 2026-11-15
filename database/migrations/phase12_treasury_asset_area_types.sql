-- Migration: Phase 12 - Expand treasury_transactions.transaction_type CHECK constraint
-- Adds ASSET_PROGRAM, INTER_AREA_IN, and INTER_AREA_OUT so manual Master Cashbook
-- BM Treasury inputs for Asset Program and Inter-Area transfers persist without constraint errors.

ALTER TABLE public.treasury_transactions
    DROP CONSTRAINT IF EXISTS treasury_transactions_transaction_type_check;

ALTER TABLE public.treasury_transactions
    ADD CONSTRAINT treasury_transactions_transaction_type_check CHECK (
        transaction_type IN (
            'HO_TRANSFER_IN', 'HO_TRANSFER_OUT',
            'BANK_DEPOSIT', 'BANK_WITHDRAWAL',
            'OFFICE_EXPENSE', 'SALARY',
            'FLOAT', 'VAULT_ADJUSTMENT',
            'INTER_BRANCH_IN', 'INTER_BRANCH_OUT',
            'INTER_AREA_IN', 'INTER_AREA_OUT',
            'ASSET_PROGRAM'
        )
    );
