# PAGE IDENTITY

* **Exact page title**: `Daily Collections`
* **Sidebar label**: `Collections`
* **Role(s)**: `Credit Officer`, `Branch Manager`, `Area Manager`, `Administrator`, `Executive Director`
* **Navigation location**: Third menu item for Credit Officer
* **Streamlit source**: `app.py` L4051–5157
* **Relevant line ranges**: L4051–5157

# PAGE PURPOSE

The core daily cash collection engine of the institution. Enables credit officers to record cash loan repayments and voluntary savings deposits/withdrawals for solidarity group members during field meetings, with real-time client balance checks, auto-calculation of excess/shortfall, immutable Account 1000 vault cash ledger posting via `atomic_execute_operations`, historical collection auditing, and error reversal requests.

# PAGE LAYOUT

1. **Header**: `st.title("Daily Collections")` + `st.caption("Record daily repayments and savings.")`
2. **Business Date Bar**: Business date display + `Late Entry / Backdated Entry` toggle.
3. **Closure Warning**: (If closed) `🏖️ Operational Activity Suspended ({open_reason}): Collections locked in Read-Only mode.`
4. **Officer Selector** (BM/AM only): Dropdown to view/enter collections on behalf of branch officers.
5. **Three Main Tabs**:
   * Tab 1: `📝 Record Collections`
   * Tab 2: `📜 Collection History & Audit`
   * Tab 3: `🔄 Error Correction & Reversals`

# SECTION INVENTORY

1. **Tab 1: 📝 Record Collections**
   * Solidarity Group Selector dropdown (auto-fills meeting day & expected roster).
   * Group Roster Table / Dynamic Input Rows (Client Name, Product, Expected Repayment, Actual Repayment Input, Savings Deposit Input, Savings Withdrawal Input, Net Paid, Status Badge).
   * Live Rollup Metric Bar: `Total Repayments`, `Total Savings Inflow`, `Total Savings Outflow`, `Total Vault Cash Collected`.
   * Action: `Submit Collections Batch` button.
2. **Tab 2: 📜 Collection History & Audit**
   * Filter controls: Date picker, Group dropdown, Status filter (`All`, `Completed`, `Reversed`).
   * Audit Dataframe: List of all posted transactions with timestamp, receipt number, client ID, amounts, officer, and posting status.
3. **Tab 3: 🔄 Error Correction & Reversals**
   * Reversal Request Form: Select transaction, enter error reason, select correction type, submit to BM approval queue.
   * My Reversal Requests Status Dataframe.

# UI COMPONENT INVENTORY

* **Toggle**: `Late Entry / Backdated Entry`
* **Group Dropdown**: `Select Group` (Displays group name and meeting day).
* **Roster Data Table / Form Grid**:
  * Member Name
  * Expected Installment (₦)
  * Repayment Input (`number_input`, default = expected)
  * Savings Deposit Input (`number_input`, default = 0)
  * Savings Withdrawal Input (`number_input`, default = 0)
* **Summary KPI Bar**:
  * `Total Expected` (₦)
  * `Actual Repayments` (₦)
  * `Net Savings` (₦)
  * `Total Cash Collected` (₦)
* **Buttons**:
  * `Submit Collections Batch`
  * `Download Master Balancing Template` (Admin)
  * `Submit Reversal Request`

# LABEL INVENTORY

* Page Title: `Daily Collections`
* Subtitle: `Record daily repayments and savings.`
* Tabs: `📝 Record Collections`, `📜 Collection History & Audit`, `🔄 Error Correction & Reversals`
* Inputs: `Select Group`, `Repayment (₦)`, `Savings Deposit (₦)`, `Savings Withdrawal (₦)`
* Rollup Metrics: `Total Expected`, `Actual Repayments`, `Net Savings`, `Total Cash Collected`
* Buttons: `Submit Collections Batch`, `Request Reversal`

# FORM INVENTORY

* **`collection_sheet_form`**: Dynamic tabular grid capturing batch repayments and savings.
* **`reversal_request_form`**: Captures transaction ID, error justification, and correction amount for BM approval.

# TABLE INVENTORY

1. **Group Roster**: Dynamic editable table of group members.
2. **Collection History Dataframe**: Columns `[Receipt No, Date, Client ID, Client Name, Group, Repayment, Savings In, Savings Out, Officer, Status]`.
3. **Reversal Requests Dataframe**: Columns `[Request ID, Date, Client Name, Amount, Reason, BM Status, Approved At]`.

# BUTTON INVENTORY

* `Submit Collections Batch`: Calls atomic transaction engine to write operational records and post Account 1000 journal entries.
* `Submit Reversal Request`: Submits correction request into `correction_requests` table.

# FILTER INVENTORY

* Group Selector: Filters roster by solidarity group.
* Date Selector: Toggled on late entry to record historical collections.
* Officer Filter (BM/AM): Selects officer in branch.

# NAVIGATION BEHAVIOUR

* Supports deep-linking from Dashboard Quick Actions (`session_state["sel_group"]`).

# RBAC BEHAVIOUR

* `CO`: Can record collections and request reversals for own groups.
* `BM`: Can record collections on behalf of officers and approve reversal requests.
* `Admin`: Global access including bulk Excel upload.

# DATA CONTRACT

* `GET /api/v1/co/collections/sheet?group_id={id}&date={date}`
* `POST /api/v1/co/collections/batch-submit`
* `POST /api/v1/co/collections/reversal-request`

# WORKFLOW

1. CO selects group (or arrives via Dashboard Quick Action).
2. System loads group roster with expected installment and savings balance.
3. CO enters collected cash per member.
4. Summary bar updates in real time.
5. CO clicks `Submit Collections Batch`.
6. Atomic RPC executes `atomic_execute_operations` $\rightarrow$ Repayments posted, savings updated, Account 1000 cash debited.
7. Success dialog displays receipt summary.

# STATES

* Locked: `🏖️ Operational Activity Suspended: Collections locked in Read-Only mode.`
* Success: `Batch collections submitted successfully!`
* Error: `Posting failed: [reason]`.

# VISUAL CHARACTERISTICS

* Tabbed interface with large font numerical inputs.
* Live green rollup summary bar for total physical cash in hand.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L4051–5157.
