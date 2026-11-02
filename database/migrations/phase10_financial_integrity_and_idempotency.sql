-- Migration: Phase 10 - Financial Integrity, Idempotency, and Concurrency Control
-- Target: ICARE Core Banking Platform (Supabase PostgreSQL)
-- Description: Creates the idempotency registry, adds database-level uniqueness constraints,
-- and updates atomic_execute_operations with concurrency guards and status invariant enforcement.

-- ============================================================================
-- 1. Idempotency Registry Table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.idempotency_keys (
    key VARCHAR(128) PRIMARY KEY,
    scope VARCHAR(64) NOT NULL, -- e.g. 'repayment', 'batch_collection', 'disbursement', 'withdrawal'
    request_hash VARCHAR(64) NOT NULL, -- SHA-256 of normalized request parameters
    status VARCHAR(32) NOT NULL DEFAULT 'PROCESSING', -- 'PROCESSING', 'COMMITTED', 'FAILED'
    response_code INTEGER,
    response_body JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    locked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours')
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_scope ON public.idempotency_keys(scope, status);
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires ON public.idempotency_keys(expires_at);

-- Enable RLS and grant service_role permissions
ALTER TABLE public.idempotency_keys ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'idempotency_keys' AND policyname = 'service_role_all_idempotency_keys'
    ) THEN
        CREATE POLICY service_role_all_idempotency_keys ON public.idempotency_keys
            FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
END $$;

-- ============================================================================
-- 2. Atomic Idempotency Lock Management Function
-- ============================================================================
CREATE OR REPLACE FUNCTION acquire_idempotency_lock(
    p_key VARCHAR,
    p_scope VARCHAR,
    p_request_hash VARCHAR,
    p_timeout_seconds INTEGER DEFAULT 60
) RETURNS JSONB AS $$
DECLARE
    v_record public.idempotency_keys%ROWTYPE;
BEGIN
    SELECT * INTO v_record FROM public.idempotency_keys WHERE key = p_key FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.idempotency_keys (key, scope, request_hash, status, locked_at)
        VALUES (p_key, p_scope, p_request_hash, 'PROCESSING', NOW())
        RETURNING * INTO v_record;
        RETURN jsonb_build_object('action', 'PROCEED', 'status', 'NEW');
    END IF;

    -- Check for request payload mismatch
    IF v_record.request_hash <> p_request_hash THEN
        RAISE EXCEPTION 'ERR_IDEMPOTENCY_PAYLOAD_MISMATCH: Idempotency key % was previously used with different parameters', p_key;
    END IF;

    -- If already committed, return cached response for immediate replay
    IF v_record.status = 'COMMITTED' THEN
        RETURN jsonb_build_object(
            'action', 'REPLAY',
            'status', 'COMMITTED',
            'response_code', v_record.response_code,
            'response_body', v_record.response_body
        );
    END IF;

    -- In-flight concurrency lock check
    IF v_record.status = 'PROCESSING' THEN
        IF v_record.locked_at > (NOW() - (p_timeout_seconds || ' seconds')::INTERVAL) THEN
            RETURN jsonb_build_object(
                'action', 'CONFLICT',
                'status', 'PROCESSING',
                'message', 'Transaction currently being processed by another worker'
            );
        ELSE
            -- Lock expired; prior worker likely crashed. Safely acquire lock.
            UPDATE public.idempotency_keys 
            SET locked_at = NOW() 
            WHERE key = p_key;
            RETURN jsonb_build_object('action', 'PROCEED', 'status', 'RECOVERED_LOCK');
        END IF;
    END IF;

    -- If previously marked failed, allow retry
    UPDATE public.idempotency_keys 
    SET status = 'PROCESSING', locked_at = NOW() 
    WHERE key = p_key;
    RETURN jsonb_build_object('action', 'PROCEED', 'status', 'RETRY');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. Database-Level Partial Unique Constraints for Financial Records
-- ============================================================================

-- Repayments
ALTER TABLE public.repayments ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(128);
CREATE UNIQUE INDEX IF NOT EXISTS uq_repayments_idempotency_key 
ON public.repayments(idempotency_key) 
WHERE idempotency_key IS NOT NULL;

