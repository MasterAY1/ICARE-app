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

## BR-DASH-005: Repayment Status Categorization (Full Payments, Excess Payments, Overdue)
- **Rule ID:** BR-DASH-005
- **Name:** Repayment Status Categorization (Full Payments, Excess Payments, Overdue)
- **Description:** Categorization of repayment performance on the Portfolio and Dashboard views:
  1. `Full Payments`: Represents exclusively loans that have **completely reached full payoff (zero balance) in the selected period** (or `status in ['Completed', 'Closed']` with collections received in the period).
     - **Count**: Number of loans fully settled in the period.
     - **Amount**: Active credit value of the completed loans (or total payoff principal).
  2. `Excess Payments`: Borrowers who paid strictly more than their scheduled expected installment for the period (`paid_in_period > expected_in_period` and not a full payoff).
     - **Count**: Number of excess-paying clients in the period.
     - **Amount**: Sum of unbudgeted surplus cash (`paid_in_period - expected_in_period`).
  3. `Overdue Portfolio`: Loans past their expected maturity/due date with outstanding balance > ₦0.
     - **Count**: Number of overdue loans.
     - **Amount**: Sum of delinquent outstanding principal.
  4. `Portfolio at Risk (PAR%)`: (Total Overdue / Total Active Credit) × 100.
- **Required Behavior:**
  - `Full Payments` must accurately report the count and monetary volume of loans settled during the period.
  - `Excess Payments` must report only unbudgeted surplus above scheduled installments.
  - Base scheduled operational repayments are derived as $\text{Actual Collection} - \text{Excess Payments}$.
- **Prohibited Behavior:**
  - Marking regular weekly/monthly installments as excess payments.
  - Hiding or zeroing full payoff completions that occurred within the selected date range.
- **Status:** CONFIRMED & MANDATORY
- **Implementation Location:** `services/portfolio_service.py`, `services/dashboard_service.py`

## BR-DASH-006: Historical Onboarding Repayments Exclusion from Period Metrics
- **Rule ID:** BR-DASH-006
- **Name:** Historical Onboarding Exclusion from Period Operations
- **Description:** Historical opening repayments imported during migration establish opening balances and MUST NOT be counted as collections of the current operational period.
- **Required Behavior:**
  - Onboarded historical repayments must have a historical/pre-go-live date or be flagged (`note = 'Legacy Repayments Onboarded'`).
  - Period collection metrics (`today_collection`, `this_week_collection`, `excess_payments`) must filter out historical onboarding opening balances.
  - Lifetime metrics (`total_outstanding_balance`, `total_paid_lifetime`) include all historical payments to compute accurate current outstanding balances.
- **Prohibited Behavior:**
  - Counting historical legacy payments as live collections of today.
  - Classifying onboarding opening balance reductions as "Excess Payments".
- **Status:** CONFIRMED
- **Implementation Location:** `services/portfolio_service.py`, `services/dashboard_service.py`, `migrate_onboarding_template.py`

## BR-DASH-007: Period Collection and Multi-Filter Cohesion Invariant
- **Rule ID:** BR-DASH-007
- **Name:** Period Collection and Multi-Filter Cohesion Invariant
- **Description:** For any selected date range $[\text{start\_date}, \text{end\_date}]$ and dropdown filter combination (Branch, Officer, Group, Product):
  $$\text{Expected Repayment (Period)} = \sum (\text{loan.loan\_repay} \times \text{scheduled\_meeting\_occurrences\_in\_period})$$
  $$\text{Actual Collection (Period)} = \sum (\text{repayments.amount\_paid\_in\_period})$$
  $$\text{Excess Payments} = \sum \max(0.0, \text{paid\_in\_period} - \text{expected\_in\_period})$$
- **Required Behavior:**
  1. `Expected Repayment (Period)` scales dynamically by the number of meeting occurrences within the selected date range for loans matching active filters.
  2. `Actual Collection (Period)` reflects total cash repayments received in the period matching active filters.
  3. `Excess Payments` only flags surplus cash above the full period expectation.
  4. All metrics across Row 1, Row 2, Row 3, Row 4, Row 5, and the Client/Group table must respond symmetrically and cohesively when any filter (Branch, Officer, Group, Product, Date Range) changes.
- **Status:** CONFIRMED & MANDATORY
- **Implementation Location:** `services/portfolio_service.py`, `app.py`

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
