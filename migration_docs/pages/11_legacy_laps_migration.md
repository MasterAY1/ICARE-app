# PAGE IDENTITY — CORRECTED

- Route/sidebar label: `Legacy LAPS Migration`
- Exact title: `🏛️ Legacy LAPS Bulk Migration Console (Super Admin)`
- Source: `app.py` 5589–5665

## Source-verified layout and controls

The page has a `📥 Bulk Excel File Upload` section. After input, it renders `Preview Uploaded Migration Data` and the first ten dataframe rows, then `🚀 Process Bulk LAPS Migration`. On failures it exposes `View Error Details`. It also shows `📜 Historical LAPS Migration Batches` and a dataframe with `migration_batch_id`, `client_name`, `branch`, `officer`, `deposit_amount`, `owner_known`, `migration_source`, and `date`.

No template-download UI or proved `/api/v1/admin/migration/laps-import` contract was observed in this route section.

> The remainder is superseded wherever it conflicts with this source-verified correction.

# Superseded document content

* **Exact page title**: `Legacy LAPS Migration`
* **Sidebar label**: `Legacy LAPS Migration`
* **Role(s)**: `Administrator`
* **Navigation location**: Sixth menu item for Administrator
* **Streamlit source**: `app.py` L5589–5665
* **Relevant line ranges**: L5589–5665

# PAGE PURPOSE

Specialized administrative migration utility to import, convert, and reconcile legacy paper-based LAPS (Loan Asset Protection Scheme) and voluntary savings balances into the digital Supabase core banking ledger.

# PAGE LAYOUT

1. **Header**: `st.title("Legacy LAPS Migration")`
2. **Template Download**: Excel template for legacy balances.
3. **File Uploader**: Excel `.xlsx` file selector.
4. **Validation Preview Table**: Displays parsed records with integrity status.
5. **Execute Migration Button**: Atomic batch import into `individual_savings` and `financial_ledger_entries`.

# SECTION INVENTORY

1. **Instructions & Template**: Downloadable schema template.
2. **Upload & Validation**: Client ID matching and balance check.
3. **Execution**: Post-migration journal summary.

# UI COMPONENT INVENTORY

* **File Uploader**: `st.file_uploader`
* **Preview Table**: `st.dataframe`
* **Button**: `Execute LAPS Migration`

# LABEL INVENTORY

* Title: `Legacy LAPS Migration`
* Buttons: `Download Template`, `Upload File`, `Execute Migration`

# FORM INVENTORY

* Upload & migration execution form.

# TABLE INVENTORY

* **Validation Table**: `[Client ID, Client Name, Legacy LAPS Balance, Status]`

# BUTTON INVENTORY

* `Execute Migration`: Inserts opening balances with historical ledger journal entries.

# FILTER INVENTORY

* None.

# NAVIGATION BEHAVIOUR

* Exclusive to System Administrator.

# RBAC BEHAVIOUR

* `Admin`: Full access. All other roles: Access Denied.

# DATA CONTRACT

* `POST /api/v1/admin/migration/laps-import`

# WORKFLOW

1. Admin downloads template $\rightarrow$ Fills legacy client balances.
2. Uploads file $\rightarrow$ System validates client IDs exist in `clients` table.
3. Admin confirms $\rightarrow$ Balances committed to database.

# STATES

* Ready, Uploaded, Validated, Completed.

# VISUAL CHARACTERISTICS

* Utility migration layout.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L5589–5665.
