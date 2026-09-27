# ICARE Flutter Frontend — Mobile Responsiveness & LAN Testing Specification

> Authority: Follow the **CRITICAL MIGRATION RULES** from user instructions.
> Goal: Responsive adaptation, NOT UI redesign. The existing desktop UI remains authoritative and unchanged.

---

## 1. Existing Responsive Behaviour & Findings

A comprehensive inspection of the existing Flutter codebase revealed:
1. **Scaffold & Navigation (`co_app_scaffold.dart`)**:
   - Currently uses a fixed horizontal `Row` with a 280px sidebar and an `Expanded` content area.
   - At screen widths $< 900\text{px}$ (tablets) and $< 600\text{px}$ (phones), the 280px sidebar severely constrains the content area, causing cramped text and layout clipping.
   - Requires adaptive layout:
     - **Desktop ($\ge 900\text{px}$)**: Retain the fixed 280px sidebar exactly as currently implemented.
     - **Phone & Tablet ($< 900\text{px}$)**: Collapse the sidebar into an `AppBar` with a hamburger menu icon (`Icons.menu`), moving the existing sidebar contents into a slide-out `Drawer`.
2. **Dashboard Cards & Tables (`co_dashboard_screen.dart`)**:
   - Metric rows: 3-card and 4-card `Row`s with `Expanded` children. On phone viewports ($< 600\text{px}$), these cards compress to $< 100\text{px}$ width.
   - Tables (`_buildMeetingPortfolioTable`, `_buildAttentionListTable`): `DataTable` widgets are not wrapped in `SingleChildScrollView(scrollDirection: Axis.horizontal)`, causing horizontal `RenderFlex` overflow on narrow viewports.
   - Top Header: Title and `Audit Center` button in a single `Row` overflows when phone width is $< 500\text{px}$.
3. **Collections Screen (`daily_collections_screen.dart`)**:
   - Top Control Bar: Switch + text + vertical divider + date picker in a single `Row` overflows on phones. Needs `Wrap` or stacked layout on mobile.
   - Primary Tabs: 3 horizontal tabs in a non-scrollable `Row`. Needs horizontal scroll on phones.
   - Group Member collection rows and staging tables require horizontal scroll protection.
4. **Withdrawal Operations (`withdrawal_operations_screen.dart`)**:
   - Primary tabs bar already has `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
   - Date picker row with `Spacer()` needs adaptive layout on phones.
   - Data tables are properly wrapped in `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
5. **Portfolio Overview (`portfolio_overview_screen.dart`)**:
   - Filter bar: 4-dropdown horizontal `Row` needs vertical stacking on phones.
   - Lifecycle 8-metric row: 8 `Expanded` cards in a single `Row` must stack into responsive 2-column or 4-column wrap on phones/tablets.
   - Savings, disbursement, loan/collection, and repayment status metric rows need responsive 2-column/1-column stacking on phones.
6. **Loan Origination (`loan_origination_screen.dart`)**:
   - Forms: 3-column input rows (Name, Nickname, Phone; Marital, Business Type, Income; ID Means, ID Number, Upload) are hardcoded in horizontal `Row`s with `Expanded` children. These must adapt to single-column on phones ($< 600\text{px}$), 2-column on tablets ($600\text{px}-899\text{px}$), and 3-column on desktop ($\ge 900\text{px}$).
7. **Cashbook (`daily_cashbook_screen.dart`)**:
   - 2-column / 3-column financial inputs and cash position KPI cards need responsive wrapping on phones.

---

## 2. Target Responsive Breakpoints

| Breakpoint Range | Device Target | Navigation Pattern | Form Layout | Metric Cards |
|---|---|---|---|---|
| **`< 600px`** | **Phone** | Top `AppBar` with hamburger + slide-out `Drawer` | 1 column (full width) | 1–2 columns stacked |
| **`600px – 899px`** | **Tablet** | Top `AppBar` with hamburger + slide-out `Drawer` (or compact rail) | 2 columns | 2 columns |
| **`>= 900px`** | **Desktop** | Fixed 280px sidebar (100% untouched) | Multi-column (original) | Original horizontal rows |

