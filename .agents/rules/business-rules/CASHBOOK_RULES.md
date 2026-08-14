# Cashbook Invariant Rules

## BR-CASH-001: ICARE Banking Model & Asset vs Financial Loan Flow Architecture
- **Rule ID:** BR-CASH-001
- **Name:** Cash Loans vs Asset Loans Settlement Architecture
- **Description:** ICARE clearly distinguishes between Cash Loans (Product Finance) and Asset Loans (Asset Program):
  1. **Cash Loan Disbursements (Financial Program)**:
     - Funds are transferred from the bank to the client.
     - Recorded on Left side under **Bank Withdrawal** (`bank_withdrawal`).
     - Balanced on Right side by **Active Credit Disbursements** (`weekly_active`, `daily_active`, `monthly_active` for Finance).
  2. **Asset Loan Disbursements (Asset Program / Asset Credit Sales)**:
     - Physical goods/assets are provided to the client on credit (NO bank cash transfer to client).
     - Recorded on Left side under **Asset Credit Sales** (`asset_credit_sales`).
     - Balanced on Right side by **Active Credit Disbursements** (`weekly_active`, `daily_active`, `monthly_active` for Asset / `fund_to_asset_program`).
  3. **Upfront Cash Collections on Asset Loans (Downpayment, Markup, Contingency)**:
     - Physical cash collected upfront enters on Left side under `Markup`, `Contingency`, etc.
     - Deposited into company bank account $\rightarrow$ balanced by **Bank Deposit** on Right side.
  4. **Cash and Carry (Outright Asset Sales)**:
     - Outright cash sales proceeds enter on Left side under **Cash and Carry** (`cash_and_carry`).
     - Deposited into bank $\rightarrow$ balanced by **Bank Deposit** on Right side.
  5. **Field Cash Collections $\rightarrow$ Bank Deposit**:
     - All physical cash collected from field (Repayments, Savings Deposits, Passbook/Form fees) is deposited into bank $\rightarrow$ balanced by **Bank Deposit** on Right side.
  6. **Cashless Client Savings Withdrawals & LAPS Payouts**:
     - Transferred from bank to client $\rightarrow$ Left side: **Bank Withdrawal**; Right side: **Product Withdrawal** / **LAPS Returns**.
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

| Operational Flow | Left Side (Inflows) | Right Side (Outflows) | Balancing Mechanism |
| :--- | :--- | :--- | :--- |
| **Asset Loan Disbursed** | **`Asset Credit Sales`** | **`Weekly/Daily/Monthly Active (Asset)`** | Asset value provided on credit (NOT in bank withdrawal). |
| **Asset Upfront Cash Collected** | `Markup`, `Contingency`, etc. | `Bank Deposit` | Upfront fee cash collected & deposited into bank. |
| **Cash & Carry Sales** | `Cash and Carry` | `Bank Deposit` | Outright sale cash proceeds deposited into bank. |
| **Cash Loan Disbursements** | `Bank Withdrawal` | `Weekly/Daily/Monthly Active (Finance)` | Bank transfer to client for cash loan. |
| **Field Cash Collections** | `Savings Deposit`, `Repayments`, `Passbook/Form Fees` | `Bank Deposit` | Field cash deposited into bank account at end of day. |
| **Client Savings Withdrawals** | `Bank Withdrawal` | `Product Withdrawal` | Bank transfer to client for savings withdrawal. |
| **LAPS Payouts** | `Bank Withdrawal` | `Laps Transferred (Returns)` | Bank transfer to client for LAPS claim payout. |
| **Loan Offsets from Savings** | `Repayments` | `Product Withdrawal` | Internal non-cash loan offset. |
| **Savings Swept to LAPS** | `LAPS Reserve` | `Product Withdrawal` | Internal non-cash LAPS sweep. |
| **Office Expenses** | — | `Expenses` | Cash expenses paid. |

---

## BR-CASH-004: Inflow & Outflow Formulas

### 1. Credit Officer (CO) Cashbook
- **Total Inflows (Left)**:
  $$\text{Total Inflows} = \text{opening\_balance} + \text{savings\_deposit} + \text{laps\_reserve} + \text{rep\_daily} + \text{rep\_12\_weeks} + \text{rep\_24\_weeks} + \text{rep\_monthly} + \text{daily\_11\_pct} + \text{weekly\_11\_pct} + \text{risk\_premium\_returns} + \text{contingency} + \text{app\_fee} + \text{passbook} + \text{asset\_credit\_sales} + \text{cash\_and\_carry} + \text{credit\_form\_damage} + \text{bonus} + \text{bank\_withdrawal}$$
  *(Note: `savings_deposit` includes Misc Fees ONLY for the designated officer, e.g. `CO3` for Ogijo).*

- **Total Outflows (Right)**:
  $$\text{Total Outflows} = \text{product\_withdrawal} + \text{weekly\_active} + \text{daily\_active} + \text{monthly\_active} + \text{office\_expenses} + \text{bank\_deposit} + \text{laps\_returns}$$

- **Closing Balance**:
  $$\text{Closing Balance} = \text{Total Inflows (Left)} - \text{Total Outflows (Right)}$$

---

### 2. Master Cashbook
- **Total Inflows (Master)**:
  $$\text{Total Inflows} = \text{Aggregated CO Inflows} + \text{funds\_received\_ho} + \text{funds\_received\_other\_branch} + \text{adjustment\_in}$$

- **Total Outflows (Master)**:
  $$\text{Total Outflows} = \text{product\_withdrawal} + \text{fund\_to\_asset\_program} + \text{fund\_to\_product\_finance} + \text{bank\_deposit} + \text{laps\_returns} + \text{office\_expenses} + \text{staff\_salaries} + \text{fund\_transferred\_ho} + \text{fund\_transferred\_other\_branch} + \text{fund\_to\_other\_area} + \text{adjustment\_out}$$

- **Closing Balance**:
  $$\text{Closing Balance} = \text{Total Inflows (Master)} - \text{Total Outflows (Master)}$$
- **Status:** CONFIRMED
- **Implementation Location:** `services/master_cashbook_projection_builder.py`

---

## BR-CASH-005: Projection Rebuild Safe Signature & Idempotency
- **Rule ID:** BR-CASH-005
- **Name:** Projection Rebuild API Consistency
- **Description:** `CashbookRepository.rebuild_projection` must accept standard signatures without creating nested UOW contexts or failing on parameter order.
- **Status:** CONFIRMED
- **Implementation Location:** `database/repositories/cashbook_repository.py`
