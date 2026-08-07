# Collection Business Rules

## BR-COL-001: Collection Status
- **Rule ID:** BR-COL-001
- **Name:** Collection Status
- **Description:** Defines the possible statuses for collection based on collected amount vs expected amount.
- **Required Behavior:** Classify collection as 'Paid' (amount >= expected), 'Not Paid' (no payment), or 'Excess' (amount > expected).
- **Prohibited Behavior:** Do not misclassify excess payments as merely 'Paid'.
- **Related Entities:** collection_performance
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`, `collection_performance` table

## BR-COL-002: Collection Gap Calculation
- **Rule ID:** BR-COL-002
- **Name:** Collection Gap Calculation
- **Description:** Defines how the collection gap is calculated.
- **Required Behavior:** Calculate Collection Gap as Expected Repayment - Collected Amount. A negative gap indicates excess.
- **Prohibited Behavior:** A negative gap (excess) must NOT be zeroed out.
- **Related Entities:** collection_performance
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`, `app.py save_repayment` function

## BR-COL-003: Repayment Loan Connection
- **Rule ID:** BR-COL-003
- **Name:** Repayment Loan Connection
- **Description:** Ensures every repayment is linked to a valid loan.
- **Required Behavior:** Repayment must be connected to the correct loan and client via the `loan_id` foreign key.
- **Prohibited Behavior:** Repayments must not be processed without a valid loan connection.
- **Related Entities:** Repayments, Loans
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`, `app.py save_repayment` function

## BR-COL-004: Repayment Event Payload
- **Rule ID:** BR-COL-004
- **Name:** Repayment Event Payload
- **Description:** Specifies required fields in the repayment event payload for classification.
- **Required Behavior:** Repayment event must include `loan_id` in the payload for correct product classification.
- **Prohibited Behavior:** Do not emit repayment events without `loan_id`.
- **Related Entities:** Events
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`

## BR-COL-005: Core Repayment Event
- **Rule ID:** BR-COL-005
- **Name:** Core Repayment Event
- **Description:** Specifies the event emitted for the core loan repayment.
- **Required Behavior:** RepaymentService must emit a `RepaymentReceived` event for the core loan amount.
- **Prohibited Behavior:** Do not omit emitting this event for valid core repayments.
- **Related Entities:** Events
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`

## BR-COL-006: Extra Fee Events
- **Rule ID:** BR-COL-006
- **Name:** Extra Fee Events
- **Description:** Ensures separate events are emitted for any extra fees collected during repayment.
- **Required Behavior:** RepaymentService must also emit separate events for each extra fee (e.g., `FeeCharged`, `BankDeposited`, etc.).
- **Prohibited Behavior:** Do not bundle extra fee amounts into the core repayment event.
- **Related Entities:** Events, Fees
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`

## BR-COL-007: Nonexistent Loan Repayment
- **Rule ID:** BR-COL-007
- **Name:** Nonexistent Loan Repayment
- **Description:** Prevents creating repayments for non-existent loans.
- **Required Behavior:** Reject any attempt to create a repayment against a nonexistent loan.
- **Prohibited Behavior:** Collection cannot create repayment against a nonexistent loan.
- **Related Entities:** Repayments, Loans
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`, `app.py save_repayment` function

## BR-COL-008: Physical vs Non-Cash Distinction
- **Rule ID:** BR-COL-008
- **Name:** Physical vs Non-Cash Distinction
- **Description:** Differentiates between transactions that affect the physical cash vault and those that do not.
- **Required Behavior:** Ensure Cash Withdrawals reduce the vault balance, while Loan Offsets operate as non-cash transactions.
- **Prohibited Behavior:** Loan Offsets must NOT reduce physical vault cash.
- **Related Entities:** Cash Vault
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`

## BR-COL-009: Bulk Collection Projection Deferral
- **Rule ID:** BR-COL-009
- **Name:** Bulk Collection Projection Deferral
- **Description:** Optimizes projection rebuilding during bulk collections.
- **Required Behavior:** During bulk collections, defer projections and fire a single rebuild at the end.
- **Prohibited Behavior:** Do not rebuild projections after every individual collection in a bulk operation.
- **Related Entities:** Projections
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`

## BR-COL-010: Overdue Tracking Dimensions
- **Rule ID:** BR-COL-010
- **Name:** Overdue Tracking Dimensions
- **Description:** Specifies the dimensions that must be tracked for overdue collections.
- **Required Behavior:** Track overdue amounts across expected, actual, shortfall, excess, and missed dimensions.
- **Prohibited Behavior:** Do not ignore any of these dimensions in overdue calculations.
- **Related Entities:** collection_performance
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`, `collection_performance` table
