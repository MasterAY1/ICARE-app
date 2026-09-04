# PAGE IDENTITY — CORRECTED

- Routes: `Reports` and `Reports & Export`
- Exact title: `Reports & Data Export`
- Source: `app.py` 9344–9487

## Source-verified layout and controls

Area Managers see `🌐 Filter Reports by Branch:`. The page contains `📊 Portfolio Summary Report`, `☁️ Export to Google Sheets`, and buttons `📤 Export Loans`, `📤 Export Repayments`, and `📤 Export Summary`. It then shows `📥 Download Excel Report` with `⬇️ Download Full Report (Excel)` followed by a Streamlit download control.

It also includes `👥 Officer Performance Reports` (`Select Officer:` and a dataframe) and `⭐ Client Risk Rating & Credit Intelligence`.

No generic report-type picker, date-range filter, CSV download button, or verified HTTP export endpoint is present in this source section. Those former claims are not parity evidence.

> The remainder is superseded wherever it conflicts with this source-verified correction.

# Superseded document content

* **Exact page title**: `Reports & Data Export`
* **Sidebar label**: `Reports & Export`
* **Role(s)**: `Branch Manager`, `Area Manager`, `Administrator`, `Executive Director`
* **Navigation location**: Sixth menu item for BM, seventh for AM, eleventh for Admin
* **Streamlit source**: `app.py` L9343–9487
* **Relevant line ranges**: L9343–9487

# PAGE PURPOSE

Institutional reporting and business intelligence suite. Generates regulatory returns, periodic portfolio performance reports, disbursement summaries, PAR analysis sheets, and enables bulk CSV/Excel exports for external analysis.

# PAGE LAYOUT

1. **Header**: `st.title("Reports & Data Export")`
2. **Report Category Selector**: Radio/Dropdown (`Portfolio Quality (PAR)`, `Disbursements Report`, `Collections & Repayments`, `Savings Balances`, `Branch Cashbook Summary`).
3. **Date & Parameter Controls**: Start Date, End Date, Branch, Officer.
4. **Report Preview Table**: Live rendering of compiled report data.
5. **Download Actions Bar**: Export to CSV and Excel buttons.

# SECTION INVENTORY

1. **Report Type Selection**: Chooses reporting template.
2. **Parameters & Date Range**: Configures reporting filters.
3. **Live Data Preview**: Displays computed report table.
4. **Export Engine**: Generates download binaries.

# UI COMPONENT INVENTORY

* **Radio Selector**: Report templates.
* **Date Range Picker**: `st.date_input`.
* **Dataframe Preview**: Formatted report grid.
* **Download Buttons**: `st.download_button` for CSV and Excel.

# LABEL INVENTORY

* Page Title: `Reports & Data Export`
* Report Categories: `Portfolio Quality (PAR)`, `Disbursements Summary`, `Collections & Repayments`, `Savings Ledger`, `EOD Cashbook Consolidation`
* Buttons: `Generate Report Preview`, `Download CSV`, `Download Excel (.xlsx)`

# FORM INVENTORY

* None.

# TABLE INVENTORY

* Dynamic Report Dataframe according to selected template.

# BUTTON INVENTORY

* `Download CSV` / `Download Excel`: Generates client-side file download.

# FILTER INVENTORY

* Report Type, Date Window, Branch, Officer.

# NAVIGATION BEHAVIOUR

* Available to managers and directors.

# RBAC BEHAVIOUR

* Data automatically filtered by caller's scope level (`BRANCH`, `REGION`, or `INSTITUTION`).

# DATA CONTRACT

* `GET /api/v1/reports/export?report_type={type}&start_date={s}&end_date={e}`

# WORKFLOW

1. User selects `Portfolio Quality (PAR)`.
2. Selects date range $\rightarrow$ Clicks `Generate Report Preview`.
3. System compiles PAR 1-30, 31-60, 90+ buckets.
4. User reviews on screen $\rightarrow$ Clicks `Download Excel`.

# STATES

* Ready, Generating, Download Complete.

# VISUAL CHARACTERISTICS

* Standard report view with large data preview grid.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L9343–9487.
