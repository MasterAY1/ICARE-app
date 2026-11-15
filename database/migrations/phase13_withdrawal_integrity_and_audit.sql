-- ==============================================================================
-- Phase 13: Withdrawal Integrity, Structured Routing, Reversal Parity & Audit
-- ==============================================================================
-- Preserves all live atomic_execute_operations tables (posting_date schema)
-- while adding internal_savings, laps_savings, fees, withdrawal_requests,
-- user_audit_logs, and financial_transactions status update support.

-- 1. Normalize legacy withdrawal_requests status values ('Pending' -> 'PENDING')
UPDATE public.withdrawal_requests
SET status = UPPER(TRIM(status))
WHERE status IS DISTINCT FROM UPPER(TRIM(status));

-- 2. Extend withdrawal_requests with structured routing, actor, idempotency, and execution audit fields
ALTER TABLE public.withdrawal_requests
    ADD COLUMN IF NOT EXISTS destination_id TEXT,
    ADD COLUMN IF NOT EXISTS destination_type TEXT,
    ADD COLUMN IF NOT EXISTS fee_type TEXT,
    ADD COLUMN IF NOT EXISTS officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(255),
    ADD COLUMN IF NOT EXISTS executed_record_id UUID,
    ADD COLUMN IF NOT EXISTS executed_table TEXT;

ALTER TABLE public.withdrawal_requests
    DROP CONSTRAINT IF EXISTS withdrawal_requests_amount_positive_check;
ALTER TABLE public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_amount_positive_check CHECK (amount > 0);

ALTER TABLE public.withdrawal_requests
    DROP CONSTRAINT IF EXISTS withdrawal_requests_status_check;
ALTER TABLE public.withdrawal_requests
    ADD CONSTRAINT withdrawal_requests_status_check CHECK (status IN ('PENDING', 'PROCESSING', 'APPROVED', 'REJECTED'));

