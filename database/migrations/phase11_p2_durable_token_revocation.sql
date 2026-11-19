-- Migration: Phase 11 Priority 2 - Durable Shared Token & User Session Revocation
-- Target: ICARE Core Banking Platform (Supabase PostgreSQL)
-- Description: Persists revoked session/challenge tokens and user-wide revocation epochs
-- across backend restarts and multi-instance deployments.

CREATE TABLE IF NOT EXISTS public.revoked_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NULL,
    revoked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_revoked_tokens_expires_at
    ON public.revoked_tokens (expires_at);

CREATE INDEX IF NOT EXISTS idx_revoked_tokens_user_id
    ON public.revoked_tokens (user_id);

CREATE TABLE IF NOT EXISTS public.user_session_revocations (
    user_id TEXT PRIMARY KEY,
    revoked_before TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.revoked_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_session_revocations ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.revoked_tokens FROM anon, authenticated;
REVOKE ALL ON public.user_session_revocations FROM anon, authenticated;

GRANT ALL ON public.revoked_tokens TO service_role;
GRANT ALL ON public.user_session_revocations TO service_role;

DROP POLICY IF EXISTS "service_role_full_access_revoked_tokens" ON public.revoked_tokens;
CREATE POLICY "service_role_full_access_revoked_tokens"
    ON public.revoked_tokens
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_user_session_revocations" ON public.user_session_revocations;
CREATE POLICY "service_role_full_access_user_session_revocations"
    ON public.user_session_revocations
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.prune_expired_revoked_tokens()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_count INTEGER := 0;
BEGIN
    DELETE FROM public.revoked_tokens
    WHERE expires_at <= NOW();
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$;
