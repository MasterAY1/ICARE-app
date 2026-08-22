# Business Date & End of Day (EOD) Invariant Rules

## BR-DATE-001: Operational Business Date Authority
- **Rule ID:** BR-DATE-001
- **Name:** Operational Business Date Authority
- **Description:** Every branch maintains an authoritative active business date (`branches.cashbook_defaults.business_date`).
- **Required Behavior:**
  - All operational flows (Collections, Disbursements, EOD Cashbook Entries) default to the branch's active business date.
  - Advancing the business date must strictly follow Nigerian working day calendars (skipping Saturdays, Sundays, and public holidays).
- **Status:** CONFIRMED
- **Implementation Location:** `services/business_date_service.py`

---

## BR-DATE-002: Closed Business Date Immutability & Entry Freeze
- **Rule ID:** BR-DATE-002
- **Name:** Closed Business Date Immutability
- **Description:** When a business date is closed via EOD Day Close (`status == 'Closed'`), all operational transactions (Repayments, Savings, Disbursements, EOD Fees, Treasury) for that date are **STRICTLY FROZEN**.
- **Required Behavior:**
  - Any attempt to post a new operational transaction to a closed date without explicit administrator backdated/late-entry approval must be rejected by service layers (`ValueError` / `BusinessRuleError`).
  - The UI must disable form submissions and display a read-only lock banner when viewing a closed business date.
- **Prohibited Behavior:**
  - Allowing Credit Officers or Branch Managers to silently add or modify records on closed business dates.
  - Modifying closing balances of closed cashbooks.
- **Status:** CONFIRMED
- **Implementation Location:** `services/business_date_service.py`, `services/repayment_service.py`, `services/savings_service.py`, `app.py`

---

## BR-DATE-003: EOD Balance Rollover & Next Working Day Advancing
- **Rule ID:** BR-DATE-003
- **Name:** EOD Balance Rollover Invariant
- **Description:** Executing EOD Day Close carries forward the exact closing balance of Account 1000 Vault Cash to the next working day.
- **Required Behavior:**
  - `master_cashbook(next_working_day).opening_balance = master_cashbook(today).closing_balance`.
  - The next day's cashbook is initialized with `status = 'Open'`.
  - The branch's operational business date is advanced to the next valid working day.
- **Status:** CONFIRMED
- **Implementation Location:** `services/business_date_service.py`

---

## BR-DATE-004: Emergency Branch Closure & Non-Working Day Operational Freeze
- **Rule ID:** BR-DATE-004
- **Name:** Non-Working Day & Emergency Closure Freeze
- **Description:** Saturdays, Sundays, Nigerian public holidays, and custom/emergency closures declared by Area Managers, Admins, or Branch Managers automatically suspend all field collections, savings deposits/withdrawals, loan disbursements, and cashbook modifications.
- **Required Behavior:**
  - `BusinessDateService.is_operational_open()` validates weekend status, public holidays, active `branch_closures`, and Day Close status.
  - Service layers reject any operational posting on non-working days or during emergency closures.
  - UI displays informative suspension notices and disables form submission buttons.
- **Status:** CONFIRMED
- **Implementation Location:** `services/business_date_service.py`, `services/repayment_service.py`, `services/savings_service.py`, `services/treasury_service.py`, `services/loan_service.py`, `app.py`
