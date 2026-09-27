# Phase 4 Authoritative Catalogue: Portfolio Management & 360° Client Dossier

> [!IMPORTANT]
> **GOVERNANCE DIRECTIVE**: This catalogue documents the authoritative visual, behavioural, structural, RBAC, data, and financial requirements for Portfolio Management and Client 360° Dossier derived from `app.py` L12192–13178.

---

## 1. Page Identity & Role Hierarchy

| Attribute | Specification |
|---|---|
| **Exact Titles** | Credit Officer: `CO Portfolio`<br>Branch Manager: `Branch Portfolio`<br>Area Manager: `Regional Portfolio`<br>Director / Admin: `Enterprise Portfolio` |
| **Subtitle** | `Comprehensive portfolio oversight, role-scoped performance analytics, and 360° client dossier.` |
| **Sidebar Label** | `Portfolio` |
| **Streamlit Source** | `app.py` L12192–13178 |
| **Primary Tabs** | 1. `Portfolio Summary & Analytics`<br>2. `Client Dossier & Inquiry` |

---

## 2. Scope & Filter Controls Container (`st.container(border=True)`)

| Control | Type | Options / Behavior |
|---|---|---|
| **Scope Header** | Text / Badge | CO: `Scope: Credit Officer Portfolio ({username}) · Branch: {branch}`<br>Executive: `Executive Read-Only Mode: Strategic view active. Operation and edit actions are disabled.` |
| **Branch Filter** | Dropdown | Shown for AM (`All` + assigned branches) and Admin/Director (`All` + all branches). |
| **Officer Filter** | Dropdown | Shown for BM, AM, and Admin (`All` + active Credit Officers in selected branch). |
| **Time Period** | Dropdown | `Today`, `Yesterday`, `Current Month` (default), `Last Month`, `Custom Date Range`. |
| **Date Range** | Date Picker | Disabled display for standard presets; active editable range picker for `Custom Date Range`. |
| **Loan Product Filter** | Dropdown | `All` + allowed/assigned loan products for the selected scope. |
| **Group Filter** | Dropdown | `All` + cascading list of solidarity groups under the selected scope. |

---

## 3. Tab 1: Portfolio Summary & Analytics

### A. Metric Rows (22 Real-Time Aggregated Metrics)
1. **Row 1: Client Lifecycle Status Breakdown (8 Metrics)**:
   - `Registered` (count)
   - `On Loan` (count)
   - `Completed` (count)
   - `Pending Loans` (count)
   - `Savings Only` (count)
   - `Dormant` (count)
   - `Suspended` (count)
   - `Closed` (count)
2. **Row 2: Savings Summary (Period Flows & Vault Position) (4 Metrics)**:
   - `Savings Deposited (Period)`: `₦{amount}` ({count} Clients)
   - `Savings Withdrawn (Period)`: `₦{amount}` ({count} Clients)
   - `Net Savings (Period)`: `₦{amount}` (Net / Balanced delta)
   - `Total Savings Balance`: `₦{amount}` ({count} Active Savers)
3. **Row 3: Disbursement Summary (2 Metrics)**:
   - `Loans Disbursed`: `{count} Loans` ({client_count} Clients)
   - `Total Amount Disbursed`: `₦{amount}` ({count} Loans Incl. Assets)
4. **Row 4: Loan & Collection Summary (4 Metrics)**:
   - `Total Active Credit`: `₦{amount}` ({count} Active Loans)
   - `Expected Repayment`: `₦{amount}` ({count} Clients)
   - `Actual Collections (Period)`: `₦{amount}` ({count} Clients Paid)
   - `Total Outstanding Balance`: `₦{amount}` ({count} Clients)
5. **Row 5: Repayment Status & Risk (4 Metrics)**:
   - `Full Payments`: `₦{amount}` ({count} Loans Settled)
   - `Excess Payments`: `₦{amount}` ({count} Surplus Payers)
   - `Overdue Portfolio`: `₦{amount}` ({count} Overdue Loans, inverse delta)
   - `Portfolio at Risk (PAR)`: `{par_pct:.2f}%` ({count} Overdue, inverse delta)

### B. Itemized Excess Payments & Payoffs Audit Expander (`BR-DASH-005`, `BR-DASH-007`)
- **Title**: `Itemized Excess Payments & Payoff Audit Ledger (Click to Expand / Collapse)`
- **Caption**: `Authoritative breakdown of surplus cash collections and full loan payoff settlements within the selected period (BR-DASH-005).`
- **Columns**: `Client Name`, `Group Name`, `Amount Paid`, `Expected Installment`, `Excess Amount`, `Active Credit Settled`, `Remaining Balance`, `Payment Date`, `Officer`.
- **Action**: `Export Excess Payments & Payoffs Audit (CSV)` button.

