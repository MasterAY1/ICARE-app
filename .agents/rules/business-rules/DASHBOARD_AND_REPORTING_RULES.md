# Dashboard and Reporting Invariant Rules

## BR-DASH-001: Metric Source Authority
- **Rule ID:** BR-DASH-001
- **Name:** Every Metric Must Have an Identified Authoritative Source
- **Description:** No dashboard metric may exist without an explicit, documented data source.
- **Required Behavior:** For every financial metric displayed, document: source table, source function, formula, business date filter, and expected ICARE meaning.
- **Prohibited Behavior:** Undocumented, ad-hoc metrics.
- **Status:** CONFIRMED

## BR-DASH-002: Metric Definition Consistency
- **Rule ID:** BR-DASH-002
- **Name:** Same Metric Must Mean the Same Thing Everywhere
- **Description:** If "Collection Today" appears on both the CO and BM dashboards, it must use the same definition, source, and formula.
- **Required Behavior:** Unified metric definitions across all dashboard views.
- **Prohibited Behavior:** CO Dashboard computing "Collection Today" from `repayments.amount_paid` while BM Dashboard computes it from `loan_schedule.paid_amount`.
- **Status:** CONFIRMED

## BR-DASH-003: No Hardcoded Financial Values
- **Rule ID:** BR-DASH-003
- **Name:** No Hardcoded Financial Values
- **Description:** Dashboard metrics must be calculated from actual data.
- **Required Behavior:** All metrics computed from database queries.
- **Prohibited Behavior:** Hardcoded values like `today_collections: 3500000.0` or `par: "0.0%"`.
- **Status:** CONFIRMED

## BR-DASH-004: PAR Calculation
- **Rule ID:** BR-DASH-004
- **Name:** Portfolio at Risk Must Use Actual Data
- **Description:** PAR% = (Total Overdue / Total Active Credit) × 100.
- **Required Behavior:** Calculate from actual loan portfolio data.
- **Prohibited Behavior:** Hardcoding PAR as "0.0%" or any static value.
- **Status:** CONFIRMED

## Business Impact Map

Every operation affects multiple downstream components. Before modifying any operation, consult this map:

| Operation | Event | Ledger (Acct 1000) | CO Cashbook | Master Cashbook | Dashboard Metrics | Schedule |
|:---|:---|:---|:---|:---|:---|:---|
| Loan Disbursement | LoanDisbursed | Credit (Outflow) | — | fund_to_asset/finance | Active Loans, Disbursements | Creates schedule |
| Loan Repayment | RepaymentReceived | Debit (Inflow) | rep_daily/12w/24w/monthly | via CO aggregation | Collections, Outstanding | Reduces outstanding |
| Savings Deposit | SavingsDeposited | Debit (Inflow) | savings_deposit | via CO aggregation | Savings Balance | — |
| Savings Withdrawal | SavingsWithdrawn | Credit (Outflow) | savings_withdrawal | via CO aggregation | Savings Balance | — |
| Fee Collection | FeeCharged | Debit (Inflow) | passbook/app_fee/etc | via CO aggregation | Fees Collected | — |
| Bank Withdrawal | BankWithdrawn | Debit (Inflow) | bank_withdrawal | via CO aggregation | Cash Position | — |
| Bank Deposit | BankDeposited | Credit (Outflow) | bank_deposit | via CO aggregation | Cash Position | — |
| HO Transfer In | CashTransferred_HO_In | Debit (Inflow) | — | funds_received_ho | Cash Position | — |
| HO Transfer Out | CashTransferred_HO_Out | Credit (Outflow) | — | fund_transferred_ho | Cash Position | — |
| Expense | ExpenseRecorded | Credit (Outflow) | — | office_expenses | Expenses | — |
| Salary | SalaryPaid | Credit (Outflow) | — | staff_salaries | Expenses | — |
| LAPS Payout (Cash) | LapsPaidOut | Credit (Outflow) | laps_returns | via CO aggregation | LAPS Balance | — |
| LAPS Payout (Bank) | LapsPaidOut | — (1050) | — | — | LAPS Balance | — |
| LAPS Transfer | LapsTransferred | — | product_withdrawal only | — | LAPS Balance | — |
| Loan Offset | LoanOffsetFromSavings | — | product_withdrawal only | — | Savings, Outstanding | Reduces outstanding |
