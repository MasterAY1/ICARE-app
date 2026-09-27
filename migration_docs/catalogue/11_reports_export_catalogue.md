# Parity Catalogue: 11 — Reports & Export

**Source Implementation**: `app.py` L13222–13861  
**Navigation & Sidebar Source**: `services/rbac_scope_service.py` L34–45 (`ROLE_NAVIGATION`), `app.py` L1925–2000  
**Backend Domain Authority**:
- `services/report_service.py` (`ReportService`)
  - `get_trial_balance`
  - `get_savings_summary`
  - `get_repayment_summary`
  - `get_area_branch_comparison`
- `services/client_risk_rating_service.py` (`ClientRiskRatingService.get_branch_risk_distribution`)
- `utils/reports.py`:
  - `generate_portfolio_summary`
  - `generate_officer_report`
  - `export_dataframe_to_excel_bytes`
  - `export_consolidated_report_to_excel`
- `services/rbac_scope_service.py` (`RBACScopeService.resolve_scope`)  
**Target Screen**: `frontend_flutter/lib/features/reports/presentation/reports_export_screen.dart`  
**API Routes Prefix**: `/api/v1/reports`  
- `GET /api/v1/reports/meta` — Dynamic filter options (branches, products, officers) scoped to user role
- `GET /api/v1/reports/trial-balance` — Double-entry Trial Balance with ledger integrity status
- `GET /api/v1/reports/savings-summary` — Savings Portfolio & Savers Breakdown with itemized list
- `GET /api/v1/reports/repayment-summary` — Collections performance, payoffs, excess payments, and product breakdowns
- `GET /api/v1/reports/portfolio-performance` — Portfolio health, officer performance breakdown, and credit risk rating
- `GET /api/v1/reports/area-comparison` — Area Manager regional comparative performance matrix (AM only)
- `GET /api/v1/reports/export/excel` — Multi-tab consolidated Excel workbook generation
- `GET /api/v1/reports/export/csv` — CSV exports for individual report tables

---

## 1. Page Title & Role-Adaptive Identity Banner

### 1.1 Branch Manager (`is_bm`)
* **Title**: `Branch Operational Reports — {BRANCH} Branch` (`app.py` L13271)
* **Subtitle**: `Single-branch double-entry trial balance, officer supervision, savings portfolio, and collections.` (`app.py` L13272)
* **Scope Level Badge**: `Single Branch ({BRANCH})` (`#EFF6FF` container, `#3B82F6` border, `#1E3A8A` text)

### 1.2 Area Manager (`is_am`)
* **Title**: `Area Manager Regional Executive Reports` (`app.py` L13284)
* **Subtitle**: `Multi-branch regional supervision, cross-branch comparative analysis, and operational performance.` (`app.py` L13285)
* **Supervised Area Badge**: `{count} Supervised Branches` (`#F0FDF4` container, `#22C55E` border, `#14532D` text)

### 1.3 Admin / Super Admin / Director (`is_admin`)
* **Title**: `Enterprise Financial & Operational Reports` (`app.py` L13297)
* **Subtitle**: `Consolidated institutional double-entry trial balance, savings portfolios, collections, and multi-branch data exports.` (`app.py` L13298)
* **Scope Level Badge**: `Institutional Scope` (`#FAF5FF` container, `#A855F7` border, `#581C87` text)

### 1.4 Credit Officer (`CO`) — Access Prohibited
* Fails closed: Route security blocks access with `Access Denied: You do not have permission to access this page.`

---

## 2. Universal Filter Controls Header

Located in an elevated white card with 1px `#E2E8F0` border (`app.py` L13309–13386):
* **Branch Scope**:
  - BM: Single branch label (disabled)
  - AM: Dropdown with `All Assigned Branches (Consolidated Area View)` + assigned branches
  - Admin: Dropdown with `All Branches (Consolidated)` + all active branches
* **Loan Product**: Dropdown with `All Products` + list of active loan products
* **Credit Officer**: Dropdown with `All Officers` + list of officers matching branch scope
* **Date Mode**:
  - `As of Date`: Single date picker (defaults to today)
  - `Date Range`: Start Date (1st of current month) and End Date (today)
  - `All Time`: Full cumulative dataset notice

---

## 3. Dynamic Navigation Tabs

### 3.1 Area Manager (`is_am`) — 6 Tabs
1. `Area Branches Comparison` (AM Exclusive)
2. `General Ledger & Trial Balance`
3. `Savings Summary`
4. `Repayment Summary`
5. `Portfolio & Officer Performance`
6. `Data Exports & Downloads`

### 3.2 Branch Manager & Admin — 5 Tabs
1. `General Ledger & Trial Balance`
2. `Savings Summary`
3. `Repayment Summary`
4. `Portfolio & Officer Performance`
5. `Data Exports & Downloads`

---

## 4. Tab Specifications

### Tab 1: Area Branches Comparison (AM Exclusive)
* **Header**: `Regional Area Performance Matrix`
* **Caption**: `Side-by-side comparative analysis of all branches under your regional supervision. Identifies branch-level risk, portfolio size, collection efficiency, and savers engagement.`
* **Summary Metrics (8 KPIs in 2 Rows)**:
  - Row 1: `Supervised Branches` (int), `People on Loan` (int + "Clients"), `Active Savers` (int + "Savers"), `Active Loans Count` (int + "Loans")
  - Row 2: `Regional Collections` (₦), `Expected Collections` (₦), `Area Efficiency` (%), `Area Savings Portfolio` (₦)
* **Table**: `Branch-by-Branch Comparative Matrix`
  - Columns: `Branch`, `No. of People on Loan`, `Active Loans`, `No. of Active Savers`, `Total Savings`, `Collections Received`, `Expected Collections`, `Collection Efficiency`, `Outstanding Portfolio`, `PAR %`, `Status`
