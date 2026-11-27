# Cashbook Invariant Rules

## BR-CASH-001: ICARE Banking Model & Asset vs Financial Loan Flow Architecture
- **Rule ID:** BR-CASH-001
- **Name:** Bank-Centric Treasury, Vault Cash (`Account 1000`), and Bank Reserve (`Account 1050`) Settlement Architecture
- **Description:** ICARE maintains strict separation between Physical Vault Cash (`Account 1000`) and Branch Bank Operations (`Account 1050`):
  1. **Cash Loan Disbursements (Financial Program)**:
     - Funds are transferred directly from Bank (`CR 1050`) to the client.
     - Recorded on Left side under **Bank Withdrawal** (`bank_withdrawal` — 100% auto-calculated, never manually entered).
     - Balanced on Right side by **Active Credit Disbursements** (`weekly_active`, `daily_active`, `monthly_active` for Finance / `fund_to_product_finance`). Net Vault impact = `0`.
  2. **Asset Loan Disbursements (Asset Program / Asset Credit Sales)**:
     - Physical goods/assets are delivered from Inventory (`CR 1300`) to the client on credit (NO cash or bank transfer to client).
     - Recorded on Left side under **Asset Credit Sales** (`asset_credit_sales`) / Master (`asset_credit_sales`).
     - Balanced on Right side by **Active Credit Disbursements** (`weekly_active`, `daily_active`, `monthly_active` for Asset / `fund_to_asset_program`). Net Vault impact = `0`.
  3. **Upfront Loan Fees, Gap Fees & Cash Collections**:
     - Customer savings deposits, standalone fees (App Fee, Passbook, Form Damage, Bonus), Asset downpayments/markups/contingencies, and repayments enter Physical Vault Cash (`DR 1000`) on Left side.
     - Upfront Finance loan interest & gap fees settle non-cash out of client savings (`FeeOffsetFromSavings` -> `DR 2000 / CR 3000`; `GapFeeOffsetFromSavings` -> `DR 2000 / CR 1200`), appearing on Right side (`product_withdrawal`) against savings already collected (never deducting cash twice).
  4. **Bank Funding Received (`HO_TRANSFER_IN`, `INTER_BRANCH_IN`, `INTER_AREA_IN`)**:
     - Enters Bank (`DR 1050 / CR 3100`).
     - Paired on Master Cashbook as `Left: funds_received_ho / funds_received_other_branch / funds_received_other_area` and `Right: bank_deposit`. Net Vault impact = `0`.
  5. **Bank Transfers Out & Payroll (`HO_TRANSFER_OUT`, `INTER_BRANCH_OUT`, `INTER_AREA_OUT`, `ASSET_PROGRAM`, `SALARY`)**:
     - Debited directly from Bank (`CR 1050`).
     - Auto-adds to `Left: bank_withdrawal` paired with `Right: fund_transferred_* / fund_to_asset_program / staff_salaries`. Net Vault impact = `0`.
  6. **100% Bank-Routed Customer Savings Withdrawals & LAPS Payouts (Option A)**:
     - All direct customer/group/misc savings withdrawals and direct LAPS payouts execute strictly via Bank Transfer (`CR 1050`). Physical cash payouts from Vault for direct withdrawals are disabled.
     - Paired as `Left: Bank Withdrawal` and `Right: Product Withdrawal` / `LAPS Returns`. Net Vault impact = `0`.
  7. **Vault Sweeps (`BANK_DEPOSIT`) & Branch Office Cash Expenses (`OFFICE_EXPENSE`)**:
     - Physical vault cash remitted to Bank (`DR 1050 / CR 1000`) sits solely on Right side (`bank_deposit`), reducing Physical Vault Cash.
     - Any physical cash spent at the branch (`DR 4000 / CR 1000`) is carried strictly as `Right: office_expenses`, reducing Physical Vault Cash.
     - Honest negative closing balance (`closing_balance < 0`) indicates Excess Banked collection surplus and carries forward negatively to the next day (`opening_balance` is NOT clamped to zero).
- **Status:** CONFIRMED
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `services/master_cashbook_projection_builder.py`

---

## BR-CASH-002: CO Cashbook Projection Invariants & Dimensionality
- **Rule ID:** BR-CASH-002
- **Name:** CO Cashbook Officer-Level Dimensional Projection
- **Description:** The CO Cashbook represents the complete daily operational ledger and collection bag of a specific Credit Officer.
- **Required Behavior:**
  - Rebuilt for a specific `branch_id`, `officer_id`, and `posting_date`.
  - **Opening Balance** = Closing balance of previous working day for that officer and branch in `co_cashbooks`.
  - **Closing Balance** = `Opening Balance + Total Inflows (Left) - Total Outflows (Right)`.
- **Status:** CONFIRMED
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

---

## BR-CASH-003: Complete Balancing Matrix

