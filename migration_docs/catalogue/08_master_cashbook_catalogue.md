# Parity Catalogue: 08 — Master Cashbook

**Source Implementation**: `app.py` L11187–12191  
**Navigation & Sidebar Source**: `services/rbac_scope_service.py` L34–36 (`ROLE_NAVIGATION["Branch Manager"]`), `app.py` L1925–2000  
**Backend Domain Authority**: 
- `services/master_cashbook_projection_builder.py` (`MasterCashbookProjectionBuilder`)
- `services/financial_reconciliation_service.py` (`FinancialReconciliationService.get_daily_collection_arrears_tally`)
- `services/business_date_service.py` (`BusinessDateService.is_operational_open`, `close_business_date`)
- `services/treasury_service.py` (`TreasuryService.post_treasury_transaction`)
- `services/correction_service.py` (`CorrectionService.approve_correction`, `reject_correction`, `request_correction`)
- `database/repositories/cashbook_repository.py` (`CashbookRepository.rebuild_projection`, `find_by_date_and_branch`, `find_range`)  
**Target Screen**: `frontend_flutter/lib/features/bm/presentation/master_cashbook_screen.dart`  
**API Routes**: 
- `GET /api/v1/bm/cashbook/daily` — Daily T-Account projection, reconciliation tally, pending reversals
- `POST /api/v1/bm/cashbook/daily/manual-entries` — Save manual inputs & post treasury transactions
- `GET /api/v1/bm/cashbook/co-aggregation` — CO cashbook ledger projection for selected officer
- `POST /api/v1/bm/cashbook/eod-close` — Execute EOD day close and advance operational date
- `GET /api/v1/bm/cashbook/monthly` — Monthly tabular ledger with official Excel columns A–AS
- `POST /api/v1/bm/cashbook/reversals/approve` — Approve pending reversal request
- `POST /api/v1/bm/cashbook/reversals/reject` — Reject pending reversal request
- `POST /api/v1/bm/cashbook/reversals/flag-treasury` — Submit new treasury transaction reversal request

---

## 1. Page Title & Tabs
* **Exact Title**: `Branch Manager Master Cashbook` (`st.title("Branch Manager Master Cashbook")`, L11188)
* **Caption**: `INITIATIVE FOR COMMUNITY ADVANCEMENT, RELIEF AND EMPOWERMENT — Credit Cash Book Ledger` (L11189)
* **3 Master Tabs**:
  1. `Daily Cashbook Entry`
  2. `CO Cashbooks Aggregation`
  3. `Monthly Ledger`
* **Zero-Emoji Governance**: No emoji characters permitted. SVG or standard icons used throughout.

---

## 2. Tab 1: Daily Cashbook Entry (`app.py` L11200–11693)

### 2.1 Date Selection & Operational Status
* **Date Picker**: `Select Date`, defaults to branch active business date (`BusinessDateService.get_business_date`).
* **Operational Status Banner**:
  - Closed & Verified (`is_mc_open == False` and reason contains 'closed'):
    - Green banner: `Master Cashbook Closed & Verified: Operations for {date} have been finalized. Closing balance has been rolled forward to next working day.`
  - Suspended / Read-Only (`is_mc_open == False`):
    - Amber/Orange banner: `Operational Activity Suspended ({reason}): Operations for {date} are in Read-Only mode.`
  - Open:
    - Normal editing active.

### 2.2 Branch Collection & Arrears Reconciliation Tally (`render_collection_arrears_tally`, L1080–1126, L11334–11350)
* **Section Title**: `Branch Collection & Arrears Reconciliation Tally ({BRANCH})`
* **Caption**: `Reconciles Field Collections & Overdue Arrears against EOD Bank Deposits`
* **Summary KPI Cards (4 Columns)**:
  1. `Scheduled Inflows`: Bold currency `₦{scheduled_expected:,.2f}`
  2. `Overdue Arrears`: Bold currency `₦{not_paid_amount:,.2f}`, delta subtitle `{not_paid_count} Not Paid` / `0 Arrears` (inverse red if > 0)
  3. `Physical Cash Collected`: Bold currency `₦{actual_cash_collected:,.2f}`, delta subtitle `+₦{excess_amount:,.2f} Excess` (green if excess > 0)
  4. `Bank Deposited`: Bold currency `₦{bank_deposited:,.2f}`
* **Reconciliation State Callout**:
  - Balanced (`|closing| < 0.01`): Green callout `Physical Cash Reconciled: Net Closing Cash Balance is ₦0.00 (Balanced). Uncollected Arrears of ₦{not_paid} recorded in Defaulter Register.`
  - Cash in Vault/Bag (`closing > 0`): Blue callout `Cash in Vault/Bag: ₦{closing} unbanked physical cash remaining. Uncollected Arrears of ₦{not_paid} recorded in Defaulter Register.`
  - Extra Cash Deposited (`closing < 0`): Orange callout `Extra Cash Deposited: Bank deposit exceeds daily collections by ₦{abs(closing)}.`
