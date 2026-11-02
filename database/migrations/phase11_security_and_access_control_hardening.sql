-- ============================================================================
-- Phase 11: Security & Access Control Hardening
-- Revoke all public privileges from anon and authenticated on sensitive recovery/payoff tables
-- Ensures strict compliance with the principle of least privilege
-- ============================================================================

-- 1. Revoke privileges on loan_overdue_recovery_records
REVOKE ALL ON TABLE public.loan_overdue_recovery_records FROM anon, authenticated;

-- 2. Revoke privileges on loan_payoff_excess_records
REVOKE ALL ON TABLE public.loan_payoff_excess_records FROM anon, authenticated;

-- 3. Ensure service_role maintains necessary administrative execution privileges
GRANT ALL ON TABLE public.loan_overdue_recovery_records TO service_role;
GRANT ALL ON TABLE public.loan_payoff_excess_records TO service_role;

-- 4. Document verification comments
COMMENT ON TABLE public.loan_overdue_recovery_records IS 'Core Banking Hardened: Anon and Authenticated access revoked. Service role access only.';
COMMENT ON TABLE public.loan_payoff_excess_records IS 'Core Banking Hardened: Anon and Authenticated access revoked. Service role access only.';
