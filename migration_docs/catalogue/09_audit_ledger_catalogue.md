# Parity Catalogue: 09 — Audit Ledger & Audit Center

**Source Implementation**: `app.py` L9833–10747  
**Navigation & Sidebar Source**: `services/rbac_scope_service.py` L34–50 (`ROLE_NAVIGATION`), `app.py` L1925–2000, `auth/authorization.py` L161–166  
**Backend Domain Authority**: 
- `database/repositories/audit_view_repository.py` (`SupabaseAuditViewRepository`)
- `services/audit_enricher_service.py` (`AuditEnricher`)
- `services/audit_reporting_service.py` (`AuditReportingService`)
- `services/financial_reconciliation_service.py` (`FinancialReconciliationService.verify_6way_financial_integrity`, `run_15_exception_reports`, `run_reconciliation_wizard_repair`)
- `services/transaction_explorer_service.py` (`TransactionExplorerService.explore_transaction`, `build_loan_audit_timeline`)
- `services/client_risk_rating_service.py` (`ClientRiskRatingService.get_branch_risk_distribution`)  
**Target Screen**: `frontend_flutter/lib/features/audit/presentation/audit_ledger_screen.dart`  
**API Routes**: 
- `GET /api/v1/audit/meta` — Branch, officer, and product filter dropdown metadata
- `GET /api/v1/audit/integrity-6way` — 6-Way mathematical financial integrity verification
- `GET /api/v1/audit/fees` — Itemized fee audit ledger, KPI metrics, and details
- `GET /api/v1/audit/treasury` — Treasury transactions audit ledger, KPI metrics, and details
- `GET /api/v1/audit/savings` — Savings audit ledger across individual, group, misc, and laps
- `GET /api/v1/audit/loans` — Loan disbursements and repayments audit ledger
- `GET /api/v1/audit/collections` — Collection performance meeting compliance audit
- `GET /api/v1/audit/exceptions` — 15 automated compliance and reconciliation exception reports
- `GET /api/v1/audit/explorer` — 360° universal transaction search across all sub-systems
- `GET /api/v1/audit/explorer/loan-timeline` — Chronological lifecycle timeline for a loan
- `GET /api/v1/audit/performance-insights` — Branch client risk distribution insights
- `POST /api/v1/audit/reconciliation-wizard/repair` — Guided self-healing projection repair
- `GET /api/v1/audit/export-csv` — Direct CSV download endpoint for audit logs

---

## 1. Role-Based Structure & Page Identity
The page dynamically adapts its title, caption, available tabs, and scope filtering based on the authenticated user's role:

### 1.1 Credit Officer (`CO`, `Officer`, `Credit Officer`)
* **Title**: `Credit Officer Audit Ledger` (`st.title("Credit Officer Audit Ledger")`, L9841)
* **Caption**: `Personalized audit trail of your client savings, loans, and collections.` (L9842)
* **3 Accessible Tabs**:
  1. `Savings Ledger`
  2. `Loan Portfolio`
  3. `Collection Performance`
* **Scoping**: Branch selector locked to officer's branch; Officer dropdown locked to current officer UUID/name.

### 1.2 Branch Manager & Area Manager (`BM`, `Branch Manager`, `AM`, `Area Manager`)
* **Title**: `Branch Audit Ledger` (`st.title("Branch Audit Ledger")`, L9846)
* **Caption**: `Read-only branch audit trails, 6-way financial integrity verification, and 360° transaction explorer.` (L9847)
* **7 Accessible Tabs**:
  1. `6-Way Integrity Match`
  2. `Fees Audit`
  3. `Treasury Audit`
  4. `Savings Ledger`
  5. `Loan Portfolio`
  6. `Collection Performance`
  7. `360° Explorer & Timeline`
* **Scoping**: Branch selector locked to assigned branch (BM) or assigned regional branches (AM); Officer dropdown active with all officers in branch.

