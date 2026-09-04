# PAGE IDENTITY

* **Exact page title**: `Performance & Risk Dashboard` (L2028) / Sub-headers per role (L2035, L2068, L2129, L2149, L2384)
* **Sidebar label**: `Dashboard`
* **Role(s)**: `Credit Officer`, `Branch Manager`, `Area Manager`, `Administrator`, `Executive Director`
* **Navigation location**: Primary top menu item across all roles
* **Streamlit source**: `app.py` L2013–2459
* **Relevant line ranges**: L2013–2459

# PAGE PURPOSE

Central operational and risk cockpit providing real-time visibility into branch performance, portfolio quality, collections, savings, cash position (Account 1000), approval queues, and staff accountability scoped to the user's role.

# PAGE LAYOUT (ROLE: CREDIT OFFICER, `app.py` L2383–2458)

1. **Top Welcome Info Alert** (`st.info` L2388)
2. **Branch Closure Warning** (`st.warning` L2390–2392, conditional)
3. **Section: Today's Repayment Summary** (3 `st.metric` cards)
4. **Section: Today's Meeting Portfolio** (Dataframe + Quick Action buttons)
5. **Section: Today's Savings** (3 `st.metric` cards)
6. **Section: Today's Repayment Status** (4 `st.metric` cards)
7. **Section: Cash Position (CO Cashbook)** (4 + 2 `st.metric` cards)
8. **Section: Today's Attention List** (Dataframe or success message)

# PAGE LAYOUT (ROLE: BRANCH MANAGER, `app.py` L2149–2382)

1. **Top Header**: `### Branch Performance Dashboard — {BRANCH} Branch`
2. **Date Context Bar**: `st.info` with business date, system date, active status.
3. **Today's Collections & Savings KPI Grid**: 4 columns (Total Repayments, Savings Inflow, Savings Outflow, Net Operational Cash).
4. **Pending BM Approval Queues**:
   * Pending Loan Approvals table with one-click `Approve` / `Reject` actions.
   * Pending Savings Withdrawal Requests table.
   * Cashbook Error Correction Requests queue.
5. **Officer Performance Matrix**: Dataframe comparing scheduled vs actual collections across all branch officers.
6. **Branch Cash Position**: Account 1000 vault reconciliation vs Master Cashbook.

# SECTION INVENTORY (CREDIT OFFICER)

1. **Welcome Alert**: Officer name, branch, business date, meeting day, time.
2. **Repayment Summary**: 60D/12W/3M, 120D/24W/6M, Total Collected Today.
3. **Meeting Portfolio**: Solidarity groups meeting today, expected vs collected amounts, quick action buttons.
4. **Savings Summary**: Savings deposited, savings withdrawn, net savings cash delta.
5. **Repayment Status Breakdown**: Full payment, excess payment, part payment, not paid counts and totals.
6. **Cash Position**: Account 1000 opening, cash in, cash out, closing, status, difference.
7. **Attention List**: Underpaying and delinquent clients requiring field follow-up.

# UI COMPONENT INVENTORY

* **Metric Cards**:
  * `60D / 12W / 3M` (₦ amount, client count delta)
  * `120D / 24W / 6M` (₦ amount, client count delta)
  * `Total Repayment Today` (₦ amount)
  * `Savings Deposited` (₦ amount, client count delta)
  * `Savings Withdrawn` (₦ amount, client count delta)
  * `Net Savings` (₦ amount)
  * `Full Payment` (₦ amount, count)
  * `Excess Payment` (₦ amount, count)
  * `Part Payment` (₦ amount, count)
  * `Not Paid` (₦ amount, count, inverse delta red)
  * `Opening Balance` (₦ amount)
  * `Cash In` (₦ amount)
  * `Cash Out` (₦ amount)
  * `Closing Balance` (₦ amount)
  * `Cashbook Status` (e.g. `🟢 Balanced`)
  * `Difference` (₦ amount)
* **Tables**:
  * `meeting_portfolio`: Columns `[Group Name, Expected, Collected, Outstanding, Compliance %, Status]`
  * `attention_list`: Columns `[Client Name, Group, Expected, Paid, Shortfall, Status]`
* **Action Buttons**:
  * `Start {Group Name} ({Status})`: Navigates to `Collections` with group pre-selected.

# LABEL INVENTORY

