-- Phase 8.6: Register BankDepositReversed Posting Rule & Clean Up Orphaned Negative Events

-- 1. Insert BankDepositReversed into posting_rules
INSERT INTO public.posting_rules (event_type, debit_account, credit_account, version, enabled)
VALUES ('BankDepositReversed', '1000', '1050', 1, TRUE)
ON CONFLICT (event_type, version) DO UPDATE SET
    debit_account = EXCLUDED.debit_account,
    credit_account = EXCLUDED.credit_account,
    enabled = EXCLUDED.enabled;

-- 2. Clean up orphaned negative events from event_store (which failed posting engine validation)
DELETE FROM public.event_store
WHERE event_id IN (
    '7746d0a2-a389-44ca-93ac-ed655ba25cc8',
    'e29563e0-3217-4ea1-b999-e135e822d41b'
);
