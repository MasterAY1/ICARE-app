# ICARE Parity Catalogue: Phase 3 — Credit Officer Withdrawal Operations

> [!IMPORTANT]
> **GOVERNANCE DIRECTIVE**:
> This catalogue is the authoritative 1:1 specification for **Phase 3 — Withdrawal Operations** (`app.py` L7260–8801).
> The Flutter implementation must achieve **100% visual, functional, structural, RBAC, and data/financial parity** against the running Streamlit application on `main`. No redesigning, simplifying, renaming, or emojis.

---

## 1. Page Title, Header & Global Metadata

- **Page Title**: `Withdrawal Operations` (`st.title("Withdrawal Operations")`)
- **Header Caption**: `"Submit withdrawal requests for BM approval. All withdrawals require Branch Manager authorization before execution."` (`st.caption(...)`)
- **Flash Message System**:
  - `withdrawal_flash_msg` rendered as green success container upon submission/approval/rejection.
  - `withdrawal_error_msg` rendered as red error alert on failure.
- **Role Permission Check**:
  - If `user_scope.is_read_only()`, render warning: `"Read-Only Access: Your role does not permit withdrawal operations."` and halt rendering (`st.stop()`).

---

## 2. Operational Date & Business Day Gate

- **Operational Date Selector**:
  - Label: `Operational Date for Withdrawals` (`st.date_input`)
  - Default Value: Active Business Date `active_b_date` (or `date.today()`)
  - Key: `wth_operational_date`
  - Help Tooltip: `"Select the date this withdrawal was requested/occurred in the field."`
- **Business Date Closure Invariant**:
  - Checks `BusinessDateService.is_operational_open(uow, branch_id, wth_op_date)`.
  - If operational activity is closed, renders high-priority warning banner:
    > `Operational Activity Suspended ({wth_open_reason}): Savings withdrawals and LAPS payouts are frozen for {wth_op_date}.`

---

## 3. RBAC Scoping & Primary Tab Structure

The primary tabs adapt dynamically based on user role (`is_manager = ROLE in ["BM", "AM", "Branch Manager", "Area Manager", "Admin", "Super Admin"]`):

### A. Credit Officer View (5 Tabs)
1. `Individual Savings`
2. `Group Savings`
3. `Misc Savings` (View-Only notice for CO)
4. `LAPS Savings`
5. `Daily Withdrawals`

### B. Branch Manager / Admin View (6 Tabs)
1. `Individual Savings`
2. `Group Savings`
3. `Misc Savings` (Full withdrawal & offset form)
4. `LAPS Savings`
5. `Pending Approvals ({count})` (Interactive authorization queue)
6. `Daily Withdrawals`

---

## 4. Tab 1: Individual Savings Specification

- **Officer Scope**:
  - For CO: Strictly clients assigned to officer (`clients.officer_id == current_user.id`), excluding `Closed` and `Suspended`.
  - For Manager: `Filter by Credit Officer` dropdown (`All Officers` + list of branch officers).
- **Group Filter**:
  - Label: `Filter by Group` (`st.selectbox`)
  - Options: `All Groups` + disambiguated group list formatted as `{name} (#{group_number} - {meeting_day})` when duplicates exist.
- **Client Search**:
  - Label: `Search Client` (`st.selectbox`)
  - Placeholder: `Type client name or code...`
  - Option Format: `{client_name} ({client_code or client_id[:8]})`
- **Balance KPI Card**:
  - Metric Label: `Individual Savings Balance`
  - Value: `₦{balance:,.2f}` derived from `uow.individual_savings.get_total_balance(client_id=c_id)`.
