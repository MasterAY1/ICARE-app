# Accounting Rules

## BR-ACCT-001: Double-Entry Enforcement
- **Rule ID:** BR-ACCT-001
- **Name:** Double-Entry Enforcement
- **Description:** Every financial transaction must have equal debits and credits.
- **Required Behavior:** Reject any journal entry where total debits ≠ total credits.
- **Prohibited Behavior:** One-sided accounting entries.
- **Related Entities:** financial_transactions, financial_ledger_entries
- **Status:** IMPLEMENTATION-VERIFIED
- **Implementation Location:** `database/repositories/ledger_repository.py`

## BR-ACCT-002: Account 1000 Physical Cash Principle
- **Rule ID:** BR-ACCT-002
- **Name:** Account 1000 Physical Cash Principle
- **Description:** Account 1000 represents the authoritative physical CO vault cash position.
- **Required Behavior:**
  - Debit to Account 1000 = physical cash entering the vault.
  - Credit to Account 1000 = physical cash leaving the vault.
  - Any operation that does NOT physically move cash MUST NOT affect Account 1000.
- **Prohibited Behavior:**
  - Internal transfers (LoanOffsetFromSavings, LapsTransferred, LapsMigrated) touching Account 1000.
  - LapsPaidOut with cash_paid=False touching Account 1000.
- **Related Entities:** financial_ledger_entries, Account 1000
- **Status:** CONFIRMED
- **Implementation Location:** `services/posting_engine.py`, `core_banking_schema.sql` posting_rules

## BR-ACCT-003: Ledger Immutability
- **Rule ID:** BR-ACCT-003
- **Name:** Ledger Immutability
- **Description:** Ledger entries are immutable. Corrections must use reversing entries.
- **Required Behavior:** Append-only to the Ledger. Use reversing (equal and opposite) entries for corrections.
- **Prohibited Behavior:** UPDATE or DELETE on financial_ledger_entries or financial_transactions.
- **Related Entities:** financial_ledger_entries, financial_transactions
- **Status:** CONFIRMED
- **Implementation Location:** `database/repositories/ledger_repository.py`

## BR-ACCT-004: Posting Rule Authority
- **Rule ID:** BR-ACCT-004
- **Name:** Posting Rule Authority
- **Description:** The posting_rules table defines the authoritative account mapping for each event type.
- **Required Behavior:** The Posting Engine MUST look up debit/credit accounts from posting_rules. Conditional overrides (e.g., LapsPaidOut cash_paid=False) must be explicitly documented.
- **Prohibited Behavior:** Hardcoding account numbers in service code. Ignoring the posting_rules table.
- **Related Entities:** posting_rules, posting_engine
- **Status:** CONFIRMED
- **Implementation Location:** `services/posting_engine.py`, `core_banking_schema.sql`

## BR-ACCT-005: Event Payload Completeness for Accounting
- **Rule ID:** BR-ACCT-005
- **Name:** Event Payload Completeness
- **Description:** Domain events must carry sufficient structured metadata for correct accounting classification.
- **Required Behavior:** Treasury events must include `transaction_type`. Loan events must include `product_category`. LAPS events must include `cash_paid`.
- **Prohibited Behavior:** Relying on narration string parsing for accounting classification.
- **Related Entities:** event_store, Domain Events
- **Status:** CONFIRMED
- **Implementation Location:** `services/treasury_service.py`, `services/loan_service.py`, `services/savings_service.py`
