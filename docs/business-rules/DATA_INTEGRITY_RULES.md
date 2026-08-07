# Data Integrity Rules

## BR-DATA-001
- **Name:** Atomic Operations
- **Description:** Financial operations must be atomic.
- **Required Behavior:** Execute financial postings in a single transaction that succeeds or fails entirely.
- **Prohibited Behavior:** Do not commit partial data or leave orphaned financial records.
- **Related Entities:** All Financial Transactions
- **Status:** Active
- **Implementation Location:** Application wide

## BR-DATA-002
- **Name:** Exception Handling
- **Description:** Database exceptions must NOT be swallowed.
- **Required Behavior:** Propagate or handle database errors explicitly, logging the failure context.
- **Prohibited Behavior:** Do not use empty catch blocks or hide underlying persistence errors.
- **Related Entities:** Database Layer
- **Status:** Active
- **Implementation Location:** Application wide

## BR-DATA-003
- **Name:** Complete Records Required
- **Description:** Partial financial records must NOT be created.
- **Required Behavior:** Ensure all required fields, foreign keys, and metadata are present before persisting.
- **Prohibited Behavior:** Do not bypass domain validation when saving financial records.
- **Related Entities:** Domain Models
- **Status:** Active
- **Implementation Location:** Application wide

## BR-DATA-004
- **Name:** Ledger Balance Enforcement
- **Description:** Ledger entries must balance (debits = credits) — enforced by `SupabaseLedgerRepository` validation.
- **Required Behavior:** Reject any journal entry where total debits do not equal total credits.
- **Prohibited Behavior:** Do not permit one-sided accounting entries.
- **Related Entities:** Ledger, Journal Entries
- **Status:** Active
- **Implementation Location:** `SupabaseLedgerRepository`

## BR-DATA-005
- **Name:** Ledger Immutability
- **Description:** Ledger transactions are immutable — update() and delete() throw NotImplementedError.
- **Required Behavior:** Append only to the ledger; use reversing entries for corrections.
- **Prohibited Behavior:** Do not execute UPDATE or DELETE operations on ledger transaction records.
- **Related Entities:** Ledger Repository
- **Status:** Active
- **Implementation Location:** `SupabaseLedgerRepository`

## BR-DATA-006
- **Name:** Event Store Idempotency
- **Description:** Event Store provides idempotency check on `event_id`.
- **Required Behavior:** Discard duplicate events based on the unique `event_id`.
- **Prohibited Behavior:** Do not process or append the same event twice.
- **Related Entities:** Event Store
- **Status:** Active
- **Implementation Location:** Event Store implementation

## BR-DATA-007
- **Name:** Multi-Level Enforcement
- **Description:** Business rules enforced at multiple levels: UI, Application, Domain, Database.
- **Required Behavior:** Apply validations across all application tiers to ensure defense in depth.
- **Prohibited Behavior:** Do not rely solely on UI-level validation.
- **Related Entities:** Architecture
- **Status:** Active
- **Implementation Location:** Application wide

## BR-DATA-008
- **Name:** Audit Log Immutability
- **Description:** Audit logs are immutable — DB triggers prevent UPDATE/DELETE on `user_audit_logs`.
- **Required Behavior:** Maintain a secure and unalterable trail of user actions.
- **Prohibited Behavior:** Do not attempt to modify or purge audit log records programmatically.
- **Related Entities:** Audit Logs
- **Status:** Active
- **Implementation Location:** `user_audit_logs` table (Database Triggers)

## BR-DATA-009
- **Name:** Relational Constraints
- **Description:** Foreign key constraints must be respected (e.g., `loans.client_id` → `clients`, `repayments.loan_id` → `loans`).
- **Required Behavior:** Enforce strict referential integrity in the database schema.
- **Prohibited Behavior:** Do not disable foreign key checks or leave dangling references.
- **Related Entities:** Database Schema
- **Status:** Active
- **Implementation Location:** Database Schema Definition

## BR-DATA-010
- **Name:** Row Level Security (RLS)
- **Description:** RLS policies enabled on `loans` and `repayments` tables.
- **Required Behavior:** Enforce authorization rules at the database level for data access.
- **Prohibited Behavior:** Do not query these tables with bypass privileges for standard application logic.
- **Related Entities:** Database Security
- **Status:** Active
- **Implementation Location:** Database Schema (RLS Policies)