* **Direct Downloads**:
  - `Download Area Comparison (CSV)`
  - `Download Area Comparison (Excel)`

### Tab 2: General Ledger & Trial Balance
* **Header**: `General Ledger Trial Balance`
* **Caption**: `Double-entry verification of all Chart of Accounts balances. Total Debits must mathematically equal Total Credits.`
* **Summary Metrics (4 KPIs)**:
  - `Total Debits` (₦)
  - `Total Credits` (₦)
  - `Net Variance` (₦)
  - `Ledger Integrity Badge`: "Balanced" (`#166534`, `#f0fdf4`) vs "Out of Balance" (`#991b1b`, `#fef2f2`)
* **Table**: `General Ledger Trial Balance`
  - Columns: `Account Code`, `Account Name`, `Account Type`, `Gross Debits`, `Gross Credits`, `Debit Balance`, `Credit Balance`, `Net Position`
* **Direct Downloads**:
  - `Download Trial Balance (CSV)`
  - `Download Trial Balance (Excel)`

### Tab 3: Savings Summary
* **Header**: `Savings Portfolio & Savers Breakdown`
* **Caption**: `Authoritative savings summary derived from individual deposits, group savings, and LAPS reserves.`
* **Summary Metrics (7 KPIs in 2 Rows)**:
  - Row 1: `Individual Deposits` (₦), `Individual Withdrawals` (₦), `Net Individual Savings` (₦), `Active Savers Count` (int + "Clients")
  - Row 2: `Net Group Savings` (₦), `LAPS Reserve` (₦), `Consolidated Savings Portfolio` (₦)
* **Table**: `Itemized Savers List`
  - Columns: `Client ID`, `Client Name`, `Group Name`, `Total Deposited`, `Total Withdrawn`, `Net Savings Balance`
* **Direct Downloads**:
  - `Download Savings Summary (CSV)`
  - `Download Savings Summary (Excel)`

### Tab 4: Repayment Summary
* **Header**: `Repayments & Collections Performance Summary`
* **Caption**: `Granular collection summary detailing base scheduled collections, full early payoffs, and excess payments.`
* **Summary Metrics (6 KPIs in 2 Rows)**:
  - Row 1: `Total Collections Received` (₦), `Scheduled Expected Collections` (₦), `Collection Efficiency` (%)
  - Row 2: `Full Payoffs Settled` (₦, count + "Loans"), `Excess Surplus Cash` (₦, count + "Events"), `Overdue Collections` (₦)
* **Sub-Table 1**: `Collections by Loan Product`
  - Columns: `Loan Product`, `Collections (NGN)`, `Transactions`, `Unique Clients`
* **Sub-Table 2**: `Itemized Collections Log`
  - Columns: `Date`, `Client Name`, `Loan Product`, `Officer`, `Amount Paid`, `Expected Amount`
* **Direct Downloads**:
  - `Download Repayments Log (CSV)`
  - `Download Repayments Log (Excel)`

### Tab 5: Portfolio & Officer Performance
* **Card 1: Portfolio Summary & Health**:
  - `Active Loans` (int)
  - `Total Portfolio` (₦)
  - `PAR %` (%)
* **Card 2: Officer Performance Breakdown**:
  - Selector: `Select Officer to Inspect:` (`All` + list of officers)
  - Table: `Client ID`, `Client Name`, `Phone`, `Group`, `Product`, `Active Credit`, `Loan Repay`, `Paid to Loan`, `Loan Balance`, `Savings`, `Overdue`, `Status`
* **Card 3: Client Risk Rating & Credit Intelligence**:
  - 5 Metric Cards:
    - `[EXCELLENT] Upgrade` (Count)
    - `[GOOD] Maintain` (Count)
    - `[FAIR] Monitor` (Count)
    - `[RISKY] No Increase` (Count)
    - `[HIGH RISK] Decline` (Count)

### Tab 6: Data Exports & Downloads
* **Header**: `Comprehensive Operational Data Exports`
* **Caption**: `Direct in-memory generation of full operational datasets. All files download directly to your browser without external cloud dependencies.`
* **Master Operational Report (Excel)**:
  - Multi-tab synchronized workbook containing:
    - `Area_Branch_Comparison` (if Area Manager)
    - `Trial_Balance`
    - `Savings_Summary`
    - `Repayment_Summary`
    - `Portfolio_Summary`
    - `Raw_Loans`
  - Download Button: `Download Master Operational Report (Excel)`
* **Raw Operational Records (CSV)**:
  - Download Button 1: `Download Raw Loans (CSV)`
  - Download Button 2: `Download Raw Repayments (CSV)`

---

## 5. Architectural & Governance Invariants
1. **Financial Source of Truth (Account 1000)**: General Ledger Trial Balance is derived directly from `financial_ledger_entries` and `chart_of_accounts`. Total Debits must equal Total Credits.
2. **Strict Zero-Emoji Governance (Rule 10)**: Emojis are strictly prohibited anywhere in UI widgets, tabs, cards, tables, alerts, or dialogs. Use Material corporate icons or SVG icons.
3. **Payoff & Excess Invariant (Rule 9)**: Repayment summaries must distinguish between scheduled collections, full early payoffs (`full_payoff_amount`), and excess payments (`excess_payment_amount`).
4. **Zero Live Data Contamination Directive**: All verification routines against live Supabase data must be strictly 100% read-only.
5. **Role-Adaptive Scoping**:
   - Branch Manager: Locked to single branch.
   - Area Manager: Scoped to assigned branches with cross-branch comparison tab.
   - Admin / Director: Global institutional scope.
   - Credit Officer: Prohibited (fails closed).
