# Fee & Origination Deduction Rules

## BR-FEE-001: Upfront Origination Deductions & Cashbook Balancing
- **Rule ID:** BR-FEE-001
- **Name:** Upfront Loan Origination Automatic Deductions
- **Description:** Markup (11%, 20%), Contingency (1%), and Gap Fee are automatic deductions applied during loan origination.
- **Required Behavior:**
  - In the double-entry ledger, upfront deductions are emitted during loan origination (`LoanDisbursed`, `FeeCharged` for Markup/Contingency, `SavingsDeposited` for Gap Fee).
  - In the Cashbook:
    - Left side (Inflows): Recorded in their respective deduction columns (`daily_11_pct`, `weekly_11_pct`, `risk_premium_returns`, `contingency`).
    - Right side (Outflows): Balanced under **Product Withdrawal** (`product_withdrawal`) because they are internal automatic deductions from the loan origination, avoiding double cash inflation.
- **Prohibited Behavior:**
  - Treating upfront origination deductions as separate physical cash collections from the client without the matching Product Withdrawal balancing entry.
  - Double-counting origination deductions.
- **Status:** CONFIRMED
- **Implementation Location:** `services/loan_service.py`, `services/withdrawal_classification_engine.py`, `services/co_cashbook_projection_builder.py`