### 1.3 Administrator & Executive Director (`Admin`, `Super Admin`, `Director`)
* **Title**: `Enterprise Audit & Reconciliation Center` (`st.title("Enterprise Audit & Reconciliation Center")`, L9859)
* **Caption**: `Read-only executive ledgers, 6-way financial integrity verification, 360° universal explorer, and 15 automated exception reports.` (L9860)
* **10 Accessible Tabs**:
  1. `6-Way Integrity Match`
  2. `Fees Audit`
  3. `Treasury Audit`
  4. `Savings Ledger`
  5. `Loan Portfolio`
  6. `Collection Performance`
  7. `Exception Reports`
  8. `360° Explorer & Timeline`
  9. `Performance Insights`
  10. `Reconciliation Wizard`
* **Scoping**: Full institution-wide access; Branch dropdown defaults to `All Branches`.

---

## 2. Tab 1: 6-Way Integrity Match (`app.py` L10057–10082)
* **Subheader**: `Live 6-Way Financial Integrity Verification`
* **Caption**: `Automated mathematical balance verification across General Ledger, Audit Views, Cashbooks, Dashboards, and Reports.`
* **Status Banner**:
  - Balanced: Green banner with verified check icon: `PERFECT MATCH — Financial Integrity Verified`
  - Mismatch: Red banner with alert icon: `Financial Integrity Mismatch Detected`
* **6-Column KPI Metric Cards**:
  1. `1. General Ledger`: `₦{ledger_total:,.2f}` (Cash Account 1000 Debit Net)
  2. `2. Audit Views`: `₦{audit_views_total:,.2f}` (Repayments + Savings Deposits + Fees + Treasury Inflows)
  3. `3. CO Cashbooks`: `₦{co_cashbooks_total:,.2f}` (Sum of total inflows across CO cashbooks)
  4. `4. Master Cashbook`: `₦{master_cashbook_total:,.2f}` (Total inflows on master cashbook)
  5. `5. Dashboard`: `₦{dashboard_total:,.2f}` (Operational cash collection for date)
  6. `6. Reports`: `₦{reports_total:,.2f}` (Reporting engine source for date)
* **Itemized Variance Breakdown Table**:
  - Rendered when `variances` list is not empty.
  - Columns: `source`, `expected`, `actual`, `variance`, `cause`.

---

## 3. Tab 2: Fees Audit (`app.py` L10086–10160)
* **Subheader**: `Fee Audit Ledgers`
* **Caption**: `Itemized audit trail of loan origination fees, passbooks, and processing charges.`
* **Filter Controls (Single-Line Horizontal Row)**:
  - `Date From`: Defaults to 1st day of current month
  - `Date To`: Defaults to current date
  - `Fee Type`: Dropdown `["ALL", "PROCESSING_FEE", "MARKUP_11", "MARKUP_20", "CONTINGENCY", "PASSBOOK", "CREDIT_FORM_DAMAGE", "BONUS"]`
  - `Branch`: Dropdown of active branches
  - `Officer`: Dropdown `["All Officers", ...]`
  - `Search`: Text input (`Client / Ref`)
* **Top 5 KPI Metrics**:
  1. `Total Amount`: `₦{total_amount:,.2f}`
  2. `Transaction Count`: `{total_count}`
  3. `Average Transaction`: `₦{average_amount:,.2f}`
  4. `Last Txn Date`: `{last_transaction_date}`
  5. `Highest Txn`: `₦{highest_amount:,.2f}`
* **Data Table**:
  - Columns: `Date`, `Client Code`, `Client Name`, `Fee Type`, `Amount`, `Officer`, `Branch`, `Reference`, `Status`
* **Expandable Transaction Inspector**:
  - Dropdown selector: `{Client Code} — {Client Name} ({Amount})`
  - 3-column detail card: Posting Date, Fee Bucket, Customer, Financial Amount, Officer, Branch, Reference, Status
  - Checkbox: `Show Advanced Technical Details` (renders formatted JSON payload)