* Exact titles: `Performance & Risk Dashboard`, `Today's Repayment Summary`, `Today's Meeting Portfolio`, `Quick Action: Start Collection`, `Today's Savings`, `Today's Repayment Status`, `Cash Position (CO Cashbook)`, `Today's Attention List`.
* Metric labels: `60D / 12W / 3M`, `120D / 24W / 6M`, `Total Repayment Today`, `Savings Deposited`, `Savings Withdrawn`, `Net Savings`, `Full Payment`, `Excess Payment`, `Part Payment`, `Not Paid`, `Opening Balance`, `Cash In`, `Cash Out`, `Closing Balance`, `Cashbook Status`, `Difference`.

# FORM INVENTORY

* None on CO Dashboard (BM Dashboard contains inline approval modals for loan/withdrawal/reversal requests).

# TABLE INVENTORY

1. **Table: Meeting Portfolio**
   * Source: `DashboardService.get_co_dashboard_data["meeting_portfolio"]`
   * Columns: `Group Name`, `Expected`, `Collected`, `Outstanding`, `Compliance %`, `Status`
2. **Table: Attention List**
   * Source: `DashboardService.get_co_dashboard_data["attention_list"]`
   * Columns: `Client Name`, `Group`, `Expected`, `Paid`, `Shortfall`, `Status`

# BUTTON INVENTORY

* `Start {Group Name} ({Status})`: Positioned in Quick Actions below Meeting Portfolio. Sets `st.session_state["Navigation"] = "Collections"` and `st.session_state["sel_group"] = g_name`.

# FILTER INVENTORY

* Date Selector (BM/AM/Admin): Dropdown or calendar picker to view historical dashboard snapshots.

# NAVIGATION BEHAVIOUR

* Default landing page post-authentication.
* Quick Action buttons route directly to `Collections`.

# RBAC BEHAVIOUR

* `CO`: Scoped strictly to own assigned officer ID and branch ID.
* `BM`: Scoped to entire branch (all officers, all groups).
* `AM`: Scoped to all branches in assigned region.
* `Admin` / `Director`: Institution-wide global metrics.

# DATA CONTRACT

* **Endpoint**: `GET /api/v1/co/dashboard`
* **Response**: Contains `welcome`, `branch_closure`, `repayment_summary`, `meeting_portfolio`, `savings`, `repayment_status`, `cash_position`, and `attention_list`.

# WORKFLOW

1. Officer logs in $\rightarrow$ Lands on Dashboard.
2. Officer inspects today's scheduled solidarity meetings and expected targets.
3. Officer clicks `Start {Group Name}` on an active meeting.
4. App transitions directly into the Daily Collections Sheet for that group.

# STATES

* Loading: Spinner.
* Empty: When no groups are scheduled: `No active groups scheduled for today.`
* Success: When attention list is empty: `🎉 All scheduled clients have completed full repayments for today!`
* Error: Red alert box with retry button.

# VISUAL CHARACTERISTICS

* Clean Streamlit card grid, border `#E2E8F0`, rounded 8px.
* Forest Green top welcome banner (`#064E3B`).
* Blue info bar for business date context (`#EFF6FF`).

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L2013–2459.

# PARITY VERIFICATION EVIDENCE (PHASE 3: CREDIT OFFICER DASHBOARD)

* **Visual Parity**: 1:1 match to `app.py` L2383–2458 (Title `Credit Officer Dashboard — {USER} ({BRANCH})`, `st.info` Welcome box with business date and meeting day, `st.warning` branch closure alert, 3 Repayment Summary cards with delta client counts, Meeting Portfolio table with `Start Collection` action buttons, 3 Savings cards, 4-tier Repayment Status cards with inverse red delta on `Not Paid`, 6 Cash Position cards reconciling Account 1000, Attention List table or green completion banner).
* **Functional Parity**: `Start {Group Name}` quick action button sets `selectedCollectionGroup` and triggers navigation to `Collections`.
* **Data Parity**: Direct integration with `GET /api/v1/co/dashboard`. Zero hardcoded business or financial metrics.
* **RBAC Parity**: Credit Officer scope (`OFFICER` level) displaying assigned branch and officer records.
* **Flutter Implementation**: [`frontend_flutter/lib/features/co/presentation/co_dashboard_screen.dart`](file:///c:/Users/DELL/Desktop/Master_%20AY%20Projects/trustmicro-credit/frontend_flutter/lib/features/co/presentation/co_dashboard_screen.dart)
* **Status**: **PARITY VERIFIED (Credit Officer Sub-Dispatch)**