### C. Loan Products & Category Intelligence Cards
- 4 High-visibility cards:
  1. `12-Week Loans`: Active Loans count, Active Credit, Outstanding, Cash vs Asset breakdown.
  2. `24-Week Loans`: Active Loans count, Active Credit, Outstanding, Cash vs Asset breakdown.
  3. `Daily Loans (60D / 120D)`: Active Loans count, Active Credit, Outstanding, Cash count.
  4. `Monthly Loans`: Active Loans count, Active Credit, Outstanding, Cash count.

### D. Group-by-Product Distribution Matrix Expander
- **Columns**: `Group Name`, `Meeting Day`, `12W Cash`, `12W Asset`, `24W Cash`, `24W Asset`, `Daily`, `Monthly`, `Total Active Loans`, `Total Active Credit`, `Total Outstanding Balance`.
- **Bottom Summary Row**: `TOTALS` row summing all counts and balances across the entire scope.

### E. Client & Group Portfolio Details Section
- **Toggle**: Radio buttons between `Detailed Client List` and `Group Aggregate Summary`.
- **Detailed Client List Mode**:
  - Quick Filter by Product: `All Active Loans ({count})`, `12-Week Loans ({count})`, `24-Week Loans ({count})`, `Asset Loans ({count})`, `Daily Loans ({count})`, `Monthly Loans ({count})`, `Excess Payers ({count})`, `All Registered Clients ({count})`.
  - Master Table Columns: `Client Code`, `Client Name`, `Group`, `Loan Product`, `Savings Balance`, `Principal Loan`, `Active Loan`, `Outstanding Balance`, `Total Paid`, `Period Excess Paid`, `Status`, `Lifecycle Status`.
  - Action: `Export Filtered Portfolio (CSV)`.
- **Group Aggregate Summary Mode**:
  - Master Table Columns: `Group Name`, `Total Clients`, `Total Savings Balance`, `Total Active Loan`, `Total Outstanding Balance`, `Total Fixed Repayment`, `Total Paid`.
  - Action: `Export Group Summary (CSV)`.

---

## 4. Tab 2: Client 360° Dossier & Financial Inquiry

### A. Client Selector & Executive Banner
- **Selector**: `Search & Select Client Account:` formatted as `{client_code} — {name} ({group})`.
- **Header Banner**: 4 KPI Cards:
  - `Total Active Credit`: `₦{amount}`
  - `Outstanding Balance`: `₦{amount}`
  - `Savings Balance`: `₦{amount}`
  - `Account Status`: `Active Loan` / `Fully Settled` / `No Active Loans`

### B. 7 Drilldown Subtabs
1. **Customer Profile**:
   - Client bio: Avatar photo / initials badge, Full Name, Client Code, Nickname, Group / Center, Phone, Address, Registration Date.
   - Guarantor details: Avatar photo / initials badge, Guarantor Name, Relationship, Phone Number, verification badge.
2. **Loan History**:
   - Table: `Disbursement Date`, `Product`, `Category`, `Loan Principal`, `Active Credit`, `Expected Installment`, `Remaining Balance`, `Status`.
3. **Repayment Ledger**:
   - Table: `Date`, `Amount Collected`, `Status`, `Transaction Type`, `Notes`.
   - Expander: `Flag a Repayment for Reversal` (`Select Repayment to Reverse`, `Reason for Reversal`, `Submit Reversal Request` button calling `CorrectionService`).
4. **Savings Ledger**:
   - Table with running balance: `Date`, `Deposit (₦)`, `Withdrawal (₦)`, `Net Balance (₦)`, `Remarks`.
5. **Meeting Collection History & Compliance**:
   - 4 KPIs: `Total Expected`, `Total Collected`, `Collection Variance`, `Compliance Rate (%)`.
   - Table: `Meeting Date`, `Expected (₦)`, `Collected (₦)`, `Variance (₦)`, `Officer`, `Compliance Status` badge (`PAID`, `PART PAYMENT`, `NOT PAID`), `Remarks`.
6. **Client Lifecycle Status & Management**:
   - Color-coded current status banner with Last Changed timestamp and Note.
   - Manual Status Change Form: Dropdown (`Registered`, `Inactive (Savings Only)`, `Closed`, `Suspended`, `Dormant`) + required Reason textfield + `Apply Status Change` button.
   - Status Change History table: `Date & Time`, `Previous Status`, `New Status`, `Trigger`, `Reason`, `Changed By`.
7. **Audit Trail**:
   - Audit compliance events table: timestamp, action, user, details.

---

## 5. Non-Negotiable Invariants
1. **Zero Live Data Contamination**: Read-only verification only.
2. **Account 1000 Vault Reconciliation**: Operational tables report status; cash reconciliation derives from Account 1000.
3. **Strict Zero-Emoji Directive**: No emojis anywhere in the UI.