* **Action**: `Export {fee_sub} CSV` button.

---

## 4. Tab 3: Treasury Audit (`app.py` L10164–10237)
* **Subheader**: `Treasury Audit Ledgers`
* **Caption**: `Audit trail of bank deposits, withdrawals, staff salaries, and inter-branch cash transfers.`
* **Filter Controls (Single-Line Horizontal Row)**:
  - `Date From`, `Date To`
  - `Category`: `["ALL", "BANK_DEPOSIT", "BANK_WITHDRAWAL", "OFFICE_EXPENSE", "STAFF_SALARY", "HO_TRANSFER_IN", "HO_TRANSFER_OUT", "BRANCH_TRANSFER_IN", "BRANCH_TRANSFER_OUT", "OTHER_AREA_TRANSFER", "ASSET_PROGRAM", "PRODUCT_FINANCE"]`
  - `Branch`, `Officer`, `Search`
* **Top 5 KPI Metrics**:
  1. `Total Amount`: `₦{total_amount:,.2f}`
  2. `Transaction Count`: `{total_count}`
  3. `Average Transaction`: `₦{average_amount:,.2f}`
  4. `Last Txn Date`: `{last_transaction_date}`
  5. `Highest Txn`: `₦{highest_amount:,.2f}`
* **Data Table**:
  - Columns: `Date`, `Category`, `Amount`, `Officer`, `Branch`, `Reference`, `Narration`, `Status`
* **Expandable Transaction Inspector**:
  - Dropdown selector: `{Category} — {Amount} ({Date})`
  - 3-column detail card: Date, Category, Amount, Reference, Officer, Branch, Narration
  - Checkbox: `Show Advanced Technical Details` (JSON)
* **Action**: `Export {tr_sub} CSV` button.

---

## 5. Tab 4: Savings Ledger (`app.py` L10241–10340)
* **Subheader**: `Savings Audit Ledgers`
* **Caption**: `Audit trail of voluntary individual deposits, group collateral savings, and laps reserves.`
* **Filter Controls (Single-Line Horizontal Row)**:
  - `Date From`, `Date To`
  - `Savings Ledger`: `["ALL", "Individual Savings", "Group Savings", "Misc Savings", "Laps Savings"]`
  - `Branch`, `Officer`, `Search`
* **Top 5 KPI Metrics**:
  1. `Total Deposits`: `₦{tot_dep:,.2f}`
  2. `Total Withdrawals`: `₦{tot_wth:,.2f}`
  3. `Net Savings Movement`: `₦{(tot_dep - tot_wth):,.2f}`
  4. `Transactions`: `{count}`
  5. `Active Accounts`: `{unique_client_codes}`
* **Data Table**:
  - Columns: `Date`, `Ledger`, `Client Code`, `Client Name`, `Remarks`, `Officer`, `Branch`, `Deposit`, `Withdrawal`, `Balance`, `Status`
* **Expandable Transaction Inspector**:
  - Dropdown selector: `{Client Code} — {Client Name} (Dep: {Deposit})`
  - 3-column detail card: Date, Client Code, Client Name, Deposit, Remarks, Withdrawal, Balance
  - Checkbox: `Show Advanced Technical Details` (JSON)
* **Action**: `Export {sav_sub} CSV` button.

---

## 6. Tab 5: Loan Portfolio (`app.py` L10344–10505)
* **Subheader**: `Loan Audit Ledgers`
* **Caption**: `Audit trail of approved principal disbursements and loan repayment collections.`
* **Filter Controls (Single-Line Horizontal Row)**:
  - `Date From`, `Date To`
  - `Loan View`: `["Loan Disbursements", "Repayments"]`
  - `Loan Product`: `["All Products", ...]`
  - `Branch`, `Officer`, `Search`
