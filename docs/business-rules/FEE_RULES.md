# Fee Business Rules

## BR-FEE-001: Fee Categories
- **Rule ID:** BR-FEE-001
- **Name:** Fee Categories
- **Description:** Defines the valid categories of fees in the system.
- **Required Behavior:** System must support Processing Fee, Passbook Fee, Markup (11% or 20%), Contingency (1%), and Credit Form Damage.
- **Prohibited Behavior:** Do not use unapproved fee categories.
- **Related Entities:** fees
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `services/repayment_service.py`, `fees` table

## BR-FEE-002: Fees vs Savings Distinction
- **Rule ID:** BR-FEE-002
- **Name:** Fees vs Savings Distinction
- **Description:** Ensures fees are not misclassified as savings.
- **Required Behavior:** Maintain clear distinction between fees and savings.
- **Prohibited Behavior:** Processing Fee Paid must NOT become Savings.
- **Related Entities:** fees, savings
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`

## BR-FEE-003: Contingency Identification
- **Rule ID:** BR-FEE-003
- **Name:** Contingency Identification
- **Description:** Requires contingency amounts to be identifiable.
- **Required Behavior:** Contingency must remain separately identifiable per product rules.
- **Prohibited Behavior:** Contingency must not be lumped indistinguishably into markup or other fees.
- **Related Entities:** fees
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `fees` table

## BR-FEE-004: Markup/Contingency Split
- **Rule ID:** BR-FEE-004
- **Name:** Markup/Contingency Split
- **Description:** Defines the split of percentage products into markup and contingency.
- **Required Behavior:** For 12% products: 11% markup + 1% contingency. For 21% products: 20% markup + 1% contingency.
- **Prohibited Behavior:** Do not apply the full percentage as markup without extracting the 1% contingency.
- **Related Entities:** fees
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-FEE-005: EOD Fee Events
- **Rule ID:** BR-FEE-005
- **Name:** EOD Fee Events
- **Description:** Ensures fees collected during End of Day (EOD) are properly emitted as events.
- **Required Behavior:** Fees collected during EOD must emit `FeeCharged` events to appear in the cashbook.
- **Prohibited Behavior:** Do not skip event emission for EOD fees.
- **Related Entities:** Events, Cashbook
- **Status:** Active
- **Implementation Location:** `services/repayment_service.py`

## BR-FEE-006: Cashbook Event Narration
- **Rule ID:** BR-FEE-006
- **Name:** Cashbook Event Narration
- **Description:** Uses narration for classifying fee events in the cashbook builder.
- **Required Behavior:** Fee events must use narration-based classification in the cashbook builder.
- **Prohibited Behavior:** Do not build cashbook entries for fees without appropriate narration classification.
- **Related Entities:** Cashbook Builder
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`

## BR-FEE-007: Fee Separation
- **Rule ID:** BR-FEE-007
- **Name:** Fee Separation
- **Description:** Prevents bundling of distinct fee amounts.
- **Required Behavior:** Ensure each fee type is recorded separately with its specific amount.
- **Prohibited Behavior:** Do not combine unrelated amounts into a single generic 'fees' field.
- **Related Entities:** fees
- **Status:** Active
- **Implementation Location:** `services/co_cashbook_projection_builder.py`, `fees` table
