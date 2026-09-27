# Parity Catalogue: 02 — Credit Officer Daily Collections

**Source Implementation**: `app.py` L4840–7259  
**Navigation Source**: `app.py` L2367, `ROLE_NAVIGATION[CO]` (`Collections`)  
**Backend Service Authority**: 
- `services/business_date_service.py` (`BusinessDateService.is_operational_open`, `get_business_date`)
- `services/schedule_service.py` (`ScheduleService.get_loan_due_breakdown`, `get_total_paid`)
- `services/repayment_service.py` (`RepaymentService.classify_repayment`)
- `services/correction_service.py` (`CorrectionService.request_correction`)
- `services/posting_engine.py` / `save_repayments` (Account 1000 atomic ledger execution)
**Target Screen**: `frontend_flutter/lib/features/co/presentation/daily_collections_screen.dart`  
**API Routes**: 
- `GET /api/v1/co/collections/sheet`
- `POST /api/v1/co/collections/batch-submit`
- `POST /api/v1/co/collections/reversal-request`
- `GET /api/v1/co/collections/history` (Audit and historical records)

---

## 1. Page Title & Identity
* **Exact Title**: `Daily Collections` (`st.title(Daily Collections)`, `app.py` L4841)
* **Caption**: `Record daily repayments and savings.` (`st.caption(Record daily repayments and savings.)`, L4842)
* **Top Control Bar**:
  - `Late Entry / Backdated Entry` toggle switch (`st.toggle(Late Entry / Backdated Entry)`, L4848)
  - If toggle active: `Select Date` date input (`st.date_input(Select Date, active_b_date)`, L4850)
  - If toggle inactive: Info banner: `Operational Business Date: **{DD Month YYYY}** ({DayName})` (`st.info(...)`, L4853)
* **Manager Role Target Officer Selector** (BM/AM/Admin only):
  - `Select Credit Officer` dropdown (`st.selectbox(Select Credit Officer, ...)`, L4882)

---

## 2. Section Titles & Navigation Structure
* **Three Primary Tabs** (`st.tabs(...)`, `app.py` L4976):
  1. `Record Collections`
  2. `Collection History & Audit`
  3. `Error Correction & Reversals`
* **Tab 1: Record Collections Modes** (`st.radio(Collection Mode, ...)`, L4992):
  - `Group Collection Sheet` (Primary mode for daily meeting collections)
  - `Single Client Quick Entry` (Ad-hoc member collection)
  - `Bulk Upload (Excel Template)` (Admin / Super Admin only)
* **Tab 1 Sections**:
  - `Persistent Collection Receipt Confirmation Card` (Renders when `collection_receipt` session state exists, L4889–4975)
  - Mode 1: `Group Collection Sheet` (`st.markdown(### Group Collection Sheet)`, L5523)
    - Expander: `Group Collection CSV Manifest (Download & Upload)` (L5784)
    - Section Header: `Members in {selected_group}` (L6009)
    - Sub-Header: `Member Collections` (L6147)
    - Staging Screen: `Review Group Collections` (L6012)
  - Mode 2: `Single Client Quick Entry` (`st.markdown(### Single Client Collection / Savings Deposit)`, L5249)
    - Caption: `Record an ad-hoc savings deposit, loan repayment, or fee for an individual member without affecting other group records.` (L5250)
    - Expander: `Additional Fees (Optional)` (L5367)
* **Tab 2: Collection History & Audit Sections**:
  - Header: `Collection History & Audit` (L6382)
  - Caption: `Inspect all daily repayments and savings deposits posted by Credit Officers.` (L6383)
  - Filter Controls: `Filter Date`, `Filter Officer` (BM/AM), `Search Client Name / Code / Note` (L6387–6398)
  - Top Metric Summary (3 KPI Columns, L6581)
  - Three Subtabs (L6742):
    1. `Group Collections ({count})`
    2. `Loan Repayments ({count})`
    3. `Savings Deposits ({count})`
  - EOD Summary inside Group Subtab: `End of Day (EOD) Inputs & Fee Summary` (L6800)
  - Historical Log inside Group Subtab: Expander `Daily EOD Inputs History Log` (L6815)
  - Audit Trail Expander: `Reversed Records on this Date (Audit Trail: {count})` (L6949)
