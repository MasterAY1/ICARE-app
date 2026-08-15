# Cashbook Metric Contracts

> Every column in the CO Cashbook and Master Cashbook MUST have a contract entry here.
> This defines what each column means, where it comes from, and which side of the T-account it belongs to.

---

## T-Account Architecture

The cashbook follows a double-sided T-account:

- **Left Side (Inflows / Debits)**: Cash received into the vault/bag, plus non-cash balancing entries.
- **Right Side (Outflows / Credits)**: Cash paid out, deposits to bank, plus non-cash balancing disbursements.
- **Closing Balance** = Total Inflows (Left) − Total Outflows (Right).

---

# CO Cashbook Columns (`co_cashbooks` table)

## Left Side — Inflows

### MC-CB-001: Opening Balance
- **Column**: `opening_balance`
- **Side**: Left (B/F)
- **Event Type**: Rollover (not from ledger)
- **Account 1000**: N/A
- **Source**: Previous day's `closing_balance` from `co_cashbooks`
- **Meaning**: Physical cash brought forward from yesterday.

### MC-CB-002: Savings Deposit
- **Column**: `savings_deposit`
- **Side**: Left
- **Event Type**: `SavingsDeposited`, `INDIVIDUAL_SAVINGS_DEPOSIT`, `GROUP_SAVINGS_DEPOSIT`
- **Account 1000**: Debit (cash in)
- **Source**: `financial_ledger_entries` where Account 1000, Debit side
- **Meaning**: Client savings collected in field. Includes pooled misc fees for designated misc officer (BR-SAV-002).

### MC-CB-003: LAPS Reserve
- **Column**: `laps_reserve`
- **Side**: Left
- **Event Type**: `LapsTransferred` (Account 2030, Credit side — internal sweep)
- **Account 1000**: Debit (when cash collected) or non-cash (when swept)
- **Source**: `financial_ledger_entries`
- **Meaning**: LAPS insurance reserve contribution.

### MC-CB-004: Repayment Daily (60D/120D)
- **Column**: `rep_daily`
- **Side**: Left
- **Event Type**: `RepaymentReceived` (Daily cycle products)
- **Account 1000**: Debit
- **Source**: `financial_ledger_entries`, classified by `loans.loan_products.repayment_cycle = 'Daily'`
- **Meaning**: Cash collected for daily loan installments.

### MC-CB-005: Repayment 12 Weeks
- **Column**: `rep_12_weeks`
- **Side**: Left
- **Event Type**: `RepaymentReceived` (Weekly cycle, 12W products)
- **Account 1000**: Debit
- **Source**: `financial_ledger_entries`, classified by product name containing "12" and `repayment_cycle = 'Weekly'`
- **Meaning**: Cash collected for 12-week weekly installments.

### MC-CB-006: Repayment 24 Weeks
- **Column**: `rep_24_weeks`
- **Side**: Left
- **Event Type**: `RepaymentReceived` (Weekly cycle, 24W products)
- **Account 1000**: Debit
- **Source**: `financial_ledger_entries`, classified by product name containing "24" and `repayment_cycle = 'Weekly'`
- **Meaning**: Cash collected for 24-week weekly installments.

### MC-CB-007: Repayment 120 Days
- **Column**: `rep_120_days`
- **Side**: Left
- **Event Type**: `RepaymentReceived` (Daily cycle, 120D products)
- **Account 1000**: Debit
- **Source**: `financial_ledger_entries`, classified by product name containing "120"
- **Meaning**: Cash collected for 120-day daily installments.

### MC-CB-008: Repayment Monthly
- **Column**: `rep_monthly`
- **Side**: Left
- **Event Type**: `RepaymentReceived` (Monthly cycle)
- **Account 1000**: Debit
- **Source**: `financial_ledger_entries`, classified by `repayment_cycle = 'Monthly'`
- **Meaning**: Cash collected for monthly installments (3M/6M tenors).

### MC-CB-009: Daily 11%
- **Column**: `daily_11_pct`
- **Side**: Left
- **Event Type**: `FeeCharged`, `MARKUP_11` (daily products)
- **Account 1000**: Debit
- **Meaning**: 11% markup fee collected on 60-day daily loans.

### MC-CB-010: Weekly 11%
- **Column**: `weekly_11_pct`
- **Side**: Left
- **Event Type**: `FeeCharged`, `MARKUP_11` (weekly products)
- **Account 1000**: Debit
- **Meaning**: 11% markup fee collected on 12-week weekly loans.

