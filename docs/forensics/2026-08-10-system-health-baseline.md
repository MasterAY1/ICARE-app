# System Health Forensic Baseline

> **Date:** August 10, 2026  
> **Notice:** This document describes observed system failures as of August 10, 2026. It is NOT permission to change business rules. The authoritative business rules remain in `.agents/rules/business-rules/`.

---

## 1. Observed Core Violations & Discrepancies

### Financial Integrity & Atomicity
- **Non-Atomic Disbursements**: 10 active loans (total ₦1,530,000 in Ogijo) were saved operationally via HTTP REST before financial posting, but failed to post `LoanDisbursed` events to the Ledger.
- **Compensating Ledger Deletions**: `services/posting_engine.py` attempts to execute SQL `DELETE` on `financial_ledger_entries` and `financial_transactions` when projection rebuilds fail, directly violating Ledger Immutability (BR-DATA-005).
- **Hardcoded Fallback Branch**: `posting_engine.py` routes unresolvable branch lookups to hardcoded UUID `1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d` (Head Office), resulting in 44 ghost entries corrupting Head Office ledger figures.
- **Faked 6-Way Reconciliation**: `services/financial_reconciliation_service.py` hardcodes `dashboard_total = master_cashbook_total` and `reports_total = master_cashbook_total` to force reconciliation passes, and computes gross debits instead of net ledger position.

### Projection & Source of Truth Violations
- **Master Cashbook Operational Queries**: `services/master_cashbook_projection_builder.py` bypasses the Ledger and directly queries `loans` and `treasury_transactions` operational tables, creating a parallel financial truth.
- **Treasury Event Collapse & Metadata Loss**: UI actions (`HO_TRANSFER_IN` and `INTER_BRANCH_IN`) collapse into a single `CashTransferred_HO_In` event without preserving `transaction_type` in event metadata.
- **CO/Ledger Discrepancies**:
  - Ogijo Branch: CO Cashbook Net = ₦119,500 vs. Ledger Net = ₦794,850 (Diff: -₦675,350)
  - Head Office: CO Cashbook Net = ₦5,000 vs. Ledger Net = ₦515,850 (Diff: -₦510,850)

### Loan Lifecycle & Repayment Schedules
- **Same-Day Repayments**: 9 out of 10 active loans have `start_date == disbursement_date` due to `loan_service.py` line 34 assigning `start_date = disbursement_date`.
- **Holiday Week Skip Bug**: `schedule_service.py` adds `timedelta(weeks=1)` when a weekly meeting day falls on a holiday, skipping an entire period instead of advancing to the next working day.
- **Asset Product Calculation**: `loan_product_engine.py` computes `active_credit = Principal - Gap Fee` for all products, omitting `(Principal + Interest) - Downpayment` for Asset products.

---

## 2. Inventory of Known Orphaned & Ghost Records

1. **10 Orphaned Active Loans (Ogijo)**:
   - `3936a198...` (₦200,000)
   - `9fca8aec...` (₦250,000)
   - `347b3697...` (₦250,000)
   - `1fc31f30...` (₦200,000)
   - `ab3ab233...` (₦200,000)
   - `5c0398c1...` (₦100,000) - `disbursement_date` is `None`
   - `485832e7...` (₦100,000)
   - `a4adf283...` (₦50,000)
   - `75e458c0...` (₦80,000)
   - `ea4cc032...` (₦100,000)
2. **44 Ghost Ledger Entries on Fallback Branch (Head Office)**:
   - Posted under UUID `1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d`.
   - 42 entries have `UNKNOWN` event types.

*Remediation Policy: DO NOT automatically clean up or delete these records. They are flagged for human-controlled DBA review.*
