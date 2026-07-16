-- ============================================================
-- ICARE RBAC Migration
-- ============================================================

-- 1. area_manager_assignments table
CREATE TABLE IF NOT EXISTS public.area_manager_assignments (
    am_id UUID REFERENCES public.app_users(id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE CASCADE,
    PRIMARY KEY (am_id, branch_id)
);
CREATE INDEX IF NOT EXISTS idx_am_assignments_am ON public.area_manager_assignments(am_id);

-- 2. user_audit_logs table (immutable)
CREATE TABLE IF NOT EXISTS public.user_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    user_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    username TEXT NOT NULL,
    role TEXT NOT NULL,
    branch TEXT,
    area_manager TEXT,
    action TEXT NOT NULL,
    module TEXT NOT NULL,
    entity_type TEXT,
    entity_id UUID,
    display_name TEXT,
    previous_value JSONB,
    new_value JSONB,
    ip_session_id TEXT,
    device_name TEXT,
    browser TEXT,
    operating_system TEXT,
    status TEXT NOT NULL CHECK (status IN ('SUCCESS', 'FAILURE', 'ERROR'))
);

-- Immutability triggers
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs are immutable';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_audit_update
BEFORE UPDATE ON public.user_audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

CREATE TRIGGER trg_prevent_audit_delete
BEFORE DELETE ON public.user_audit_logs
FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

CREATE INDEX IF NOT EXISTS idx_ual_timestamp ON public.user_audit_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_ual_username ON public.user_audit_logs(username);
CREATE INDEX IF NOT EXISTS idx_ual_action ON public.user_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_ual_entity ON public.user_audit_logs(entity_type, entity_id);

-- 3. login_history table
CREATE TABLE IF NOT EXISTS public.login_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    username TEXT NOT NULL,
    login_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    logout_time TIMESTAMP WITH TIME ZONE,
    session_id TEXT,
    failed_attempts INTEGER DEFAULT 0,
    ip_address TEXT,
    device_name TEXT,
    browser TEXT,
    operating_system TEXT,
    status TEXT NOT NULL CHECK (status IN ('SUCCESS', 'FAILURE'))
);
CREATE INDEX IF NOT EXISTS idx_login_history_user ON public.login_history(user_id);
CREATE INDEX IF NOT EXISTS idx_login_history_time ON public.login_history(login_time);

-- 4. app_users alterations
ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS last_login TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS last_activity TIMESTAMP WITH TIME ZONE;