### MC-CB-011: Risk Premium / 20% Markup
- **Column**: `risk_premium_returns`
- **Side**: Left
- **Event Type**: `FeeCharged`, `MARKUP_20`
- **Account 1000**: Debit
- **Meaning**: 20% markup/risk premium collected on extended products (24W, 120D, 6M).

### MC-CB-012: Contingency (1%)
- **Column**: `contingency`
- **Side**: Left
- **Event Type**: `FeeCharged`, `CONTINGENCY`
- **Account 1000**: Debit
- **Meaning**: 1% mandatory contingency reserve fee on asset loans.

### MC-CB-013: App Fee / Processing Fee
- **Column**: `app_fee`
- **Side**: Left
- **Event Type**: `FeeCharged`, `PROCESSING_FEE`
- **Account 1000**: Debit
- **Meaning**: Loan application/registration processing fee.

### MC-CB-014: Passbook
- **Column**: `passbook`
- **Side**: Left
- **Event Type**: `FeeCharged`, `PASSBOOK`
- **Account 1000**: Debit
- **Meaning**: Physical client passbook issuance fee.

### MC-CB-015: Asset Credit Sales
- **Column**: `asset_credit_sales`
- **Side**: Left (Balancing)
- **Event Type**: `LoanDisbursed` (Asset category loans)
- **Account 1000**: N/A — non-cash balancing entry (BR-CASH-001)
- **Source**: Derived from originated asset loans
- **Meaning**: Value of goods disbursed on credit. Balances right-side Active Loan disbursements. NO bank cash transfer occurs.

### MC-CB-016: Cash and Carry
- **Column**: `cash_and_carry`
- **Side**: Left
- **Event Type**: `AssetSoldCash`
- **Account 1000**: Debit
- **Meaning**: Direct cash proceeds from outright asset sales.

### MC-CB-017: Credit Form Damage
- **Column**: `credit_form_damage`
- **Side**: Left
- **Event Type**: `FeeCharged`, `PenaltyCharged` (damage)
- **Account 1000**: Debit
- **Meaning**: Penalty for damaged/mutilated credit forms.

### MC-CB-018: Bonus
- **Column**: `bonus`
- **Side**: Left
- **Event Type**: `FeeCharged` (bonus narration)
- **Account 1000**: Debit
- **Meaning**: Incentive/bonus revenue.

### MC-CB-019: Bank Withdrawal
- **Column**: `bank_withdrawal`
- **Side**: Left (Balancing/Inflow)
- **Event Type**: `BankWithdrawn`, Cash Loan Disbursements
- **Account 1000**: Debit
- **Source**: `financial_ledger_entries` or derived from cash loan disbursements
- **Meaning**: Cash drawn from bank into vault, or cashless bank transfers for cash loan disbursements/savings withdrawals/LAPS payouts (BR-CASH-001).

---

## Right Side — Outflows

### MC-CB-020: Weekly Active (12W + 24W)
- **Column**: `weekly_active`
- **Side**: Right
- **Event Type**: `LoanDisbursed` (Weekly cycle)
- **Account 1000**: Credit
- **Source**: `loans` table — loans originated today with `repayment_cycle = 'Weekly'`
- **Meaning**: New weekly loans disbursed by the CO today.

### MC-CB-021: Daily Active (60D + 120D)
- **Column**: `daily_active`
- **Side**: Right
- **Event Type**: `LoanDisbursed` (Daily cycle)
- **Account 1000**: Credit
- **Source**: `loans` table — loans originated today with `repayment_cycle = 'Daily'`
- **Meaning**: New daily loans disbursed by the CO today.

### MC-CB-022: Monthly Active
- **Column**: `monthly_active`
- **Side**: Right
- **Event Type**: `LoanDisbursed` (Monthly cycle)
- **Account 1000**: Credit
- **Meaning**: New monthly loans disbursed today.

### MC-CB-023: Product Withdrawal
- **Column**: `product_withdrawal`
- **Side**: Right
- **Event Type**: `SavingsWithdrawn`, `LoanOffsetFromSavings`, `LapsTransferred`
- **Account 1000**: Credit (when cash paid) or non-cash (internal offset/sweep)
- **Meaning**: Customer savings withdrawals, loan-savings offsets, and LAPS sweeps.

### MC-CB-024: Office Expenses
- **Column**: `office_expenses`
- **Side**: Right
- **Event Type**: `ExpenseRecorded`
- **Account 1000**: Credit (Account 4000 Debit)
- **Meaning**: Daily petty cash and operational expenses.

