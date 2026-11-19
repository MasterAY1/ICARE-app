-- Migration: Phase 11 Priority 3 - Distributed Authentication Rate Limiting & Atomic MFA Replay Protection
-- Target: ICARE Core Banking Platform (Supabase PostgreSQL)
-- Description: Persists sliding-window authentication rate limit state and atomic TOTP replay nonces
-- across backend restarts and multi-instance deployments.

CREATE TABLE IF NOT EXISTS public.auth_rate_limit_state (
    limit_key TEXT PRIMARY KEY,
    failure_timestamps JSONB NOT NULL DEFAULT '[]'::jsonb,
    locked_until TIMESTAMPTZ NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_auth_rate_limit_locked_until
    ON public.auth_rate_limit_state (locked_until);

CREATE TABLE IF NOT EXISTS public.mfa_replay_nonces (
    replay_key TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_mfa_replay_nonces_expires_at
    ON public.mfa_replay_nonces (expires_at);

ALTER TABLE public.auth_rate_limit_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mfa_replay_nonces ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.auth_rate_limit_state FROM anon, authenticated;
REVOKE ALL ON public.mfa_replay_nonces FROM anon, authenticated;

GRANT ALL ON public.auth_rate_limit_state TO service_role;
GRANT ALL ON public.mfa_replay_nonces TO service_role;

DROP POLICY IF EXISTS "service_role_full_access_auth_rate_limit_state" ON public.auth_rate_limit_state;
CREATE POLICY "service_role_full_access_auth_rate_limit_state"
    ON public.auth_rate_limit_state
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_mfa_replay_nonces" ON public.mfa_replay_nonces;
CREATE POLICY "service_role_full_access_mfa_replay_nonces"
    ON public.mfa_replay_nonces
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.consume_mfa_totp_nonce(
    p_replay_key TEXT,
    p_user_id TEXT,
    p_ttl_seconds INTEGER DEFAULT 90
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_inserted INTEGER := 0;
    v_ttl INTEGER := GREATEST(COALESCE(p_ttl_seconds, 90), 30);
BEGIN
    DELETE FROM public.mfa_replay_nonces
    WHERE replay_key = p_replay_key
      AND expires_at <= NOW();

    INSERT INTO public.mfa_replay_nonces (replay_key, user_id, consumed_at, expires_at)
    VALUES (
        p_replay_key,
        COALESCE(NULLIF(TRIM(p_user_id), ''), 'unknown'),
        NOW(),
        NOW() + (v_ttl || ' seconds')::INTERVAL
    )
    ON CONFLICT (replay_key) DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted > 0;
END;
$$;

CREATE OR REPLACE FUNCTION public.prune_expired_mfa_replay_nonces()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INTEGER := 0;
BEGIN
    DELETE FROM public.mfa_replay_nonces
    WHERE expires_at <= NOW();
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;