CREATE UNIQUE INDEX IF NOT EXISTS uq_withdrawal_requests_idempotency_key
    ON public.withdrawal_requests (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_wr_officer_id
    ON public.withdrawal_requests (officer_id);

-- 3. Add idempotency_key to internal_savings, laps_savings, and fees
ALTER TABLE public.internal_savings
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS uq_internal_savings_idempotency_key
    ON public.internal_savings (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

ALTER TABLE public.laps_savings
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS uq_laps_savings_idempotency_key
    ON public.laps_savings (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

ALTER TABLE public.fees
    ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(255);
CREATE UNIQUE INDEX IF NOT EXISTS uq_fees_idempotency_key
    ON public.fees (idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- 4. Remove blocking >= 0 CHECK constraints on laps_savings so compensating
--    negative reversal rows match individual_savings and group_savings
ALTER TABLE public.laps_savings
    DROP CONSTRAINT IF EXISTS laps_savings_withdrawal_amount_check,
    DROP CONSTRAINT IF EXISTS laps_savings_deposit_amount_check;

-- 5. Seed missing posting_rules used by withdrawal reversals and LAPS restoration
INSERT INTO public.posting_rules (event_type, debit_account, credit_account, version, effective_from, enabled)
VALUES
    ('SavingsWithdrawalReversed', '1000', '2000', 1, '2026-01-01', true),
    ('LapsRestoredToSavings', '2030', '2000', 1, '2026-01-01', true)
ON CONFLICT (event_type, version) DO NOTHING;

-- 6. Extend atomic_execute_operations while preserving all live branches
CREATE OR REPLACE FUNCTION public.atomic_execute_operations(p_operations jsonb)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    op JSONB;
    op_type TEXT;
    tbl TEXT;
    rec JSONB;
    v_match JSONB;
    v_rec_id UUID;
    v_branch_id UUID;
    v_amount NUMERIC;
    v_row_count INTEGER;
    v_current_status TEXT;
BEGIN
    IF p_operations IS NULL OR jsonb_array_length(p_operations) = 0 THEN
        RAISE EXCEPTION 'ERR_EMPTY_OPERATIONS: Operation batch cannot be null or empty';
    END IF;

    FOR op IN SELECT * FROM jsonb_array_elements(p_operations)
    LOOP
        op_type := op->>'type';
        tbl := op->>'table';
        rec := op->'record';
        v_match := op->'match';

        IF op_type NOT IN ('insert', 'update', 'update_loan', 'post_financial_transaction') THEN
            RAISE EXCEPTION 'ERR_UNAUTHORIZED_OP_TYPE: Operation type % is not permitted', op_type;
        END IF;

        IF op_type = 'post_financial_transaction' THEN
            PERFORM public.post_financial_transaction(
                COALESCE(rec->'header_payload', (rec->>'header_payload')::jsonb),
                COALESCE(rec->'entries_payload', (rec->>'entries_payload')::jsonb)
            );

        ELSIF tbl = 'repayments' THEN
            IF op_type = 'insert' THEN
                IF rec->>'amount_paid' IS NULL OR rec->>'loan_id' IS NULL OR rec->>'client_id' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_REPAYMENT_INSERT_PAYLOAD: amount_paid, loan_id, client_id, and branch_id are required';
                END IF;

                v_amount := (rec->>'amount_paid')::numeric;
                IF v_amount <> ROUND(v_amount, 2) THEN
                    RAISE EXCEPTION 'ERR_INVALID_CURRENCY_PRECISION: Repayment amount % exceeds 2 decimal places', v_amount;
                END IF;

                INSERT INTO public.repayments (
                    id, date, loan_id, client_id, amount_paid, officer_id, branch_id,
                    payment_status, expected_amount, overdue_amount, note, transaction_type,
                    idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    COALESCE((rec->>'date')::timestamptz, (rec->>'payment_date')::timestamptz, NOW()),
                    (rec->>'loan_id')::uuid,
                    (rec->>'client_id')::uuid,
                    v_amount,
                    (rec->>'officer_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    COALESCE(rec->>'payment_status', 'PAID'),
                    COALESCE((rec->>'expected_amount')::numeric, 0.00),
                    COALESCE((rec->>'overdue_amount')::numeric, 0.00),
                    COALESCE(rec->>'note', ''),
                    COALESCE(rec->>'transaction_type', 'Loan'),
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );

            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE((rec->>'id')::uuid, (v_match->>'id')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_REPAYMENT_UPDATE_IDENTIFIER: Record id is required for repayment update';
                END IF;

                v_branch_id := COALESCE((rec->>'branch_id')::uuid, (v_match->>'branch_id')::uuid);

                UPDATE public.repayments
                SET amount_paid = COALESCE((rec->>'amount_paid')::numeric, repayments.amount_paid),
                    date = COALESCE((rec->>'date')::timestamptz, repayments.date),
                    payment_status = COALESCE(rec->>'payment_status', repayments.payment_status),
                    expected_amount = COALESCE((rec->>'expected_amount')::numeric, repayments.expected_amount),
                    overdue_amount = COALESCE((rec->>'overdue_amount')::numeric, repayments.overdue_amount),
                    note = COALESCE(rec->>'note', repayments.note),
                    transaction_type = COALESCE(rec->>'transaction_type', repayments.transaction_type),
                    idempotency_key = COALESCE(rec->>'idempotency_key', repayments.idempotency_key)
                WHERE id = v_rec_id
                  AND (v_branch_id IS NULL OR repayments.branch_id = v_branch_id);

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Repayment % not found or branch consistency check failed', v_rec_id;
                ELSIF v_row_count > 1 THEN
                    RAISE EXCEPTION 'ERR_MULTIPLE_RECORDS_UPDATED: Repayment update affected % records', v_row_count;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table repayments is not permitted', op_type;
            END IF;

        ELSIF tbl = 'loans' THEN
            IF op_type = 'insert' THEN
                IF rec->>'client_id' IS NULL OR rec->>'product_id' IS NULL OR rec->>'branch_id' IS NULL OR rec->>'amount' IS NULL THEN
                    RAISE EXCEPTION 'ERR_LOAN_INSERT_PAYLOAD: client_id, product_id, branch_id, and amount are required';
                END IF;

                v_amount := (rec->>'amount')::numeric;
                IF v_amount <= 0 OR v_amount <> ROUND(v_amount, 2) THEN
                    RAISE EXCEPTION 'ERR_INVALID_LOAN_AMOUNT: Loan amount % must be positive and have at most 2 decimal places', v_amount;
                END IF;

                INSERT INTO public.loans (
                    loan_id, client_id, product_id, branch_id, officer_id, amount,
                    status, start_date, expected_end_date, disbursement_date, extra_fields, created_at
                ) VALUES (
                    COALESCE((rec->>'loan_id')::uuid, (rec->>'id')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    (rec->>'product_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    (rec->>'officer_id')::uuid,
                    v_amount,
                    COALESCE(rec->>'status', 'Active'),
                    (rec->>'start_date')::date,
                    (rec->>'expected_end_date')::date,
                    (rec->>'disbursement_date')::date,
                    COALESCE(rec->'extra_fields', '{}'::jsonb),
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );

            ELSIF op_type IN ('update', 'update_loan') THEN
                v_rec_id := COALESCE((v_match->>'loan_id')::uuid, (rec->>'loan_id')::uuid, (rec->>'id')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_LOAN_UPDATE_IDENTIFIER: loan_id is required for loan update';
                END IF;

                v_branch_id := COALESCE((v_match->>'branch_id')::uuid, (rec->>'branch_id')::uuid);

                IF rec->>'status' = 'Active' THEN
                    SELECT status INTO v_current_status FROM public.loans WHERE loan_id = v_rec_id FOR UPDATE;
                    IF v_current_status = 'Active' THEN
                        RAISE EXCEPTION 'ERR_LOAN_ALREADY_ACTIVE: Loan % has already been activated and disbursed. Duplicate disbursement rejected.', v_rec_id;
                    END IF;
                END IF;

                UPDATE public.loans
                SET status = COALESCE(rec->>'status', status),
                    start_date = COALESCE((rec->>'start_date')::date, start_date),
                    expected_end_date = COALESCE((rec->>'expected_end_date')::date, expected_end_date),
                    disbursement_date = COALESCE((rec->>'disbursement_date')::date, disbursement_date),
                    extra_fields = CASE
                        WHEN rec->'extra_fields' IS NOT NULL THEN COALESCE(loans.extra_fields, '{}'::jsonb) || (rec->'extra_fields')
                        ELSE loans.extra_fields
                    END
                WHERE loan_id = v_rec_id
                  AND (v_branch_id IS NULL OR loans.branch_id = v_branch_id);

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Loan % not found or branch consistency check failed', v_rec_id;
                ELSIF v_row_count > 1 THEN
                    RAISE EXCEPTION 'ERR_MULTIPLE_RECORDS_UPDATED: Loan update affected % records', v_row_count;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table loans is not permitted', op_type;
            END IF;

        ELSIF tbl = 'clients' THEN
            IF op_type = 'update' THEN
                v_rec_id := COALESCE((v_match->>'client_id')::uuid, (rec->>'client_id')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_CLIENT_UPDATE_IDENTIFIER: client_id is required for client update';
                END IF;

                v_branch_id := COALESCE((v_match->>'branch_id')::uuid, (rec->>'branch_id')::uuid);

                UPDATE public.clients
                SET status = COALESCE(rec->>'status', status),
                    status_id = COALESCE((rec->>'status_id')::uuid, status_id),
                    status_changed_at = COALESCE((rec->>'status_changed_at')::timestamptz, status_changed_at),
                    status_changed_by = COALESCE(rec->>'status_changed_by', status_changed_by),
                    status_note = COALESCE(rec->>'status_note', status_note)
                WHERE client_id = v_rec_id
                  AND (v_branch_id IS NULL OR clients.branch_id = v_branch_id);

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Client % not found or branch consistency check failed', v_rec_id;
                ELSIF v_row_count > 1 THEN
                    RAISE EXCEPTION 'ERR_MULTIPLE_RECORDS_UPDATED: Client update affected % records', v_row_count;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table clients is not permitted (updates only)', op_type;
            END IF;

        ELSIF tbl = 'client_status_history' THEN
            IF op_type = 'insert' THEN
                IF rec->>'client_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_STATUS_HISTORY_PAYLOAD: client_id is required';
                END IF;

                INSERT INTO public.client_status_history (
                    id, client_id, from_status, to_status, changed_by, reason, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    rec->>'from_status',
                    COALESCE(rec->>'to_status', rec->>'status'),
                    rec->>'changed_by',
                    COALESCE(rec->>'reason', rec->>'status_note', ''),
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table client_status_history is not permitted', op_type;
            END IF;

        ELSIF tbl = 'individual_savings' THEN
            IF op_type = 'insert' THEN
                IF rec->>'client_id' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_INDIVIDUAL_SAVINGS_PAYLOAD: client_id and branch_id are required';
                END IF;

                INSERT INTO public.individual_savings (
                    id, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount,
                    posting_date, reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE((rec->>'deposit_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'withdrawal_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    rec->>'reference',
                    rec->>'remarks',
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table individual_savings is not permitted', op_type;
            END IF;

        ELSIF tbl = 'group_savings' THEN
            IF op_type = 'insert' THEN
                IF rec->>'group_id' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_GROUP_SAVINGS_PAYLOAD: group_id and branch_id are required';
                END IF;

                INSERT INTO public.group_savings (
                    id, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount,
                    posting_date, reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    (rec->>'group_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE((rec->>'deposit_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'withdrawal_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    rec->>'reference',
                    rec->>'remarks',
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table group_savings is not permitted', op_type;
            END IF;

        ELSIF tbl = 'internal_savings' THEN
            IF op_type = 'insert' THEN
                IF rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_INTERNAL_SAVINGS_PAYLOAD: branch_id is required';
                END IF;

                INSERT INTO public.internal_savings (
                    id, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount,
                    posting_date, reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    NULLIF(rec->>'client_id', '')::uuid,
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE((rec->>'deposit_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'withdrawal_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    rec->>'reference',
                    rec->>'remarks',
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table internal_savings is not permitted', op_type;
            END IF;

        ELSIF tbl = 'laps_savings' THEN
            IF op_type = 'insert' THEN
                IF rec->>'client_id' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_LAPS_SAVINGS_PAYLOAD: client_id and branch_id are required';
                END IF;

                INSERT INTO public.laps_savings (
                    id, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount,
                    posting_date, reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE((rec->>'deposit_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'withdrawal_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    rec->>'reference',
                    rec->>'remarks',
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table laps_savings is not permitted', op_type;
            END IF;

        ELSIF tbl = 'fees' THEN
            IF op_type = 'insert' THEN
                IF rec->>'branch_id' IS NULL OR rec->>'fee_type' IS NULL OR rec->>'amount' IS NULL THEN
                    RAISE EXCEPTION 'ERR_FEES_PAYLOAD: branch_id, fee_type, and amount are required';
                END IF;

                v_amount := (rec->>'amount')::numeric;
                IF v_amount <> ROUND(v_amount, 2) THEN
                    RAISE EXCEPTION 'ERR_INVALID_CURRENCY_PRECISION: Fee amount % exceeds 2 decimal places', v_amount;
                END IF;

                INSERT INTO public.fees (
                    id, posting_date, client_id, branch_id, officer_id, fee_type, amount,
                    reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    NULLIF(rec->>'client_id', '')::uuid,
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    rec->>'fee_type',
                    v_amount::numeric(16, 2),
                    rec->>'reference',
                    rec->>'remarks',
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table fees is not permitted', op_type;
            END IF;

        ELSIF tbl = 'withdrawal_requests' THEN
            IF op_type = 'insert' THEN
                IF rec->>'savings_type' IS NULL OR rec->>'operation_type' IS NULL OR rec->>'client_name' IS NULL OR rec->>'requested_by' IS NULL OR rec->>'amount' IS NULL THEN
                    RAISE EXCEPTION 'ERR_WR_INSERT_PAYLOAD: savings_type, operation_type, client_name, requested_by, and amount are required';
                END IF;

                v_amount := (rec->>'amount')::numeric;
                IF v_amount <= 0 OR v_amount <> ROUND(v_amount, 2) THEN
                    RAISE EXCEPTION 'ERR_INVALID_WR_AMOUNT: Withdrawal request amount % must be positive and have at most 2 decimal places', v_amount;
                END IF;

                INSERT INTO public.withdrawal_requests (
                    id, savings_type, operation_type, client_id, client_name, group_name, loan_id,
                    branch_id, requested_by, officer_id, amount, reference, remarks, payout_method,
                    destination_id, destination_type, fee_type, idempotency_key,
                    executed_record_id, executed_table, status, approved_by, approved_at,
                    rejection_reason, operational_date, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    rec->>'savings_type',
                    rec->>'operation_type',
                    rec->>'client_id',
                    rec->>'client_name',
                    rec->>'group_name',
                    rec->>'loan_id',
                    NULLIF(rec->>'branch_id', '')::uuid,
                    rec->>'requested_by',
                    NULLIF(rec->>'officer_id', '')::uuid,
                    v_amount::numeric(16, 2),
                    rec->>'reference',
                    rec->>'remarks',
                    COALESCE(rec->>'payout_method', 'Cash'),
                    rec->>'destination_id',
                    rec->>'destination_type',
                    rec->>'fee_type',
                    rec->>'idempotency_key',
                    NULLIF(rec->>'executed_record_id', '')::uuid,
                    rec->>'executed_table',
                    COALESCE(UPPER(TRIM(rec->>'status')), 'PENDING'),
                    rec->>'approved_by',
                    (rec->>'approved_at')::timestamptz,
                    rec->>'rejection_reason',
                    (rec->>'operational_date')::date,
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );

            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE((v_match->>'id')::uuid, (rec->>'id')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_WR_UPDATE_IDENTIFIER: id is required for withdrawal_requests update';
                END IF;

                v_branch_id := COALESCE((v_match->>'branch_id')::uuid, (rec->>'branch_id')::uuid);
                v_current_status := NULLIF(UPPER(TRIM(v_match->>'status')), '');

                UPDATE public.withdrawal_requests
                SET status = COALESCE(NULLIF(UPPER(TRIM(rec->>'status')), ''), withdrawal_requests.status),
                    approved_by = COALESCE(rec->>'approved_by', withdrawal_requests.approved_by),
                    approved_at = COALESCE((rec->>'approved_at')::timestamptz, withdrawal_requests.approved_at),
                    rejection_reason = COALESCE(rec->>'rejection_reason', withdrawal_requests.rejection_reason),
                    operational_date = COALESCE((rec->>'operational_date')::date, withdrawal_requests.operational_date),
                    executed_record_id = COALESCE(NULLIF(rec->>'executed_record_id', '')::uuid, withdrawal_requests.executed_record_id),
                    executed_table = COALESCE(rec->>'executed_table', withdrawal_requests.executed_table)
                WHERE id = v_rec_id
                  AND (v_branch_id IS NULL OR withdrawal_requests.branch_id = v_branch_id)
                  AND (v_current_status IS NULL OR withdrawal_requests.status = v_current_status);

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Withdrawal request % not found or status/branch guard failed', v_rec_id;
                ELSIF v_row_count > 1 THEN
                    RAISE EXCEPTION 'ERR_MULTIPLE_RECORDS_UPDATED: Withdrawal request update affected % records', v_row_count;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table withdrawal_requests is not permitted', op_type;
            END IF;

        ELSIF tbl = 'treasury_transactions' THEN
            IF op_type = 'insert' THEN
                IF rec->>'branch_id' IS NULL OR rec->>'amount' IS NULL OR rec->>'transaction_type' IS NULL THEN
                    RAISE EXCEPTION 'ERR_TREASURY_PAYLOAD: branch_id, amount, and transaction_type are required';
                END IF;

                INSERT INTO public.treasury_transactions (
                    id, posting_date, branch_id, officer_id, transaction_type, amount,
                    source_branch, destination_branch, reference, remarks, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    (rec->>'branch_id')::uuid,
                    (rec->>'officer_id')::uuid,
                    rec->>'transaction_type',
                    (rec->>'amount')::numeric(16, 2),
                    rec->>'source_branch',
                    rec->>'destination_branch',
                    rec->>'reference',
                    rec->>'remarks',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table treasury_transactions is not permitted', op_type;
            END IF;

        ELSIF tbl = 'financial_transactions' THEN
            IF op_type = 'update' THEN
                v_rec_id := COALESCE((v_match->>'transaction_id')::uuid, (rec->>'transaction_id')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_FT_UPDATE_IDENTIFIER: transaction_id is required';
                END IF;

                UPDATE public.financial_transactions
                SET status = COALESCE(rec->>'status', financial_transactions.status)
                WHERE transaction_id = v_rec_id;

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Financial transaction % not found', v_rec_id;
                ELSIF v_row_count > 1 THEN
                    RAISE EXCEPTION 'ERR_MULTIPLE_RECORDS_UPDATED: Financial transaction update affected % records', v_row_count;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table financial_transactions is not permitted (updates only)', op_type;
            END IF;

        ELSIF tbl = 'event_store' THEN
            IF op_type = 'insert' THEN
                IF rec->>'event_id' IS NULL OR rec->>'aggregate_id' IS NULL OR rec->>'event_type' IS NULL THEN
                    RAISE EXCEPTION 'ERR_EVENT_STORE_PAYLOAD: event_id, aggregate_id, and event_type are required';
                END IF;

                INSERT INTO public.event_store (
                    event_id, aggregate_id, aggregate_type, event_type, version,
                    payload, metadata, status, created_at
                ) VALUES (
                    (rec->>'event_id')::uuid,
                    (rec->>'aggregate_id')::uuid,
                    rec->>'aggregate_type',
                    rec->>'event_type',
                    COALESCE((rec->>'version')::int, 1),
                    COALESCE(rec->'payload', '{}'::jsonb),
                    COALESCE(rec->'metadata', '{}'::jsonb),
                    COALESCE(rec->>'status', 'Completed'),
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table event_store is not permitted', op_type;
            END IF;

        ELSIF tbl = 'audit_logs' THEN
            IF op_type = 'insert' THEN
                IF rec->>'action' IS NULL THEN
                    RAISE EXCEPTION 'ERR_AUDIT_LOG_PAYLOAD: action is required';
                END IF;

                INSERT INTO public.audit_logs (
                    id, user_id, action, description, table_name, record_id, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    CASE
                        WHEN NULLIF(rec->>'user_id', '') IS NOT NULL
                             AND (rec->>'user_id')::uuid <> '00000000-0000-0000-0000-000000000000'::uuid
                        THEN (rec->>'user_id')::uuid
                        ELSE NULL
                    END,
                    rec->>'action',
                    rec->>'description',
                    rec->>'table_name',
                    NULLIF((rec->>'record_id'), '')::uuid,
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table audit_logs is not permitted', op_type;
            END IF;

        ELSIF tbl = 'user_audit_logs' THEN
            IF op_type = 'insert' THEN
                IF rec->>'username' IS NULL OR rec->>'role' IS NULL OR rec->>'action' IS NULL OR rec->>'module' IS NULL THEN
                    RAISE EXCEPTION 'ERR_USER_AUDIT_LOG_PAYLOAD: username, role, action, and module are required';
                END IF;

                INSERT INTO public.user_audit_logs (
                    id, timestamp, user_id, username, role, branch, area_manager,
                    action, module, entity_type, entity_id, display_name,
                    previous_value, new_value, status
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    COALESCE((rec->>'timestamp')::timestamptz, NOW()),
                    CASE
                        WHEN NULLIF(rec->>'user_id', '') IS NOT NULL
                             AND (rec->>'user_id')::uuid <> '00000000-0000-0000-0000-000000000000'::uuid
                        THEN (rec->>'user_id')::uuid
                        ELSE NULL
                    END,
                    rec->>'username',
                    rec->>'role',
                    rec->>'branch',
                    rec->>'area_manager',
                    rec->>'action',
                    rec->>'module',
                    rec->>'entity_type',
                    NULLIF(rec->>'entity_id', '')::uuid,
                    rec->>'display_name',
                    rec->'previous_value',
                    rec->'new_value',
                    COALESCE(NULLIF(rec->>'status', ''), 'SUCCESS')
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table user_audit_logs is not permitted', op_type;
            END IF;

        ELSE
            RAISE EXCEPTION 'ERR_UNAUTHORIZED_TABLE: Table % is not supported in atomic transactions', tbl;
        END IF;
    END LOOP;
END;
$function$;
