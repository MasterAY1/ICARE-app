-- Migration: Phase 11 Priority 1 - Idempotency Key Ownership & Branch Scoping
-- Target: ICARE Core Banking Platform (Supabase PostgreSQL)
-- Description: Adds user_id and branch_id ownership columns to public.idempotency_keys
-- and replaces acquire_idempotency_lock with an ownership-enforcing 6-parameter function.

ALTER TABLE public.idempotency_keys ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.idempotency_keys ADD COLUMN IF NOT EXISTS branch_id TEXT;
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_owner ON public.idempotency_keys(user_id, branch_id);

DROP FUNCTION IF EXISTS public.acquire_idempotency_lock(VARCHAR, VARCHAR, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION public.acquire_idempotency_lock(
    p_key VARCHAR,
    p_scope VARCHAR,
    p_request_hash VARCHAR,
    p_timeout_seconds INTEGER DEFAULT 60,
    p_user_id TEXT DEFAULT NULL,
    p_branch_id TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_record public.idempotency_keys%ROWTYPE;
BEGIN
    SELECT * INTO v_record FROM public.idempotency_keys WHERE key = p_key FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO public.idempotency_keys (key, scope, request_hash, status, locked_at, user_id, branch_id)
        VALUES (p_key, p_scope, p_request_hash, 'PROCESSING', NOW(), p_user_id, p_branch_id)
        RETURNING * INTO v_record;
        RETURN jsonb_build_object('action', 'PROCEED', 'status', 'NEW');
    END IF;

    IF v_record.user_id IS NOT NULL AND p_user_id IS NOT NULL AND v_record.user_id <> p_user_id THEN
        RAISE EXCEPTION 'ERR_IDEMPOTENCY_OWNERSHIP_VIOLATION: Idempotency key % belongs to another user', p_key;
    END IF;

    IF v_record.request_hash <> p_request_hash THEN
        RAISE EXCEPTION 'ERR_IDEMPOTENCY_PAYLOAD_MISMATCH: Idempotency key % was previously used with different parameters', p_key;
    END IF;

    IF v_record.status = 'COMMITTED' THEN
        RETURN jsonb_build_object(
            'action', 'REPLAY',
            'status', 'COMMITTED',
            'response_code', v_record.response_code,
            'response_body', v_record.response_body,
            'user_id', v_record.user_id,
            'branch_id', v_record.branch_id
        );
    END IF;

    IF v_record.status = 'PROCESSING' THEN
        IF v_record.locked_at > (NOW() - (p_timeout_seconds || ' seconds')::INTERVAL) THEN
            RETURN jsonb_build_object(
                'action', 'CONFLICT',
                'status', 'PROCESSING',
                'message', 'Transaction currently being processed by another worker'
            );
        ELSE
            UPDATE public.idempotency_keys
            SET locked_at = NOW(),
                user_id = COALESCE(user_id, p_user_id),
                branch_id = COALESCE(branch_id, p_branch_id)
            WHERE key = p_key;
            RETURN jsonb_build_object('action', 'PROCEED', 'status', 'RECOVERED_LOCK');
        END IF;
    END IF;

    UPDATE public.idempotency_keys
    SET status = 'PROCESSING',
        locked_at = NOW(),
        user_id = COALESCE(user_id, p_user_id),
        branch_id = COALESCE(branch_id, p_branch_id)
    WHERE key = p_key;
    RETURN jsonb_build_object('action', 'PROCEED', 'status', 'RETRY');
END;
$$;