* **Tab 3: Error Correction & Reversal Hub Sections**:
  - Header: `Error Correction & Reversal Hub` (L6980)
  - Caption: `Flag an erroneous collection (loan repayment or savings deposit) for Branch Manager approval.` (L6981)
  - Section Header: `Selected Transaction Details` (L7195)
  - Bottom Section: `Submitted Reversal Requests` (L7229)

---

## 3. Labels & Metric Cards
### Tab 1: Persistent Collection Receipt (Header Metrics)
| Metric Label | Value Format | Subtitle / Note |
|---|---|---|
| `Batch Reference` | `{batch_id}` | e.g. `COL-2026-09-16-ABCD12` |
| `Group / Source` | `{group_name}` | e.g. `Unity Group` |
| `Officer / Branch` | `{officer} ({branch})` | e.g. `CO1 (Ogijo)` |
| `Recorded At` | `{DD Mon YYYY, hh:mm A}` | Timestamp |
| `Total Cash Collected` | `₦{total_cash:,.2f}` | Grand physical cash inflow |
| `Loan Repayments` | `₦{total_repayment:,.2f}` | Repayments total |
| `Savings Deposits` | `₦{total_savings:,.2f}` | Individual & communal savings |
| `Members Processed` | `{total_submitted} records` | Total transactions recorded |

### Tab 1: Group Collection Sheet — Communal Savings Row
* Label: `**Group Communal Savings** · Available: ₦{group_savings_balance:,.0f}`
* Caption: `Communal group contribution`
* Input: `Group Savings (₦)` (step: 500, placeholder: 0)

### Tab 1: Review Group Collections Staging Banners
* Info Banner: `**Total Money Collected (Cash In):** ₦{total_in:,.0f}`
* Warning Banner: `**Total Money Given Out (Cash Out):** ₦{total_out:,.0f}`
* Success Banner: `**NET CASH EXPECTED FROM GROUP:** ₦{net_cash:,.0f}`
* Caption Note: `**Total Net Savings:** ₦{total_net_savings:,.0f} *(Includes Individual & Group Savings)*`

### Tab 1: Single Client Overview Cards
* In-Group Client (4 Cards):
  1. `Group Name`: `{group_name}`
  2. `Personal Savings`: `₦{savings_bal:,.2f}`
  3. `Group Savings Fund`: `₦{grp_savings_bal:,.2f}`
  4. `Outstanding Loan`: `₦{rem_bal:,.2f}` (or `No Active Loan`)
* Ungrouped Client (3 Cards):
  1. `Membership`: `Individual (Ungrouped)`
  2. `Personal Savings`: `₦{savings_bal:,.2f}`
  3. `Outstanding Loan`: `₦{rem_bal:,.2f}` (or `No Active Loan`)

### Tab 2: Collection History Top KPIs (3 Cards)
| Card Label | Value Format | Delta / Subtitle |
|---|---|---|
| `Total Repayments Collected` | `₦{tot_reps:,.2f}` | `{paid_cnt} Paid, {not_paid_cnt} Not Paid` |
| `Total Savings Deposited` | `₦{tot_sav:,.2f}` | `{count} Deposits` |
| `Grand Total Cash Collected` | `₦{grand_total:,.2f}` | `Total Physical Inflow` |

### Tab 2: Group Collections Subtab KPIs (4 Cards)
| Card Label | Value Format | Delta / Subtitle |
|---|---|---|
| `Total Group Repayments` | `₦{sum_reps:,.2f}` | `{count} Loan Records` |
| `Total Group Savings` | `₦{sum_sav:,.2f}` | `{count} Savings Records` |
| `Grand Total Collections` | `₦{sum_tot:,.2f}` | `Total Group Inflow` |
| `Active Groups` | `{count} Groups` | `With Activity Today` |

### Tab 2: EOD Inputs & Fee Summary (8 Metric Cards)
Row 1:
1. `B/F Opening Cash`: `₦{opening:,.2f}`
2. `Bank Deposited`: `₦{bank_deposit:,.2f}`
3. `Office Expenses`: `₦{expenses:,.2f}`
4. `Credit Form / App Fee`: `₦{app_fee:,.2f}`
Row 2:
5. `Passbook Fees`: `₦{passbook:,.2f}`
6. `Misc Fees`: `₦{misc:,.2f}`
7. `Credit Form Damage`: `₦{cfd:,.2f}`
8. `Staff Bonus`: `₦{bonus:,.2f}`