---

## 3. API & LAN Configuration

### Current Configuration
- `ApiClient` in `frontend_flutter/lib/core/network/api_client.dart`:
  ```dart
  final effectiveUrl = baseUrl ?? (kIsWeb ? '' : 'http://127.0.0.1:8000');
  ```
- In Flutter Web, relative path `''` requests `/api/...` on the same host and port as the web page.
- `scratch/proxy_server.py` runs on `0.0.0.0:3000` and forwards `/api/` requests to `http://127.0.0.1:8000`.

### LAN Support Strategy
- Support `--dart-define=API_BASE_URL=...` for explicit override without hardcoding any permanent LAN IP.
- Ensure reverse proxy and FastAPI listen on `0.0.0.0` (all interfaces) so any device on the Wi-Fi network can connect to `http://<PC-LAN-IP>:3000`.
- Identified PC LAN IP: **`192.168.1.177`**.

---

## 4. Components Requiring Mobile Adaptation

1. **`co_app_scaffold.dart`**:
   - Add breakpoint detection: `final isDesktop = MediaQuery.of(context).size.width >= 900;`.
   - On mobile/tablet: Render top `AppBar` with hamburger button, and drawer containing existing sidebar.
   - On desktop: Retain existing fixed 280px sidebar layout.
2. **`co_dashboard_screen.dart`**:
   - Adapt header: `Wrap` or `Column` for title and Audit Center button on mobile.
   - Adapt metric rows: 1 column on phone ($<600\text{px}$), 2 columns on tablet ($600-899\text{px}$), 3/4 columns on desktop ($\ge 900\text{px}$).
   - Wrap `DataTable` in `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
3. **`daily_collections_screen.dart`**:
   - Adapt top control bar to `Wrap` on mobile.
   - Wrap primary tabs in `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
   - Ensure member input cards fit full width on phones.
4. **`withdrawal_operations_screen.dart`**:
   - Adapt operational date bar for mobile width.
5. **`portfolio_overview_screen.dart`**:
   - Adapt filter bar into 1 or 2 columns on mobile.
   - Adapt 8-metric lifecycle row into responsive wrap (2 columns on mobile, 4 on tablet, 8 on desktop).
   - Adapt 4-metric rows into 1 or 2 columns on mobile.
6. **`loan_origination_screen.dart`**:
   - Adapt 3-column input rows into single column on mobile, 2 columns on tablet, 3 columns on desktop.
7. **`daily_cashbook_screen.dart`**:
   - Wrap cashbook tables in horizontal scroll and stack EOD input fields on mobile.

---

## 5. Files Changed & Deliberately Left Untouched

### Files To Be Changed (Presentation / Client Layer Only):
- `frontend_flutter/lib/core/network/api_client.dart` (Add `API_BASE_URL` environment support)
- `frontend_flutter/lib/features/shared/presentation/co_app_scaffold.dart` (Adaptive drawer navigation)
- `frontend_flutter/lib/features/co/presentation/co_dashboard_screen.dart` (Responsive metrics, horizontal table scroll)
- `frontend_flutter/lib/features/co/presentation/daily_collections_screen.dart` (Responsive control bar, scrollable tabs)
- `frontend_flutter/lib/features/co/presentation/withdrawal_operations_screen.dart` (Responsive date picker bar)
- `frontend_flutter/lib/features/co/presentation/portfolio_overview_screen.dart` (Responsive filter bar & metric grids)
- `frontend_flutter/lib/features/co/presentation/loan_origination_screen.dart` (Responsive form rows)
- `frontend_flutter/lib/features/co/presentation/daily_cashbook_screen.dart` (Responsive EOD forms & tables)

### Files Deliberately Left Untouched (100% Immutable Business / Backend):
- `api/routes/*` (All FastAPI routes and logic untouched)
- `api/schemas/*` (All Pydantic contracts untouched)
- `services/*` (All domain engines untouched)
- `database/*` (All repositories and Supabase client untouched)
- `auth/*` (All auth and session logic untouched)
- `models/*` (All domain models untouched)
- Live database schema & data (100% read-only verification)