* **Sub-View A: Loan Disbursements**:
  - **Top 5 KPI Metrics**:
    1. `Total Principal Disbursed`: `₦{tot_p:,.2f}`
    2. `Loans Disbursed`: `{count}`
    3. `Average Principal`: `₦{avg_p:,.2f}`
    4. `Borrowers Count`: `{unique_clients}`
    5. `Active Portfolio`: `₦{tot_p:,.2f}`
  - **Data Table Columns**: `Disbursement Date`, `Loan Number`, `Client Code`, `Client Name`, `Product`, `Officer`, `Branch`, `Principal`, `Status`
  - **Inspector Card**: Loan Number, Disbursement Date, Client, Principal, Product, Status + JSON toggle
  - **Action**: `Export Loan Disbursements CSV`
* **Sub-View B: Repayments**:
  - **Top 4 KPI Metrics**:
    1. `Total Repayments Collected`: `₦{tot_r:,.2f}`
    2. `Repayment Count`: `{count}`
    3. `Average Repayment`: `₦{avg_r:,.2f}`
    4. `Active Paying Clients`: `{unique_clients}`
  - **Data Table Columns**: `Repayment Date`, `Loan Number`, `Client Code`, `Client Name`, `Product`, `Amount Paid`, `Officer`, `Branch`, `Transaction Type`, `Status`
  - **Inspector Card**: Repayment Date, Loan Number, Client Code, Client Name, Product, Amount Paid, Officer, Branch + JSON toggle
  - **Action**: `Export Repayments CSV`

---

## 7. Tab 6: Collection Performance (`app.py` L10509–10624)
* **Subheader**: `Collection Performance Audit`
* **Caption**: `Meeting compliance matrix comparing expected collections against actual payments.`
* **Filter Controls (Single-Line Horizontal Row)**:
  - `Date From`: Defaults to 30 days prior (`date.today() - timedelta(days=30)`)
  - `Date To`: Defaults to current date
  - `Branch`, `Officer`
  - `Compliance Status`: `["ALL", "PAID", "PART_PAYMENT", "NOT_PAID"]`
  - `Search`: Text input (`Client / Code / Group`)
* **Top 5 KPI Metrics**:
  1. `Expected Collections`: `₦{tot_exp:,.2f}`
  2. `Actual Collections`: `₦{tot_act:,.2f}`
  3. `Collection Variance`: `₦{tot_var:,.2f}` (delta `-₦{tot_var:,.2f}` if variance > 0, red delta)
  4. `Meeting Compliance`: `{comp_ratio:.1f}%`
  5. `Meetings Audited`: `{len(records)} ({paid_count} Paid)`
* **Data Table Columns**:
  - `Meeting Date`, `Client Code`, `Client Name`, `Group`, `Expected`, `Paid`, `Compliance %`, `Officer`, `Branch`, `Status`
* **Expandable Meeting Inspector**:
  - Dropdown: `{Meeting Date} — {Client Name} (Paid: {Paid} / Exp: {Expected})`
  - 3-column detail card: Meeting Date, Client Code, Client Name, Group, Expected Amount, Actual Paid, Compliance, Status, Officer
  - Checkbox: `Show Advanced Technical Details` (JSON)
* **Action**: `Export Collection Performance CSV`

---

## 8. Tab 7: Exception Reports (`app.py` L10628–10642)
* **Subheader**: `15 Automated Audit Exception Reports`
* **Caption**: `Scans core database for compliance breaches, unposted transactions, or projection anomalies.`
* **Header Metric**: `Total Exceptions Detected`: `{total_exceptions}` with delta `{exception_rules_evaluated} Rules Evaluated`
* **15 Expandable Rule Cards** (`Rule: {Rule Name} ({count} issues)`):
  - When issues exist: Render full table of anomalous records with zero index.
  - When 0 issues: Green status badge/text: `Zero exceptions detected for this rule.`