- **Destination Operation Radio (`Where is the money going?`)**:
  1. `Client Bank Account (Transfer)`
     - Info Box: `Electronic Transfer to Client | Right Side: Product Withdrawal | Left Side: Bank Withdrawal | Vault Cash: ₦0 (Untouched)`
  2. `Loan Repayment / Asset Debt Offset`
     - Info Box: `Non-Cash Debt Offset | Right Side: Product Withdrawal | Left Side: Loan Repayment (rep_*) / Asset Credit | Vault Cash: ₦0 (Untouched)`
     - Sub-Selector: `Target Borrower` radio: `Own Loan` vs `Another Member's Loan`.
     - Target Loan Selector: `Select Target Loan` dropdown (`{prefix}Loan {lid[:8]} — Balance: ₦{bal:,.2f} (Active Credit: ₦{act_cred:,.0f})`).
     - 3 Metric Cards:
       - `Outstanding Balance`: `₦{cur_ld.balance:,.2f}`
       - `Active Credit`: `₦{cur_ld.active_credit:,.2f}`
       - `Total Paid to Date`: `₦{cur_ld.total_repaid:,.2f}`
  3. `Fee Payment from Savings`
     - Info Box: `Non-Cash Fee Payment | Right Side: Product Withdrawal | Left Side: Fee Income | Vault Cash: ₦0 (Untouched)`
     - Fee Type Selector: `Select Fee Type` dropdown (`Credit Form Damage Fee`, `Passbook Fee`, `Application Fee`, `Misc Fee / Penalty`, `Other (Prior Payment Clearance / Shortfall)`).
     - If `other`: Info note explaining that this deducts savings to clear collection cash shortage without inflow.
  4. `Another Member or Group Savings`
     - Info Box: `Non-Cash Savings Reallocation | Right Side: Product Withdrawal | Left Side: Savings Deposit | Vault Cash: ₦0 (Untouched)`
     - Transfer Target Category: `Individual Member` vs `Group Savings`.
     - Recipient Dropdown: Member selector or Group selector.
  5. `LAPS Reserve`
     - Info Box: `Sweep Residual Savings to LAPS Protection Reserve | Right Side: Product Withdrawal | Left Side: LAPS Reserve | Vault Cash: ₦0 (Untouched)`
- **Form Controls (`ind_withdrawal_form`)**:
  - `Amount (₦)` number input (step: 500.0, format: `%.2f`).
  - `Remarks` text area (placeholder: `"Reason or extra details..."`).
  - Manager Checkbox: `Authorize & Post Immediately (Direct BM / Admin Execution)` (default: True, Manager only).
  - Submit Button:
    - If Manager & auto-exec: `Authorize & Post Withdrawal to Ledger` (primary).
    - If CO / non-exec: `Submit for BM Approval` (secondary).
- **Validation Rules**:
  - `amount > 0`
  - `amount <= individual_savings_balance`
  - Must select valid loan if Loan Offset.
  - Must select valid recipient if Transfer.

---

## 5. Tab 2: Group Savings Specification

- **Officer Scope**:
  - For CO: Strictly groups assigned to officer (`groups.officer_id == current_user.id`).
  - For Manager: `Filter by Credit Officer` dropdown.
- **Group Selector**:
  - Label: `Search Group` (`st.selectbox`)
  - Placeholder: `Type group name...`
  - Option Format: Disambiguated group names.
- **Balance KPI Card**:
  - Metric Label: `Group Savings Balance`
  - Value: `₦{balance:,.2f}` derived from `uow.group_savings.get_total_balance(group_id=...)`.
- **Destination Operation Radio (`Where is the money going?`, key `grp_dest_op`)**:
  1. `Group Bank Account (Transfer)`
  2. `Loan Repayment / Asset Debt Offset (Member Debt)`
     - Member Dropdown: `Select Member` from group members.
     - Loan Dropdown: `Select Loan` with 3 metrics (`Outstanding Balance`, `Active Credit`, `Total Paid to Date`).
  3. `Fee Payment from Group Savings`
     - Fee Type Selector + Optional Affected Member Selector.
  4. `Another Member or Group Savings`
     - Transfer Destination Radio: `Group Member` vs `Another Group`.
     - Recipient Selector.
  5. `LAPS Reserve (Group Closed)`
- **Form Controls (`grp_withdrawal_form`)**:
  - `Amount (₦)`, `Remarks`, Manager `Authorize & Post Immediately` checkbox, and Submit button.

---

## 6. Tab 3: Misc Savings Specification

