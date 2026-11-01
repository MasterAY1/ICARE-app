-- Phase 2 Production Hardening: Enforce composite uniqueness on loan schedule installments
-- Eliminates race conditions and duplicate schedule generation during concurrent origination retries.

DO $$
BEGIN
    -- 1. Ensure zero duplicate records exist before adding constraint
    IF EXISTS (
        SELECT 1
        FROM public.loan_schedule
        GROUP BY loan_id, installment_number
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Cannot add unique constraint: duplicate (loan_id, installment_number) records exist in public.loan_schedule';
    END IF;

    -- 2. Add composite unique constraint if not already present
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON c.conrelid = t.oid
        JOIN pg_namespace n ON t.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND t.relname = 'loan_schedule'
          AND c.conname = 'uq_loan_installment'
    ) THEN
        ALTER TABLE public.loan_schedule
            ADD CONSTRAINT uq_loan_installment UNIQUE (loan_id, installment_number);
    END IF;

    -- 3. Clean up legacy redundant non-unique index if it exists
    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'loan_schedule'
          AND indexname = 'idx_loan_schedule_loan_installment'
    ) THEN
        DROP INDEX public.idx_loan_schedule_loan_installment;
    END IF;
END $$;
