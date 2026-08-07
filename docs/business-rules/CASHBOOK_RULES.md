# Cashbook Business Rules

## BR-CASH-001
- **Name:** CO Cashbook is Operational
- **Description:** CO Cashbook is an operational cashbook, NOT merely a display/report. It reflects field-level financial activity.
- **Required Behavior:** Treat the CO cashbook as a core operational record reflecting real field activity.
- **Prohibited Behavior:** Do not treat or implement the CO cashbook as a read-only or derived reporting view.
- **Related Entities:** CO Cashbook
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `co_cashbooks` table

## BR-CASH-002
- **Name:** Event Stream Source
- **Description:** CO Cashbook is built from the event stream (`journal_entries` joined with `event_store`), NOT from `repayments` table directly.
- **Required Behavior:** Always reconstruct and update the cashbook based on the immutable event stream and journal entries.
- **Prohibited Behavior:** Do not query the `repayments` table to build cashbook entries.
- **Related Entities:** Event Store, Journal Entries, CO Cashbook
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-CASH-003
- **Name:** Cash Account Tracking
- **Description:** CO Cashbook only tracks cash account (account_code 1000). Non-cash accounts skipped except for product_withdrawal tracking.
- **Required Behavior:** Only process transactions involving account code 1000 for cashbook entries.
- **Prohibited Behavior:** Do not include non-cash ledger accounts in the CO cashbook projection.
- **Related Entities:** CO Cashbook, Ledger Accounts
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-CASH-004
- **Name:** Master Cashbook Separation
- **Description:** Master Cashbook aggregates ALL CO Cashbooks for a branch + treasury transactions. It is separate from CO Cashbook.
- **Required Behavior:** Maintain a distinct Master Cashbook that rolls up branch-level CO cashbooks and adds treasury activities.
- **Prohibited Behavior:** Do not merge Master Cashbook and CO Cashbook into a single data structure or table.
- **Related Entities:** Master Cashbook, CO Cashbook, Treasury
- **Status:** Active
- **Implementation Location:** `services/master_cashbook_projection_builder.py`, `master_cashbook` table

## BR-CASH-005
- **Name:** CO Cashbook Inflow Categories
- **Description:** CO Cashbook Inflow categories include Repayments (Daily/12W/24W/120D/Monthly), Savings, LAPS Reserve, Bank Withdrawal, Fees (Markup, Contingency, Processing, Passbook, Misc), Asset Sales, Cash & Carry.
- **Required Behavior:** Categorize inflows strictly into the defined categories.
- **Prohibited Behavior:** Do not use arbitrary or unapproved categories for cashbook inflows.
- **Related Entities:** CO Cashbook, Inflows
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-CASH-006
- **Name:** CO Cashbook Outflow Categories
- **Description:** CO Cashbook Outflow categories include Savings Withdrawal, LAPS Returns, Bank Deposit.
- **Required Behavior:** Categorize outflows strictly into the defined categories.
- **Prohibited Behavior:** Do not introduce undocumented outflow categories.
- **Related Entities:** CO Cashbook, Outflows
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-CASH-007
- **Name:** Closing Balance Calculation
- **Description:** Closing Balance = Opening + Total Inflows - Total Outflows.
- **Required Behavior:** Compute the closing balance using the strict mathematical formula based on daily flow.
- **Prohibited Behavior:** Do not calculate closing balance using external aggregates or independent ledger queries bypassing daily flow.
- **Related Entities:** CO Cashbook, Master Cashbook
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `services/master_cashbook_projection_builder.py`

## BR-CASH-008
- **Name:** Opening Balance Rollover
- **Description:** Opening Balance = Previous day's Closing Balance.
- **Required Behavior:** Carry forward the exact closing balance of the previous business day as the new opening balance.
- **Prohibited Behavior:** Do not allow manual editing or overriding of the opening balance.
- **Related Entities:** CO Cashbook, Master Cashbook
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `services/master_cashbook_projection_builder.py`

## BR-CASH-009
- **Name:** Repayment Classification
- **Description:** Repayment classification in cashbook uses loan_products.repayment_cycle and product name to categorize (Daily→60d, Weekly→12w/24w, Monthly).
- **Required Behavior:** Derive cashbook inflow classification based on product definitions and cycles.
- **Prohibited Behavior:** Do not hardcode product names or skip the `loan_products` configuration lookup.
- **Related Entities:** Loan Products, CO Cashbook
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-CASH-010
- **Name:** Master Cashbook Inclusions
- **Description:** Master Cashbook additionally includes Treasury transactions (HO transfers, branch transfers, expenses, salaries) and Loan disbursement pools (Asset/Finance).
- **Required Behavior:** Project all treasury and disbursement events into the Master Cashbook.
- **Prohibited Behavior:** Do not record treasury or branch-level disbursements into individual CO Cashbooks.
- **Related Entities:** Master Cashbook, Treasury, Disbursements
- **Status:** Active
- **Implementation Location:** `services/master_cashbook_projection_builder.py`

## BR-CASH-011
- **Name:** Entry Origin Identification
- **Description:** Automatic and manual entries must remain distinguishable.
- **Required Behavior:** Tag and persist the origin (manual/system) of all cashbook entries.
- **Prohibited Behavior:** Do not obscure the source of an entry or mix manual and automated markers.
- **Related Entities:** Cashbook Entries
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `services/master_cashbook_projection_builder.py`

## BR-CASH-012
- **Name:** EOD Global Entries
- **Description:** EOD global entries (expenses, bank deposits, fees) are saved via save_repayment with GLOBAL-{officer} client ID.
- **Required Behavior:** Use the `GLOBAL-{officer}` identifier to record aggregated end-of-day entries.
- **Prohibited Behavior:** Do not associate branch-wide EOD entries with individual client accounts.
- **Related Entities:** Repayments, Cashbook
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-CASH-013
- **Name:** Automatic Projection Rebuild
- **Description:** Cashbook projection is rebuilt automatically after each financial posting unless deferred.
- **Required Behavior:** Trigger the projection builder upon any new financial event.
- **Prohibited Behavior:** Do not require manual user action to update the cashbook after postings.
- **Related Entities:** Event Store, Cashbook Projections
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `services/master_cashbook_projection_builder.py`