- **Balance Metric**: `Branch Misc Savings Balance`: `₦{misc_bal:,.2f}` derived from `uow.misc_savings.get_total_balance(branch=...)`.
- **RBAC Segmentation**:
  - **Credit Officer**: View-Only! Displays info box:
    > `"Misc Savings is managed by the Branch Manager and the Designated Officer. You can view the balance but cannot submit withdrawals."`
  - **Branch Manager / Admin**: Form enabled with destination options (`Client Bank Account`, `Loan Repayment`, `Fee Payment`, `Savings Transfer`).

---

## 7. Tab 4: LAPS Savings Specification

- **Caption**: `"LAPS records for closed clients and groups. Submit a payout request when a closed client returns to collect their savings."`
- **Record Selector**:
  - Label: `Select LAPS Record` (`st.selectbox`)
  - Options: Records from `laps_savings` with positive balances (`{client_id[:12]}... — Balance: ₦{balance:,.2f}`).
- **Balance Metric**: `LAPS Balance`: `₦{balance:,.2f}`.
- **Form Controls (`laps_payout_form`)**:
  - `Payout Amount (₦)`
  - `Payout Method` radio: `Cash` vs `Bank Transfer`.
    - If `Cash`: Info box: `Product Withdrawal Value: Reduced | Physical Cash Outflow: YES (Vault Cash paid out to client)`
    - If `Bank Transfer`: Info box: `Product Withdrawal Value: Reduced | Physical Cash Outflow: NO (Paid directly via Bank Account)`
  - `Remarks` text area.
  - Submit Button: `Authorize & Post LAPS Payout to Ledger` vs `Submit LAPS Payout for BM Approval`.

---

## 8. Tab 5 (BM Only): Pending Approvals Specification

- **Header / Tab Title**: `Pending Approvals ({count})`
- **Item Card Layout**:
  - Container with border (`st.container(border=True)`).
  - Column 1 (Info, width 3): Client Name, Savings Type, Operation Type, Requested By, Reference Code, Operational Date, Notes.
  - Column 2 (Amount, width 2): Red bold text `₦{amount:,.2f}`, label: `Withdrawal Amount`.
  - Column 3 (Actions, width 2):
    - `Approve` button (primary) -> Executes `SavingsService` domain posting + marks status `APPROVED`.
    - `Reject` button (secondary) -> Expands rejection reason field + `Confirm Rejection` button -> marks status `REJECTED`.

---

## 9. Tab 5 (CO) / Tab 6 (BM): Daily Withdrawals Specification

- **Subheader**: `Daily Withdrawals`
- **Caption**: `"Review all savings withdrawals, upfront loan fee deductions, and request status for your clients."`
- **Filters**:
  - Credit Officer selector (BM only).
  - `Show all dates` checkbox.
  - `Operational Date` date picker (when `Show all dates` is false).
- **Top 5 KPI Metric Cards**:
  1. `Total Withdrawn Today` (or `Total Withdrawn`): `₦{total_withdrawn:,.2f}`
  2. `Loan Fees Deducted`: `₦{upfront_total:,.2f}` (Markup Interest + Gap fees auto-deducted on disbursement)
  3. `Cash & Bank Paid`: `₦{payout_total:,.2f}` (Cash Payout, Bank Transfer, Group Withdrawal)
  4. `Debt & Fee Offsets`: `₦{offset_total:,.2f}` (Loan Offsets, Fee Offsets)
  5. `Waiting for Approval`: `{count} requests`, `₦{pending_amt:,.2f}`
- **List Filter & Search**:
  - `Filter by Type` dropdown: `All Types`, `Loan Fee Deductions`, `Cash & Bank Payouts`, `Loan & Fee Offsets`, `Group Withdrawals`.
  - `Search records` text input: filters by client name, client code, loan ID, reference.
