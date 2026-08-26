# Dashboard Metric Contracts

> Every metric displayed on a dashboard MUST have a contract entry here.
> If a metric does not appear below, it is undocumented and must be added before it can be modified.

---

## MC-DASH-001: Today's Collections

- **Business Meaning**: Physical cash loan repayments received during the selected business date.
- **Authoritative Source**: `repayments.amount_paid`
- **Included**: All repayment transactions where `date = target_date`.
- **Excluded**: `transaction_type = 'ONBOARDING_LEGACY'` and `note = 'Legacy Repayments Onboarded'` (BR-DASH-006).
- **Date Definition**: Operational business date (defaults to `date.today()`).
- **Branch Filter**: `branch_id` (BM scope), all branches (Director/Admin scope).
- **Officer Filter**: `officer_id` (CO scope), all officers (BM scope).
- **Calculation**: `SUM(repayments.amount_paid) WHERE date = target_date AND NOT onboarding_legacy`
- **Display Format**: `₦{value:,.0f}`
- **Known Consumers**: CO Dashboard, BM Dashboard, AM Dashboard, Admin Dashboard, Director Dashboard, Daily Report.

---

## MC-DASH-002: MTD Collections

- **Business Meaning**: Cumulative loan repayments received from the first of the current month through the target date.
- **Authoritative Source**: `repayments.amount_paid`
- **Included**: All repayment transactions where `date >= month_start AND date <= target_date`.
- **Excluded**: Onboarding legacy records (BR-DASH-006).
- **Date Definition**: `month_start` = first calendar day of target month.
- **Calculation**: `SUM(repayments.amount_paid) WHERE date >= month_start AND date <= target_date AND NOT onboarding_legacy`
- **Display Format**: `₦{value:,.0f}`
- **Known Consumers**: Director Dashboard.

---

## MC-DASH-003: Outstanding Portfolio

- **Business Meaning**: Net remaining unpaid principal owed to the institution across all active loans.
- **Authoritative Source**: `loans.active_credit` minus `repayments.amount_paid` (lifetime).
- **Included**: All loans with `status IN ('Active', 'Approved')`. Includes historical onboarding repayments in lifetime paid calculation.
- **Excluded**: Closed, Rejected, Written-Off loans.
- **Calculation**: `SUM(MAX(0.0, loans.active_credit - lifetime_repayments_for_loan))`
- **Display Format**: `₦{value:,.0f}`
- **Known Consumers**: BM Dashboard, AM Dashboard, Director Dashboard, Portfolio Page.

---

## MC-DASH-004: Total Active Savings

- **Business Meaning**: Aggregate savings balance across individual, group, and misc (internal) savings categories.
- **Authoritative Source**: `individual_savings`, `group_savings`, `internal_savings`.
- **Included**: All active client/group savings. Misc savings included at branch level and for designated officer only at CO level (BR-SAV-002).
- **Excluded**: LAPS savings (BR-SAV-001).
- **Calculation**: `(SUM(individual_savings.deposit_amount) - SUM(individual_savings.withdrawal_amount)) + (SUM(group_savings.deposit_amount) - SUM(group_savings.withdrawal_amount)) + (SUM(internal_savings.deposit_amount) - SUM(internal_savings.withdrawal_amount))`
- **Display Format**: `₦{value:,.0f}`
- **Known Consumers**: BM Dashboard, AM Dashboard, Director Dashboard, Portfolio Page.

---

## MC-DASH-005: Portfolio at Risk (PAR%)

- **Business Meaning**: Proportion of active portfolio value that is delinquent/overdue.
- **Authoritative Source**: `loan_schedule` (overdue installments) and `loans.active_credit`.
- **Included**: Active loans only (`status = 'Active'`). Overdue = schedule installments where `due_date < today` and `paid_amount < total_due`.
- **Calculation**: `(SUM(overdue_unpaid_installments) / SUM(active_credit)) × 100` (BR-DASH-004).
- **Display Format**: `{value:.1f}%`
- **Known Consumers**: BM Dashboard, AM Dashboard, Director Dashboard, Portfolio Page, Reports.