* **Non-Paying Clients Expander**:
  - Collapsible: `View Non-Paying Clients ({count} Arrears Records)`
  - Table: `Client Name`, `Client Code`, `Expected Installment`, `Shortfall / Arrears`, `Type` (`Partial Payment Shortfall` vs `Marked NOT PAID (₦0)`).

### 2.3 Daily Ledger Table (Auto-Summed from CO Data — Excel T-Account Layout, L11351–11428)
* **Section Title**: `Daily Ledger (Auto-Summed from CO Data)`
* **Dual-Column Balanced T-Account Table**:
  - Left Side: `Inflows (Left)`, `Amount (₦) `
  - Right Side: `Outflows (Right)`, `Amount (₦)  `
* **Exact Inflow Rows**:
  1. Opening Balance
  2. Savings Deposit (Amount)
  3. Credit Repayment (60 days)
  4. Credit Repayment (120 days)
  5. Credit Repayment (12 weeks)
  6. Credit Repayment (24 weeks)
  7. Credit Repayment (Monthly)
  8. Laps Reserve
  9. Funds Received from Head Office
  10. Funds Received from Branch Office
  11. Funds Received from Other Areas
  12. Asset Credit Sales
  13. Cash & Carry
  14. Funds from Finance
  15. Daily 11%
  16. Daily 20%
  17. Weekly 11%
  18. Weekly 20%
  19. Monthly 11%/20%
  20. Contingency (1%)
  21. Credit Form Damage
  22. Bonus
  23. Credit Form / App Fee
  24. Pass Book
  25. Bank Withdrawal
  26. Adjustment In
* **Exact Outflow Rows**:
  1. Active Loan (60 Days)
  2. Active Loan (120 Days)
  3. Active Loan (12 Weeks)
  4. Active Loan (24 Weeks)
  5. Active Loan (Monthly)
  6. Fund Transferred to Branch Office
  7. Fund Transferred to Head Office
  8. Fund Transferred to Other Areas
  9. Fund To Assets
  10. Fund to Finance
  11. Product/Savings Withdrawal
  12. Staff Salaries
  13. Office Expenses
  14. Laps Return
  15. Bank Deposit
  16. Adjustment Out

### 2.4 BM Manual Inputs Form (`app.py` L11429–11583)
* **Section Header**: `BM Manual Inputs`
* **Subsection 1: Inflows (Vault Funding Received)**:
  - `Funds Received from Head Office` (number input, min 0.0, step 1000)
  - `Funds Received from Branch Office` (number input, min 0.0, step 1000)
  - `Funds Received from Other Areas` (number input, min 0.0, step 1000)
* **Subsection 2: Outflows (Corporate Transfers)**:
  - `Fund Transferred to Branch Office` (number input, min 0.0, step 1000)
  - `Fund Transferred to H.O.` (number input, min 0.0, step 1000)
  - `Fund Transferred to Other Areas` (number input, min 0.0, step 1000)
  - `Staff Salaries` (number input, min 0.0, step 1000)
* **Subsection 3: Branch Treasury Adjustments & Debt Management (BIA-BM-CASHBOOK-059)**:
  - Expander: `Branch Treasury Adjustments & Debt Management`
  - Caption: `Record branch-level cash debts, borrowed vault floats, deficit settlements, or direct adjustments without affecting Credit Officer collection metrics.`
  - `Adjustment In (₦)` (number input, min 0.0, step 500)
  - `Adjustment Out (₦)` (number input, min 0.0, step 500)
  - `Adjustment Reason / Debt Narration` (text input, placeholder `e.g., Short-term emergency cash float borrowed from Mr. X`)
* **Daily Summary KPIs**:
  - `Opening Balance`: `₦{opening:,.0f}`
  - `Total Inflows (Left)`: `₦{total_inflows:,.0f}`
  - `Total Outflows (Right)`: `₦{total_outflows:,.0f}`
  - `Closing Balance`: `₦{closing_balance:,.0f}` (Green success card if $\ge 0$, red error card if $< 0$)
* **Submit Action**:
  - Primary button: `Save Master Cashbook Entry`
  - Posts treasury transactions via `TreasuryService.post_treasury_transaction` if values > 0.
  - Rebuilds cashbook projection via `uow.cashbook.rebuild_projection(branch_id, view_date)`.

### 2.5 Branch Error Correction & Reversals Hub (Four-Eyes BR-ERR-001, L11584–11693)
* **Section Header**: `Branch Error Correction & Reversals Hub`
* **Caption**: `Review pending reversal requests from Credit Officers and manage branch-level treasury reversals.`
* **Pending Reversals List**:
  - Queries `correction_requests` where `status == 'Pending'` and `branch_id == BRANCH_ID`.
  - Item card:
    - Type badge: `[Loan Repayment]`, `[Savings Deposit]`, `[EOD Fee]`, `[Office Expense]`, `[Treasury Transfer]`
    - `Ref: #{record_id[:8]}`
    - `Requested by: {user} • Submitted: {date}`
    - `Reason: {reason}`
    - Status pill: `Pending Approval` (amber badge)
    - Action buttons: `Approve` (primary) and `Reject` (secondary).
