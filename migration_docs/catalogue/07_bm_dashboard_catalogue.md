# Parity Catalogue: 07 — Branch Manager Dashboard

**Source Implementation**: `app.py` L2560–3138  
**Navigation & Sidebar Source**: `app.py` L1925–2000, `services/rbac_scope_service.py` L34–36 (`ROLE_NAVIGATION["Branch Manager"]`)  
**Backend Service Authority**: `services/dashboard_service.py` L701–945 (`DashboardService.get_bm_dashboard_data`)  
**Target Screen**: `frontend_flutter/lib/features/bm/presentation/bm_dashboard_screen.dart`  
**API Route**: `GET /api/v1/bm/dashboard` (`api/routes/bm/dashboard.py`, `api/schemas/bm_dashboard.py`)  

---

## 1. Page Title & Identity
* **Exact Global Header**: `Performance & Risk Dashboard` (`app.py` L2430 / L2435)
  - Rendered with optional `Audit Center` top-right button if permitted.
* **Exact Section Title**: `Branch Manager Dashboard — {BRANCH} Branch` (`st.markdown(f"### Branch Manager Dashboard — {BRANCH} Branch")`, L2561)
* **Caption**: `Branch Daily Operations, Officer Status, & Approvals` (`st.caption(...)`, L2562)
* **Contextual Alerts**:
  - Flash Success Banner (`st.success(flash_msg)`) on approval/rejection actions.
  - Branch Closure Warning (`st.warning(...)`) if holiday or branch closure active.

---

## 2. Branch Approvals Hub (Conditional Section)
Rendered whenever `has_p_loans or has_p_wr or has_p_corr` is true (`app.py` L2580–3105).
* **Section Header**: `Branch Approvals Hub` (`st.markdown("### Branch Approvals Hub")`, L2581)
* **Section Caption**: `Filter by officer, configure operational disbursement dates, and process batch or individual approvals.` (L2582)
* **Navigation Tabs**: Authentic Streamlit Pill Tabs:
  1. `Loan Disbursements ({count})` (if pending loans > 0)
  2. `Withdrawals ({count})` (if pending withdrawals > 0)
  3. `Error Corrections ({count})` (if pending corrections > 0)

### Tab 1: Loan Disbursements
* **Filters**:
  - `Filter Officer`: Dropdown (`All Officers`, list of distinct officers).
  - `Filter Product`: Dropdown (`All Products`, list of distinct loan products).
  - `Search Client Name / Code`: Text input with placeholder `Type name or code...`.
* **Batch Controls**:
  - `Batch Operational Disbursement Date`: Date picker (defaults to branch business date).
  - `Select All ({count})`: Checkbox.
  - `Approve Selected Loans`: Primary red button (`#FF4B4B`), full width.
* **Item Cards**:
  - Container with 1px border.
  - Checkbox.
  - Client name (bold) & code in badge.
  - Subtitle: `Product: {product} | Officer: {officer}`.
  - Amount: Bold formatted currency `₦{amount:,.2f}`, caption `Requested Principal`.
  - Operational Date: Individual date input defaulting to batch date.
  - Actions: `Approve` button (primary red), `Reject` button (secondary/outline).

### Tab 2: Withdrawals
* **Filters**:
  - `Filter Officer`: Dropdown (`All Officers`, list of distinct requesters).
  - `Filter Savings Type`: Dropdown (`All Types`, list of distinct savings types).
  - `Search Client / Reference`: Text input with placeholder `Type name or ref...`.
* **Batch Controls**:
  - `Batch Operational Withdrawal Date`: Date picker (defaults to branch business date).
  - `Select All ({count})`: Checkbox.
  - `Approve Selected Withdrawals`: Primary red button (`#FF4B4B`).
* **Item Cards**:
  - Container with 1px border.
  - Checkbox.
  - Client name & savings type badge (`Individual`, `Group`, `Misc`).
  - Subtitle: `Op: {operation_type} | Requested by: {requested_by}`.
  - Remarks italicized.
  - Amount: Red currency `₦{amount:,.2f}` (`color: #b91c1c`), caption `Withdrawal Amount`.
  - Operational Date: Individual date input defaulting to requested date or batch date.
  - Actions: `Approve` button (primary red), `Reject` button (secondary, opens rejection reason input).

