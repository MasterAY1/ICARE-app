# Phase 5 Authoritative Catalogue: Credit Officer Daily Cashbook & Reconciliation

> [!IMPORTANT]
> **GOVERNANCE DIRECTIVE**: This catalogue documents the authoritative visual, behavioural, structural, RBAC, data, and financial requirements for the Credit Officer Daily Cashbook derived from `app.py` L10748–11186.

---

## 1. Page Identity & Role Scoping

| Attribute | Specification |
|---|---|
| **Title** | `Credit Officer Daily Cashbook` |
| **Subtitle** | `Daily T-Account Ledger — Reconciled against Account 1000 Vault Cash` |
| **Sidebar Label** | `Daily Cashbook` / `CO Cashbook` |
| **Streamlit Source** | `app.py` L10748–11186 |
| **Role Scoping** | **CO**: Scoped strictly to authenticated officer's cashbook.<br>**BM / Admin / AM**: Dynamic dropdown to inspect any officer in the branch. |

---

## 2. Header & Operational Date Controls

| Control | Type | Behavior / Spec |
|---|---|---|
| **Select Date** | Date Picker | Defaults to active operational business date (`BusinessDateService.get_business_date`). |
| **Operational Status Banner** | Alert Banner | If operational day is suspended or closed (`is_operational_open == False`), displays warning: `Operational Activity Suspended ({open_reason}): Operations for {date} are in Read-Only mode.` |
| **Officer Selection** | Badge / Dropdown | **CO**: Info banner `Viewing Cashbook for Officer: {USER} ({BRANCH} Branch)`.<br>**BM / Admin / AM**: `Select Credit Officer` dropdown displaying `{full_name} ({username})`. |

---

## 3. End of Day & Global Outflows & Additional Collections Form

*Collapsible expander container (`st.expander("End of Day / Global Outflows & Additional Collections", expanded=False)`)*

| Field | Type | Description |
|---|---|---|
| **Opening Balance (B/F Cash)** | Number Input | Manual override of opening vault cash balance. |
| **Office Expenses** | Number Input | Branch / field operational expenses for the day. |
| **Bank Deposited** | Number Input | Physical cash deposited into bank account from vault. |
| **Credit Form / App Fee** | Number Input | Processing and credit application fees collected. |
| **Pass Book** | Number Input | Passbook sales / membership fees collected. |
| **Misc Fee** | Number Input | Miscellaneous fee collected (routed to Misc pool). |
| **Cr Form Dmg** | Number Input | Fees charged for damaged credit forms. |
| **Bonus** | Number Input | Bonus income / cash adjustments. |
| **Submit Action** | Button (`Save End of Day Outflows & Fees`) | Calculates delta against current database values, appends domain events (`FeeCharged`/`FeeReversed`, `ExpenseRecorded`/`ExpenseReversed`, `BankDeposited`/`BankDepositReversed`), posts to `financial_ledger_entries` (Account 1000), updates manual opening balance, and cascades projection rebuild. |

---

## 4. Daily Field Collection & Arrears Reconciliation Tally

*Computed via `FinancialReconciliationService.get_daily_collection_arrears_tally`*

| Metric / Section | Specification |
|---|---|
| **Title** | `Daily Field Collection & Arrears Reconciliation Tally ({target_co})` |
| **Expected Collections** | Total scheduled loan repayment installments due on this business date. |
| **Actual Collections** | Physical cash repayments collected and recorded on this date. |
| **Variance / Arrears** | Shortfall or surplus relative to scheduled collection ($Expected - Actual$). |
| **Reconciliation Status** | Balanced / Under-collected / Surplus badge. |

---

## 5. Balanced 2-Column T-Account Ledger Display

*Balanced Double-Entry Table displaying Debit (Inflows) on Left, Credit (Outflows) on Right*