- **4 Subtabs**:
  1. `All Today's Withdrawals ({count})` (or `All Withdrawals`):
     - Table: `Date`, `Client Name`, `Client Code`, `Group`, `Type`, `Amount`, `Details`, `Reference`.
  2. `Loan Fee Deductions ({count})`:
     - Caption: `"When a loan is disbursed, markup interest and gap fees are automatically deducted from the borrower's savings."`
     - Table: `Date`, `Client Name`, `Client Code`, `Loan Reference`, `Interest Deducted`, `Gap Fee Deducted`, `Total Deducted`, `Status` (`Auto-deducted on Disbursement`).
  3. `Cash & Bank Payouts ({count})`:
     - Table: `Date`, `Client / Group`, `Group`, `Payment Type`, `Amount`, `Approval Notes`, `Reference`.
  4. `My Requests & Status ({count})`:
     - Cards showing: Request Name, Type, Op, Reference, Requested By, Date, Remarks, Rejection Reason (if rejected), Authorized By (if approved), Amount (Green if Approved, Red if Rejected, Amber if Pending), Status Badge (`[Approved & Posted]`, `[Rejected]`, `[Waiting for Approval]`).

---

## 10. Financial Ledger Invariants & Double-Entry Impact

Under GEMINI Invariant 1 (`Account 1000 is Financial Source of Truth`):
1. **Physical Cash Payout (LAPS Cash Payout)**:
   - Debit: Account 2000 (Savings Deposits Liability)
   - Credit: Account 1000 (Vault Cash)
   - Physical cash decreases.
2. **Bank Transfer Payout**:
   - Debit: Account 2000 (Savings Deposits Liability)
   - Credit: Account 1010 (Bank Account)
   - Physical cash (Account 1000) is **₦0.00 untouched**.
3. **Loan Repayment / Debt Offset**:
   - Debit: Account 2000 (Savings Deposits Liability)
   - Credit: Account 1200 (Active Loans Receivable)
   - Non-cash internal journal entry. Physical cash is **₦0.00 untouched**.
4. **Fee Payment from Savings**:
   - Debit: Account 2000 (Savings Deposits Liability)
   - Credit: Account 4000 series (Fee Income)
   - Non-cash internal journal entry. Physical cash is **₦0.00 untouched**.

---

## 11. Backend API Endpoint Architecture

| Endpoint | Method | Role | Description |
|---|:---:|:---:|---|
| `/api/v1/co/withdrawals/individual-options` | `GET` | CO, BM, AM | Disambiguated groups, active clients, savings balance, eligible active loans. |
| `/api/v1/co/withdrawals/group-options` | `GET` | CO, BM, AM | Officer-scoped groups, communal balance, members, and eligible loans. |
| `/api/v1/co/withdrawals/misc-balance` | `GET` | All | Branch misc savings balance and role capability notice. |
| `/api/v1/co/withdrawals/laps-options` | `GET` | CO, BM, AM | LAPS records with positive balance available for payout. |
| `/api/v1/co/withdrawals/request` | `POST` | CO, BM, AM | Creates pending withdrawal request or directly executes if BM. |
| `/api/v1/co/withdrawals/daily-withdrawals` | `GET` | CO, BM, AM | Top 5 KPIs, parsed transaction history, loan fee deductions, and request statuses. |
| `/api/v1/co/withdrawals/pending-approvals` | `GET` | BM, AM, Admin | Pending withdrawal queue for Branch Manager. |
| `/api/v1/co/withdrawals/approve` | `POST` | BM, AM, Admin | Approves request, invokes `SavingsService`, posts to ledger. |
| `/api/v1/co/withdrawals/reject` | `POST` | BM, AM, Admin | Rejects request with audit reason. |

---

## 12. Visual Tokens & Zero-Emoji Governance

- Typography: Headings in `Plus Jakarta Sans`, Body in `Source Sans 3`, Monetary values in tabular `JetBrains Mono`.
- Zero-Emoji Governance: Strictly no emoji glyphs.
  - Status badges use clean institutional pills:
    - Approved: Text `#15803D`, BG `#DCFCE7`, Border `#86EFAC`
    - Rejected: Text `#B91C1C`, BG `#FEE2E2`, Border `#FCA5A5`
    - Waiting: Text `#B45309`, BG `#FEF3C7`, Border `#FCD34D`
- Card borders: 1px `#E2E8F0`, flat background `#FFFFFF`, 0px elevation.
