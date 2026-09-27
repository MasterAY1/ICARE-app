# Phase 6 Authoritative Catalogue: Loan Origination & Registration

> [!IMPORTANT]
> **GOVERNANCE DIRECTIVE**: This catalogue documents the authoritative visual, behavioural, structural, RBAC, data, and financial requirements for Loan Origination & Registration derived from `app.py` L3217–4838.

---

## 1. Page Identity & Role Scoping

| Attribute | Specification |
|---|---|
| **Title** | `Origination & Registration` |
| **Subtitle** | `Client Onboarding, Loan Applications, Disbursements, and Profile Management` |
| **Sidebar Label** | `Loan Origination` / `Origination` |
| **Streamlit Source** | `app.py` L3217–4838 |
| **Role Scoping** | **CO**: Scoped to assigned solidarity groups and registered clients; view-only notice for Pending Disbursements activation.<br>**BM / Admin / AM**: Access full branch portfolio; authorization privilege to activate and disburse pending loans. |

---

## 2. Navigation Architecture

*Horizontal radio navigation bar (`st.radio("Navigate", ["Client Registration", "Loan Application", "Pending Disbursements", "Edit Client & Guarantor"])`)*

| Tab Index | Section Name | Target Flow |
|---|---|---|
| **Tab 1** | `Client Registration` | Register new individual clients or solidarity group members; create groups dynamically. |
| **Tab 2** | `Loan Application` | Search client, review profile & savings, configure loan terms (Finance vs Asset), evaluate renewal eligibility, submit for BM approval. |
| **Tab 3** | `Pending Disbursements` | Review queued applications in `Pending` status; Checker action for BM/AM/Admin to authorize and activate cash disbursement. |
| **Tab 4** | `Edit Client & Guarantor` | Search existing client, inspect and update client personal info, ID documents, and guarantor records across tables. |

---

## 3. Tab 1: Client Registration Specifications

### A. Method Selection
- **Role Scoping**: Admins/Super Admins see radio toggle between `Single Client` and `Bulk Onboarding`. For CO, BM, and AM, defaults directly to `Single Client`.

### B. Solidarity Group Assignment
- **Mode Dropdown**: `Individual (No Group)`, `+ Create New Group`, or existing active branch groups.
- **Disambiguation Rule**: Duplicate group names are disambiguated as `{Group Name} (#{Group Number} - {Meeting Day})`.
- **New Group Creation**: When `+ Create New Group` is selected, reveals 3 inputs:
  1. `New Group Name` (text, e.g. "Alaba Traders")
  2. `New Group Number (2-digits)` (text, e.g. "01")
  3. `Meeting Day` (select: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday, Daily)
- **Existing Group Selection**: Displays informative banner: `Selected group '{name}' (Code: {number}) meets on {meeting_day}`.

### C. Personal Info & Registration Date Form
- **Registration Date**: Date input (defaults to active operational business date via `BusinessDateService.get_business_date`).
- **Fields (3-column grid)**:
  - Row 1: `Full Name` (required), `Nickname`, `Phone Number` (required)
  - Row 2: `Home Address` (full width)
  - Row 3: `Marital Status` (`Single`, `Married`, `Divorced`, `Widowed`), `Business Type` (default "Trader"), `Average Monthly Income (₦)` (step 5,000)
  - Row 4: `Business Address`, `Other Financial Obligations (if any)`
- **Means of Identification**:
  - `Means of ID`: `National ID (NIN)`, `Voter's Card`, `Driver's License`, `International Passport`, `None`
  - `ID Number`: Text input
  - `Upload ID Document`: File uploader (`.jpg`, `.jpeg`, `.png`, `.pdf`)
  - `Passport Photograph`: File uploader (`.jpg`, `.jpeg`, `.png`)

### D. Guarantor Info Form
- **Fields (3-column grid)**:
  - Row 1: `Guarantor Full Name`, `Guarantor Nickname`, `Guarantor Phone`
  - Row 2: `Guarantor Home Address` (full width)
  - Row 3: `Guarantor Marital Status`, `Guarantor Occupation`, `Relationship with Client`
  - Row 4: `Guarantor Office Address`
- **Guarantor Identification**:
  - `Guarantor Means of ID`, `Guarantor ID Number`
  - `Upload Guarantor ID Document`, `Upload Guarantor Passport Photograph`

### E. Action & Persistence Rules
- **Submit Action**: Button `Register Client` (primary, full width).
- **Client ID Generation**:
  - Individual: `{BRANCH_CODE}-IND-{SEQ_3_DIGITS}`
  - Group: `{BRANCH_CODE}-{GROUP_CODE_2_DIGITS}-{SEQ_3_DIGITS}`