| Operational Flow | Left Side (Inflows) | Right Side (Outflows) | Net Vault Impact |
| :--- | :--- | :--- | :--- |
| **Asset Loan Disbursed** | `Asset Credit Sales` | `Weekly/Daily/Monthly Active (Asset)` | `0` (Inventory credit `1300`) |
| **Asset Upfront Cash Collected** | `Markup`, `Contingency`, etc. | `Bank Deposit` (when banked) | `+Cash` until banked |
| **Cash & Carry Sales** | `Cash and Carry` | `Bank Deposit` (when banked) | `+Cash` until banked |
| **Cash Loan Disbursements** | `Bank Withdrawal` (auto) | `Weekly/Daily/Monthly Active (Finance)` / `Fund to Product Finance` | `0` (Bank credit `1050`) |
| **Field Cash Collections** | `Savings Deposit`, `Repayments`, `Passbook/Form Fees` | `Bank Deposit` (when banked) | `+Cash` until banked |
| **Client Savings Withdrawals** | `Bank Withdrawal` (auto) | `Product Withdrawal` | `0` (Bank credit `1050`) |
| **LAPS Payouts** | `Bank Withdrawal` (auto) | `Laps Transferred (Returns)` | `0` (Bank credit `1050`) |
| **Loan & Upfront Fee Offsets from Savings** | *(already in Vault/Bank from prior savings)* | `Product Withdrawal` | `-Savings / 0 Vault change` |
| **Savings Swept to LAPS** | `LAPS Reserve` | `Product Withdrawal` | `0` (Non-cash sweep) |
| **Bank Funding Received (`HO`/`Branch`/`Area`)** | `Funds Received (HO / Branch / Area)` | `Bank Deposit` | `0` (Bank debit `1050`) |
| **Corporate Bank Transfers Out & Salaries** | `Bank Withdrawal` (auto) | `Fund Transferred (HO / Branch / Area / Asset)`, `Staff Salaries` | `0` (Bank credit `1050`) |
| **Physical Vault Sweep to Bank** | — | `Bank Deposit` | `-Vault Cash` (`+Bank 1050`) |
| **Vault Adjustment In (`FLOAT`)** | `Adjustment In` | — | `+Vault Cash` (`DR 1000`) |
| **Office Cash Expenses** | — | `Office Expenses` | `-Vault Cash` (`CR 1000`) |

---

## BR-CASH-004: Inflow & Outflow Formulas

### 1. Credit Officer (CO) Cashbook
*(Built strictly for Credit Officer user roles; BM roles never appear as `co_cashbooks` rows.)*
- **Total Inflows (Left)**:
  $$\text{Total Inflows} = \text{opening\_balance} + \text{savings\_deposit} + \text{laps\_reserve} + \text{rep\_daily} + \text{rep\_12\_weeks} + \text{rep\_24\_weeks} + \text{rep\_monthly} + \text{daily\_11\_pct} + \text{weekly\_11\_pct} + \text{risk\_premium\_returns} + \text{contingency} + \text{app\_fee} + \text{passbook} + \text{asset\_credit\_sales} + \text{cash\_and\_carry} + \text{credit\_form\_damage} + \text{bonus} + \text{bank\_withdrawal}$$
  *(Note: `savings_deposit` includes Misc Fees ONLY for the branch's designated officer, e.g. `CO3` for Ogijo).*

- **Total Outflows (Right)**:
  $$\text{Total Outflows} = \text{product\_withdrawal} + \text{weekly\_active} + \text{daily\_active} + \text{monthly\_active} + \text{office\_expenses} + \text{bank\_deposit} + \text{laps\_returns}$$

- **Closing Balance**:
  $$\text{Closing Balance} = \text{Total Inflows (Left)} - \text{Total Outflows (Right)}$$

---

### 2. Master Cashbook
- **Total Inflows (Master)**:
  $$\text{Total Inflows} = \text{Aggregated CO Inflows} + \text{funds\_received\_ho} + \text{funds\_received\_other\_branch} + \text{funds\_received\_other\_area} + \text{branch\_bank\_withdrawal} + \text{branch\_asset\_credit\_sales} + \text{adjustment\_in}$$
  *(where `bank_withdrawal` is 100% auto-calculated from Bank `CR 1050` outflows — never manually entered).*

- **Total Outflows (Master)**:
  $$\text{Total Outflows} = \text{product\_withdrawal} + \text{fund\_to\_asset\_program} + \text{fund\_to\_product\_finance} + \text{bank\_deposit} + \text{laps\_returns} + \text{office\_expenses} + \text{staff\_salaries} + \text{fund\_transferred\_ho} + \text{fund\_transferred\_other\_branch} + \text{fund\_to\_other\_area} + \text{adjustment\_out}$$

- **Closing Balance**:
  $$\text{Closing Balance} = \text{Total Inflows (Master)} - \text{Total Outflows (Master)}$$
  *(Honest carry-forward: negative closing balances representing Excess Banked carry forward unaltered into the next day's `opening_balance`.)*
- **Status:** CONFIRMED
- **Implementation Location:** `services/master_cashbook_projection_builder.py`

---

## BR-CASH-005: Projection Rebuild Safe Signature & Idempotency
- **Rule ID:** BR-CASH-005
- **Name:** Projection Rebuild API Consistency
- **Description:** `CashbookRepository.rebuild_projection` must accept standard signatures without creating nested UOW contexts or failing on parameter order.
- **Status:** CONFIRMED
- **Implementation Location:** `database/repositories/cashbook_repository.py`
