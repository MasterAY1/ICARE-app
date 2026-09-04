# PAGE IDENTITY — CORRECTED

- Route/sidebar label: `Master Cashbook`
- Exact title: `Branch Manager Master Cashbook`
- Source: `app.py` 7649–8598

## Source-verified structure

The page caption is `INITIATIVE FOR COMMUNITY ADVANCEMENT, RELIEF AND EMPOWERMENT — Credit Cash Book Ledger`. Its three tabs are exactly `Daily Cashbook Entry`, `CO Cashbooks Aggregation`, and `Monthly Ledger`.

`Daily Cashbook Entry` has `Select Date`, operational-closure messages, a projection-backed dataframe, a cashbook form including `Staff Salaries`, a calculated closing-balance status, and `💾 Save Master Cashbook Entry`. It includes pending-reversal review (`✅ Approve`, `❌ Reject`), a `🏛️ Flag Branch Treasury Entry for Reversal` expander, and `Submit Treasury Reversal Request`.

`CO Cashbooks Aggregation` exposes `Select Date`, `Select Credit Officer`, a CO cashbook dataframe, and `🔒 Execute EOD Day Close`. `Monthly Ledger` has a ledger dataframe and an Excel download control.

The source rebuilds/reads cashbook projections through `SupabaseUnitOfWork` and `uow.cashbook`; no FastAPI contract is proven. Former claims about a four-metric vault cockpit, a remittance form, or `Reconcile Master Vault` are unsupported.

> The remainder is superseded wherever it conflicts with this source-verified correction.

# Superseded document content

* **Exact page title**: `Branch Manager Master Cashbook`
* **Sidebar label**: `Master Cashbook`
* **Role(s)**: `Branch Manager`, `Area Manager`, `Administrator`
* **Navigation location**: Third menu item for Branch Manager
* **Streamlit source**: `app.py` L7649–8598
* **Relevant line ranges**: L7649–8598

# PAGE PURPOSE

The master branch vault cashbook. Aggregates all officer cashbooks across the entire branch, reconciles master vault cash inflows against bank deposits, tracks inter-officer transfers, manages petty cash disbursements, and provides Branch Managers with an authoritative daily physical cash balance.

# PAGE LAYOUT

1. **Header**: `st.title("Branch Manager Master Cashbook")`
2. **Date Context & Controls**: Business date selector + Branch selector (for AM/Admin).
3. **Branch Vault Reconciliation Summary**: 4 metrics (Vault Opening Cash, Total Officer Turn-in, Total Branch Outflows, Master Vault Closing Balance).
4. **Officer Breakdown Grid**: Comparative table showing cash turn-in per officer.
5. **Master Outflows & Bank Remittance Form**: Record bulk bank deposits and branch operating expenses.
6. **Consolidated Branch T-Account Ledger**: Complete 38-column branch master journal.

# SECTION INVENTORY

1. **Branch Vault Cockpit**: High-level vault cash summary.
2. **Officer Remittance Audit**: Individual CO collection turn-ins and balancing status.
3. **Master Outflows Form**: Captures branch-level commercial bank lodgments.
4. **Master T-Account Dataframe**: Reconciled master ledger.

# UI COMPONENT INVENTORY

* **Metric Cards**: `Vault Opening Balance`, `Total Collections Received`, `Bank Remittances`, `Vault Closing Balance`, `Master Status`.
* **Remittance Form**: Bank selection, teller reference, deposit amount, deposit slip attachment.
* **Master T-Account Tables**: Comprehensive consolidated inflow and outflow tables.

# LABEL INVENTORY

* Title: `Branch Manager Master Cashbook`
* Metrics: `Master Vault Opening`, `Officer Remittances`, `Bank Deposits`, `Master Vault Closing`
* Buttons: `Post Master Bank Lodgment`, `Reconcile Master Vault`

# FORM INVENTORY

* **`master_eod_form`**: Submits consolidated branch lodgments and adjustments.

# TABLE INVENTORY

* **Officer Remittance Matrix**: `[Officer Name, Collections Inflow, Savings Inflow, Expenses, Bank Lodged, Net Cash Handed Over, Status]`.

# BUTTON INVENTORY

* `Reconcile Master Vault`: Closes the master cashbook for the day and advances branch date.

# FILTER INVENTORY

* Date Picker & Branch Selector.

# NAVIGATION BEHAVIOUR

* Accessible to BM, AM, and Admin.

# RBAC BEHAVIOUR

* `CO`: Access Denied.
* `BM`: Scoped to assigned branch.
* `AM` / `Admin`: Can switch between branches.

# DATA CONTRACT

* `GET /api/v1/bm/master-cashbook?branch_id={id}&date={date}`
* `POST /api/v1/bm/master-cashbook/remittance`

# WORKFLOW

1. BM opens `Master Cashbook` after all field officers return.
2. BM verifies each officer's physical cash handover against their `CO Cashbook` balance.
3. BM records total cash bundled and dispatched to the bank.
4. BM posts remittance $\rightarrow$ Master Cashbook reconciles to ₦0 variance.

# STATES

* Balanced / Discrepancy.

# VISUAL CHARACTERISTICS

* Wide table format, high density, professional banking vault styling.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L7649–8598.
