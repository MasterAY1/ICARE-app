# Savings Rules

## BR-SAV-001: Four Savings Categories & Total Active Savings Definition
- **Rule ID:** BR-SAV-001
- **Name:** Savings Categories & Aggregate Definition
- **Description:** The system maintains four distinct savings ledger categories:
  1. `Individual Savings`: Client-level personal savings.
  2. `Group Savings`: Group-level communal savings fund.
  3. `Misc Savings` (Internal Savings): Special internal savings fund.
  4. `LAPS Savings` (Loan Additional Protection Scheme): Special risk/protection reserve.
- **Required Behavior:**
  - `Total Active Savings` = `Individual Savings` + `Group Savings` + `Misc Savings`.
  - `LAPS Savings` is a distinct risk reserve and MUST be excluded from `Total Active Savings`.
  - Savings Balance for each category = `Sum(deposits) - Sum(withdrawals)`.
- **Prohibited Behavior:**
  - Omission of Group Savings or Misc Savings from Portfolio Total Savings.
  - Adding LAPS Savings to Total Active Savings.
- **Status:** CONFIRMED
- **Implementation Location:** `services/savings_service.py`, `services/portfolio_service.py`, `services/dashboard_service.py`

## BR-SAV-002: Misc Savings Officer Assignment & Aggregation
- **Rule ID:** BR-SAV-002
- **Name:** Misc Savings Officer Assignment
- **Description:** Misc Savings is managed exclusively by one designated Credit Officer per branch (for Ogijo branch: `CO3` / `Miss. Olajumoke`).
- **Required Behavior:**
  - When aggregating savings at the Branch / Institution level (BM, AM, Executive, Admin), all Misc Savings within the branch are included in the branch's `Total Active Savings`.
  - When aggregating savings at the Officer level (CO scope):
    - For the designated Misc Savings officer (`CO3` in Ogijo), their portfolio and dashboard savings total includes their assigned clients' Individual Savings + their assigned groups' Group Savings + **all Misc Savings for the branch**.
    - For all other officers, their savings total consists of their assigned clients' Individual Savings + their assigned groups' Group Savings.
- **Prohibited Behavior:**
  - Splitting Misc Savings arbitrarily across officers who do not manage it.
  - Excluding Misc Savings from the designated officer's total active savings.
- **Status:** CONFIRMED
- **Implementation Location:** `services/portfolio_service.py`, `services/savings_service.py`, `services/dashboard_service.py`

## BR-SAV-003: Group Portfolio Summary Table Group Savings Inclusion
- **Rule ID:** BR-SAV-003
- **Name:** Group Summary Total Savings Formula
- **Description:** The Group Portfolio Summary table must accurately reflect both member savings and group communal savings.
- **Required Behavior:**
  - For each group in the Group Portfolio Summary table:
    $$\text{Total Savings Balance} = \sum(\text{Individual Savings of All Group Members}) + \text{Group Savings Balance of the Group}$$
- **Prohibited Behavior:**
  - Displaying only the sum of individual members' savings while ignoring the group's communal savings fund.
- **Status:** CONFIRMED
- **Implementation Location:** `services/portfolio_service.py` (`group_df` aggregation)

## BR-SAV-004: Savings Operations Physical Cash & Bank Routing Principle
- **Rule ID:** BR-SAV-004
- **Name:** Savings Bank Payout & Internal Settlement Alignment
- **Required Behavior:**
  - `SavingsDeposited`: Physical field cash received (`DR Account 1000 / CR Account 2000`).
  - `SavingsWithdrawn` (Direct Withdrawal): Routed exclusively via Bank Transfer (`cash_paid=False`, `payout_method="Bank Transfer"`, `DR Account 2000 / CR Account 1050`). Direct Vault cash withdrawals are disabled.
  - `LapsPaidOut` (Direct Claim Payout): Routed exclusively via Bank Transfer (`cash_paid=False`, `DR Account 2030 / CR Account 1050`).
  - `FeeOffsetFromSavings` & `GapFeeOffsetFromSavings`: Internal non-cash settlement of upfront loan interest (`DR 2000 / CR 3000`) and gap fee (`DR 2000 / CR 1200`) from savings during Finance loan disbursement; MUST NOT touch `Account 1000` or `Account 1050`.
  - `LoanOffsetFromSavings` & `LapsTransferred`: Internal non-cash operations; MUST NOT affect `Account 1000` or `Account 1050`.
  - Reversals inspect `original_cash_account` on the linked `financial_ledger_entries` so pre-cutover cash reversals credit/debit `1000` and bank payouts reverse `1050` symmetrically.
- **Status:** CONFIRMED
- **Implementation Location:** `services/posting_engine.py`, `services/savings_service.py`, `api/routes/co/withdrawals.py`

## BR-SAV-005: Misc Savings Collecting Officer vs Managing Officer Audit Trace
- **Rule ID:** BR-SAV-005
- **Name:** Misc Savings Dual-Officer Audit Trace
- **Description:** Every Credit Officer in the field can collect Misc Savings/Fees from clients, but the balance pool is managed by the branch's designated officer. Full audit traceability of the collector and manager must be preserved.
- **Required Behavior:**
  - When any CO collects Misc Savings, the system records:
    1. `collecting_officer`: The CO who physically collected the cash from the client in the field.
    2. `managing_officer`: The branch's designated officer who manages the pooled Misc Savings balance.
    3. `amount`, `client_id`, `branch_id`, `posting_date`, `reference`, `narration`.
  - An audit log entry is written to `audit_logs` capturing `action="Misc Savings Deposit"`, `actor=collecting_officer`, `details={"collecting_officer": collecting_officer, "managing_officer": managing_officer, "amount": amount, "client_id": client_id}`.
  - The Audit Ledger / Audit Views must display both the collecting officer and the managing officer.
- **Prohibited Behavior:**
  - Overwriting or losing the identity of the officer who physically collected the deposit.
  - Failing to log the deposit in the audit trail.
- **Status:** CONFIRMED
- **Implementation Location:** `services/savings_service.py`, `database/repositories/savings_repository.py`, `app.py`

## BR-SAV-006: Branch-Level Designated Misc Savings Officer Configuration
- **Rule ID:** BR-SAV-006
- **Name:** Branch Misc Savings Officer Configuration
- **Description:** Each branch assigns one active Credit Officer as its designated Misc Savings manager.
- **Required Behavior:**
  - The system provides a centralized resolver `SavingsService.get_branch_misc_savings_officer(uow, branch_id)`.
  - Admins and Branch Managers can configure or reassign the designated officer for their branch.
  - Default for Ogijo branch: `CO3` (`Miss. Olajumoke`).
- **Prohibited Behavior:**
  - Hardcoding officer names without branch scoping.
- **Status:** CONFIRMED
- **Implementation Location:** `services/savings_service.py`, `app.py`
