-- =============================================================================
-- PHASE 14: COMPLETE CO STACK INTEGRITY OVERHAUL (BIA-CO-OPS-023 OPTION 1)
-- =============================================================================
-- 1. Schema additions: group_id on fees & withdrawal_requests (prevents Group
--    Fee Payment FK crash against fees.client_id -> clients.client_id).
-- 2. Constraint alignments:
--    - loans_status_check: add 'Defaulter'
--    - correction_requests_status_check: add 'Processing'
-- 3. Posting rules seed: BankWithdrawalReversed, SavingsDepositReversed,
--    CashTransferred_HO_In_Reversed, CashTransferred_HO_Out_Reversed,
--    ProductWithdrawn.
-- 4. Deduplicate the 16 split 2026-09-18 loan_payoff_excess_records pairs into
--    'FULL_PAYOFF_AND_EXCESS' and enforce unique partial index on repayment_id.
-- 5. Safe non-ledger operational metadata cleanup (no immutable ledger mutation).
-- 6. Rebuild atomic_execute_operations RPC aligned with live PostgreSQL columns
--    and single-RPC atomicity across origination, collections, withdrawals, and
--    client lifecycle transitions.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Add nullable group_id FK columns on fees and withdrawal_requests
-- ---------------------------------------------------------------------------
ALTER TABLE public.withdrawal_requests
    ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(group_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_group_id
    ON public.withdrawal_requests(group_id);

ALTER TABLE public.fees
    ADD COLUMN IF NOT EXISTS group_id UUID REFERENCES public.groups(group_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fees_group_id
    ON public.fees(group_id);

-- ---------------------------------------------------------------------------
-- 2. Align CHECK constraints on loans and correction_requests
-- ---------------------------------------------------------------------------
ALTER TABLE public.loans DROP CONSTRAINT IF EXISTS loans_status_check;
ALTER TABLE public.loans ADD CONSTRAINT loans_status_check CHECK (
    status = ANY (ARRAY[
        'Pending'::text,
        'Approved'::text,
        'Active'::text,
        'Completed'::text,
        'Closed'::text,
        'Defaulter'::text,
        'Internal Account'::text,
        'Written Off'::text,
        'Rejected'::text,
        'Cancelled'::text
    ])
);

ALTER TABLE public.correction_requests DROP CONSTRAINT IF EXISTS correction_requests_status_check;
ALTER TABLE public.correction_requests ADD CONSTRAINT correction_requests_status_check CHECK (
    status = ANY (ARRAY[
        'Pending'::text,
        'Processing'::text,
        'Approved'::text,
        'Rejected'::text
    ])
);

-- ---------------------------------------------------------------------------
-- 3. Seed missing posting rules (reversals & product withdrawal)
-- ---------------------------------------------------------------------------
INSERT INTO public.posting_rules (event_type, debit_account, credit_account, version, enabled) VALUES
('BankWithdrawalReversed', '1050', '1000', 1, TRUE),
('SavingsDepositReversed', '2000', '1000', 1, TRUE),
('CashTransferred_HO_In_Reversed', '3100', '1000', 1, TRUE),
('CashTransferred_HO_Out_Reversed', '1000', '3100', 1, TRUE),
('ProductWithdrawn', '2000', '1000', 1, TRUE)
ON CONFLICT (event_type, version) DO UPDATE SET
    debit_account = EXCLUDED.debit_account,
    credit_account = EXCLUDED.credit_account,
    enabled = EXCLUDED.enabled;

-- ---------------------------------------------------------------------------
-- 4. Deduplicate split loan_payoff_excess_records & enforce unique index
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- 5. Safe non-ledger operational metadata repairs
-- ---------------------------------------------------------------------------
-- 5a. Backfill executed_record_id / executed_table for matching APPROVED withdrawal_requests
UPDATE public.withdrawal_requests wr
SET executed_record_id = isav.id,
    executed_table = 'individual_savings'
FROM public.individual_savings isav
WHERE wr.status = 'APPROVED'
  AND wr.executed_record_id IS NULL
  AND COALESCE(wr.reference, '') <> ''
  AND isav.reference = wr.reference;

UPDATE public.withdrawal_requests wr
SET executed_record_id = gsav.id,
    executed_table = 'group_savings'
FROM public.group_savings gsav
WHERE wr.status = 'APPROVED'
  AND wr.executed_record_id IS NULL
  AND COALESCE(wr.reference, '') <> ''
  AND gsav.reference = wr.reference;

UPDATE public.withdrawal_requests wr
SET executed_record_id = lsav.id,
    executed_table = 'laps_savings'
FROM public.laps_savings lsav
WHERE wr.status = 'APPROVED'
  AND wr.executed_record_id IS NULL
  AND COALESCE(wr.reference, '') <> ''
  AND lsav.reference = wr.reference;

-- Backfill withdrawal_requests.officer_id from matched client or branch user suffix
UPDATE public.withdrawal_requests wr
SET officer_id = c.officer_id
FROM public.clients c
WHERE wr.officer_id IS NULL
  AND wr.client_id ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
  AND c.client_id = wr.client_id::uuid
  AND c.officer_id IS NOT NULL;

UPDATE public.withdrawal_requests wr
SET officer_id = u.id
FROM public.app_users u
WHERE wr.officer_id IS NULL
  AND wr.branch_id IS NOT NULL
  AND u.branch_id = wr.branch_id
  AND (u.username = wr.requested_by OR u.username ILIKE '%_' || wr.requested_by);

-- 5b. Sync OGI-14-011 fully-paid Finance loan 12a970ec-2f09-4440-acdd-9d44752ae13e -> Completed
UPDATE public.loans l
SET status = 'Completed',
    updated_at = NOW()
WHERE l.loan_id = '12a970ec-2f09-4440-acdd-9d44752ae13e'::uuid
  AND l.status = 'Active'
  AND l.is_deleted = FALSE
  AND COALESCE((SELECT SUM(r.amount_paid) FROM public.repayments r WHERE r.loan_id = l.loan_id), 0) >= l.total_due;

-- 5c. Mark unpaid loan_schedule rows as 'Paid' for Completed loans whose total repayments cover total_due
UPDATE public.loan_schedule ls
SET status = 'Paid',
    paid_amount = CASE
        WHEN COALESCE(ls.paid_amount, 0) < ls.total_due THEN ls.total_due
        ELSE ls.paid_amount
    END,
    paid_date = COALESCE(ls.paid_date, l.expected_end_date, l.disbursement_date, l.date),
    updated_at = NOW()
FROM public.loans l
WHERE ls.loan_id = l.loan_id
  AND l.status = 'Completed'
  AND l.is_deleted = FALSE
  AND ls.status <> 'Paid'
  AND COALESCE((SELECT SUM(r.amount_paid) FROM public.repayments r WHERE r.loan_id = l.loan_id), 0) >= l.total_due;

-- 5d. Sync Ogijo active-loan 'Inactive (Savings Only)' clients -> 'On Loan' (leaving 'Defaulter' and 'Closed' untouched)
UPDATE public.clients c
SET status = 'On Loan',
    status_id = '11111111-1111-1111-1111-111111110003'::uuid,
    updated_at = NOW()
WHERE c.is_deleted = FALSE
  AND c.status = 'Inactive (Savings Only)'
  AND EXISTS (
      SELECT 1 FROM public.loans l
      WHERE l.client_id = c.client_id
        AND l.is_deleted = FALSE
        AND l.status IN ('Active', 'Disbursed')
  );

-- 5e. Sync text clients.status with authoritative status_id FK name when client has no active loan contradiction
UPDATE public.clients c
SET status = cs.name,
    updated_at = NOW()
FROM public.client_statuses cs
WHERE cs.status_id = c.status_id
  AND c.is_deleted = FALSE
  AND c.status IS DISTINCT FROM cs.name;

-- ---------------------------------------------------------------------------
-- 6. Rebuild public.atomic_execute_operations RPC aligned with live schema
-- ---------------------------------------------------------------------------
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
    v_actor_uid UUID;
    v_old_status_uid UUID;
    v_new_status_uid UUID;
    v_raw_actor TEXT;
    v_loan_id UUID;
    v_uuid_regex CONSTANT TEXT := '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
BEGIN
    IF p_operations IS NULL OR jsonb_array_length(p_operations) = 0 THEN
        RAISE EXCEPTION 'ERR_EMPTY_OPERATIONS: Operation batch cannot be null or empty';
    END IF;

    FOR op IN SELECT * FROM jsonb_array_elements(p_operations)
    LOOP
        op_type := op->>'type';
        tbl := op->>'table';
        rec := COALESCE(op->'record', '{}'::jsonb);
        v_match := COALESCE(op->'match', '{}'::jsonb);

        IF op_type NOT IN ('insert', 'update', 'update_loan', 'delete', 'delete_pending', 'post_financial_transaction') THEN
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
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    COALESCE((rec->>'date')::timestamptz, (rec->>'payment_date')::timestamptz, NOW()),
                    (rec->>'loan_id')::uuid,
                    (rec->>'client_id')::uuid,
                    v_amount,
                    NULLIF(rec->>'officer_id', '')::uuid,
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
                v_rec_id := COALESCE(NULLIF(rec->>'id', '')::uuid, NULLIF(v_match->>'id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_REPAYMENT_UPDATE_IDENTIFIER: Record id is required for repayment update';
                END IF;

                v_branch_id := COALESCE(NULLIF(rec->>'branch_id', '')::uuid, NULLIF(v_match->>'branch_id', '')::uuid);

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
                IF rec->>'client_id' IS NULL OR rec->>'product_id' IS NULL OR rec->>'branch_id' IS NULL
                   OR COALESCE(rec->>'loan_amount', rec->>'amount') IS NULL THEN
                    RAISE EXCEPTION 'ERR_LOAN_INSERT_PAYLOAD: client_id, product_id, branch_id, and loan_amount are required';
                END IF;

                v_amount := COALESCE(rec->>'loan_amount', rec->>'amount')::numeric;
                IF v_amount <= 0 OR v_amount <> ROUND(v_amount, 2) THEN
                    RAISE EXCEPTION 'ERR_INVALID_LOAN_AMOUNT: Loan amount % must be positive and have at most 2 decimal places', v_amount;
                END IF;

                INSERT INTO public.loans (
                    loan_id, client_id, product_id, branch_id, officer_id, date,
                    loan_amount, active_credit, loan_repay, total_due, status,
                    product_category, start_date, expected_end_date, disbursement_date,
                    extra_fields, guarantor_id_means, guarantor_id_number,
                    guarantor_id_card_url, guarantor_passport_url, created_at, updated_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'loan_id', '')::uuid, NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    (rec->>'product_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE((rec->>'date')::date, (rec->>'disbursement_date')::date, CURRENT_DATE),
                    v_amount,
                    COALESCE((rec->>'active_credit')::numeric, v_amount),
                    COALESCE((rec->>'loan_repay')::numeric, 0.00),
                    COALESCE((rec->>'total_due')::numeric, (rec->>'total_payable')::numeric, v_amount),
                    COALESCE(rec->>'status', 'Pending'),
                    COALESCE(rec->>'product_category', 'Finance'),
                    (rec->>'start_date')::date,
                    (rec->>'expected_end_date')::date,
                    (rec->>'disbursement_date')::date,
                    COALESCE(rec->'extra_fields', '{}'::jsonb),
                    rec->>'guarantor_id_means',
                    rec->>'guarantor_id_number',
                    rec->>'guarantor_id_card_url',
                    rec->>'guarantor_passport_url',
                    COALESCE((rec->>'created_at')::timestamptz, NOW()),
                    NOW()
                );

            ELSIF op_type IN ('update', 'update_loan') THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'loan_id', '')::uuid, NULLIF(rec->>'loan_id', '')::uuid, NULLIF(rec->>'id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_LOAN_UPDATE_IDENTIFIER: loan_id is required for loan update';
                END IF;

                v_branch_id := COALESCE(NULLIF(v_match->>'branch_id', '')::uuid, NULLIF(rec->>'branch_id', '')::uuid);

                IF rec->>'status' = 'Active' AND COALESCE(rec->>'_allow_active_metadata_update', 'false') <> 'true' THEN
                    SELECT status INTO v_current_status FROM public.loans WHERE loan_id = v_rec_id FOR UPDATE;
                    IF v_current_status = 'Active' THEN
                        RAISE EXCEPTION 'ERR_LOAN_ALREADY_ACTIVE: Loan % has already been activated and disbursed. Duplicate disbursement rejected.', v_rec_id;
                    END IF;
                END IF;

                UPDATE public.loans
                SET status = COALESCE(rec->>'status', status),
                    loan_amount = COALESCE((rec->>'loan_amount')::numeric, (rec->>'amount')::numeric, loan_amount),
                    active_credit = COALESCE((rec->>'active_credit')::numeric, active_credit),
                    loan_repay = COALESCE((rec->>'loan_repay')::numeric, loan_repay),
                    total_due = COALESCE((rec->>'total_due')::numeric, (rec->>'total_payable')::numeric, total_due),
                    product_category = COALESCE(rec->>'product_category', product_category),
                    date = COALESCE((rec->>'date')::date, date),
                    start_date = COALESCE((rec->>'start_date')::date, start_date),
                    expected_end_date = COALESCE((rec->>'expected_end_date')::date, expected_end_date),
                    disbursement_date = COALESCE((rec->>'disbursement_date')::date, disbursement_date),
                    guarantor_id_means = COALESCE(rec->>'guarantor_id_means', guarantor_id_means),
                    guarantor_id_number = COALESCE(rec->>'guarantor_id_number', guarantor_id_number),
                    guarantor_id_card_url = COALESCE(rec->>'guarantor_id_card_url', guarantor_id_card_url),
                    guarantor_passport_url = COALESCE(rec->>'guarantor_passport_url', guarantor_passport_url),
                    updated_at = NOW(),
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
            v_raw_actor := NULLIF(TRIM(COALESCE(rec->>'status_changed_by', '')), '');
            IF v_raw_actor IS NOT NULL THEN
                IF v_raw_actor ~ v_uuid_regex THEN
                    v_actor_uid := v_raw_actor::uuid;
                ELSE
                    SELECT id INTO v_actor_uid FROM public.app_users WHERE username = v_raw_actor LIMIT 1;
                END IF;
            ELSE
                v_actor_uid := NULL;
            END IF;

            IF op_type = 'insert' THEN
                IF rec->>'name' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_CLIENT_INSERT_PAYLOAD: name and branch_id are required';
                END IF;

                v_new_status_uid := NULLIF(rec->>'status_id', '')::uuid;
                IF v_new_status_uid IS NULL AND NULLIF(rec->>'status', '') IS NOT NULL THEN
                    SELECT status_id INTO v_new_status_uid FROM public.client_statuses WHERE name = rec->>'status' LIMIT 1;
                END IF;

                INSERT INTO public.clients (
                    client_id, name, nickname, phone, address, marital_status, business_type,
                    average_monthly_income, other_obligations, client_code, business_address,
                    occupation, id_means, id_number, id_card_url, passport_url,
                    registration_date, branch_id, group_id, officer_id, status, status_id,
                    status_changed_at, status_changed_by, status_note, created_at, updated_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'client_id', '')::uuid, gen_random_uuid()),
                    rec->>'name',
                    rec->>'nickname',
                    rec->>'phone',
                    rec->>'address',
                    rec->>'marital_status',
                    rec->>'business_type',
                    COALESCE((rec->>'average_monthly_income')::numeric, 0),
                    rec->>'other_obligations',
                    rec->>'client_code',
                    rec->>'business_address',
                    rec->>'occupation',
                    rec->>'id_means',
                    rec->>'id_number',
                    rec->>'id_card_url',
                    rec->>'passport_url',
                    COALESCE((rec->>'registration_date')::date, CURRENT_DATE),
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'group_id', '')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE(rec->>'status', 'Registered'),
                    v_new_status_uid,
                    COALESCE((rec->>'status_changed_at')::timestamptz, NOW()),
                    v_actor_uid,
                    rec->>'status_note',
                    COALESCE((rec->>'created_at')::timestamptz, NOW()),
                    NOW()
                );

            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'client_id', '')::uuid, NULLIF(rec->>'client_id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_CLIENT_UPDATE_IDENTIFIER: client_id is required for client update';
                END IF;

                v_branch_id := COALESCE(NULLIF(v_match->>'branch_id', '')::uuid, NULLIF(rec->>'branch_id', '')::uuid);
                v_new_status_uid := NULLIF(rec->>'status_id', '')::uuid;
                IF v_new_status_uid IS NULL AND NULLIF(rec->>'status', '') IS NOT NULL THEN
                    SELECT status_id INTO v_new_status_uid FROM public.client_statuses WHERE name = rec->>'status' LIMIT 1;
                END IF;

                UPDATE public.clients
                SET status = COALESCE(rec->>'status', status),
                    status_id = COALESCE(v_new_status_uid, status_id),
                    status_changed_at = COALESCE((rec->>'status_changed_at')::timestamptz, status_changed_at),
                    status_changed_by = COALESCE(v_actor_uid, status_changed_by),
                    status_note = COALESCE(rec->>'status_note', status_note),
                    name = COALESCE(rec->>'name', name),
                    nickname = COALESCE(rec->>'nickname', nickname),
                    phone = COALESCE(rec->>'phone', phone),
                    address = COALESCE(rec->>'address', address),
                    marital_status = COALESCE(rec->>'marital_status', marital_status),
                    business_type = COALESCE(rec->>'business_type', business_type),
                    average_monthly_income = COALESCE((rec->>'average_monthly_income')::numeric, average_monthly_income),
                    other_obligations = COALESCE(rec->>'other_obligations', other_obligations),
                    business_address = COALESCE(rec->>'business_address', business_address),
                    occupation = COALESCE(rec->>'occupation', occupation),
                    id_means = COALESCE(rec->>'id_means', id_means),
                    id_number = COALESCE(rec->>'id_number', id_number),
                    id_card_url = COALESCE(rec->>'id_card_url', id_card_url),
                    passport_url = COALESCE(rec->>'passport_url', passport_url),
                    group_id = COALESCE(NULLIF(rec->>'group_id', '')::uuid, group_id),
                    officer_id = COALESCE(NULLIF(rec->>'officer_id', '')::uuid, officer_id),
                    updated_at = NOW()
                WHERE client_id = v_rec_id
                  AND (v_branch_id IS NULL OR clients.branch_id = v_branch_id);

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Client % not found or branch consistency check failed', v_rec_id;
                ELSIF v_row_count > 1 THEN
                    RAISE EXCEPTION 'ERR_MULTIPLE_RECORDS_UPDATED: Client update affected % records', v_row_count;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table clients is not permitted', op_type;
            END IF;

        ELSIF tbl = 'client_status_history' THEN
            IF op_type = 'insert' THEN
                IF rec->>'client_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_STATUS_HISTORY_PAYLOAD: client_id is required';
                END IF;

                v_old_status_uid := NULLIF(rec->>'old_status_id', '')::uuid;
                IF v_old_status_uid IS NULL AND NULLIF(rec->>'from_status', '') IS NOT NULL THEN
                    SELECT status_id INTO v_old_status_uid FROM public.client_statuses WHERE name = rec->>'from_status' LIMIT 1;
                END IF;

                v_new_status_uid := NULLIF(rec->>'new_status_id', '')::uuid;
                IF v_new_status_uid IS NULL AND COALESCE(NULLIF(rec->>'to_status', ''), NULLIF(rec->>'status', '')) IS NOT NULL THEN
                    SELECT status_id INTO v_new_status_uid
                    FROM public.client_statuses
                    WHERE name = COALESCE(NULLIF(rec->>'to_status', ''), NULLIF(rec->>'status', ''))
                    LIMIT 1;
                END IF;

                IF v_new_status_uid IS NULL THEN
                    RAISE EXCEPTION 'ERR_STATUS_HISTORY_PAYLOAD: valid new_status_id or to_status is required';
                END IF;

                v_raw_actor := NULLIF(TRIM(COALESCE(rec->>'changed_by', '')), '');
                IF v_raw_actor IS NOT NULL THEN
                    IF v_raw_actor ~ v_uuid_regex THEN
                        v_actor_uid := v_raw_actor::uuid;
                    ELSE
                        SELECT id INTO v_actor_uid FROM public.app_users WHERE username = v_raw_actor LIMIT 1;
                    END IF;
                ELSE
                    v_actor_uid := NULL;
                END IF;

                INSERT INTO public.client_status_history (
                    id, client_id, old_status_id, new_status_id, changed_by,
                    changed_at, reason, trigger_type, trigger_reference
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    v_old_status_uid,
                    v_new_status_uid,
                    v_actor_uid,
                    COALESCE((rec->>'changed_at')::timestamptz, (rec->>'created_at')::timestamptz, NOW()),
                    COALESCE(rec->>'reason', rec->>'status_note', ''),
                    COALESCE(NULLIF(rec->>'trigger_type', ''), 'SYSTEM'),
                    rec->>'trigger_reference'
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table client_status_history is not permitted', op_type;
            END IF;

        ELSIF tbl = 'guarantors' THEN
            IF op_type = 'insert' THEN
                IF rec->>'name' IS NULL THEN
                    RAISE EXCEPTION 'ERR_GUARANTOR_PAYLOAD: name is required';
                END IF;
                INSERT INTO public.guarantors (
                    guarantor_id, name, phone, address, occupation, business_address,
                    id_means, id_number, id_card_url, passport_url, created_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'guarantor_id', '')::uuid, gen_random_uuid()),
                    rec->>'name',
                    rec->>'phone',
                    rec->>'address',
                    rec->>'occupation',
                    rec->>'business_address',
                    rec->>'id_means',
                    rec->>'id_number',
                    rec->>'id_card_url',
                    rec->>'passport_url',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'guarantor_id', '')::uuid, NULLIF(rec->>'guarantor_id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_GUARANTOR_UPDATE_IDENTIFIER: guarantor_id is required';
                END IF;
                UPDATE public.guarantors
                SET name = COALESCE(rec->>'name', name),
                    phone = COALESCE(rec->>'phone', phone),
                    address = COALESCE(rec->>'address', address),
                    occupation = COALESCE(rec->>'occupation', occupation),
                    business_address = COALESCE(rec->>'business_address', business_address),
                    id_means = COALESCE(rec->>'id_means', id_means),
                    id_number = COALESCE(rec->>'id_number', id_number),
                    id_card_url = COALESCE(rec->>'id_card_url', id_card_url),
                    passport_url = COALESCE(rec->>'passport_url', passport_url)
                WHERE guarantor_id = v_rec_id;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table guarantors is not permitted', op_type;
            END IF;

        ELSIF tbl = 'groups' THEN
            IF op_type = 'insert' THEN
                IF rec->>'name' IS NULL OR rec->>'meeting_day' IS NULL OR rec->>'branch_id' IS NULL THEN
                    RAISE EXCEPTION 'ERR_GROUP_PAYLOAD: name, meeting_day, and branch_id are required';
                END IF;
                INSERT INTO public.groups (
                    group_id, name, meeting_day, branch_id, officer_id, status,
                    group_number, current_member_sequence, leader_name, created_at, updated_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'group_id', '')::uuid, gen_random_uuid()),
                    rec->>'name',
                    rec->>'meeting_day',
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE(rec->>'status', 'Active'),
                    rec->>'group_number',
                    COALESCE((rec->>'current_member_sequence')::int, 0),
                    rec->>'leader_name',
                    COALESCE((rec->>'created_at')::timestamptz, NOW()),
                    NOW()
                );
            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'group_id', '')::uuid, NULLIF(rec->>'group_id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_GROUP_UPDATE_IDENTIFIER: group_id is required';
                END IF;
                UPDATE public.groups
                SET name = COALESCE(rec->>'name', name),
                    meeting_day = COALESCE(rec->>'meeting_day', meeting_day),
                    officer_id = COALESCE(NULLIF(rec->>'officer_id', '')::uuid, officer_id),
                    status = COALESCE(rec->>'status', status),
                    current_member_sequence = COALESCE((rec->>'current_member_sequence')::int, current_member_sequence),
                    leader_name = COALESCE(rec->>'leader_name', leader_name),
                    updated_at = NOW()
                WHERE group_id = v_rec_id;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table groups is not permitted', op_type;
            END IF;

        ELSIF tbl = 'client_memberships' THEN
            IF op_type = 'insert' THEN
                INSERT INTO public.client_memberships (
                    membership_id, client_id, group_id, branch_id, officer_id, start_date, end_date, created_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'membership_id', '')::uuid, gen_random_uuid()),
                    NULLIF(rec->>'client_id', '')::uuid,
                    NULLIF(rec->>'group_id', '')::uuid,
                    NULLIF(rec->>'branch_id', '')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    COALESCE((rec->>'start_date')::date, CURRENT_DATE),
                    (rec->>'end_date')::date,
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'membership_id', '')::uuid, NULLIF(rec->>'membership_id', '')::uuid);
                UPDATE public.client_memberships
                SET group_id = COALESCE(NULLIF(rec->>'group_id', '')::uuid, group_id),
                    officer_id = COALESCE(NULLIF(rec->>'officer_id', '')::uuid, officer_id),
                    end_date = COALESCE((rec->>'end_date')::date, end_date)
                WHERE (v_rec_id IS NOT NULL AND membership_id = v_rec_id)
                   OR (v_rec_id IS NULL AND (v_match->>'client_id') IS NOT NULL AND client_id = (v_match->>'client_id')::uuid AND end_date IS NULL);
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table client_memberships is not permitted', op_type;
            END IF;

        ELSIF tbl = 'loan_schedule' THEN
            IF op_type IN ('delete', 'delete_pending') THEN
                v_loan_id := COALESCE(NULLIF(v_match->>'loan_id', '')::uuid, NULLIF(rec->>'loan_id', '')::uuid);
                IF v_loan_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_SCHEDULE_DELETE_IDENTIFIER: loan_id is required';
                END IF;
                DELETE FROM public.loan_schedule
                WHERE loan_id = v_loan_id
                  AND status <> 'Paid';
            ELSIF op_type = 'insert' THEN
                IF rec->>'loan_id' IS NULL OR rec->>'installment_number' IS NULL OR rec->>'due_date' IS NULL THEN
                    RAISE EXCEPTION 'ERR_SCHEDULE_INSERT_PAYLOAD: loan_id, installment_number, and due_date are required';
                END IF;
                INSERT INTO public.loan_schedule (
                    id, loan_id, installment_number, due_date, principal, interest, fees,
                    total_due, status, paid_date, paid_amount, version, created_at, updated_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    (rec->>'loan_id')::uuid,
                    (rec->>'installment_number')::int,
                    (rec->>'due_date')::date,
                    COALESCE((rec->>'principal')::numeric, 0),
                    COALESCE((rec->>'interest')::numeric, 0),
                    COALESCE((rec->>'fees')::numeric, 0),
                    COALESCE((rec->>'total_due')::numeric, 0),
                    COALESCE(rec->>'status', 'Pending'),
                    (rec->>'paid_date')::date,
                    COALESCE((rec->>'paid_amount')::numeric, 0),
                    COALESCE((rec->>'version')::int, 1),
                    COALESCE((rec->>'created_at')::timestamptz, NOW()),
                    NOW()
                );
            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'id', '')::uuid, NULLIF(rec->>'id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_SCHEDULE_UPDATE_IDENTIFIER: id is required';
                END IF;
                UPDATE public.loan_schedule
                SET paid_amount = COALESCE((rec->>'paid_amount')::numeric, paid_amount),
                    paid_date = CASE
                        WHEN rec ? 'paid_date' THEN (rec->>'paid_date')::date
                        ELSE paid_date
                    END,
                    status = COALESCE(rec->>'status', status),
                    due_date = COALESCE((rec->>'due_date')::date, due_date),
                    updated_at = NOW()
                WHERE id = v_rec_id;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table loan_schedule is not permitted', op_type;
            END IF;

        ELSIF tbl = 'loan_payoff_excess_records' THEN
            IF op_type = 'insert' THEN
                IF rec->>'loan_id' IS NULL OR rec->>'client_id' IS NULL OR rec->>'branch_id' IS NULL OR rec->>'record_type' IS NULL THEN
                    RAISE EXCEPTION 'ERR_PAYOFF_EXCESS_PAYLOAD: loan_id, client_id, branch_id, and record_type are required';
                END IF;
                INSERT INTO public.loan_payoff_excess_records (
                    id, repayment_id, loan_id, client_id, officer_id, branch_id,
                    date, record_type, amount_paid, expected_installment,
                    active_credit_settled, excess_amount, remaining_balance_before,
                    remaining_balance_after, notes, created_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    NULLIF(rec->>'repayment_id', '')::uuid,
                    (rec->>'loan_id')::uuid,
                    (rec->>'client_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    (rec->>'branch_id')::uuid,
                    COALESCE((rec->>'date')::date, CURRENT_DATE),
                    rec->>'record_type',
                    COALESCE((rec->>'amount_paid')::numeric, 0),
                    COALESCE((rec->>'expected_installment')::numeric, 0),
                    COALESCE((rec->>'active_credit_settled')::numeric, 0),
                    COALESCE((rec->>'excess_amount')::numeric, 0),
                    COALESCE((rec->>'remaining_balance_before')::numeric, 0),
                    COALESCE((rec->>'remaining_balance_after')::numeric, 0),
                    rec->>'notes',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                )
                ON CONFLICT (repayment_id) WHERE repayment_id IS NOT NULL DO UPDATE SET
                    record_type = EXCLUDED.record_type,
                    amount_paid = EXCLUDED.amount_paid,
                    expected_installment = EXCLUDED.expected_installment,
                    active_credit_settled = EXCLUDED.active_credit_settled,
                    excess_amount = EXCLUDED.excess_amount,
                    remaining_balance_before = EXCLUDED.remaining_balance_before,
                    remaining_balance_after = EXCLUDED.remaining_balance_after,
                    notes = EXCLUDED.notes;
            ELSIF op_type = 'delete' THEN
                IF NULLIF(v_match->>'repayment_id', '') IS NULL THEN
                    RAISE EXCEPTION 'ERR_PAYOFF_EXCESS_DELETE: repayment_id match is required';
                END IF;
                DELETE FROM public.loan_payoff_excess_records WHERE repayment_id = (v_match->>'repayment_id')::uuid;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table loan_payoff_excess_records is not permitted', op_type;
            END IF;

        ELSIF tbl = 'loan_overdue_recovery_records' THEN
            IF op_type = 'insert' THEN
                IF rec->>'loan_id' IS NULL OR rec->>'client_id' IS NULL OR rec->>'branch_id' IS NULL OR rec->>'recovery_type' IS NULL THEN
                    RAISE EXCEPTION 'ERR_OVERDUE_RECOVERY_PAYLOAD: loan_id, client_id, branch_id, and recovery_type are required';
                END IF;
                INSERT INTO public.loan_overdue_recovery_records (
                    id, repayment_id, loan_id, client_id, officer_id, branch_id,
                    recovery_date, recovery_timestamp, recovery_type, total_repayment_amount, recovered_amount,
                    overdue_before, overdue_after, notes, created_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    NULLIF(rec->>'repayment_id', '')::uuid,
                    (rec->>'loan_id')::uuid,
                    (rec->>'client_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    (rec->>'branch_id')::uuid,
                    COALESCE((rec->>'recovery_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    COALESCE((rec->>'recovery_timestamp')::timestamptz, NOW()),
                    rec->>'recovery_type',
                    COALESCE((rec->>'total_repayment_amount')::numeric, 0),
                    COALESCE((rec->>'recovered_amount')::numeric, 0),
                    COALESCE((rec->>'overdue_before')::numeric, 0),
                    COALESCE((rec->>'overdue_after')::numeric, 0),
                    rec->>'notes',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSIF op_type = 'delete' THEN
                IF NULLIF(v_match->>'repayment_id', '') IS NULL THEN
                    RAISE EXCEPTION 'ERR_OVERDUE_RECOVERY_DELETE: repayment_id match is required';
                END IF;
                DELETE FROM public.loan_overdue_recovery_records WHERE repayment_id = (v_match->>'repayment_id')::uuid;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table loan_overdue_recovery_records is not permitted', op_type;
            END IF;

        ELSIF tbl = 'client_profile_update_requests' THEN
            IF op_type = 'insert' THEN
                INSERT INTO public.client_profile_update_requests (
                    request_id, client_id, branch_id, requested_by, proposed_changes,
                    previous_values, status, rejection_reason, reviewed_by, reviewed_at, created_at, updated_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'request_id', '')::uuid, gen_random_uuid()),
                    (rec->>'client_id')::uuid,
                    (rec->>'branch_id')::uuid,
                    (rec->>'requested_by')::uuid,
                    COALESCE(rec->'proposed_changes', '{}'::jsonb),
                    COALESCE(rec->'previous_values', '{}'::jsonb),
                    COALESCE(rec->>'status', 'Pending'),
                    rec->>'rejection_reason',
                    NULLIF(rec->>'reviewed_by', '')::uuid,
                    (rec->>'reviewed_at')::timestamptz,
                    COALESCE((rec->>'created_at')::timestamptz, NOW()),
                    NOW()
                );
            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'request_id', '')::uuid, NULLIF(rec->>'request_id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_PROFILE_REQ_IDENTIFIER: request_id is required';
                END IF;
                UPDATE public.client_profile_update_requests
                SET status = COALESCE(rec->>'status', status),
                    rejection_reason = COALESCE(rec->>'rejection_reason', rejection_reason),
                    reviewed_by = COALESCE(NULLIF(rec->>'reviewed_by', '')::uuid, reviewed_by),
                    reviewed_at = COALESCE((rec->>'reviewed_at')::timestamptz, reviewed_at),
                    updated_at = NOW()
                WHERE request_id = v_rec_id
                  AND (NULLIF(v_match->>'status', '') IS NULL OR status = v_match->>'status');

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Profile update request % not found or state guard failed', v_rec_id;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table client_profile_update_requests is not permitted', op_type;
            END IF;

        ELSIF tbl = 'correction_requests' THEN
            IF op_type = 'insert' THEN
                INSERT INTO public.correction_requests (
                    id, record_id, record_type, requested_by, branch_id, reason, status, created_at, updated_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    (rec->>'record_id')::uuid,
                    rec->>'record_type',
                    NULLIF(rec->>'requested_by', '')::uuid,
                    NULLIF(rec->>'branch_id', '')::uuid,
                    COALESCE(rec->>'reason', ''),
                    COALESCE(rec->>'status', 'Pending'),
                    COALESCE((rec->>'created_at')::timestamptz, NOW()),
                    NOW()
                );
            ELSIF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'id', '')::uuid, NULLIF(rec->>'id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_CORRECTION_UPDATE_IDENTIFIER: id is required';
                END IF;
                UPDATE public.correction_requests
                SET status = COALESCE(rec->>'status', status),
                    approved_by = COALESCE(NULLIF(rec->>'approved_by', '')::uuid, approved_by),
                    approval_date = COALESCE((rec->>'approval_date')::timestamptz, approval_date),
                    reason = COALESCE(rec->>'reason', reason),
                    updated_at = NOW()
                WHERE id = v_rec_id
                  AND (NULLIF(v_match->>'status', '') IS NULL OR status = v_match->>'status');

                GET DIAGNOSTICS v_row_count = ROW_COUNT;
                IF v_row_count = 0 THEN
                    RAISE EXCEPTION 'ERR_RECORD_NOT_FOUND: Correction request % not found or status guard failed', v_rec_id;
                END IF;
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table correction_requests is not permitted', op_type;
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
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
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
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
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
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
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
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
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
                    id, posting_date, client_id, group_id, branch_id, officer_id, fee_type, amount,
                    reference, remarks, idempotency_key, created_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    NULLIF(rec->>'client_id', '')::uuid,
                    NULLIF(rec->>'group_id', '')::uuid,
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
                    id, savings_type, operation_type, client_id, group_id, client_name, group_name, loan_id,
                    branch_id, requested_by, officer_id, amount, reference, remarks, payout_method,
                    destination_id, destination_type, fee_type, idempotency_key,
                    executed_record_id, executed_table, status, approved_by, approved_at,
                    rejection_reason, operational_date, created_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    rec->>'savings_type',
                    rec->>'operation_type',
                    NULLIF(rec->>'client_id', ''),
                    NULLIF(rec->>'group_id', '')::uuid,
                    rec->>'client_name',
                    rec->>'group_name',
                    NULLIF(rec->>'loan_id', ''),
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
                v_rec_id := COALESCE(NULLIF(v_match->>'id', '')::uuid, NULLIF(rec->>'id', '')::uuid);
                IF v_rec_id IS NULL THEN
                    RAISE EXCEPTION 'ERR_WR_UPDATE_IDENTIFIER: id is required for withdrawal_requests update';
                END IF;

                v_branch_id := COALESCE(NULLIF(v_match->>'branch_id', '')::uuid, NULLIF(rec->>'branch_id', '')::uuid);
                v_current_status := NULLIF(UPPER(TRIM(v_match->>'status')), '');

                UPDATE public.withdrawal_requests
                SET status = COALESCE(NULLIF(UPPER(TRIM(rec->>'status')), ''), withdrawal_requests.status),
                    approved_by = COALESCE(rec->>'approved_by', withdrawal_requests.approved_by),
                    approved_at = COALESCE((rec->>'approved_at')::timestamptz, withdrawal_requests.approved_at),
                    rejection_reason = COALESCE(rec->>'rejection_reason', withdrawal_requests.rejection_reason),
                    operational_date = COALESCE((rec->>'operational_date')::date, withdrawal_requests.operational_date),
                    executed_record_id = COALESCE(NULLIF(rec->>'executed_record_id', '')::uuid, withdrawal_requests.executed_record_id),
                    executed_table = COALESCE(rec->>'executed_table', withdrawal_requests.executed_table),
                    group_id = COALESCE(NULLIF(rec->>'group_id', '')::uuid, withdrawal_requests.group_id)
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
                    reference, remarks, created_at
                ) VALUES (
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
                    COALESCE((rec->>'posting_date')::date, (rec->>'date')::date, CURRENT_DATE),
                    (rec->>'branch_id')::uuid,
                    NULLIF(rec->>'officer_id', '')::uuid,
                    rec->>'transaction_type',
                    (rec->>'amount')::numeric(16, 2),
                    rec->>'reference',
                    rec->>'remarks',
                    COALESCE((rec->>'created_at')::timestamptz, NOW())
                );
            ELSE
                RAISE EXCEPTION 'ERR_UNSUPPORTED_COMBINATION: Operation % on table treasury_transactions is not permitted', op_type;
            END IF;

        ELSIF tbl = 'financial_transactions' THEN
            IF op_type = 'update' THEN
                v_rec_id := COALESCE(NULLIF(v_match->>'transaction_id', '')::uuid, NULLIF(rec->>'transaction_id', '')::uuid);
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
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
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
                    COALESCE(NULLIF(rec->>'id', '')::uuid, gen_random_uuid()),
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