-- Individual Savings
ALTER TABLE public.individual_savings ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(128);
CREATE UNIQUE INDEX IF NOT EXISTS uq_individual_savings_idempotency_key 
ON public.individual_savings(idempotency_key) 
WHERE idempotency_key IS NOT NULL;

-- Group Savings
ALTER TABLE public.group_savings ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(128);
CREATE UNIQUE INDEX IF NOT EXISTS uq_group_savings_idempotency_key 
ON public.group_savings(idempotency_key) 
WHERE idempotency_key IS NOT NULL;

-- ============================================================================
-- 4. Hardened atomic_execute_operations RPC
-- ============================================================================
CREATE OR REPLACE FUNCTION atomic_execute_operations(p_operations jsonb)
RETURNS void AS $$
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

        -- Global check for supported op types
        IF op_type NOT IN ('insert', 'update', 'update_loan', 'post_financial_transaction') THEN
            RAISE EXCEPTION 'ERR_UNAUTHORIZED_OP_TYPE: Operation type % is not permitted', op_type;
        END IF;

        -- Matrix Router: Explicit (op_type, table) validation
        IF op_type = 'post_financial_transaction' THEN
            PERFORM public.post_financial_transaction(
                COALESCE(rec->'header_payload', (rec->>'header_payload')::jsonb),
                COALESCE(rec->'entries_payload', (rec->>'entries_payload')::jsonb)
            );

        -- Table: repayments
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

        -- Table: loans
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

                -- Concurrency & Idempotency Guard: Disallow activating an already active loan
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

        -- Table: clients
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

        -- Table: client_status_history
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

        -- Table: individual_savings
        ELSIF tbl = 'individual_savings' THEN
            IF op_type = 'insert' THEN
                IF rec->>'client_id' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_INDIVIDUAL_SAVINGS_PAYLOAD: client_id and branch_id are required';
                END IF;

                INSERT INTO public.individual_savings (
                    id, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount,
                    date, reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    (rec->>'officer_id')::uuid,
                    COALESCE((rec->>'deposit_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'withdrawal_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'date')::date, (rec->>'posting_date')::date, CURRENT_DATE),
                    rec->>'reference',
                    rec->>'remarks',
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table individual_savings is not permitted', op_type;
            END IF;

        -- Table: group_savings
        ELSIF tbl = 'group_savings' THEN
            IF op_type = 'insert' THEN
                IF rec->>'group_id' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_GROUP_SAVINGS_PAYLOAD: group_id and branch_id are required';
                END IF;

                INSERT INTO public.group_savings (
                    id, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount,
                    date, reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    (rec->>'group_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    (rec->>'officer_id')::uuid,
                    COALESCE((rec->>'deposit_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'withdrawal_amount')::numeric(16, 2), 0.00),
                    COALESCE((rec->>'date')::date, (rec->>'posting_date')::date, CURRENT_DATE),
                    rec->>'reference',
                    rec->>'remarks',
                    rec->>'idempotency_key',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table group_savings is not permitted', op_type;
            END IF;

        -- Table: treasury_transactions
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

        -- Table: event_store
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

        -- Table: audit_logs
        ELSIF tbl = 'audit_logs' THEN
            IF op_type = 'insert' THEN
                IF rec->>'action' IS NULL THEN
                    RAISE EXCEPTION 'ERR_AUDIT_LOG_PAYLOAD: action is required';
                END IF;

                INSERT INTO public.audit_logs (
                    id, user_id, action, description, table_name, record_id, created_at
                ) VALUES (
                    COALESCE((rec->>'id')::uuid, gen_random_uuid()),
                    NULLIF((rec->>'user_id'), '')::uuid,
                    rec->>'action',
                    rec->>'description',
                    rec->>'table_name',
                    NULLIF((rec->>'record_id'), '')::uuid,
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table audit_logs is not permitted', op_type;
            END IF;

        ELSE
            RAISE EXCEPTION 'ERR_UNAUTHORIZED_TABLE: Table % is not supported in atomic transactions', tbl;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
