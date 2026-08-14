# Projection Rules

## PROJ-001: CO Cashbook Is a Dimensional View of Account 1000 & Operational Balancing
**Status:** MANDATORY

The CO Cashbook is a projection of Account 1000 Ledger entries, dimensionalized by `officer_id` and balanced by field cash bank deposits and client bank transfers.

**Required Behavior:**
- **Field Cash Collections $\rightarrow$ Bank Deposit**: All cash collected from the field (Repayments, Savings, Markups, Fees) is deposited into the company bank account at end of day, recorded under `bank_deposit` on the Right side.
- **Client Payouts via Bank Transfers $\rightarrow$ Bank Withdrawal**: Client payouts (Loan disbursements, Customer savings withdrawals, LAPS claims) are executed via bank transfer, recorded under `bank_withdrawal` on the Left side.
- **Balancing Columns on Right Side**:
  - `weekly_active`, `daily_active`, `monthly_active` balance the loan disbursement portion of `bank_withdrawal`.
  - `product_withdrawal` balances customer savings withdrawals from `bank_withdrawal`, as well as non-cash loan offsets and LAPS sweeps.
  - `laps_returns` balances the LAPS payout portion of `bank_withdrawal`.
- **Misc Fees / Internal Savings**: Added to `Savings Deposit` ONLY for the branch's designated Misc Savings officer (e.g. CO3 in Ogijo).

---

## PROJ-002: Master Cashbook Is a Branch-Level Projection of the Same Financial Truth
**Status:** MANDATORY

The Master Cashbook aggregates all CO Cashbooks for the branch, plus directly incorporates branch-level Treasury and Disbursement operations from Account 1000.

**Required Behavior:**
- Master Cashbook aggregates all CO Cashbook entries for a branch.
- For branch-level items (Treasury, HO transfers, Disbursements, Staff Salaries, Expenses), the Master Cashbook queries Account 1000 Ledger entries directly.
- Outflows sum CO product withdrawals, vault loan disbursements (`fund_to_asset_program`, `fund_to_product_finance`), bank deposits, staff salaries, expenses, and treasury transfers.

---

## PROJ-003: Projection Failure Must Not Corrupt Financial History
**Status:** MANDATORY

**Required Behavior:**
- If a projection rebuild fails, log the error and flag it for manual review.
- The underlying Ledger entries MUST remain untouched.
- Retry the projection rebuild, or defer it for batch processing.

---

## PROJ-004: No Double Counting
**Status:** MANDATORY

Every physical cash movement MUST appear in exactly one projection path.
