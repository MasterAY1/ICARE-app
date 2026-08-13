# Error Correction Rules

## BR-ERR-001: Four-Eyes Correction Principle
- **Rule ID:** BR-ERR-001
- **Name:** Four-Eyes Correction Principle
- **Description:** No single user can initiate and execute a financial correction independently.
- **Required Behavior:** 
  - Credit Officers (CO) can only *request* a correction by submitting a reason.
  - Branch Managers (BM) or Global Admins must independently *review and approve* the correction before it takes effect.
- **Prohibited Behavior:** COs reversing their own transactions. BMs creating and automatically approving their own corrections without a request trail.
- **Related Entities:** `correction_requests`, `app_users`
- **Status:** IMPLEMENTATION-PENDING

## BR-ERR-002: Reversing Entries Only
- **Rule ID:** BR-ERR-002
- **Name:** Reversing Entries Only
- **Description:** Corrections must be mathematically netted out via new entries, not by modifying historical data.
- **Required Behavior:** 
  - To correct an error, the system must generate a new Reversal event (e.g., `RepaymentReversed`) that posts exact opposite debits and credits to the ledger.
  - The operational table (e.g., `repayments`) must receive a compensating negative record, OR the original record must be flagged as `reversed: true` (if schema supports it), while a new adjusting record is added to ensure sum aggregates remain accurate.
- **Prohibited Behavior:** Running `UPDATE` or `DELETE` on financial ledger entries or historical repayment records.
- **Related Entities:** `financial_ledger_entries`, `repayments`
- **Status:** IMPLEMENTATION-PENDING

## BR-ERR-003: Physical Cash Alignment Check
- **Rule ID:** BR-ERR-003
- **Name:** Physical Cash Alignment Check
- **Description:** Reversals inherently affect the Cashbook projections and Account 1000.
- **Required Behavior:** The Approver (BM) must physically verify if cash moved before approving a reversal, as the reversal will immediately deduct or add to the current day's expected Cash in Vault.
- **Prohibited Behavior:** Approving corrections without confirming the physical cash count.
- **Related Entities:** `co_cashbooks`, `master_cashbook`
- **Status:** IMPLEMENTATION-PENDING
