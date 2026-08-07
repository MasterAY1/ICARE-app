# Savings Business Rules

## BR-SAV-001: Four Savings Categories
- **Rule ID:** BR-SAV-001
- **Name:** Four Savings Categories
- **Description:** The system tracks four distinct categories of savings: Individual Savings, Group Savings, Misc Savings, and LAPS.
- **Required Behavior:** Must maintain separate ledgers for Individual Savings, Group Savings, Misc Savings, and LAPS.
- **Prohibited Behavior:** These categories must NOT be merged into a single generic savings account.
- **Related Entities:** individual_savings, group_savings, internal_savings, laps_savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`, `individual_savings`, `group_savings`, `internal_savings`, `laps_savings` tables

## BR-SAV-002: Total Savings Calculation
- **Rule ID:** BR-SAV-002
- **Name:** Total Savings Calculation
- **Description:** Defines how the total savings balance is calculated across different categories.
- **Required Behavior:** Total Savings must be calculated as the sum of Individual + Group + Misc savings.
- **Prohibited Behavior:** LAPS must be excluded from the Total Savings calculation unless explicitly required.
- **Related Entities:** individual_savings, group_savings, internal_savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`

## BR-SAV-003: Savings Balance Calculation
- **Rule ID:** BR-SAV-003
- **Name:** Savings Balance Calculation
- **Description:** Defines how the balance is calculated for each savings ledger category.
- **Required Behavior:** Savings Balance must be calculated as Sum(deposits) - Sum(withdrawals) per ledger category.
- **Prohibited Behavior:** Do not calculate balances without distinguishing by category.
- **Related Entities:** individual_savings, group_savings, internal_savings, laps_savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`

## BR-SAV-004: LAPS Separation
- **Rule ID:** BR-SAV-004
- **Name:** LAPS Separation
- **Description:** LAPS (Loan and Protection Scheme) is treated as a separate reserve fund.
- **Required Behavior:** LAPS must be maintained as a separate reserve ledger.
- **Prohibited Behavior:** LAPS must not be included in Total Savings.
- **Related Entities:** laps_savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`, `laps_savings` table

## BR-SAV-005: Savings Withdrawal Ledger Impact
- **Rule ID:** BR-SAV-005
- **Name:** Savings Withdrawal Ledger Impact
- **Description:** Withdrawals must correctly impact the specific savings category ledger.
- **Required Behavior:** A savings withdrawal must reduce the correct specific category ledger (Individual, Group, etc.).
- **Prohibited Behavior:** A withdrawal must not reduce an aggregated total without deducting from a specific category.
- **Related Entities:** individual_savings, group_savings, internal_savings, laps_savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`

## BR-SAV-006: Loan Offset from Savings
- **Rule ID:** BR-SAV-006
- **Name:** Loan Offset from Savings
- **Description:** Describes the mechanism for offsetting a loan using a client's savings.
- **Required Behavior:** Process loan offset from savings as an internal non-cash operation.
- **Prohibited Behavior:** This operation must NOT reduce physical vault cash.
- **Related Entities:** Loans, Savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`

## BR-SAV-007: LAPS Transfer
- **Rule ID:** BR-SAV-007
- **Name:** LAPS Transfer
- **Description:** Defines the process of transferring funds to LAPS.
- **Required Behavior:** Process LAPS transfer as an internal non-cash sweep to LAPS reserves.
- **Prohibited Behavior:** Do not treat this as a physical cash deposit.
- **Related Entities:** laps_savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`

## BR-SAV-008: LAPS Payout
- **Rule ID:** BR-SAV-008
- **Name:** LAPS Payout
- **Description:** Specifies the allowed payout methods for LAPS.
- **Required Behavior:** Allow LAPS payout to be processed as either Cash (which impacts the vault) or Bank Transfer (which bypasses the vault).
- **Prohibited Behavior:** Do not process Bank Transfer payouts as vault cash reductions.
- **Related Entities:** laps_savings, Cash Vault, Bank Accounts
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`

## BR-SAV-009: Misc Savings Classification
- **Rule ID:** BR-SAV-009
- **Name:** Misc Savings Classification
- **Description:** Clarifies the nature of the Misc Savings category.
- **Required Behavior:** Treat Misc Savings as a real savings ledger.
- **Prohibited Behavior:** Misc Savings must NOT be treated as a fee.
- **Related Entities:** internal_savings
- **Status:** Active
- **Implementation Location:** `services/savings_service.py`, `internal_savings` table
