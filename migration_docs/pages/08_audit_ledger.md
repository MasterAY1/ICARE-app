# PAGE IDENTITY — CORRECTED

- Routes: `Audit Center` and `Audit Ledger`
- Source: `app.py` 6588–7199

## Source-verified RBAC structure

The page does not have one fixed title or a single generic audit layout:

- Credit Officer: `Credit Officer Audit Ledger`; tabs `Savings Ledger`, `Loan Portfolio`, `Collection Performance`.
- BM/AM: `Branch Audit Ledger`; tabs `6-Way Integrity Match`, `Fees Audit`, `Treasury Audit`, `Savings Ledger`, `Loan Portfolio`, `Collection Performance`, `360° Explorer & Timeline`.
- Other permitted roles: `Enterprise Audit & Reconciliation Center`; adds `Exception Reports`, `Performance Insights`, and `🧙 Reconciliation Wizard` to the audit controls.

The wizard contains `Select Reconciliation Date:` and `🚀 Start Guided Projection Repair`. This is an existing Streamlit operation and must be explicitly represented in a full parity review; it cannot be replaced with the former proposed simple ledger filter screen.

> The remainder is superseded wherever it conflicts with this source-verified correction.

# Superseded document content

* **Exact page title**: `Audit Center` / `Audit Ledger`
* **Sidebar label**: `Audit Ledger`
* **Role(s)**: `Branch Manager`, `Area Manager`, `Administrator`, `Executive Director`
* **Navigation location**: Fifth menu item for BM/AM, tenth for Admin
* **Streamlit source**: `app.py` L6588–7199
* **Relevant line ranges**: L6588–7199

# PAGE PURPOSE

The forensic audit and compliance verification hub of ICARE. Provides immutable access to the double-entry `financial_ledger_entries` (Account 1000 and all nominal accounts), Domain Event Store (`event_store`), user activity audit trail, and system integrity verification checks.

# PAGE LAYOUT

1. **Header**: `st.title("Audit Ledger")` + `st.caption("Immutable financial journal entries and domain event audit trail.")`
2. **Filter Header**: Date range picker, Account code selector (`Account 1000 - Vault Cash`, `Account 1200 - Loans Receivable`, `Account 2000 - Member Savings`), Event type selector, Branch selector.
3. **Audit KPI Metrics**: Total Debits, Total Credits, Net Journal Delta (must equal ₦0 for double-entry integrity), Total Event Count.
4. **Ledger Entries Table**: Master double-entry journal with transaction UUID, timestamp, account code, debit, credit, narrative, and posting officer.
5. **Event Store Drilldown Table**: Raw domain events with payload metadata.

# SECTION INVENTORY

1. **Forensic Search & Filter Bar**: Multi-criteria query builder.
2. **Double-Entry Balance KPI**: Asserts mathematical debit/credit balance.
3. **General Ledger Journal Grid**: Complete ledger history.
4. **Domain Event Stream**: Immutable event log.

# UI COMPONENT INVENTORY

* **Date Range Picker**: `st.date_input("Audit Period")`
* **Account Code Dropdown**: Filter by chart of accounts.
* **Integrity Status Banner**: `🟢 Double-Entry Ledger Balanced (Debits = Credits)` or `🚨 Imbalance Detected`.
* **Data Table**: Paginated ledger entries.

# LABEL INVENTORY

* Page Title: `Audit Ledger`
* Metrics: `Total Debits (₦)`, `Total Credits (₦)`, `Ledger Imbalance (₦)`, `Total Events Logged`
* Columns: `Entry ID`, `Date/Time`, `Account Code`, `Account Name`, `Debit (₦)`, `Credit (₦)`, `Narrative`, `Officer`, `Branch`

# FORM INVENTORY

* None (Strictly immutable read-only audit interface).

# TABLE INVENTORY

* **Journal Entries Table**: `[Entry ID, Timestamp, Account Code, Debit, Credit, Reference, Narrative, User, Branch]`

# BUTTON INVENTORY

* `Export Audit Log (CSV)`: Downloads filtered ledger slice for external auditors.

# FILTER INVENTORY

* Account Code, Date Range, Branch, Event Type, User.

# NAVIGATION BEHAVIOUR

* Available to compliance and management roles.

# RBAC BEHAVIOUR

* `CO`: Access Denied.
* `BM`: Scoped to branch entries.
* `AM` / `Admin` / `Director`: Institution-wide ledger access.

# DATA CONTRACT

* `GET /api/v1/audit/ledger?account_code={code}&start_date={s}&end_date={e}`

# WORKFLOW

1. Auditor opens `Audit Ledger`.
2. Selects audit date window $\rightarrow$ System queries `financial_ledger_entries`.
3. System validates $\sum \text{Debits} - \sum \text{Credits} = 0$.
4. Auditor inspects individual journal lines and associated domain events.

# STATES

* Balanced / Error Imbalance.

# VISUAL CHARACTERISTICS

* Monospace fonts for transaction UUIDs and account codes. High precision financial layout.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L6588–7199.
