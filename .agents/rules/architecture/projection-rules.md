# Projection Rules

## PROJ-001: CO Cashbook Is a Dimensional View of Account 1000

**Status:** MANDATORY

The CO Cashbook is a projection of Account 1000 Ledger entries, dimensionalized by officer_id.

**Required Behavior:**
- CO Cashbook MUST be rebuilt from `financial_ledger_entries` joined with `financial_transactions` and `event_store`.
- It MUST filter for `account_code = '1000'` only (physical vault cash).
- Product withdrawal tracking (LapsTransferred, LoanOffsetFromSavings) is tracked as a separate metric but MUST NOT affect physical cash flow calculations.

**Prohibited Behavior:**
- Building CO Cashbook from the `repayments` table.
- Including non-Account-1000 entries in cash flow calculations.

## PROJ-002: Master Cashbook Is a Branch-Level Projection of the Same Financial Truth

**Status:** MANDATORY

The Master Cashbook MUST derive from the same source as the CO Cashbook: Account 1000 Ledger entries.

**Required Behavior:**
- Master Cashbook aggregates all CO Cashbook entries for a branch.
- For branch-level items not assigned to a specific officer (Treasury, Disbursements), the Master Cashbook MUST query Account 1000 Ledger entries directly, NOT operational tables.
- Every Master Cashbook field must map to a specific Account 1000 Ledger event type.

**Prohibited Behavior:**
- Querying `treasury_transactions` for treasury data.
- Querying `loans` for disbursement data.
- Creating parallel sources of the same financial truth.
- Any field in Master Cashbook that cannot be traced to a specific Account 1000 Ledger event.

## PROJ-003: Projection Failure Must Not Corrupt Financial History

**Status:** MANDATORY

**Required Behavior:**
- If a projection rebuild fails, log the error and flag it for manual review.
- The underlying Ledger entries MUST remain untouched.
- Retry the projection rebuild, or defer it for batch processing.

**Prohibited Behavior:**
- Deleting Ledger entries because the projection failed.
- Modifying Ledger entries to make a projection balance.
- Silently swallowing projection errors.

## PROJ-004: No Double Counting

**Status:** MANDATORY

Every physical cash movement MUST appear in exactly one projection path.

**Required Behavior:**
- If CO Cashbook captures an event (e.g., RepaymentReceived), the Master Cashbook MUST obtain it via CO Cashbook aggregation, NOT from a separate query.
- If Master Cashbook directly queries the Ledger for Treasury events (which are not in CO Cashbooks), these MUST be mutually exclusive event types from those captured by CO Cashbooks.

**Prohibited Behavior:**
- Master Cashbook summing CO Cashbook totals AND separately querying the Ledger for the same event types.
- Counting the same cash movement through both an operational table query and a Ledger query.