---

## MC-DASH-006: Recovery Rate

- **Business Meaning**: Institutional portfolio recovery percentage.
- **Authoritative Source**: Derived from PAR%.
- **Calculation**: `100.0% - PAR%`
- **Display Format**: `{value:.1f}%`
- **Known Consumers**: Director Dashboard.

---

## MC-DASH-007: Active Clients

- **Business Meaning**: Count of distinct clients with at least one active/approved loan.
- **Authoritative Source**: `loans` table.
- **Calculation**: `COUNT(DISTINCT client_id) WHERE status IN ('Active', 'Approved')`
- **Filters**: Scoped by `branch_id` (BM), `assigned_branches` (AM), all (Director/Admin).
- **Display Format**: Integer count.
- **Known Consumers**: BM Dashboard, AM Dashboard.

---

## MC-DASH-008: Repayment Status & Risk Breakdown (BR-DASH-005, BR-DASH-007)
- **Invariant**: `Excess Payments = SUM(MAX(0.0, paid_in_period - expected_in_period))`
- Scheduled base operational payments equal `Actual Collection (Period) - Excess Payments`.

Three core categories evaluated per loan in an operational period:

### Full Payments (Closed / Settled)
- **Calculation**: Complete loan payoff achieved with repayments posted in the selected period.
- **Count**: Number of loans fully settled in the period.
- **Amount**: Active credit value of completed loans in the period.

### Excess Payments
- **Calculation**: Borrowers who paid strictly more than their scheduled expected installment for the period (`paid_in_period > expected_in_period` and not a full payoff).
- **Count**: Number of excess-paying clients in the period.
- **Amount**: Strictly the surplus cash portion = `paid_in_period - expected_in_period`.

### Overdue Portfolio
- **Calculation**: Loans past expected maturity date with remaining balance > ₦0.
- **Count**: Number of overdue delinquent loans.
- **Amount**: Sum of overdue unpaid balance.

- **Known Consumers**: Portfolio Page (Row 5), CO Dashboard, BM Dashboard, Admin Dashboard.

---

## MC-DASH-009: Cash Position (CO Cashbook Summary)

- **Business Meaning**: Daily vault/bag cash position for a specific Credit Officer.
- **Authoritative Source**: `co_cashbooks` projection.
- **Calculation**:
  - `Opening Balance` = previous day closing balance.
  - `Cash In` = `total_inflows` from projection.
  - `Cash Out` = `total_outflows` from projection.
  - `Closing Balance` = `Opening + Inflows - Outflows`.
- **Known Consumers**: CO Dashboard, BM Dashboard (officer grid).

---

## MC-DASH-010: Cash Position (Master Cashbook Summary)

- **Business Meaning**: Daily branch vault cash position.
- **Authoritative Source**: `master_cashbook` projection.
- **Calculation**:
  - `Opening Balance` = previous day closing balance.
  - `Total Inflows` = aggregated CO inflows + treasury inflows.
  - `Total Outflows` = aggregated CO outflows + treasury outflows.
  - `Closing Balance` = `Opening + Inflows - Outflows`.
- **Known Consumers**: BM Dashboard, Audit Center (6-way reconciliation).

---

## MC-DASH-011: Today's Savings Deposits

- **Business Meaning**: Cash savings collected from clients today.
- **Authoritative Source**: `individual_savings.deposit_amount` (greenfield) or `repayments.savings_amount` (legacy).
- **Calculation**: `SUM(deposit_amount) WHERE posting_date = target_date`
- **Known Consumers**: CO Dashboard, Admin Dashboard, Daily Report.

---

## MC-DASH-012: Today's Loan Disbursements

- **Business Meaning**: Total principal disbursed today.
- **Authoritative Source**: `loans.loan_amount`
- **Calculation**: `SUM(loan_amount) WHERE start_date = target_date`
- **Known Consumers**: Admin Dashboard.