### Inflows (Left / Debit Column — 19 Items)
1. `Opening Balance` (B/F cash from previous day or manual opening)
2. `Savings Deposit` (Period client savings deposits collected)
3. `Credit Rep (Daily)` (Repayments collected on Daily 60-day loans)
4. `Credit Rep (12 Weeks)` (Repayments collected on 12-Week loans)
5. `Credit Rep (24 Weeks)` (Repayments collected on 24-Week loans)
6. `Credit Rep (Monthly)` (Repayments collected on Monthly loans)
7. `Laps Reserve` (LAPS reserve deposits)
8. `Asset Credit Sales` (Asset loan margin/sales collections)
9. `Cash & Carry` (Direct cash sales collections)
10. `Daily 11% Markup` (Markup portion for daily loans)
11. `Weekly 11% Markup` (Markup portion for weekly 12W loans)
12. `Weekly 20% Markup` (Markup portion for weekly 24W loans)
13. `Monthly / 20% Markup` (Markup portion for monthly loans)
14. `Contingency (1%)` (Contingency fund deductions)
15. `Credit Form / App Fee` (Application fees collected)
16. `Credit Form Damage` (Form damage fees collected)
17. `Pass Book` (Passbook fees collected)
18. `Bonus` (Bonus collections)
19. `Bank Withdrawal` (Physical cash drawn from bank into vault)

### Outflows (Right / Credit Column — 8 Items)
1. `Active Loan (Daily)` (New daily loans disbursed today)
2. `Active Loan (12 Weeks)` (New 12-week loans disbursed today)
3. `Active Loan (24 Weeks)` (New 24-week loans disbursed today)
4. `Active Loan (Monthly)` (New monthly loans disbursed today)
5. `Product / Savings Withdrawal` (Savings withdrawals paid out in cash)
6. `Office Expenses` (Daily operational expenses paid in cash)
7. `LAPS Returns / Payouts` (LAPS returns disbursed)
8. `Bank Deposit` (Cash deposited into bank)

### Summary KPI Cards (4 Metrics)
1. **Opening Balance**: `₦{amount}`
2. **Total Inflows**: `₦{total_inflows}`
3. **Total Outflows**: `₦{total_outflows}`
4. **Closing Balance**: `₦{closing_balance}` (Green container if >= 0, Red container if < 0)

---

## 6. Cashbook Error Correction & Reversal Hub (`BR-ERR-001`)

*Under Four-Eyes Rule BR-ERR-001: Corrections require formal approval before ledger reversal*

| Component | Specification |
|---|---|
| **Container** | `st.expander("Flag an EOD Fee / Expense / Deposit for Reversal", expanded=False)` |
| **Transaction Selector** | Dropdown of recent EOD transactions (`FeeCharged`, `ExpenseRecorded`, `BankDeposited`, `BankWithdrawn`) within scope, excluding already flagged/pending/approved records. Formatted as `{Amount} | {Type} | {Narration} (#{EventID})`. |
| **Reason Input** | Text input: `Reason for Reversal` (e.g., "Typo in office expense. Typed 50000 instead of 5000."). |
| **Submit Button** | `Submit Reversal Request to BM` (invokes `CorrectionService.request_correction`). |
| **Submitted Requests Table** | Table with columns: `Date`, `Type`, `Record Ref`, `Reason`, `Status` badge, `Approved By`. |

---

## 7. Authoritative Non-Negotiable Invariants

1. **Account 1000 Physical Vault Cash Invariant**: Every cash entry maps directly to Account 1000 double-entry postings.
2. **Double-Entry Balance Formula**: Closing = Total Inflows - Total Outflows.
3. **Immutability Invariant (FP-002)**: Historical transactions cannot be deleted or updated in place; adjustments require compensating ledger entries.
4. **Strict Zero-Emoji Governance (GEMINI Rule 10)**: Emojis are 100% prohibited. Clean corporate badges and SVG/Material icons only.
5. **Zero Live Data Contamination**: All verification tests must execute purely read-only queries against live database.
