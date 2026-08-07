# ICARE Product Rules

This document outlines the business rules governing the loan and asset products available in the ICARE system, as well as the calculation rules for their associated schedules, fees, and markups.

## Finance Products

### BR-PROD-001: Daily 60 Days
- **Rule ID**: BR-PROD-001
- **Name**: Daily 60 Days
- **Description**: Finance product with a daily repayment frequency over 60 days.
- **Required Behavior**: System must calculate repayment schedules based on a 60-day duration with 12% interest rate.
- **Prohibited Behavior**: Repayment frequency cannot be modified to non-daily for this product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (FINANCE_PRODUCTS), `loan_products` table

### BR-PROD-002: Daily 120 Days
- **Rule ID**: BR-PROD-002
- **Name**: Daily 120 Days
- **Description**: Finance product with a daily repayment frequency over 120 days.
- **Required Behavior**: System must calculate repayment schedules based on a 120-day duration with 21% interest rate.
- **Prohibited Behavior**: Repayment frequency cannot be modified to non-daily for this product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (FINANCE_PRODUCTS), `loan_products` table

### BR-PROD-003: Weekly 12W
- **Rule ID**: BR-PROD-003
- **Name**: Weekly 12W
- **Description**: Finance product with a weekly repayment frequency over 12 weeks.
- **Required Behavior**: System must calculate repayment schedules based on a 12-week duration with 12% interest rate.
- **Prohibited Behavior**: Repayment frequency cannot be modified to non-weekly for this product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (FINANCE_PRODUCTS), `loan_products` table

### BR-PROD-004: Weekly 24W
- **Rule ID**: BR-PROD-004
- **Name**: Weekly 24W
- **Description**: Finance product with a weekly repayment frequency over 24 weeks.
- **Required Behavior**: System must calculate repayment schedules based on a 24-week duration with 21% interest rate.
- **Prohibited Behavior**: Repayment frequency cannot be modified to non-weekly for this product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (FINANCE_PRODUCTS), `loan_products` table

### BR-PROD-005: Monthly 3M
- **Rule ID**: BR-PROD-005
- **Name**: Monthly 3M
- **Description**: Finance product with a monthly repayment frequency over 3 months.
- **Required Behavior**: System must calculate repayment schedules based on a 3-month duration with 12% interest rate.
- **Prohibited Behavior**: Repayment frequency cannot be modified to non-monthly for this product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (FINANCE_PRODUCTS), `loan_products` table

### BR-PROD-006: Monthly 6M
- **Rule ID**: BR-PROD-006
- **Name**: Monthly 6M
- **Description**: Finance product with a monthly repayment frequency over 6 months.
- **Required Behavior**: System must calculate repayment schedules based on a 6-month duration with 21% interest rate.
- **Prohibited Behavior**: Repayment frequency cannot be modified to non-monthly for this product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (FINANCE_PRODUCTS), `loan_products` table

## Asset Products

### BR-PROD-007: 60-Day Asset
- **Rule ID**: BR-PROD-007
- **Name**: 60-Day Asset
- **Description**: Asset financing product with a 60-day duration.
- **Required Behavior**: Schedule must be generated for 60 days with applicable 12% interest calculation, gap fee must be 0.
- **Prohibited Behavior**: Cannot apply non-zero gap fees for this asset product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (ASSET_PRODUCTS), `loan_products` table

### BR-PROD-008: 120-Day Asset
- **Rule ID**: BR-PROD-008
- **Name**: 120-Day Asset
- **Description**: Asset financing product with a 120-day duration.
- **Required Behavior**: Schedule must be generated for 120 days with applicable 21% interest calculation, gap fee must be 0.
- **Prohibited Behavior**: Cannot apply non-zero gap fees for this asset product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (ASSET_PRODUCTS), `loan_products` table

### BR-PROD-009: Weekly 12W Asset
- **Rule ID**: BR-PROD-009
- **Name**: Weekly 12W Asset
- **Description**: Asset financing product over 12 weeks.
- **Required Behavior**: Schedule must be generated for 12 weeks with 12% interest calculation, gap fee must be 0.
- **Prohibited Behavior**: Cannot apply non-zero gap fees for this asset product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (ASSET_PRODUCTS), `loan_products` table

### BR-PROD-010: Weekly 24W Asset
- **Rule ID**: BR-PROD-010
- **Name**: Weekly 24W Asset
- **Description**: Asset financing product over 24 weeks.
- **Required Behavior**: Schedule must be generated for 24 weeks with 21% interest calculation, gap fee must be 0.
- **Prohibited Behavior**: Cannot apply non-zero gap fees for this asset product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (ASSET_PRODUCTS), `loan_products` table

### BR-PROD-011: Monthly 3M Asset
- **Rule ID**: BR-PROD-011
- **Name**: Monthly 3M Asset
- **Description**: Asset financing product over 3 months.
- **Required Behavior**: Schedule must be generated for 3 months with 12% interest calculation, gap fee must be 0.
- **Prohibited Behavior**: Cannot apply non-zero gap fees for this asset product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (ASSET_PRODUCTS), `loan_products` table

