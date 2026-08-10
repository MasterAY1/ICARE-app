# Transaction Atomicity Rules

## ATOM-001: Operational Write + Financial Posting Must Be Atomic

**Status:** MANDATORY

An operational record (loan, repayment, savings transaction, treasury transaction) and its corresponding financial ledger posting MUST succeed or fail as a single unit.

**Required Behavior:**
- Use Supabase RPCs (stored procedures) to wrap the operational write and financial posting in a single database transaction.
- If the financial posting fails, the operational record MUST NOT be committed.
- If the operational write fails, no financial posting should occur.

**Prohibited Behavior:**
- "Save first, try ledger later" patterns.
- Committing an operational record via HTTP REST, then attempting a separate HTTP call for the ledger posting.
- Marking a loan as Active before its `LoanDisbursed` event has been successfully posted to the Ledger.
- Recording a repayment as successful before its `RepaymentReceived` event has been posted.

## ATOM-002: No Silent Fallbacks

**Status:** MANDATORY

If any step in a financial pipeline fails, the system MUST fail closed.

**Required Behavior:**
- Missing `branch_id` → raise an error.
- Unknown event type → raise an error.
- Failed posting → raise an error and prevent the operational record from committing.
- Missing classification → raise an error.
- Unresolvable branch name → raise an error.

**Prohibited Behavior:**
- Using a hardcoded default branch ID.
- Silently swallowing exceptions with empty `except: pass` blocks in financial pipelines.
- Substituting a generic value when a required field is missing.
- Logging a warning and continuing when a financial operation partially fails.

## ATOM-003: Ledger Entries Are Immutable

**Status:** MANDATORY

Ledger entries, once committed, MUST NEVER be modified or deleted.

**Required Behavior:**
- Corrections are made by posting reversing entries (equal and opposite).
- Projection failures must be handled as projection failures, not by rewriting financial history.
- The `SupabaseLedgerRepository` must continue to throw `NotImplementedError` on `update()` and `delete()`.

**Prohibited Behavior:**
- Deleting ledger entries to compensate for projection rebuild failure.
- Updating ledger entry amounts or sides.
- Using SQL `DELETE FROM financial_ledger_entries` for any reason other than a DBA-approved data remediation with full audit trail.

## ATOM-004: Unit of Work Must Not Spawn Nested Units of Work

**Status:** MANDATORY

When a service or repository method is called within an existing `SupabaseUnitOfWork` context, it MUST use the same UOW instance.

**Required Behavior:**
- Pass the existing `uow` as a parameter to downstream methods.
- Projection builders should receive the UOW from the caller.

**Prohibited Behavior:**
- Creating `with SupabaseUnitOfWork() as uow:` inside a method that is already executing within a UOW context.
- This causes connection isolation issues, potential deadlocks, and stale reads.