### Tab 3: Selected Transaction Reversal Card (3 Cards)
1. `Amount`: `₦{amount:,.2f}`
2. `Client Code`: `{client_code}`
3. `Date`: `{date}`
Subtitle: `Client Name: {name} | Category: {category} • Full Ref ID: {ref} • Note: {note}`

---

## 4. Buttons & Quick Actions
* **Tab 1: Member Card Action**:
  - `Mark ₦0 (Arrears)` checkbox (`app.py` L6198)
* **Tab 1: Group Form Submission Action**:
  - Button: `Calculate Totals & Review Members` (primary, full width, L6243)
* **Tab 1: Staging Review Actions**:
  - Button: `Edit / Go Back` (secondary, L6077)
  - Button: `Confirm & Save Collections` (primary, full width, L6081)
* **Tab 1: Persistent Receipt Actions**:
  - Button: `Record Next Group / Return to Collections` (primary, full width, L4951)
  - Expander: `View / Copy WhatsApp Summary` containing formatted text receipt (L4973)
* **Tab 1: Single Client Form Submission Action**:
  - Button: `Post Client Transaction` (primary, full width, L5375)
* **Tab 2: Audit Trail Expander Actions**:
  - Expander toggle for each group: `{Group Name} — Total: {Amount} ({Count} Records)` (L6771)
* **Tab 3: Error Correction Submission Action**:
  - Button: `Submit Reversal Request to BM` (primary, L7204)

---

## 5. Tables & Columns
### Table 1: Persistent Receipt — Member Verification Breakdown (Expander)
* Rendered via `st.dataframe(..., hide_index=True)`
* Columns:
  1. `Client / Member` (string, left-aligned)
  2. `Repayment (₦)` (currency, right-aligned)
  3. `Savings (₦)` (currency, right-aligned)
  4. `Posting Status` (string, e.g. `POSTED`)

### Table 2: Group Collection Sheet — Review Staging Table
* Rendered before final save (`app.py` L6071)
* Columns:
  1. `Client` (string, e.g. `Adewa Dorcas (OGI-001)`)
  2. `Savings (₦)` (currency, e.g. `₦1,000` or `-`)
  3. `Repayment (₦)` (currency, e.g. `₦2,500` or `₦0 (Expected ₦2,500)`)
  4. `Status` (badge text, e.g. `FULL PAID`, `PART PAID (₦500 Arrears)`, `NOT PAID (₦2,500 Arrears)`, `EXCESS (₦1,000 Advance)`)

### Table 3: Tab 2 — Group Collections Summary
* Rendered in Subtab 0 (`app.py` L6765)
* Columns:
  1. `Group Name` (string)
  2. `Total Repayment (₦)` (currency)
  3. `Member Savings (₦)` (currency)
  4. `Group Savings (₦)` (currency)
  5. `Total Savings (₦)` (currency)
  6. `Grand Total Collected (₦)` (currency, bold)
  7. `Paying Members` (string, e.g. `12 Clients`)

### Table 4: Tab 2 — Group Itemized Breakdown (Inside Expander)
* Rendered per group (`app.py` L6775)
* Columns:
  1. `Client Name` (string)
  2. `Client Code` (string)
  3. `Type` (string: `Loan Repayment`, `Member Savings`, `Group Savings`)
  4. `Product` (string)
  5. `Expected (₦)` (currency)
  6. `Amount Paid (₦)` (currency)
  7. `Status` (string)
  8. `Time` (string, `HH:MM`)
  9. `Officer` (string)

### Table 5: Tab 2 — Daily EOD Inputs History Log (Expander)
* Rendered in Subtab 0 (`app.py` L6841)
* Columns: `Date`, `Officer`, `B/F Cash`, `Bank Deposit`, `Expenses`, `App Fee`, `Passbook`, `Misc Fees`, `Form Damage`, `Bonus`, `Closing Cash`

### Table 6: Tab 2 — Loan Repayments Subtab
* Rendered in Subtab 1 (`app.py` L6900)
* Columns: `Time`, `Officer`, `Client Name`, `Client Code`, `Product`, `Expected (₦)`, `Amount Paid (₦)`, `Status`, `Note / Type`, `Ref ID`

### Table 7: Tab 2 — Savings Deposits Subtab
* Rendered in Subtab 2 (`app.py` L6940)
* Columns: `Time`, `Officer`, `Client Name`, `Client Code`, `Deposit Amount (₦)`, `Remarks / Reference`, `Ref ID`

