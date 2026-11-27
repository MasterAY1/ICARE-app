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

## BR-ACCT-002: Account 1000 Physical Vault Cash vs Account 1050 Bank Principle
- **Rule ID:** BR-ACCT-002
- **Name:** Physical Vault Cash (`1000`), Branch Bank (`1050`), and Asset Inventory (`1300`) Separation
- **Description:** Account `1000` represents strictly physical vault cash held at the branch/CO bag. Account `1050` represents the branch corporate bank account. Account `1300` represents asset loan inventory.
- **Required Behavior:**
  - **Account `1000` Debits (`+Vault Cash`)**: Physical field collections (`RepaymentReceived`, `SavingsDeposited`, standalone cash `FeeCharged`, `AssetSoldCash`) and explicit Vault float adjustments (`VaultAdjusted_In`).
  - **Account `1000` Credits (`-Vault Cash`)**: Vault cash sweeps deposited into bank (`BankDeposited` -> `DR 1050 / CR 1000`) and physical office cash expenses (`ExpenseRecorded` -> `DR 4000 / CR 1000`).
  - **Account `1050` Operations (Non-Vault Cash)**: Corporate Transfers IN (`CashTransferred_HO_In` -> `DR 1050 / CR 3100`), Corporate Transfers OUT (`CashTransferred_HO_Out` -> `DR 3100 / CR 1050`), Staff Salaries (`SalaryPaid` -> `DR 4100 / CR 1050`), Finance Loan Disbursements (`LoanDisbursed` Finance -> `DR 1200 / CR 1050`), and all Bank-routed direct Customer Savings Withdrawals & LAPS Payouts (`SavingsWithdrawn`, `LapsPaidOut` -> `CR 1050`).
  - **Non-Cash Internal Settles**: Asset `LoanDisbursed` (`DR 1200 / CR 1300`), `FeeOffsetFromSavings` (`DR 2000 / CR 3000`), `GapFeeOffsetFromSavings` (`DR 2000 / CR 1200`), `LoanOffsetFromSavings` (`DR 2000 / CR 1200`), and `LapsTransferred`/`LapsMigrated` MUST NOT touch `Account 1000` or `Account 1050`.
- **Prohibited Behavior:**
  - Posting HO/Branch/Area transfers or Staff Salaries against `Account 1000`.
  - Routing direct customer savings withdrawals or LAPS payouts through physical Vault Cash (`1000`).
  - Reversing a journal entry against a different cash account than the original posting.
- **Related Entities:** financial_ledger_entries, Account 1000, Account 1050, Account 1300
- **Status:** CONFIRMED
- **Implementation Location:** `services/posting_engine.py`, `database/schemas/core_banking_schema.sql`, `database/migrations/phase18_bank_centric_treasury_and_cashbook_alignment.sql`

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
- **Description:** The `posting_rules` table defines the authoritative account mapping for each event type.
- **Required Behavior:** The Posting Engine MUST look up debit/credit accounts from `posting_rules`. Conditional overrides (`LoanDisbursed` Finance -> `1050` vs Asset -> `1300`, `ExpenseReversed`, reversal symmetry via `original_cash_account`, etc.) must be explicitly documented and preserve symmetry on reversals.
- **Prohibited Behavior:** Hardcoding conflicting account numbers across services or breaking reversal cash-account symmetry.
- **Related Entities:** posting_rules, posting_engine
- **Status:** CONFIRMED
- **Implementation Location:** `services/posting_engine.py`, `database/schemas/core_banking_schema.sql`

## BR-ACCT-005: Event Payload Completeness for Accounting
- **Rule ID:** BR-ACCT-005
- **Name:** Event Payload Completeness
- **Description:** Domain events must carry sufficient structured metadata for correct accounting classification.
- **Required Behavior:** Treasury events must include `transaction_type`. Loan events must include `product_category`. LAPS events must include `cash_paid`.
- **Prohibited Behavior:** Relying on narration string parsing for accounting classification.
- **Related Entities:** event_store, Domain Events
- **Status:** CONFIRMED
- **Implementation Location:** `services/treasury_service.py`, `services/loan_service.py`, `services/savings_service.py`
