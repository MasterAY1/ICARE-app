# Fee Rules

## BR-FEE-001: Fee Classifications & Ledgers
- **Rule ID:** BR-FEE-001
- **Name:** Fee Classifications & Operational Ledgers
- **Description:** Fees collected from clients fall into distinct categories:
  1. `Passbook Fee`
  2. `Application Fee` (App Fee)
  3. `Card / Form Fee` (CFD / CC)
  4. `Markup Fee` (11% or 20% upfront/collected)
  5. `Contingency Fee`
  6. `Passbook Bonus`
- **Required Behavior:**
  - Every fee collection emits a `FeeCharged` domain event.
  - Fees represent operational income/reserves and debit physical cash (Account 1000) when received in cash.
  - Upfront loan fees deducted from disbursement reduce the net disbursement payout.
- **Status:** CONFIRMED
- **Implementation Location:** `services/loan_service.py`, `services/posting_engine.py`, `app.py`