* **Flag Branch Treasury Entry for Reversal Expander**:
  - Expander: `Flag Branch Treasury Entry for Reversal`
  - Select from recent 25 `treasury_transactions`: format `[{type}] {date} | ₦{amount} — {remarks} | Ref: {id[:8]}`
  - Text input: `Reason for Reversal`
  - Primary button: `Submit Treasury Reversal Request`

---

## 3. Tab 2: CO Cashbooks Aggregation (`app.py` L11694–11899)

### 3.1 Officer & Date Selection
* **Date Picker**: `Select Date`, defaults to active business date.
* **Credit Officer Dropdown**:
  - Dropdown populated with branch Credit Officers (`CO`, `Officer`, `Credit Officer`).
  - Formatted as `Full Name (username)`.

### 3.2 CO Daily Cashbook Ledger (T-Account Layout)
* Rebuilt from `co_cashbooks` for selected officer and date.
* Dual-column layout (Inflows Left / Outflows Right).
* Inflows Left: Opening Balance, Savings Deposit, Credit Rep (Daily, 12W, 24W, Monthly), Laps Reserve, Asset Credit Sales, Cash & Carry, Daily 11%, Weekly 11%, Monthly Markup, Contingency (1%), Credit Form / App Fee, Credit Form Damage, Pass Book, Bonus, Bank Withdrawal.
* Outflows Right: Active Loan (Daily, 12W, 24W, Monthly), Product / Savings Withdrawal, Office Expenses, LAPS Returns / Payouts, Bank Deposit.
* 4 Summary Metrics:
  - `Opening Balance`: `₦{opening:,.0f}`
  - `Total Inflows`: `₦{inflows:,.0f}`
  - `Total Outflows`: `₦{outflows:,.0f}`
  - `Closing`: `₦{closing:,.0f}` (Green if $\ge 0$, Red if $< 0$)

### 3.3 Branch Manager End of Day (EOD) Controls (`app.py` L11871–11899)
* **Section Header**: `Branch Manager End of Day (EOD) Controls`
* **Status Callout**:
  - If already closed: `EOD Day Close Already Executed for {date}. Branch operational date has advanced to next working day.`
  - If cannot close: `Cannot execute Day Close ({reason}).`
  - If open: Callout `Operational Date: {date}. Executing Day Close will freeze all entries for {date} and advance operational business date to the Next Working Day.`
* **Action Button**:
  - Primary button: `Execute EOD Day Close`
  - Calls `BusinessDateService.close_business_date(uow, branch_id, view_date, closed_by=USER)`.

---

## 4. Tab 3: Monthly Ledger (`app.py` L11900–12191)

### 4.1 Filters & Scope
* **Month Selector**: Dropdown (January to December), default current month.
* **Year Input**: Number input (2024–2030), default current year.
* **Branch Selector**:
  - RBAC aware: BM restricted to assigned branch; AM to regional branches; Admin/Director to all operational branches.

### 4.2 Tabular Monthly Ledger
* Displays full daily cashbook progression for all days in selected month.
* Strictly reordered to match official Excel `Credit_Cash_Book_Ledger.xlsx` (Columns A–AS):
  - Inflows (A–AA): Date, Opening Balance, Savings Deposit (Amount), Credit Repayment (60 days, 120 days, 12 weeks, 24 weeks, Monthly), Laps Reserve, Funds Received (Head Office, Branch Office, Other Areas), Asset Credit Sales, Cash & Carry, Funds from Finance, Daily 11%, Daily 20%, Weekly 11%, Weekly 20%, Monthly 11%/20%, Contingency (1%), Credit Form Damage, Bonus, App Fee, Pass Book, Bank Withdrawal, Adjustment In, Total Inflows.
  - Outflows (AC–AS): 60 days, 120 days, 12 weeks, 24 weeks, Monthly, Branch Office, Head Office, Other Areas, Fund To Assets, Fund to Finance, Product/Savings withdrawals, Staff Salaries, Office Expenses, Laps Return, Bank Deposit, Adjustment Out, Total Outflows, Closing Balance.

### 4.3 Monthly Summary KPIs
* 4 Columns:
  1. `Month Opening Balance`: `₦{month_opening:,.0f}`
  2. `Total Monthly Inflows`: `₦{month_inflows:,.0f}` (Sum of daily inflows excluding opening balances)
  3. `Total Monthly Outflows`: `₦{month_outflows:,.0f}` (Sum of daily outflows)
  4. `Month-End Closing Balance`: `₦{month_closing:,.0f}` (Closing balance of final ledger entry)

### 4.4 Export Option
* `Download Ledger as Excel (.xlsx)` / CSV export.

---

## 5. Non-Negotiable Invariants
1. **Ledger Truth (Account 1000)**: All cash positions derive 100% of physical cash movements from Account 1000 journal entries.
2. **Strict Zero-Emoji Governance (Rule 10)**: 0 emoji characters allowed anywhere in the UI.
3. **Zero Live Data Contamination**: Read-only verification during test execution; no test records created in production database.
