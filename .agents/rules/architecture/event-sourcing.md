# Event Sourcing Rules

## EVT-001: Domain Events Are the Source of Intent

**Status:** MANDATORY

Domain Events represent business operations that have occurred. They are the trigger for financial postings.

**Required Behavior:**
- Every financial operation MUST emit a Domain Event before posting to the Ledger.
- Events MUST contain all metadata required for downstream processing (branch, officer, amount, classification, transaction_type).
- Events are immutable once appended to the Event Store.

**Prohibited Behavior:**
- Posting to the Ledger without a corresponding Domain Event.
- Modifying events after they have been appended.
- Emitting events with incomplete payloads (e.g., missing `loan_id`, `transaction_type`, `classification`).

## EVT-002: Event Payload Completeness

**Status:** MANDATORY

Every Domain Event payload MUST contain sufficient structured metadata for downstream consumers to correctly process it WITHOUT relying on string parsing of narration fields.

**Required Behavior:**
- Treasury events MUST include a `transaction_type` field (e.g., "HO_TRANSFER_IN", "INTER_BRANCH_IN", "OFFICE_EXPENSE").
- Loan events MUST include `product_category` (e.g., "Finance", "Asset").
- Repayment events MUST include `loan_id`.
- LAPS events MUST include `cash_paid` boolean where applicable.

**Prohibited Behavior:**
- Relying on narration string matching to classify events in downstream projections.
- Collapsing semantically different operations into the same event type without preserving the distinction in structured metadata.

## EVT-003: Posting Rules Are Authoritative for Accounting

**Status:** MANDATORY

The `posting_rules` table determines which accounts are debited and credited for each event type.

**Required Behavior:**
- The Posting Engine MUST look up the posting rule for the event type.
- The Posting Engine MAY conditionally override the credit account based on structured payload fields (e.g., `LapsPaidOut` with `cash_paid=False` redirects credit from 1000 to 1050).
- All overrides MUST be documented and justified by a specific business rule.

**Prohibited Behavior:**
- Hardcoding account numbers in service layer code.
- Ignoring the posting rule table.
- Creating posting overrides that are not backed by an explicit business rule.