### MC-CB-025: Bank Deposit
- **Column**: `bank_deposit`
- **Side**: Right
- **Event Type**: `BankDeposited`
- **Account 1000**: Credit
- **Meaning**: Physical cash deposited into company bank account at EOD.

### MC-CB-026: LAPS Returns
- **Column**: `laps_returns`
- **Side**: Right
- **Event Type**: `LapsPaidOut`
- **Account 1000**: Credit (when `cash_paid=True`)
- **Meaning**: LAPS insurance claim payouts to clients.

---

# Master Cashbook Additional Columns (`master_cashbook` table)

These columns exist only at branch level and are NOT in CO cashbooks:

### MC-CB-030: Funds Received (Head Office)
- **Column**: `funds_received_ho`
- **Side**: Left
- **Event Type**: `CashTransferred_HO_In` / `HO_TRANSFER_IN`
- **Meaning**: Vault capital injected from Head Office.

### MC-CB-031: Funds Received (Other Branch)
- **Column**: `funds_received_other_branch`
- **Side**: Left
- **Event Type**: `CashTransferred_HO_In` / `INTER_BRANCH_IN`
- **Meaning**: Inter-branch cash transfer received.

### MC-CB-032: Fund to Asset Program
- **Column**: `fund_to_asset_program`
- **Side**: Right
- **Event Type**: `LoanDisbursed` (Asset category, branch aggregate)
- **Meaning**: Total capital deployed to asset loan programs today.

### MC-CB-033: Fund to Product Finance
- **Column**: `fund_to_product_finance`
- **Side**: Right
- **Event Type**: `LoanDisbursed` (Finance category, branch aggregate)
- **Meaning**: Total cash disbursed for product finance loans today.

### MC-CB-034: Staff Salaries
- **Column**: `staff_salaries`
- **Side**: Right
- **Event Type**: `SalaryPaid` / `SALARY`
- **Meaning**: Branch staff salaries paid from vault.

### MC-CB-035: Fund Transferred (Head Office)
- **Column**: `fund_transferred_ho`
- **Side**: Right
- **Event Type**: `CashTransferred_HO_Out` / `HO_TRANSFER_OUT`
- **Meaning**: Excess vault cash returned to Head Office.

### MC-CB-036: Fund Transferred (Other Branch)
- **Column**: `fund_transferred_other_branch`
- **Side**: Right
- **Event Type**: `CashTransferred_HO_Out` / `INTER_BRANCH_OUT`
- **Meaning**: Cash transferred to another branch.

### MC-CB-037: Adjustment In / Out
- **Columns**: `adjustment_in`, `adjustment_out`, `adjustment_reason`
- **Side**: Left (in) / Right (out)
- **Meaning**: BM manual corrections for previous-day discrepancies.

---

# Balancing Formulas

## CO Cashbook (BR-CASH-004)

$$\text{Total Inflows} = \text{opening\_balance} + \text{savings\_deposit} + \text{laps\_reserve} + \text{rep\_daily} + \text{rep\_12\_weeks} + \text{rep\_24\_weeks} + \text{rep\_monthly} + \text{daily\_11\_pct} + \text{weekly\_11\_pct} + \text{risk\_premium\_returns} + \text{contingency} + \text{app\_fee} + \text{passbook} + \text{asset\_credit\_sales} + \text{cash\_and\_carry} + \text{credit\_form\_damage} + \text{bonus} + \text{bank\_withdrawal}$$

$$\text{Total Outflows} = \text{product\_withdrawal} + \text{weekly\_active} + \text{daily\_active} + \text{monthly\_active} + \text{office\_expenses} + \text{bank\_deposit} + \text{laps\_returns}$$

$$\text{Closing Balance} = \text{Total Inflows} - \text{Total Outflows}$$

## Master Cashbook

$$\text{Total Inflows} = \text{Aggregated CO Inflows} + \text{funds\_received\_ho} + \text{funds\_received\_other\_branch} + \text{adjustment\_in}$$

$$\text{Total Outflows} = \text{product\_withdrawal} + \text{fund\_to\_asset\_program} + \text{fund\_to\_product\_finance} + \text{bank\_deposit} + \text{laps\_returns} + \text{office\_expenses} + \text{staff\_salaries} + \text{fund\_transferred\_ho} + \text{fund\_transferred\_other\_branch} + \text{fund\_to\_other\_area} + \text{adjustment\_out}$$

$$\text{Closing Balance} = \text{Total Inflows} - \text{Total Outflows}$$