### Table 8: Tab 2 — Reversed Records on this Date (Audit Trail Expander)
* Rendered in collapsed expander (`app.py` L6977)
* Columns: `Type`, `Client`, `Amount`, `Status` (`Reversed`), `Ref ID`, `Note / Reason`

### Table 9: Tab 3 — Submitted Reversal Requests Table
* Rendered in Tab 3 (`app.py` L7256)
* Columns: `Date`, `Type`, `Record Ref`, `Reason`, `Status`, `Approved By`

---

## 6. Filters, Tabs & Forms
* **Tab 1 Form**: `collections_form` containing member expanders, communal group savings input, and `Calculate Totals & Review Members` button.
* **Tab 1 Single Client Form**: `single_client_collection_form` containing client picker, loan picker (if multiple), deposit/repayment inputs, optional fee expander, note input, and `Post Client Transaction` button.
* **Tab 2 Filters**:
  - `Filter Date` (`st.date_input`)
  - `Filter Officer` (`st.selectbox` for BM/AM/Admin)
  - `Search Client Name / Code / Note` (`st.text_input`)
* **Tab 3 Filters**:
  - Radio: `Select Category` (`Loan Repayments` / `Savings Deposits`)
  - `Transaction Date` (`st.date_input`)
  - `Filter by Client Name / Code / Ref (Optional)` (`st.text_input`)
  - `All Recent (Last 14 Days)` (`st.checkbox`)

---

## 7. Status Indicators & Badges
* **Repayment Classifications** (`services/repayment_service.py`):
  - `FULL PAID` / `PAID`: `#16A34A` green badge.
  - `PART PAID`: `#D97706` amber badge (e.g. `PART PAID (₦X Arrears)`).
  - `NOT PAID`: `#DC2626` red badge (e.g. `NOT PAID (₦X Arrears)`).
  - `EXCESS`: `#2563EB` blue badge (e.g. `EXCESS (₦X Advance)`).
  - `SAVINGS DEPOSIT`: `#059669` emerald badge.
  - `GROUP SAVINGS`: `#0284C7` sky blue badge.
* **Reversal Request Statuses**:
  - `Pending`: `#D97706` amber.
  - `Approved`: `#16A34A` green.
  - `Rejected`: `#DC2626` red.
* **Strict Zero-Emoji Directive**: No emojis anywhere in badges, tabs, headers, or buttons.

---

## 8. Colours & Styling Tokens
* **Background Canvas**: `#F8FAFC`
* **Card Surface**: `#FFFFFF`, `border: 1px solid #E2E8F0`, `border-radius: 8px`
* **Receipt Card**:
  - Border: `2px solid #22C55E`
  - Background: `#F0FDF4`
  - Heading: `#15803D`
  - Body: `#166534`
* **Accent Colors**:
  - Primary Emerald: `#064E3B` / `#065F46`
  - Primary Action Blue: `#2563EB`
  - Warning Alert: `#FFFBEB` bg, `#FDE68A` border, `#92400E` text
  - Danger Alert: `#FEF2F2` bg, `#FCA5A5` border, `#DC2626` text
  - Success Alert: `#F0FDF4` bg, `#BBF7D0` border, `#166534` text

---

## 9. Typography
* **Page & Section Headings**: `Plus Jakarta Sans`, 600/700 weight
* **Body Text & Captions**: `Source Sans 3` / System sans-serif, 400/500 weight
* **Financial Figures & Codes**: `JetBrains Mono` / Monospace tabular numbers, 600 weight

---

## 10. Icons
* Strictly zero emojis (GEMINI Rule 10).
* Clean SVG / Material icons:
  - Check circle SVG (`Icons.check_circle_outline`) for confirmations
  - Alert warning SVG (`Icons.warning_amber_rounded`) for arrears/suspensions
  - Search icon (`Icons.search`)
  - Date calendar icon (`Icons.calendar_today`)

---

## 11. Layout & Spacing
* Content Container: Full container width with 24px padding.
* Member Card Spacing: 12px vertical spacing between member rows/expanders.
* Side-by-side inputs: 12px to 16px horizontal spacing between Loan Repayment (Left) and Savings Deposit (Right).
* Review screen: Clear summary cards stacked before the review table, followed by the two action buttons.

---