- **Database Postings**:
  1. Create group in `groups` if `+ Create New Group` was selected.
  2. Insert record into `clients` with initial status `11111111-1111-1111-1111-111111110001` (`Registered`).
  3. Insert membership into `client_memberships`.
  4. Create guarantor record in `guarantors` and link.
  5. Create baseline placeholder loan row with guarantor extra fields (`app.py` L3575-3612).
- **Success Feedback**: `Successfully registered {name}! Assigned Client ID: {generated_client_code}`.

---

## 4. Tab 2: Loan Application Specifications

### A. Client Search & Profile Summary
- **Client Search**: Text input `Search Client by Name or Client ID`.
  - Filters matching clients with RBAC hierarchy: CO restricted to assigned clients (`officer_id`), BM restricted to branch (`branch_id`), AM restricted to assigned branches.
  - Dropdown selector: `{client_code} - {name}`.
- **Profile Summary Banner**:
  - Row 1: `Client ID`, `Full Name`, `Phone`
  - Row 2: `Branch`, `Group`, `Credit Officer`
  - Row 3: `Guarantor Details` (`Name`, `Phone`, `Relationship`)
- **Pooled Savings Balance Banner**:
  - Displays: `Current Pooled Savings Balance: ₦{savings_bal:,.2f}`.

### B. Loan Product Configuration
- **Product Category**: `Finance` vs `Asset`.
- **Loan Products**:
  - Finance: `Daily 60 Days`, `Daily 120 Days`, `Weekly 12W`, `Weekly 24W`, `Monthly 3M`, `Monthly 6M`.
  - Asset: `60-Day Asset`, `120-Day Asset`, `Weekly 12W Asset`, `Weekly 24W Asset`, `Monthly 3M Asset`, `Monthly 6M Asset`, `Cash and Carry`.
- **Requested Amount / Asset Cost**: Currency number input (step 10,000).
- **Interest Rates & Durations**:
  - 60-Day / 12W / 3M: Rate = 12% (`0.12`).
  - 120-Day / 24W / 6M: Rate = 21% (`0.21`).
  - Cash and Carry: Rate = 0% (`0.0`), Duration = 1.

### C. Live Renewal Eligibility Checker
- Evaluated via `RenewalService.check_eligibility(uow, client_id, requested_amount, product_type, product_category)`.
- If eligible: Green alert box `ELIGIBLE: {reason}` + optional warnings.
- If ineligible: Red alert box `NOT ELIGIBLE:` with bulleted failure reasons + warnings.

### D. Asset Loan Downpayment Rules
- **Downpayment Source**: Radio `Cash (Physical Payment)`, `Savings (Deduct from Pooled Savings)`, `Split (Part Cash, Part Savings)`.
- **Mathematical Formulations**:
  - $\text{Total Cost} = \text{Requested Amount} + \text{Interest}$
  - $\text{Initial Downpayment} = \text{Cash Downpayment} + \text{Savings Downpayment}$
  - $\text{Active Loan} = \text{Total Cost} - \text{Initial Downpayment}$
  - $\text{Expected Installment} = \frac{\text{Active Loan}}{\text{Duration}}$
- **Savings Check**: If $\text{Savings Downpayment} > \text{Savings Balance}$, display error banner and block submission.

### E. Finance Loan Upfront & Gap Fee Rules
- **Gap Fee / Base Savings**: Calculated via modulo rounding step ($50$ or $1,000$ for weekly).
- **Mathematical Formulations**:
  - $\text{Interest} = \text{Requested Amount} \times \text{Rate}$
  - $\text{Total Upfront Required} = \text{Interest} + \text{Gap Fee}$
  - $\text{Active Credit} = \text{Requested Amount} - \text{Gap Fee}$
  - $\text{Expected Installment} = \frac{\text{Active Credit}}{\text{Duration}}$
  - $\text{Total Payable} = \text{Requested Amount} + \text{Interest}$
- **Savings Check**: If $\text{Total Upfront Required} > \text{Savings Balance}$, display error banner and block submission.

