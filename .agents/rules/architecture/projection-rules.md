# Projection Rules

## PROJ-001: CO Cashbook Is a Dimensional View of Vault Cash (`1000`) & Bank Settlement Pairing
**Status:** MANDATORY

The CO Cashbook is built exclusively for active Credit Officer roles (`CO` / `Credit Officer`), dimensionalized by `officer_id`, tracking physical Vault Cash alongside auto-calculated Bank settlement pairings.

**Required Behavior:**
- **Field Cash Collections -> Bank Deposit**: Physical cash collected from the field (Repayments, Savings, Asset upfront cash/Cash-and-Carry, standalone Fees) enters Vault Cash (`1000`); when deposited to bank (`BankDeposited` -> `CR 1000`), it appears under `bank_deposit` on the Right side.
- **Bank Transfers & Disbursements -> Auto Bank Withdrawal**: Bank-routed outflows (Finance `LoanDisbursed`, direct Customer Savings Withdrawals, direct LAPS Payouts) credit Bank (`1050`) and auto-populate `bank_withdrawal` on the Left side — there is NO manual `bank_withdrawal` input.
- **Balancing Columns on Right Side**:
  - `weekly_active`, `daily_active`, `monthly_active` balance the Finance loan disbursement portion of `bank_withdrawal` (or `asset_credit_sales` for Asset loans).
  - `product_withdrawal` balances direct Bank savings withdrawals (paired with `bank_withdrawal`) as well as non-cash offsets (`LoanOffsetFromSavings`, `FeeOffsetFromSavings`, `GapFeeOffsetFromSavings`, `LapsTransferred`).
  - `laps_returns` balances the Bank-routed LAPS payout portion of `bank_withdrawal`.
- **Misc Fees / Internal Savings**: Added to `Savings Deposit` ONLY for the branch's designated Misc Savings officer (e.g. CO3 in Ogijo).

---

## PROJ-002: Master Cashbook Is a Branch-Level Projection of Vault (`1000`) & Bank (`1050`) Pairs
**Status:** MANDATORY

The Master Cashbook aggregates all Credit Officer `co_cashbooks` rows for the branch, incorporates branch-level Treasury (`1000` and `1050`) & non-CO disbursement events, preserves negative excess-banked carry-forward (`opening_balance` never clamped to zero), and exposes live `bank_balance` (`Account 1050` Net).

**Required Behavior:**
- Master Cashbook aggregates all CO Cashbook entries for a branch (strictly Credit Officers, zero BM rows).
- **Bank Funding Received (`CashTransferred_HO_In`)**: Pairs `Left: funds_received_ho / funds_received_other_branch / funds_received_other_area` with `Right: bank_deposit` (`Net Vault = 0`, `DR 1050`).
- **Bank Transfers Out & Salaries (`CashTransferred_HO_Out`, `SalaryPaid`, `HO/Branch/Area/Asset Out`)**: Auto-credits `Left: bank_withdrawal` paired with `Right: fund_transferred_* / fund_to_asset_program / staff_salaries` (`Net Vault = 0`, `CR 1050`).
- **Office Cash Expenses & Physical Vault Sweeps**: Physical branch cash outlays (`ExpenseRecorded` -> `CR 1000`) post solely to `Right: office_expenses`; physical vault deposits (`BankDeposited` -> `CR 1000`) post solely to `Right: bank_deposit`.
- **Vault Float Adjustments (`VaultAdjusted_In`)**: Debits `Account 1000` and populates `Left: adjustment_in` idempotently without double-counting manual DB entries.

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
