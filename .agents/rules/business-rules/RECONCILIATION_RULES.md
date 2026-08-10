# Reconciliation Rules

## BR-RECON-001: Independent Source Verification
- **Rule ID:** BR-RECON-001
- **Name:** Independent Source Verification
- **Description:** The 6-way reconciliation must query 6 independent data sources.
- **Required Behavior:**
  1. General Ledger Total: Query `financial_ledger_entries` for Account 1000, calculate NET (debits - credits).
  2. Audit Views Total: Query operational audit trails independently.
  3. CO Cashbooks Total: Sum `co_cashbooks.closing_balance` for the branch.
  4. Master Cashbook Total: Read `master_cashbook.closing_balance` for the branch.
  5. Dashboard Total: Calculate the same metric that the dashboard displays, using the dashboard's actual source.
  6. Reports Total: Calculate the same metric that reports display, using the reports' actual source.
- **Prohibited Behavior:**
  - Assigning one source's value to another (e.g., `dashboard_total = master_cashbook_total`).
  - Only counting debits in the Ledger check (ignoring credits).
  - Silently forcing reconciliation to pass.
- **Related Entities:** financial_ledger_entries, co_cashbooks, master_cashbook, dashboard, reports
- **Status:** CONFIRMED
- **Implementation Location:** `services/financial_reconciliation_service.py`

## BR-RECON-002: Mismatch Is an Error to Expose
- **Rule ID:** BR-RECON-002
- **Name:** Mismatch Exposure
- **Description:** A reconciliation mismatch must be clearly reported, not hidden.
- **Required Behavior:** When sources disagree, report the variance with branch, date, expected value, actual value, difference, source A, source B, and likely cause.
- **Prohibited Behavior:** Masking, hiding, or automatically correcting reconciliation mismatches.
- **Related Entities:** Reconciliation Service
- **Status:** CONFIRMED
- **Implementation Location:** `services/financial_reconciliation_service.py`

## BR-RECON-003: Orphan Detection
- **Rule ID:** BR-RECON-003
- **Name:** Orphan Detection
- **Description:** The system must detect orphaned records (operational records without Ledger postings and Ledger entries without event_store references).
- **Required Behavior:**
  - Detect Active loans without `LoanDisbursed` events.
  - Detect repayments without `RepaymentReceived` events.
  - Detect Ledger entries where the `event_store` foreign key returns null.
  - Report all orphans with branch, date, amount, and likely cause.
- **Prohibited Behavior:**
  - Automatically creating missing Ledger entries for orphaned operational records.
  - Automatically deleting orphaned operational records.
  - Silently ignoring orphans.
- **Related Entities:** loans, repayments, event_store, financial_ledger_entries
- **Status:** CONFIRMED
- **Implementation Location:** `services/financial_reconciliation_service.py`

## BR-RECON-004: Historical Data Remediation Protocol
- **Rule ID:** BR-RECON-004
- **Name:** Historical Data Remediation
- **Description:** Historical inconsistencies must follow a controlled remediation process.
- **Required Behavior:**
  1. DETECT: Identify the orphaned/inconsistent record.
  2. FREEZE: Do not automatically remediate.
  3. INVESTIGATE: Determine the original operation, check audit/event history.
  4. DETERMINE: Establish whether cash actually moved physically.
  5. PROPOSE: Draft the correction entry.
  6. APPROVE: Obtain explicit human approval.
  7. REMEDIATE: Execute the approved correction with full audit trail.
- **Prohibited Behavior:**
  - Automatic repair of historical financial data.
  - Deleting or modifying existing Ledger entries.
  - Fabricating missing events without investigation.
- **Related Entities:** All financial tables
- **Status:** CONFIRMED
- **Implementation Location:** Manual DBA/Admin process