* **Rules Inventory**:
  1. Loans Approved without Disbursement
  2. Loans Disbursed without Ledger Posting
  3. Repayments without Loan
  4. Savings Withdrawal without Ledger Entry
  5. Negative Savings Balance
  6. Duplicate Receipt Numbers
  7. Duplicate Transaction References
  8. Orphan Ledger Entries
  9. Unbalanced Journal Entries
  10. Cashbook Differences
  11. Projection Differences
  12. Missing Collection Records
  13. Clients with Overdue Repayments
  14. Loans without Installment Schedule
  15. Inactive Clients with Active Loan

---

## 9. Tab 8: 360° Universal Explorer & Timeline (`app.py` L10646–10716)
* **Subheader**: `360° Universal Search & Audit Timeline`
* **Caption**: `Search by Client Code (e.g. OGI-12-005), Customer Name, Officer, Loan Number, or Reference ID.`
* **Search Input**: Full-width text field with placeholder `e.g. OGI-12-005, Adewale, Ayomide, REF-00382`
* **Result Sub-Sections (Rendered when matching records found)**:
  1. **Loans**: Table + Expander: `View Loan Lifecycle Audit Timelines` (chronological events table per loan)
  2. **Repayments**: Table of matching repayments
  3. **Savings Ledger**: Table of matching savings transactions
  4. **Fee Ledger**: Table of matching fees
  5. **Treasury Ledger**: Table of matching treasury transactions
  6. **General Ledger Journals**: Table of matching journal entries + Expander: `Inspect Journal Double-Entry Legs` (Journal Ref, Account, Leg [DEBIT/CREDIT], Debit, Credit, Line Narration)
  7. **Audit Logs**: Table of matching user audit log entries

---

## 10. Tab 9: Performance Insights (`app.py` L10720–10730)
* **Subheader**: `Executive Performance Insights`
* **Caption**: `System Performance & Portfolio Quality Insights`
* **Content**: Visualized client risk rating distribution breakdown (`EXCELLENT`, `GOOD`, `FAIR`, `RISKY`, `HIGH_RISK`, `total_clients`).

---

## 11. Tab 10: Reconciliation Wizard (`app.py` L10734–10746)
* **Subheader**: `Guided Reconciliation Wizard`
* **Caption**: `Interactive wizard to verify balance, locate discrepancies, and trigger automated projection repair.`
* **Controls**:
  - `Select Reconciliation Date`: Date picker defaulting to current date
  - `Start Guided Projection Repair`: Primary red button
* **Execution Flow**:
  - Triggers `FinancialReconciliationService.run_reconciliation_wizard_repair`
  - Success banner: `Reconciliation repair complete. Rebuilt {rebuilt_officer_count} officer cashbooks & Master Cashbook.`
  - Renders resulting verification status and 6-way integrity match.

---

## 12. Strict Zero-Emoji Compliance Mapping
| Streamlit Element | Streamlit Presentation | Flutter Institutional Presentation |
|---|---|---|
| Balanced Status | `🟢 PERFECT MATCH` | `Icon(Icons.check_circle, color: #16A34A)` + Green Pill Badge |
| Mismatch Status | `🔴 Financial Integrity Mismatch` | `Icon(Icons.error_outline, color: #DC2626)` + Red Pill Badge |
| Paid Status | `🟢 Paid` | Institutional Badge `#DCFCE7` text `#15803D` |
| Part Payment | `🟡 Part Payment` | Institutional Badge `#FEF3C7` text `#B45309` |
| Not Paid | `🔴 Not Paid` | Institutional Badge `#FEE2E2` text `#B91C1C` |
| Wizard Icon | `🧙 Reconciliation Wizard` | `Icon(Icons.auto_fix_high)` |
| Repair Action | `🚀 Start Guided Projection Repair` | Streamlit Primary Red `#FF4B4B` Button with `Icon(Icons.build_outlined)` |
| Debit Leg | `📥 DEBIT` | Institutional Arrow `Icon(Icons.arrow_downward, color: #2563EB)` + Text |
| Credit Leg | `📤 CREDIT` | Institutional Arrow `Icon(Icons.arrow_upward, color: #D97706)` + Text |