### Tab 3: Error Corrections (Reversals)
* **Filters**:
  - `Filter Requester`: Dropdown (`All Officers`, list of distinct requesters).
  - `Filter Transaction Type`: Dropdown (`All Types`, list of distinct record types).
  - `Search Ref / Reason`: Text input with placeholder `Type reference or note...`.
* **Batch Controls**:
  - `Select All ({count})`: Checkbox.
  - `Approve Selected Reversals`: Primary red button (`#FF4B4B`).
* **Item Cards**:
  - Container with 1px border.
  - Checkbox.
  - `[{record_type}] Ref: #{record_id[:8]}`.
  - Subtitle: `Requested by: {req_user} • Submitted: {date}`.
  - Reason: `Reason: *{reason}*`.
  - Status Tag: `Pending Approval` amber badge (`#FEF3C7` bg, `#92400E` text).
  - Actions: `Approve` button (primary red), `Reject` button (secondary).

---

## 3. Section A: Branch Summary (4 Columns)
Rendered via `st.columns(4)` (`app.py` L3108–3114).
| Card Label | Value Format | Source | Accent / Styling |
|---|---|---|---|
| `Active Clients` | `{count}` (e.g. 296) | `loans` table active borrowers count | Flat white container, 1px `#E2E8F0` border |
| `Active Savings` | `₦{amt:,.0f}` | `SavingsService.get_branch_totals` | Flat white container, 1px `#E2E8F0` border |
| `Collection Today` | `₦{amt:,.0f}` | `repayments` table (non-legacy) | Flat white container, 1px `#E2E8F0` border |
| `PAR` | `{pct}%` (e.g. 17.5%) | `DashboardService.calculate_par_pct` (`BR-DASH-004`) | Flat white container, 1px `#E2E8F0` border |

---

## 4. Section B: Officer Collection Status Grid
Rendered via `st.markdown("#### Officer Collection Status")` & `st.dataframe` (`app.py` L3116–3126).
| Column Name | Type | Formatting / Meaning |
|---|---|---|
| `Officer` | String | Officer username (e.g. `CO1`, `CO2`, `CO3`, `CO4`) |
| `Scheduled Groups` | String | Comma-separated scheduled group names with numbers (e.g. `Patience (#45), Olainukan (#46)`) |
| `Expected` | Currency | Sum of `loan_schedule.total_due` for active loans due today (`₦{amt:,.0f}`) |
| `Collected` | Currency | Sum of non-legacy repayments received today (`₦{amt:,.0f}`) |
| `Outstanding` | Currency | `max(0.0, Expected - Collected)` (`₦{amt:,.0f}`) |
| `Compliance %` | Percentage | `(Collected / Expected) * 100` formatted as `{pct:.1f}%` |
| `Closing Balance` | Currency | Cash closing balance from `co_cashbooks` (`₦{amt:,.0f}`) |
| `Status` | Institutional Tag | `Normal` (>= 80% or empty), `Requires Attention` (< 80%), or `Closed` |

---

## 5. Section C: Branch Cash Position (Master Cashbook)
Rendered via `st.markdown("#### Branch Cash Position (Master Cashbook)")` (`app.py` L3128–3138).
### Row 1: 4 Metric Columns
| Card Label | Value Format | Source |
|---|---|---|
| `Opening Balance` | `₦{amt:,.0f}` | `master_cashbook.opening_balance` (Account 1000) |
| `Total Inflows` | `₦{amt:,.0f}` | `master_cashbook.total_inflows - opening_balance` |
| `Total Outflows` | `₦{amt:,.0f}` | `master_cashbook.total_outflows` |
| `Closing Balance` | `₦{amt:,.0f}` | `master_cashbook.closing_balance` |

### Row 2: 2 Metric Columns
| Card Label | Value Format | Source / Meaning |
|---|---|---|
| `Cashbook Status` | String | `Balanced` if difference == 0.0 else `Unbalanced` |
| `Difference` | `₦{amt:,.0f}` | `abs(opening + inflows - outflows - closing)` |

---

## 6. RBAC & Governance
- **Role Authorization**: `Branch Manager` (`BM`) and supervising management (`Area Manager`, `Admin`, `Super Admin`).
- **Scoping**: Branch-wide (e.g. `Ogijo` branch covers all 51 groups and all 4 field officers: `CO1`, `CO2`, `CO3`, `CO4`).
- **Zero-Emoji Rule**: 100% compliant with Rule 10 (corporate SVG/Material icons and status badges only).