### F. Application Submission & Auto-Heal
- **Active Loan Check & Auto-Heal (`BR-CLI-005`)**: Checks if client has an existing Active or Pending loan in the same category. If an Active loan has $\text{Total Due} - \text{Total Paid} \le 0$, automatically heals by transitioning the loan and client status to `Completed`. If unpaid balance remains, blocks submission.
- **Application Date**: Date input (default active business date).
- **Remarks / Notes**: Text area.
- **Submit Action**: `Submit Application for BM Approval` (primary).
  - Creates Loan with `status = LoanStatus.PENDING` (`lifecycle_status: "Submitted"`).
  - Transitions client status to `Pending Loan` (`ClientStatusService.on_loan_submitted`).
  - Generates initial schedule (`ScheduleService.generate_schedule`).
  - Flashes message: `Application submitted successfully! Repayment schedule generated and loan is Pending BM Approval.` and switches tab to `Pending Disbursements`.

---

## 5. Tab 3: Pending Disbursements Specifications

### A. Pending Loans List
- **Filter**: `Status == 'Pending'` and `Loan Amount > 0` within user's RBAC scope.
- **Empty State**: `No pending loans found.`
- **Table Columns**:
  1. `Client Name`
  2. `Group Name` (`"-"` if individual)
  3. `Date`
  4. `Officer`
  5. `Loan Amount` (formatted ₦)
  6. `Loan Product`

### B. Checker Action: Authorize & Activate Disbursement
- **RBAC Governance**:
  - Credit Officer (`CO`): Displays info banner `Note: You are a Credit Officer. Only Branch Managers or Area Managers can authorize and activate disbursements.`
  - Branch Manager (`BM`), Area Manager (`AM`), Admin (`Admin`): Form container `Checker Action: Activate Loan`.
- **Form Controls**:
  - `Select Client to Activate`: Dropdown formatted `{Client Name} — {Loan Product} (₦{Loan Amount})`.
  - `Actual Disbursement Date`: Date picker (defaults to today).
  - `Authorize & Activate Disbursement` button.
- **Disbursement Processing Rules (`FP-008`, `source-of-truth.md`)**:
  1. **Working Day Validation**: Calls `BusinessDateService.is_working_day(today, closures)`. If not a working day, aborts with error: `Non-Working Day Restriction: Loans cannot be activated or disbursed on {reason}. Please select a valid working day.`
  2. **First Repayment Schedule Date**:
     - Daily loans: $\text{Disbursement Date} + 1\text{ day}$.
     - Weekly loans: Next valid group meeting day strictly after disbursement date ($\text{days ahead} \ge 1$).
     - Holiday adjustment: `BusinessDateService.get_next_working_day(initial_start_date, closures)`.
  3. **Disburse Execution (`LoanService.disburse_loan`)**:
     - Updates loan: `status = LoanStatus.ACTIVE`, `start_date = final_start_date`, `expected_end_date`.
     - Dispatches double-entry domain event: debits client loan account, credits physical vault cash (Account 1000).
     - Auto-deducts upfront fees / gap fee / asset downpayment if applicable (`BR-FEE-001`).
     - Transitions client lifecycle status to `On Loan` (`BR-CLI-002`).
     - Generates authoritative schedule.
  4. **Feedback**: `Successfully activated and disbursed loan! Disbursement Date set to {date}.` (with schedule adjustment notice if shifted).

---

## 6. Tab 4: Edit Client & Guarantor Specifications

### A. Client Search
- Text input `Search Client by Name or Client ID to Edit` with RBAC hierarchy filtering.
- Dropdown selector: `{client_code} - {name}`.

### B. Form Fields
- **1. Personal Details**:
  - `Full Name` (required), `Phone Number`, `Home Address`.
  - `Marital Status` (`Married`, `Single`, `Divorced`, `Widowed`).
  - `Business Type`, `Average Monthly Income (₦)`, `Other Obligations`.
  - `Means of ID`, `ID Number`.
  - `Upload ID Document (replaces current)`, `Upload Passport Photograph (replaces current)`.
- **2. Guarantor Info**:
  - `Guarantor Full Name`, `Guarantor Phone Number`, `Guarantor Home Address`.
  - `Guarantor Marital Status`, `Guarantor Occupation`, `Relationship with Client`, `Guarantor Office Address`.
  - `Guarantor Means of ID`, `Guarantor ID Number`.
  - `Upload Guarantor ID Document`, `Upload Guarantor Passport Photograph`.

### C. Update Persistence
- Updates `clients` record.
- Updates latest loan's `extra_fields` and guarantor columns.
- Syncs/updates or inserts record in `guarantors` table.
- Links guarantor in `loan_guarantors`.
- Success notification: `Client and Guarantor details updated successfully.`

---

## 7. Zero-Emoji Directive Verification

- Strictly 0 emojis in tab labels, buttons, headers, alert banners, cards, or tables.
- SVG icons and Material Corporate icons used exclusively.
