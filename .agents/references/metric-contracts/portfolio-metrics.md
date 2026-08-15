# Portfolio & Savings Metric Contracts

> Every portfolio metric and savings balance displayed in the system MUST have a contract entry here.

---

## MC-PORT-001: Total Active Credit

- **Business Meaning**: Aggregate static contract credit value of all currently open loans.
- **Authoritative Source**: `loans.active_credit`
- **Included**: `status IN ('Active', 'Approved')`
- **Excluded**: Closed, Rejected, Written-Off loans.
- **Calculation**: `SUM(loans.active_credit)`
- **Filters**: Scoped by `branch_id`, `officer_id`, `product_id`, `group_id`.
- **Display Format**: `₦{value:,.0f}`
- **Known Consumers**: Portfolio Page, BM Dashboard, Director Dashboard, PAR calculation denominator.

> **Critical Distinction**: `active_credit` is a **static** contract value set at origination. It does NOT decrease with repayments. Use `outstanding_balance` for the dynamic remaining amount.

---

## MC-PORT-002: Total Outstanding Balance

- **Business Meaning**: Net remaining unpaid principal owed across the active portfolio.
- **Authoritative Source**: `loans.active_credit` minus `repayments.amount_paid` (lifetime).
- **Included**: Active loans. Lifetime repayments **include** historical onboarding records (BR-DASH-006).
- **Calculation**: `SUM(MAX(0.0, active_credit - total_paid_lifetime))`
- **Display Format**: `₦{value:,.0f}`
- **Known Consumers**: Portfolio Page, BM Dashboard, AM Dashboard, Director Dashboard.

> **Critical Distinction**: This is different from `active_credit`. Outstanding Balance **decreases** with every repayment.

---

## MC-PORT-003: Total Expected Repayment

- **Business Meaning**: Sum of scheduled periodic installment amounts due across active loans.
- **Authoritative Source**: `loans.loan_repay` or `loan_schedule.total_due`
- **Calculation**: `SUM(loans.loan_repay)` for all active loans, or `SUM(loan_schedule.total_due)` for a specific date.
- **Known Consumers**: Portfolio Page, CO Dashboard (meeting portfolio grid).

---

## MC-PORT-004: Actual Collection (Period)

- **Business Meaning**: Repayments received during a specific date range.
- **Authoritative Source**: `repayments.amount_paid`
- **Included**: Transactions within `[start_date, end_date]`.
- **Excluded**: `transaction_type = 'ONBOARDING_LEGACY'` (BR-DASH-006).
- **Calculation**: `SUM(amount_paid) WHERE date BETWEEN start_date AND end_date AND NOT onboarding`
- **Known Consumers**: Portfolio Page, Daily Report.

---

## MC-PORT-005: Disbursement Summary

- **Business Meaning**: Volume and total principal disbursed during a selected period.
- **Authoritative Source**: `loans.loan_amount`, `loans.start_date`
- **Included**: `status IN ('Active', 'Approved', 'Completed', 'Closed')`
- **Calculation**:
  - `count`: `COUNT(loans) WHERE start_date IN [start, end]`
  - `amount`: `SUM(loan_amount) WHERE start_date IN [start, end]`
- **Known Consumers**: Portfolio Page, Admin Dashboard.

---

## MC-PORT-006: Group Total Savings (BR-SAV-003)

- **Business Meaning**: Combined savings balance for a group including individual member savings AND communal group savings.
- **Authoritative Source**: `individual_savings` + `group_savings`
- **Calculation**: `SUM(individual savings of all group members) + group communal savings balance`
- **Known Consumers**: Portfolio Page (Group Portfolio Summary table).

---

## MC-PORT-007: Loan Valuation Parameters

These are **per-loan** values, not aggregated metrics:

| Field | Column | Meaning | Static/Dynamic |
|:---|:---|:---|:---|
| **Loan Amount** | `loans.loan_amount` | Gross principal disbursed | Static |
| **Gap Fee** | `loans.extra_fields->gap_fee` | Upfront deduction retained at disbursement | Static |
| **Active Credit** | `loans.active_credit` | Net contractual credit = `loan_amount - gap_fee` | Static |
| **Fixed Repayment** | `loans.loan_repay` | Scheduled periodic installment | Static |
| **Total Due** | `loans.total_due` | Total payable including interest/markup | Static |
| **Total Paid** | Computed | `SUM(repayments.amount_paid)` for loan | Dynamic |
| **Outstanding Balance** | Computed | `MAX(0, active_credit - total_paid)` | Dynamic |
| **Remaining Balance** | Computed | `MAX(0, total_due - total_paid)` (onboarded loans) | Dynamic |

> **NEVER** treat `loan_amount`, `active_credit`, `total_due`, and `outstanding_balance` as interchangeable. Each has a distinct business meaning.

---

## MC-PORT-008: Product Pricing

### 11% Markup Products (60D Daily, 12W Weekly, 3M Monthly)
- Total Interest Rate = **12%** (11% Markup + 1% Contingency)
- Interest = `Amount × 0.12`
- Contingency = `Interest × (1/12)`
- Markup = `Interest - Contingency`

### 20% Markup Products (120D Daily, 24W Weekly, 6M Monthly)
- Total Interest Rate = **21%** (20% Markup + 1% Contingency)
- Interest = `Amount × 0.21`
- Contingency = `Interest × (1/21)`
- Markup = `Interest - Contingency`

---

# Savings Metric Contracts

---

## MC-SAV-001: Individual Savings Balance

- **Business Meaning**: Client-level personal savings balance.
- **Authoritative Source**: `individual_savings` table.
- **Calculation**: `SUM(deposit_amount) - SUM(withdrawal_amount) WHERE client_id = target`
- **Known Consumers**: Collection Page, Portfolio Page, Client 360, Withdrawal Operations.

---

## MC-SAV-002: Group Savings Balance

- **Business Meaning**: Communal group savings pool balance.
- **Authoritative Source**: `group_savings` table.
- **Calculation**: `SUM(deposit_amount) - SUM(withdrawal_amount) WHERE group_id = target`
- **Known Consumers**: Collection Page (group header), Portfolio Page.

---

## MC-SAV-003: Misc Savings Balance (Internal Savings)

- **Business Meaning**: Branch-level pooled internal savings fund.
- **Authoritative Source**: `internal_savings` table.
- **Calculation**: `SUM(deposit_amount) - SUM(withdrawal_amount) WHERE branch_id = target`
- **Officer Attribution (BR-SAV-002)**: Managed by designated CO per branch. Included in that officer's portfolio total. Excluded from other officers. Included in branch-level totals.
- **Known Consumers**: Portfolio Page, Withdrawal Operations.

---

## MC-SAV-004: Total Active Savings (BR-SAV-001)

- **Business Meaning**: Aggregate savings balance across all categories EXCEPT LAPS.
- **Calculation**: `Individual Savings + Group Savings + Misc Savings`
- **Excluded**: LAPS Savings (risk reserve, not active savings).
- **Known Consumers**: BM Dashboard, AM Dashboard, Director Dashboard, Portfolio Page.

---

## MC-SAV-005: LAPS Savings Balance

- **Business Meaning**: Loan Additional Protection Scheme reserve balance.
- **Authoritative Source**: `laps_savings` table.
- **Calculation**: `SUM(deposit_amount) - SUM(withdrawal_amount)`
- **Excluded from**: Total Active Savings (BR-SAV-001).
- **Known Consumers**: Withdrawal Operations, Branch Totals.
