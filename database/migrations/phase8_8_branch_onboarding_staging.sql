-- Phase 8.8: Branch Onboarding Staging & Digital Ingestion Schema
-- Author: ICARE Core Banking System
-- Purpose: Provides isolated staging tables for web-based branch onboarding, draft persistence, and atomic approval.

CREATE TABLE IF NOT EXISTS branch_onboarding_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    branch_id UUID REFERENCES branches(branch_id),
    branch_name TEXT NOT NULL,
    branch_code TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected')),
    created_by UUID REFERENCES app_users(id),
    contact_person TEXT,
    contact_phone TEXT,
    total_groups INTEGER DEFAULT 0,
    total_members INTEGER DEFAULT 0,
    total_savings NUMERIC(15,2) DEFAULT 0.00,
    total_active_credit NUMERIC(15,2) DEFAULT 0.00,
    total_current_balance NUMERIC(15,2) DEFAULT 0.00,
    payload JSONB DEFAULT '{"officers": [], "groups": [], "members": []}'::jsonb,
    validation_summary JSONB DEFAULT '{"is_valid": true, "errors": [], "warnings": []}'::jsonb,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '14 days'),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES app_users(id),
    approval_notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_token ON branch_onboarding_sessions(token);
CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_status ON branch_onboarding_sessions(status);
CREATE INDEX IF NOT EXISTS idx_onboarding_sessions_branch ON branch_onboarding_sessions(branch_id);