## 12. Empty States
* Tab 1: `No active members in this group.` (`st.info(...)`, L5565)
* Tab 1 Single Client: `No registered active clients found.` (L5253)
* Tab 2 Group Collections: `No group collections found for {date}.` (L6777)
* Tab 2 Loan Repayments: `No loan repayments recorded on {date}.` (L6904)
* Tab 2 Savings: `No savings deposits recorded on {date}.` (L6944)
* Tab 3 Search: `No {category} found for {date} matching your criteria.` (L7225)
* Tab 3 Reversals: `You have not submitted any reversal requests yet.` (L7258)

---

## 13. Error States
* Missing amount in single client: `Please enter a Personal Savings Deposit, Group Savings Deposit, Loan Repayment, or Fee amount greater than ₦0.` (L5386)
* Suspended activity warning: `Cannot submit new collections today ({open_reason}). Switch to the active business date or enable Late Entry.` (L6241)
* Missing reversal reason: `Please provide a valid reason for the reversal.` (L7222)
* Backend network or atomic commit error: Red error card with exact error detail.

---

## 14. Success States & Receipt Confirmation
* **Persistent Receipt Confirmation**:
  - Trigger: Successful commit of collections batch.
  - State: Remains displayed until the user clicks `Record Next Group / Return to Collections`.
  - Header: `COLLECTION SAVED & CONFIRMED IN GENERAL LEDGER`
  - Subtitle: `All repayments and savings deposits have been committed to the database and physical cash recorded in Account 1000.`
* **Single Client Success**:
  - Redirects to receipt view with single client breakdown.
* **Reversal Request Success**:
  - `Reversal request submitted to Branch Manager for approval! (Ref: #{req_id[:8]})`

---

## 15. Conditional States (Suspended Activity / Late Entry)
* **Trigger**: Branch operational day is closed (`is_operational_open == False`) and `Late Entry / Backdated Entry` toggle is OFF.
* **UI State**:
  - Top alert: `Operational Activity Suspended ({open_reason}): Collections for {date} are locked in Read-Only mode.`
  - Form submit button disabled or replaced with lock warning: `Cannot submit new collections today ({open_reason}).`
  - Review screen Confirm button locked with error notice: `Operational activity suspended ({open_reason}). Entries are locked.`

---

## 16. Calculations (Server-Side Authority)
* **Loan Repayment Due & Schedule**:
  - `ScheduleService.get_loan_due_breakdown(uow, loan_id, view_date)` computes `total_due_today`, `overdue_arrears`, `current_installment`, `has_overdue`.
* **Repayment Classification & Arrears**:
  - `RepaymentService.classify_repayment(...)` computes authoritative `status` (`PAID`, `PART_PAID`, `NOT_PAID`, `EXCESS`) and `overdue_shortfall`.
* **Savings Balances**:
  - Queried directly from `individual_savings` and `group_savings` tables.
* **Financial Ledger Posting**:
  - Committed atomically to Account 1000 via `save_repayments`.

---

## 17. Navigation & RBAC Visibility
* **Role Visibility**:
  - `Credit Officer` (`CO`): Restricted to own assigned groups and clients (`officer_id == USER_ID`).
  - `Branch Manager` (`BM`): Scoped to branch; can select officer from branch officer dropdown.
  - `Area Manager` (`AM`): Scoped to assigned branches in region.
  - `Admin` / `Super Admin`: Full system scope; has extra mode `Bulk Upload (Excel Template)`.

---

## 18. Required API Contract
* **Collection Sheet Endpoint**: `GET /api/v1/co/collections/sheet?group_name={name}&date={YYYY-MM-DD}`
  - Returns: `group_name`, `date`, `meeting_day`, `is_open`, `open_reason`, `members: [CollectionSheetMember]`
* **Batch Submit Endpoint**: `POST /api/v1/co/collections/batch-submit`
  - Body: `BatchCollectionInput` (`group_name`, `date`, `collections`, `group_savings_deposit`, `group_savings_withdrawal`)
  - Returns: `BatchCollectionResponse` (`success`, `total_cash_in`, `total_repayments`, `total_savings`, `items_processed`, `message`)
* **Reversal Request Endpoint**: `POST /api/v1/co/collections/reversal-request`
  - Body: `ReversalRequestInput` (`record_id`, `record_type`, `reason`)
  - Returns: `ReversalRequestResponse` (`success`, `request_id`, `status`, `message`)
* **History Endpoint**: `GET /api/v1/co/collections/history?date={YYYY-MM-DD}&officer_id={id}&search={term}`
  - Returns: `repayments`, `savings`, `group_savings`, `eod_summary`, `reversals`
