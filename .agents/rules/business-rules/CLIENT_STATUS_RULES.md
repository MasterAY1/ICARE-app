# Client Status Lifecycle Rules

## BR-CLI-001: Client Status Must Be Uniquely Defined
- **Rule ID:** BR-CLI-001
- **Name:** Client Status Uniqueness & Authority
- **Description:** Every client must have exactly one authoritative lifecycle status at any point in time. The status must be stored as a foreign key to the `client_statuses` reference table (UUID-based), not as a free-text string.
- **Required Behavior:**
  - `clients.status_id` references `client_statuses.status_id` (UUID).
  - Every status change is recorded in `client_status_history` with timestamp, changed_by, reason, and trigger_type.
  - Status is the single source of truth for client lifecycle position.
- **Prohibited Behavior:**
  - Free-text status values on the `clients` table.
  - Deriving client status from loan status at query time (must be persisted).
  - Multiple simultaneous statuses for the same client.
- **Status:** CONFIRMED

## BR-CLI-002: Client Lifecycle States
- **Rule ID:** BR-CLI-002
- **Name:** Predefined Client Lifecycle States
- **Description:** The following are the only valid client lifecycle states:
  1. **Registered**: Onboarded, never received a loan.
  2. **Pending Loan**: Loan application submitted, awaiting BM approval.
  3. **On Loan**: Loan approved by BM and disbursed; outstanding balance > 0.
  4. **Completed**: Recently finished paying a loan; expected to re-apply soon.
  5. **Dormant**: Inactive for longer than the branch-configured dormancy threshold (no loan, no savings activity).
  6. **Inactive (Savings Only)**: No longer borrows but still has savings with the company.
  7. **Closed**: Client relationship fully terminated; no active products.
  8. **Suspended**: Temporarily suspended (investigation, dispute).
  9. **Defaulter**: Overdue loan past maturity with no payments for > 30 days. This is a **warning flag only** and does NOT automatically block new loan applications. The BM decides whether to grant a new loan.
- **Required Behavior:** All services, dashboards, and reports must use these predefined statuses for client classification.
- **Prohibited Behavior:** Inventing ad-hoc statuses like "Active Loan", "Full Paid (Closed)", "Normal Paid", etc. as client statuses. Those are repayment period statuses, not client lifecycle statuses.
- **Status:** CONFIRMED

## BR-CLI-003: Automatic System Transitions
- **Rule ID:** BR-CLI-003
- **Name:** System-Managed Client Status Transitions
- **Description:** Certain status transitions must happen automatically without manual intervention:
  1. **Registered → Pending Loan**: Triggered when a loan application is submitted for the client.
  2. **Pending Loan → On Loan**: Triggered when the BM approves the loan and it is disbursed (`LoanDisbursed` event).
  3. **On Loan → Completed**: Triggered when the final repayment clears the loan outstanding balance to ₦0.00.
  4. **On Loan → Defaulter**: Triggered when the loan is past maturity date + 30 days with no payments. This is a **warning flag only** — BM physically decides on subsequent lending.
  5. **Completed → Dormant**: Triggered when more than the branch-configured dormancy threshold passes after loan completion with no new loan and no savings activity.
  6. **Completed → Pending Loan**: Triggered when the completed client submits a new loan application.
- **Required Behavior:**
  - System transitions must update `clients.status_id`, `clients.status_changed_at`, and log to `client_status_history` with `trigger_type = 'SYSTEM'`.
  - Loan `status` must also transition (e.g., `Active → Completed`) in sync with the client status change.
- **Prohibited Behavior:**
  - Leaving a loan as `Active` when outstanding balance = ₦0.00.
  - Leaving a client as `On Loan` when all their loans are completed.
- **Status:** CONFIRMED

## BR-CLI-004: Manual CO-Controlled Transitions
- **Rule ID:** BR-CLI-004
- **Name:** Credit Officer Direct Status Control
- **Description:** The Credit Officer (CO) may directly change client status for the following transitions via the Portfolio page. **No BM approval is required** for status changes — COs have full control.
  1. **Any → Inactive (Savings Only)**: Client has savings but no interest in new loans.
  2. **Any → Closed**: Client relationship ended.
  3. **Any → Suspended**: Temporary suspension for investigation.
  4. **Dormant → Registered**: CO re-activates a dormant client for potential lending.
- **Required Behavior:**
  - Manual transitions must update `clients.status_id`, `clients.status_changed_at`, `clients.status_changed_by`, and log to `client_status_history` with `trigger_type = 'MANUAL'`.
  - A free-text `status_note` must be provided for manual transitions.
