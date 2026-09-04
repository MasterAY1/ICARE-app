# PAGE IDENTITY

* **Exact page title**: `Withdrawal Operations`
* **Sidebar label**: `Withdrawal Operations`
* **Role(s)**: `Credit Officer`, `Branch Manager`, `Area Manager`, `Administrator`, `Executive Director`
* **Navigation location**: Fourth menu item for Credit Officer
* **Streamlit source**: `app.py` L5158–5588
* **Relevant line ranges**: L5158–5588

# PAGE PURPOSE

Manages client savings withdrawal workflows across 4 distinct savings categories: Individual Savings, Group Savings, Misc Savings, and LAPS Savings. Enforces strict dual-control authorization: Credit Officers initiate withdrawal requests with real-time balance validation, which enter a pending state until authorized by the Branch Manager.

# PAGE LAYOUT

1. **Header**: `st.title("Withdrawal Operations")` + `st.caption("Submit withdrawal requests for BM approval. All withdrawals require Branch Manager authorization before execution.")`
2. **Read-Only / Closure Guard**: Fails closed if role lacks write access or branch is closed.
3. **Four Main Tabs**:
   * Tab 1: `Individual Savings`
   * Tab 2: `Group Savings`
   * Tab 3: `Misc Savings`
   * Tab 4: `LAPS Savings`

# SECTION INVENTORY

1. **Tab 1: Individual Savings**
   * Filter controls: Officer filter (for BM/AM), Solidarity Group filter.
   * Client Lookup dropdown: Shows Client ID, Full Name, and Group.
   * Client Financial Position Card: Displays Total Cumulative Savings (₦), Active Loan Balance (₦), and Maximum Allowable Withdrawal (₦).
   * Request Form: Withdrawal Amount (₦), Reason / Narrative text, `Submit Individual Withdrawal Request` button.
2. **Tab 2: Group Savings**
   * Group Selector: Displays group name, assigned officer, total collective group savings balance.
   * Request Form: Withdrawal Amount, Purpose, `Submit Group Withdrawal Request`.
3. **Tab 3: Misc Savings**
   * Client Lookup, Miscellaneous Balance, Request Amount, Purpose, Submission.
4. **Tab 4: LAPS Savings**
   * Loan Asset Protection Scheme balance inquiry and payout submission for matured/completed loan cycles.

# UI COMPONENT INVENTORY

* **Savings Category Tabs**: 4 tabs (`Individual Savings`, `Group Savings`, `Misc Savings`, `LAPS Savings`).
* **Filters**: `Filter by Credit Officer`, `Filter by Group`.
* **Balance Metric Display**: Blue card showing `Available Savings Balance` (₦).
* **Inputs**:
  * `Client Selector` (Dropdown with searchable name/code)
  * `Withdrawal Amount (₦)` (`number_input` with min=100, max=available balance)
  * `Reason / Narrative` (`text_area`)
* **Submit Buttons**: `Submit Individual Withdrawal Request`, `Submit Group Withdrawal Request`, `Submit Misc Withdrawal Request`, `Submit LAPS Withdrawal Request`.

# LABEL INVENTORY

* Page Title: `Withdrawal Operations`
* Subtitle: `Submit withdrawal requests for BM approval. All withdrawals require Branch Manager authorization before execution.`
* Tabs: `Individual Savings`, `Group Savings`, `Misc Savings`, `LAPS Savings`
* Labels: `Filter by Credit Officer`, `Filter by Group`, `Select Client`, `Available Savings Balance`, `Withdrawal Amount (₦)`, `Reason for Withdrawal`
* Warnings: `🏖️ Operational Activity Suspended: Savings withdrawals and LAPS payouts are frozen today.`
* Error: `Withdrawal amount cannot exceed available balance.`

# FORM INVENTORY

* **`ind_withdrawal_form`**: Submits individual savings withdrawal request.
* **`group_withdrawal_form`**: Submits group collective withdrawal request.
* **`misc_withdrawal_form`**: Submits miscellaneous savings withdrawal request.
* **`laps_withdrawal_form`**: Submits LAPS refund/payout request.

# TABLE INVENTORY

* Recent Withdrawal Requests Queue: Columns `[Request ID, Date, Client/Group, Type, Amount (₦), Status, BM Approval Date]`.

# BUTTON INVENTORY

* `Submit Individual Withdrawal Request`: Inserts record in `withdrawal_requests` with status `Pending BM Approval`.
* `Submit Group Withdrawal Request`: Inserts group withdrawal record.

# FILTER INVENTORY

* Officer Filter: Filters client list by assigned Credit Officer.
* Group Filter: Filters client list by solidarity group.

# NAVIGATION BEHAVIOUR

* Fourth option in Credit Officer sidebar.
* Post-submission displays green success banner and refreshes eligible client balance.

# RBAC BEHAVIOUR

* `CO`: Initiates withdrawal requests for own clients.
* `BM` / `Admin`: Authorizes or rejects pending withdrawal requests in BM Dashboard.

# DATA CONTRACT

* `GET /api/v1/co/withdrawals/eligible-clients?group_id={id}`
* `POST /api/v1/co/withdrawals/request`

# WORKFLOW

1. CO opens `Withdrawal Operations` $\rightarrow$ Selects `Individual Savings`.
2. CO filters by group $\rightarrow$ Selects client.
3. System fetches real-time savings balance from `individual_savings` table.
4. CO inputs requested amount ($\le$ available balance) and narrative reason.
5. CO clicks `Submit Individual Withdrawal Request`.
6. Record created in `withdrawal_requests` (Status: `Pending`).
7. BM reviews and authorizes in BM Dashboard $\rightarrow$ Physical vault cash disbursed $\rightarrow$ Account 1000 journal entry posted.

# STATES

* Suspended: `🏖️ Operational Activity Suspended: Savings withdrawals frozen today.`
* Insufficient Balance: `Error: Withdrawal amount exceeds available balance of ₦X,XXX.`
* Success: `Withdrawal request for ₦X,XXX submitted for Branch Manager approval.`

# VISUAL CHARACTERISTICS

* Tabbed categories with clear available balance indicators.
* Clean inputs with currency formatting.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L5158–5588.
