# Source of Truth Rules

## SOT-001: Ledger is the Financial Source of Truth

**Status:** MANDATORY

The `financial_ledger_entries` table, specifically Account `1000` (Vault Cash), is the authoritative physical cash position for every branch.

**Required Behavior:**
- All financial reporting must ultimately derive from Ledger entries.
- Account 1000 Debit = physical cash entering the CO vault.
- Account 1000 Credit = physical cash leaving the CO vault.
- Any operation that does NOT physically move cash MUST NOT affect Account 1000.

**Prohibited Behavior:**
- Cashbook projections MUST NOT invent cash movements from `loans`, `treasury_transactions`, `repayments`, or any other operational table.
- Dashboard metrics MUST NOT present operational table values as financial truth unless they reconcile to the Ledger.

## SOT-002: Operational Tables Describe Business Objects, Not Financial Truth

**Status:** MANDATORY

Operational tables (`loans`, `repayments`, `individual_savings`, `group_savings`, `internal_savings`, `laps_savings`, `treasury_transactions`, `fees`) represent the business state of entities.

They are NOT independently authoritative for financial reporting.

**Required Behavior:**
- Use operational tables for business queries (e.g., "how many active loans?", "what is client X's savings balance?").
- Use the Ledger for financial queries (e.g., "what is the branch's cash position?", "what is total cash collected today?").

**Prohibited Behavior:**
- Querying `loans` to determine how much cash left the vault.
- Querying `treasury_transactions` to determine branch cash inflows.
- Treating operational record existence as proof that financial posting succeeded.

## SOT-003: Every Cash Movement Has One Authoritative Event

**Status:** MANDATORY

For every physical cash movement:
1. A Domain Event is created (source of intent).
2. The Posting Engine applies the Posting Rule (source of accounting logic).
3. A Ledger Entry is created (source of financial truth).
4. CO and Master Cashbooks are projections of that Ledger Entry.

The event determines the accounting entry.  
The Ledger determines the financial truth.  
Cashbooks are projections of that truth.

**Prohibited Behavior:**
- Creating financial truth from operational table queries.
- Bypassing the event → posting → ledger pipeline.
- Computing cash positions by aggregating operational tables.

## SOT-004: Projection Hierarchy

**Status:** MANDATORY

The canonical projection hierarchy is:

```
financial_ledger_entries (Account 1000)
            │
    ┌───────┴───────┐
    ↓               ↓
CO Cashbook    Master Cashbook
(by officer)   (by branch)
    │               │
    └───────┬───────┘
            ↓
     Reconciliation
            ↓
     Dashboard / Reports
```

Not:

```
loans ──────────────→ Master Cashbook
treasury_transactions → Master Cashbook  
ledger ──────────────→ another report
CO Cashbook ─────────→ dashboard
```

The second architecture is explicitly forbidden. It produces inconsistent numbers.
