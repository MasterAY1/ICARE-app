# PAGE IDENTITY

* **Exact page title**:
  * `CO Portfolio` (for Credit Officer)
  * `Branch Portfolio` (for Branch Manager)
  * `Regional Portfolio` (for Area Manager)
  * `Enterprise Portfolio` (for Admin / Director)
* **Sidebar label**: `Portfolio`
* **Role(s)**: `Credit Officer`, `Branch Manager`, `Area Manager`, `Administrator`, `Executive Director`
* **Navigation location**: Fifth menu item for Credit Officer, second for BM/AM/Admin
* **Streamlit source**: `app.py` L8599–9299
* **Relevant line ranges**: L8599–9299

# PAGE PURPOSE

The primary analytical and risk surveillance module of the institution. Provides hierarchical portfolio oversight (Officer $\rightarrow$ Branch $\rightarrow$ Region $\rightarrow$ Enterprise), tracks Portfolio at Risk (PAR 1-30, PAR 31-60, PAR 90+), loan maturity profiles, and delivers a deep 360° Client Dossier containing historical loan cycles, savings ledger, compliance track record, and guarantor links.

# PAGE LAYOUT

1. **Title**: Role-dynamic title (`CO Portfolio`, `Branch Portfolio`, `Regional Portfolio`, `Enterprise Portfolio`) + subtitle.
2. **Scope Filter Container** (`st.container(border=True)`):
   * CO: Fixed scope indicator.
   * BM: Credit Officer dropdown filter.
   * AM: Branch selector + Officer filter.
   * Admin/Director: Global branch and officer cascading filters.
3. **Portfolio KPI Metrics Bar**: 4–5 cards (Total Active Principal, Cumulative Disbursed, Cumulative Repaid, PAR % / Non-Performing, Active Clients).
4. **Main Portfolio Table**: Comprehensive loan and client registry.
5. **Client 360° Dossier Section** (Expandable / drilldown on client selection).

# SECTION INVENTORY

1. **Scope & Hierarchy Header**: Resolves user permission boundaries and filters.
2. **Portfolio Health & Risk Metrics**: Real-time aggregation of active principal, PAR ratios, and recovery percentages.
3. **Loan Portfolio Dataframe**: Master listing of active and completed client accounts with sorting and search.
4. **Client 360° Dossier**:
   * Personal & KYC Profile.
   * Loan Performance Timeline & Schedule Ledger.
   * Savings Balance & Transaction History.
   * Solidarity Group & Guarantor Network.

# UI COMPONENT INVENTORY

* **KPI Metric Cards**:
  * `Active Portfolio (Principal)` (₦)
  * `Total Disbursed` (₦)
  * `Total Repaid` (₦)
  * `Portfolio at Risk (PAR)` (%)
  * `Active Borrowers` (count)
* **Cascading Dropdowns**: `Branch Filter`, `Credit Officer Filter`, `Group Filter`, `Status Filter`.
* **Search Input**: `Search by Client Name or ID`.
* **Data Table**: Full portfolio view with custom column sorting.
* **Client Dossier Card**: Detailed modal/container view.

# LABEL INVENTORY

* Dynamic Titles: `CO Portfolio`, `Branch Portfolio`, `Regional Portfolio`, `Enterprise Portfolio`
* Subtitle: `Comprehensive portfolio oversight, role-scoped performance analytics, and 360° client dossier.`
* Metrics: `Active Portfolio`, `Cumulative Disbursed`, `Cumulative Repaid`, `PAR > 30 Days`, `Active Borrowers`
* Table Headers: `Client ID`, `Client Name`, `Solidarity Group`, `Credit Officer`, `Loan Product`, `Disbursed Date`, `Loan Amount`, `Total Repaid`, `Outstanding Balance`, `Status`, `Action`

# FORM INVENTORY

* None (Analytical / reporting view).

# TABLE INVENTORY

* **Master Portfolio Table**:
  * Columns: `Client ID`, `Client Name`, `Group Name`, `Officer`, `Product`, `Disbursed Date`, `Principal (₦)`, `Repaid (₦)`, `Outstanding (₦)`, `Status`

# BUTTON INVENTORY

* `View 360° Dossier`: Opens full client performance history.
* `Export Portfolio (CSV/Excel)`: Downloads filtered portfolio records.

# FILTER INVENTORY

* `Branch Filter` (AM/Admin/Director)
* `Credit Officer Filter` (BM/AM/Admin/Director)
* `Group Filter`
* `Loan Status Filter` (`All`, `Active`, `Completed`, `Defaulted`)

# NAVIGATION BEHAVIOUR

* Accessible from sidebar.
* Supports search query filtering without reloading.

# RBAC BEHAVIOUR

* `CO`: Strictly sees own borrowers.
* `BM`: Sees all borrowers in assigned branch.
* `AM`: Sees all borrowers in assigned region.
* `Director` / `Admin`: Global institutional portfolio.

# DATA CONTRACT

* `GET /api/v1/portfolio/overview?branch_id={id}&officer_id={id}`
* `GET /api/v1/portfolio/client/{id}/dossier`

# WORKFLOW

1. User navigates to `Portfolio`.
2. System resolves scope and loads active portfolio metrics.
3. User filters by group or searches client name.
4. User clicks client row $\rightarrow$ Opens 360° Dossier showing full repayment history, savings balance, and loan cycles.

# STATES

* Empty: `No active loans matching the selected filters.`
* Loading: Spinner.
* Success: Complete data grid loaded.

# VISUAL CHARACTERISTICS

* Wide responsive data table.
* Role-specific title styling.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L8599–9299.