- **Prohibited Behavior:**
  - CO manually setting status to `On Loan` (system-only, requires actual loan approval by BM + disbursement).
  - CO manually setting status to `Completed` (system-only, requires actual loan repayment clearing balance).
  - Changing status without recording in `client_status_history`.
- **Status:** CONFIRMED

## BR-CLI-005: Loan Status Lifecycle Alignment
- **Rule ID:** BR-CLI-005
- **Name:** Loan Status Must Transition When Balance Reaches Zero
- **Description:** The `loans.status` column must transition from `Active` to `Completed` when the outstanding balance (total_due - lifetime_repayments) reaches ₦0.00.
- **Required Behavior:**
  - When a repayment event causes outstanding balance ≤ 0: `loans.status = 'Completed'`.
  - When a loan is completed, the client status must also transition (On Loan → Completed) if no other active loans exist.
  - Active Loans KPI count must only include loans where `status = 'Active'` AND `outstanding_balance > 0`.
- **Prohibited Behavior:**
  - Leaving `loans.status = 'Active'` when the outstanding balance is ₦0.00.
  - Counting completed loans in the "Active Loans" metric.
- **Status:** CONFIRMED

## BR-CLI-006: Dashboard Metrics From Client Status
- **Rule ID:** BR-CLI-006
- **Name:** Portfolio Metrics Must Derive From Client Status Table
- **Description:** All client-count metrics on dashboards must be derived from `clients.status_id` joined to `client_statuses`.
- **Required Behavior:**
  - `Active Borrowers` = COUNT(clients WHERE status = 'On Loan')
  - `Pending Loan` = COUNT(clients WHERE status = 'Pending Loan')
  - `Recently Completed` = COUNT(clients WHERE status = 'Completed')
  - `Dormant Clients` = COUNT(clients WHERE status = 'Dormant')
  - `Closed Clients` = COUNT(clients WHERE status = 'Closed')
  - `Defaulters` = COUNT(clients WHERE status = 'Defaulter') — **warning flag only**
  - `Savings-Only` = COUNT(clients WHERE status = 'Inactive (Savings Only)')
  - `Total Active Relationship` = COUNT(clients WHERE status NOT IN ('Closed', 'Suspended'))
- **Prohibited Behavior:**
  - Computing active_clients_count from `len(active_loans_by_client)` or raw loan table rows.
  - Computing dormant_clients as `total - active - closed` (must be a persisted status).
- **Status:** CONFIRMED

## BR-CLI-007: Status History Audit Trail
- **Rule ID:** BR-CLI-007
- **Name:** Every Status Change Must Be Audited
- **Description:** The `client_status_history` table provides a complete, immutable audit trail of every client lifecycle status change.
- **Required Behavior:**
  - Every transition (system or manual) inserts a row into `client_status_history`.
  - Fields: `client_id`, `old_status_id`, `new_status_id`, `changed_by`, `changed_at`, `reason`, `trigger_type`, `trigger_reference`.
  - History rows are never deleted or updated.
- **Prohibited Behavior:**
  - Deleting or modifying status history records.
  - Changing client status without inserting a history record.
- **Status:** CONFIRMED

## BR-CLI-008: Dormancy Threshold Configuration
- **Rule ID:** BR-CLI-008
- **Name:** Dormancy Threshold is Configurable Per Branch
- **Description:** The number of days of inactivity before a client is marked as `Dormant` must be configurable per branch, not a fixed company-wide constant.
- **Required Behavior:**
  - The `branches` table must have a `dormancy_threshold_days` column (INTEGER, default 90).
  - The dormancy check evaluates against the branch's configured threshold.
  - Different branches may have different dormancy windows based on local business conditions.
- **Prohibited Behavior:**
  - Hardcoding a company-wide dormancy threshold (e.g., `DORMANCY_DAYS = 90`).
- **Status:** CONFIRMED

## BR-CLI-009: Defaulter Status is Warning Only
- **Rule ID:** BR-CLI-009
- **Name:** Defaulter Status Does Not Block Loan Applications
- **Description:** The `Defaulter` status is a **warning flag** only. It does NOT automatically block a client from applying for or receiving a new loan.
- **Required Behavior:**
  - When a client is flagged as `Defaulter`, a visual warning is displayed on the loan application and renewal screens.
  - The BM makes the final physical decision on whether to approve a new loan for a defaulter.
  - `RenewalService.check_eligibility()` must return `is_eligible = True` with a warning, not `is_eligible = False`.
- **Prohibited Behavior:**
  - Automatically rejecting loan applications from clients with `Defaulter` status.
  - Hiding the defaulter history from the BM approval screen.
- **Status:** CONFIRMED
