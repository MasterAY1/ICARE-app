# Loan Origination Workflow Rules

## BR-LOAN-001
**Name:** Loan Application Prerequisites
**Description:** Loan Application requires Client + Guarantor + Product Selection.
**Required Behavior:** Before a loan application can be submitted, a client must be selected, a guarantor must be provided, and a valid loan product must be selected.
**Prohibited Behavior:** Submitting an application without a client, guarantor, or product.
**Related Entities:** Client, Guarantor, Loan Product, Loan Application.
**Status:** Confirmed.
**Implementation Location:** `app.py` lines 3096-3414, `services/loan_service.py`

## BR-LOAN-002
**Name:** Product-Driven Repayment
**Description:** Repayment behavior must be determined by the selected loan product.
**Required Behavior:** The system must use the selected loan product's configuration to determine repayment schedules, amounts, and behaviors.
**Prohibited Behavior:** Hardcoding or using default repayment behaviors ignoring the product configuration.
**Related Entities:** Loan Product, Loan, Repayment Schedule.
**Status:** Confirmed.
**Implementation Location:** `services/loan_product_engine.py`

## BR-LOAN-003
**Name:** Concurrent Loan Block
**Description:** A client cannot have an Active or Pending loan of the same product category (Finance/Asset).
**Required Behavior:** The system must prevent a client from applying for a new loan if they already have an Active or Pending loan in the same category.
**Prohibited Behavior:** Allowing multiple Active/Pending loans of the same category for a single client.
**Related Entities:** Client, Loan.
**Status:** Confirmed.
**Implementation Location:** `services/loan_service.py`

## BR-LOAN-004
**Name:** Savings Sufficiency for Finance Loans
**Description:** For Finance loans, savings must cover Interest + Gap Fee (total_upfront_required).
**Required Behavior:** The system must check the client's savings balance against the `total_upfront_required` before approving a Finance loan.
**Prohibited Behavior:** Approving a Finance loan when the client's savings are insufficient to cover the required upfront fees.
**Related Entities:** Client, Savings, Loan, Loan Product.
**Status:** Confirmed.
**Implementation Location:** `services/loan_service.py`, `services/loan_product_engine.py`

## BR-LOAN-005
**Name:** Auto-Deduction of Upfront Fees
**Description:** SavingsService withdraws Interest + Gap from client savings on application.
**Required Behavior:** Upon loan application for applicable products, the system must automatically deduct the required upfront fees from the client's savings account.
**Prohibited Behavior:** Disbursing the loan without securing the upfront fees from savings if required by the product.
**Related Entities:** SavingsService, Client, Loan.
**Status:** Confirmed.
**Implementation Location:** `services/loan_service.py`

## BR-LOAN-006
**Name:** Branch Manager Approval
**Description:** BM must approve before disbursement. CO cannot approve.
**Required Behavior:** Only a user with the Branch Manager (BM) role can approve a loan application to move it to disbursement.
**Prohibited Behavior:** Credit Officers (CO) approving loan applications.
**Related Entities:** User (BM, CO), Loan Application.
**Status:** Confirmed.
**Implementation Location:** `app.py` lines 3096-3414, `services/loan_service.py`

## BR-LOAN-007
**Name:** Disbursement Events Generation
**Description:** Disbursement creates events: FeeCharged for Markup, FeeCharged for Contingency, plus applicable fee events.
**Required Behavior:** Upon loan disbursement, the system must generate all relevant financial events including markup and contingency fees.
**Prohibited Behavior:** Disbursing a loan without generating the corresponding fee events.
**Related Entities:** Loan, Financial Event.
**Status:** Confirmed.
**Implementation Location:** `services/loan_service.py`

## BR-LOAN-008
**Name:** Repayment Schedule Generation
**Description:** ScheduleService generates a schedule respecting working days, meeting days, and holidays.
**Required Behavior:** The system must generate a repayment schedule that aligns with the client's/group's meeting days and skips configured holidays/non-working days.
**Prohibited Behavior:** Generating schedules on invalid days (holidays, weekends if excluded).
**Related Entities:** ScheduleService, Loan, Calendar/Holidays.
**Status:** Confirmed.
**Implementation Location:** `services/schedule_service.py`

## BR-LOAN-009
**Name:** Active Credit Calculation
**Description:** Determines the active credit amount based on product type.
**Required Behavior:** For Finance: `Principal - Gap Fee`. For Asset: `(Principal + Interest) - Downpayment`. The system must calculate this accurately.
**Prohibited Behavior:** Using incorrect formulas for active credit calculation based on product category.
**Related Entities:** Loan, Loan Product.
**Status:** Confirmed.
**Implementation Location:** `services/loan_product_engine.py`

## BR-LOAN-010
**Name:** Total Due/Payable Calculation
**Description:** Total amount payable by the client.
**Required Behavior:** For both Finance and Asset loans, the total payable is equal to the Active Credit.
**Prohibited Behavior:** Calculating Total Due differently from Active Credit for standard products.
**Related Entities:** Loan.
**Status:** Confirmed.
**Implementation Location:** `services/loan_product_engine.py`

## BR-LOAN-011
**Name:** Expected Installment Calculation
**Description:** Calculation for the periodic installment amount.
**Required Behavior:** The expected installment must be calculated as `Active Credit ÷ Duration`.
**Prohibited Behavior:** Incorrect installment calculations leading to over or under-payment schedules.
**Related Entities:** Loan, Repayment Schedule.
**Status:** Confirmed.
**Implementation Location:** `services/loan_product_engine.py`, `services/schedule_service.py`

## BR-LOAN-012
**Name:** Loan Status Lifecycle
**Description:** Defines the valid state transitions for a loan.
**Required Behavior:** A loan must follow the lifecycle: Pending → Approved → Active → Completed/Closed.
**Prohibited Behavior:** Skipping states (e.g., Pending directly to Active without Approval) or invalid backward transitions.
**Related Entities:** Loan.
**Status:** Confirmed.
**Implementation Location:** `services/loan_service.py`

## BR-LOAN-013
**Name:** Client ID Format
**Description:** Standardized format for Client IDs.
**Required Behavior:** Client IDs must be generated in the format `{BranchCode(3)}-{GroupNumber(2+)}-{MemberSeq(3)}` (e.g., OGI-01-001).
**Prohibited Behavior:** Creating Client IDs that do not conform to this naming convention.
**Related Entities:** Client, Branch, Group.
**Status:** Confirmed.
**Implementation Location:** `services/loan_service.py`

## BR-LOAN-014
**Name:** Allowed Products Filter
**Description:** Restricts Credit Officers to specific products via extra_fields.
**Required Behavior:** Credit Officers must only be able to originate loans for products listed in their `extra_fields.allowed_products`.
**Prohibited Behavior:** COs originating loans for products they are not authorized for.
**Related Entities:** User (CO), Loan Product.
**Status:** Confirmed.
**Implementation Location:** `app.py` lines 3096-3414
