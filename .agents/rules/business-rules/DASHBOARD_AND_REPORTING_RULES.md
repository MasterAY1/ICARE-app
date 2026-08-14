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

## BR-DASH-005: Repayment Status Categorization
- **Rule ID:** BR-DASH-005
- **Name:** Repayment Status Categorization (Normal, Excess, Part, Full/Closed, Overdue)
- **Description:** Categorization of client repayment performance in a period:
  1. `Full Payments (Closed)`: Total lifetime repayments equal or exceed active credit (`total_paid_lifetime >= active_credit`).
  2. `Normal Paid`: Actual collection in the period equals the scheduled installment (`paid_in_period == loan_repay`).
  3. `Excess Paid`: Actual collection in the period exceeds the scheduled installment (`paid_in_period > loan_repay`).
  4. `Part Paid`: Actual collection in the period is positive but less than scheduled installment (`0 < paid_in_period < loan_repay`).
  5. `Overdue`: Loan is past its maturity/end date with remaining outstanding balance > 0 and no payment in current cycle.
- **Required Behavior:**
  - Status categorization in a period must compare payments made **in that period** against the scheduled periodic installment (`loan_repay`).
- **Prohibited Behavior:**
  - Comparing lifetime cumulative payments to a single period's installment when categorizing period payment status.
- **Status:** CONFIRMED
- **Implementation Location:** `services/portfolio_service.py`, `services/dashboard_service.py`

## BR-DASH-006: Historical Onboarding Repayments Exclusion from Period Metrics
- **Rule ID:** BR-DASH-006
- **Name:** Historical Onboarding Exclusion from Period Operations
- **Description:** Historical opening repayments imported during migration establish opening balances and MUST NOT be counted as collections of the current operational period.
- **Required Behavior:**
  - Onboarded historical repayments must have a historical/pre-go-live date or be flagged (`note = 'Legacy Repayments Onboarded'`).
  - Period collection metrics (`today_collection`, `this_week_collection`, `normal_payments`, `excess_payments`, `part_payments`) must filter out historical onboarding opening balances.
  - Lifetime metrics (`total_outstanding_balance`, `total_paid_lifetime`) include all historical payments to compute accurate current outstanding balances.
- **Prohibited Behavior:**
  - Counting historical legacy payments as live collections of today.
  - Classifying onboarding opening balance reductions as "Excess Payments".
- **Status:** CONFIRMED
- **Implementation Location:** `services/portfolio_service.py`, `services/dashboard_service.py`, `migrate_onboarding_template.py`

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