### BR-PROD-012: Monthly 6M Asset
- **Rule ID**: BR-PROD-012
- **Name**: Monthly 6M Asset
- **Description**: Asset financing product over 6 months.
- **Required Behavior**: Schedule must be generated for 6 months with 21% interest calculation, gap fee must be 0.
- **Prohibited Behavior**: Cannot apply non-zero gap fees for this asset product.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (ASSET_PRODUCTS), `loan_products` table

### BR-PROD-013: Cash and Carry
- **Rule ID**: BR-PROD-013
- **Name**: Cash and Carry
- **Description**: Immediate settlement asset product.
- **Required Behavior**: Must use 0% rate, 1-day duration, and One-Time frequency.
- **Prohibited Behavior**: Cannot apply interest, markup, or contingency. Cannot span more than 1 day.
- **Related Entities**: LoanProduct, LoanProductEngine
- **Status**: CONFIRMED
- **Implementation Location**: `config/constants.py` (ASSET_PRODUCTS), `loan_products` table

## Calculation Rules (LoanProductEngine)

### BR-PROD-CALC-001: 12% Products Calculation
- **Rule ID**: BR-PROD-CALC-001
- **Name**: 12% Products Calculation
- **Description**: Defines calculations for 12% interest products (60-day, 12W, 3M).
- **Required Behavior**: 
  - Interest = Principal × 12%
  - Markup = Interest × (11/12) = Principal × 11%
  - Contingency = Interest × (1/12) = Principal × 1%
  - Total = Principal + 11% markup + 1% contingency
- **Prohibited Behavior**: Deviation from exact ratios for Markup (11/12) and Contingency (1/12) of interest.
- **Related Entities**: LoanProductEngine
- **Status**: IMPLEMENTATION-VERIFIED
- **Implementation Location**: `services/loan_product_engine.py` (calculate_loan_setup)

### BR-PROD-CALC-002: 21% Products Calculation
- **Rule ID**: BR-PROD-CALC-002
- **Name**: 21% Products Calculation
- **Description**: Defines calculations for 21% interest products (120-day, 24W, 6M).
- **Required Behavior**: 
  - Interest = Principal × 21%
  - Markup = Interest × (20/21) = Principal × 20%
  - Contingency = Interest × (1/21) = Principal × 1%
  - Total = Principal + 20% markup + 1% contingency
- **Prohibited Behavior**: Deviation from exact ratios for Markup (20/21) and Contingency (1/21) of interest.
- **Related Entities**: LoanProductEngine
- **Status**: IMPLEMENTATION-VERIFIED
- **Implementation Location**: `services/loan_product_engine.py` (calculate_loan_setup)

### BR-PROD-CALC-003: Cash & Carry Calculation
- **Rule ID**: BR-PROD-CALC-003
- **Name**: Cash & Carry Calculation
- **Description**: Defines calculations for Cash & Carry products.
- **Required Behavior**: Must enforce 0% interest, 1-day duration, and One-Time frequency. Principal equals Total repayment.
- **Prohibited Behavior**: Cannot calculate markups or contingencies for Cash & Carry.
- **Related Entities**: LoanProductEngine
- **Status**: IMPLEMENTATION-VERIFIED
- **Implementation Location**: `services/loan_product_engine.py` (calculate_loan_setup)

### BR-PROD-CALC-004: Gap Fee and Rounding
- **Rule ID**: BR-PROD-CALC-004
- **Name**: Gap Fee and Rounding Rules
- **Description**: Defines gap fee calculations and repayment rounding for schedules.
- **Required Behavior**: 
  - Loan Repayment = Principal ÷ Duration, floored to nearest round_step (50 for weekly/daily, 100 for monthly).
  - Gap Fee = Principal - (Loan Repayment × Duration).
  - For weekly products with force_gap=True: gap must be ≥ 1000 and a multiple of 1000.
  - Active Credit = Principal - Gap Fee.
  - For Asset products: gap_fee = 0.
- **Prohibited Behavior**: Cannot apply gap fees to Asset products. Cannot ignore force_gap constraints for weekly products.
- **Related Entities**: LoanProductEngine
- **Status**: IMPLEMENTATION-VERIFIED
- **Implementation Location**: `services/loan_product_engine.py` (calculate_loan_setup)

### BR-PROD-CALC-005: Product Parameter Determination
- **Rule ID**: BR-PROD-CALC-005
- **Name**: Product Parameter Determination
- **Description**: The loan product fundamentally determines schedule variables.
- **Required Behavior**: The chosen product strictly determines Duration, Repayment frequency, Expected repayment, Applicable markup %, Contingency %, and the resulting Schedule.
- **Prohibited Behavior**: Overriding product-derived parameters (like frequency or duration) manually during loan creation without creating a new product variant.
- **Related Entities**: LoanProductEngine
- **Status**: IMPLEMENTATION-VERIFIED
- **Implementation Location**: `services/loan_product_engine.py` (calculate_loan_setup)
