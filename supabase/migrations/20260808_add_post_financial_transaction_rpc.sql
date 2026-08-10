-- Migration: Atomic Financial Posting RPC
-- Created to fix financial integrity issues (P1 backlog) by replacing the 
-- two-step manual insert + compensation logic with a single atomic Postgres transaction.

CREATE OR REPLACE FUNCTION post_financial_transaction(
    header_payload jsonb,
    entries_payload jsonb
) RETURNS uuid AS $$
DECLARE
    new_tx_id uuid;
    entry jsonb;
BEGIN
    -- Insert header
    INSERT INTO financial_transactions (
        transaction_id, event_id, posting_date, branch_id, officer_id, 
        narration, reference, status, reversal_of, currency_code
    )
    VALUES (
        COALESCE((header_payload->>'transaction_id')::uuid, gen_random_uuid()),
        NULLIF((header_payload->>'event_id'), '')::uuid,
        COALESCE((header_payload->>'posting_date')::date, CURRENT_DATE),
        NULLIF((header_payload->>'branch_id'), '')::uuid,
        NULLIF((header_payload->>'officer_id'), '')::uuid,
        header_payload->>'narration',
        header_payload->>'reference',
        COALESCE(header_payload->>'status', 'Posted'),
        NULLIF((header_payload->>'reversal_of'), '')::uuid,
        COALESCE(header_payload->>'currency_code', 'NGN')
    )
    RETURNING transaction_id INTO new_tx_id;

    -- Insert entries
    FOR entry IN SELECT * FROM jsonb_array_elements(entries_payload)
    LOOP
        INSERT INTO financial_ledger_entries (
            transaction_id, branch_id, account_code, side, amount, aggregate_type, aggregate_id
        )
        VALUES (
            new_tx_id,
            COALESCE(NULLIF((entry->>'branch_id'), '')::uuid, NULLIF((header_payload->>'branch_id'), '')::uuid),
            entry->>'account_code',
            entry->>'side',
            (entry->>'amount')::numeric,
            entry->>'aggregate_type',
            NULLIF((entry->>'aggregate_id'), '')::uuid
        );
    END LOOP;

    RETURN new_tx_id;
EXCEPTION
    WHEN OTHERS THEN
        -- Rollback happens automatically in plpgsql if an exception is raised
        RAISE;
END;
$$ LANGUAGE plpgsql;
