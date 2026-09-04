# PAGE IDENTITY

* **Exact page title**: `📖 Credit Officer Daily Cashbook`
* **Sidebar label**: `CO Cashbook`
* **Role(s)**: `Credit Officer`, `Branch Manager`, `Area Manager`, `Administrator`
* **Navigation location**: Sixth menu item for Credit Officer, fourth for AM/Admin
* **Streamlit source**: `app.py` L7200–7648
* **Relevant line ranges**: L7200–7648

# PAGE PURPOSE

The authoritative daily physical vault cash journal for individual Credit Officers. Implements a double-entry 38-column 2-sided T-Account ledger (Debit Inflows vs Credit Outflows) mathematically projected from Account 1000 journal entries in `financial_ledger_entries`. Allows officers to record end-of-day bank deposits, office expenses, passbook fees, and damaged form penalties to achieve a ₦0 closing reconciliation.

# PAGE LAYOUT

1. **Header**: `st.title("📖 Credit Officer Daily Cashbook")` + `st.caption("Daily T-Account Ledger — Reconciled against Account 1000 Vault Cash")`
2. **Context Controls**: Date selector (`Select Date`) + Officer selector (BM/AM/Admin) or Officer confirmation badge (CO).
3. **Closure Warning**: (If closed) `🏖️ Operational Activity Suspended ({co_open_reason}): Operations are in Read-Only mode.`
4. **Form: End of Day / Global Outflows & Additional Collections** (`st.form("eod_form")`).
5. **Two-Sided T-Account Ledger Grid**:
   * Left Column: Debit / Cash Inflows (19 ledger categories)
   * Right Column: Credit / Cash Outflows & Disbursements (8 categories + Closing Balance)
6. **Cashbook Summary & Status Pill**: Green `🟢 Balanced` / Red `🔴 Discrepancy: ₦X,XXX`.
7. **Reversals & Correction Audit Log Table**.

# SECTION INVENTORY

1. **Context & Date Selector**: Sets target date and target credit officer.
2. **EOD Outflows & Fees Input Form**: Captures non-installment cash movements (Expenses, Bank Deposits, Application Fees, Passbooks, CFD, Bonuses).
3. **Debit Side (Inflows Table)**: 19 columns reconciling physical collections, savings deposits, fee revenues, and opening balance.
4. **Credit Side (Outflows Table)**: 8 columns reconciling new loan disbursements, savings payouts, office expenditures, and bank deposits.
5. **Reconciliation Box**: Verifies $\text{Total Inflows} - \text{Total Outflows} = \text{Closing Cash in Hand}$.

# UI COMPONENT INVENTORY

* **Date Selector**: `st.date_input("Select Date")`
* **Officer Selector**: `st.selectbox("Select Credit Officer")`
* **EOD Form Inputs**:
  * `Opening Balance (B/F Cash)` (`number_input`)
  * `Office Expenses` (`number_input`)
  * `Bank Deposited` (`number_input`)
  * `Credit Form / App Fee` (`number_input`)
  * `Pass Book` (`number_input`)
  * `Misc Fee` (`number_input`)
  * `Cr Form Dmg` (`number_input`)
  * `Bonus` (`number_input`)
* **Submit Button**: `💾 Save End of Day Outflows & Fees`
* **T-Account Side-by-Side Tables**: Left table (Inflows) + Right table (Outflows).
* **Balancing Alert**: `🟢 Balanced` or `🔴 Discrepancy`.

# LABEL INVENTORY

* Page Title: `📖 Credit Officer Daily Cashbook`
* Subtitle: `Daily T-Account Ledger — Reconciled against Account 1000 Vault Cash`
* Form Heading: `📤 End of Day / Global Outflows & Additional Collections`
* Subhead: `💳 Additional Collections & Fees`
* Fields: `Opening Balance (B/F Cash)`, `Office Expenses`, `Bank Deposited`, `Credit Form / App Fee`, `Pass Book`, `Misc Fee`, `Cr Form Dmg`, `Bonus`
* Inflow Columns: `Opening B/F`, `Savings Deposit`, `LAPS Reserve`, `Repay Daily`, `Repay 12W`, `Repay 24W`, `Repay Monthly`, `Daily 11%`, `Weekly 11%`, `Weekly 20%`, `Risk Premium`, `Contingency`, `App Fee`, `Cr Form Dmg`, `Passbook`, `Bonus`, `Asset Sales`, `Cash & Carry`, `Bank Withdrawal`, `Total Inflows`
* Outflow Columns: `Daily Active`, `Weekly 12W Active`, `Weekly 24W Active`, `Monthly Active`, `Product Withdrawal`, `Office Expenses`, `LAPS Returns`, `Bank Deposit`, `Total Outflows`, `Closing Balance`

# FORM INVENTORY

* **`eod_form`**: Submits daily adjustments and fee receipts to the financial ledger.

# TABLE INVENTORY

1. **Table: Debit Cash Inflows (Left Side)**: Displays all cash inflows with exact amounts.
2. **Table: Credit Cash Outflows (Right Side)**: Displays all cash disbursements and expenses.

# BUTTON INVENTORY

* `💾 Save End of Day Outflows & Fees`: Triggers posting event into Account 1000 and recalculates `co_cashbooks` row.

# FILTER INVENTORY

* Date Picker: Selects historical or current business date.
* Officer Filter: Allows managers to inspect officer cashbooks.

# NAVIGATION BEHAVIOUR

* Sixth option in CO sidebar.

# RBAC BEHAVIOUR

* `CO`: Can view and edit own cashbook for the active business date.
* `BM` / `AM`: Can view all officer cashbooks in branch/region.

# DATA CONTRACT

* `GET /api/v1/co/cashbook?date={date}&officer_id={id}`
* `POST /api/v1/co/cashbook/eod-adjustments`

# WORKFLOW

1. CO completes field collections $\rightarrow$ Opens `CO Cashbook`.
2. System projects all daily repayments, savings, and loan disbursements from Account 1000.
3. CO logs any office expenses incurred or cash deposited into the branch bank account.
4. CO inputs application fees and passbooks sold.
5. CO clicks `Save End of Day Outflows & Fees`.
6. Ledger updates $\rightarrow$ System verifies closing balance $\rightarrow$ Cashbook status marked `Balanced`.

# STATES

* Read-Only: Fails closed on holidays/closures.
* Balanced: `🟢 Cashbook Balanced — Total Inflows match Total Outflows + Closing Cash.`
* Discrepancy: `🔴 Discrepancy detected: Inflows and Outflows differ by ₦X,XXX.`

# VISUAL CHARACTERISTICS

* Two-column split layout representing traditional banking T-Account cashbooks.
* Heavy financial density with Naira formatting.

# KNOWN AMBIGUITIES

* None. 100% matched to `app.py` L7200–7648.
