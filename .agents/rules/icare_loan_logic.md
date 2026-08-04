---
description: Strict business logic rules for ICARE loans regarding principal, active credit, repayments, and schedule generation.
---

# ICARE Microfinance Loan Logic

When working with loan calculations, database mappings, or UI metrics in the ICARE app, ALWAYS use the following definitions:

1. **Principal (`loan_amount`)**: The total initial amount of the loan (e.g., 100,000).
2. **Gap Fee**: The fee collected upfront (e.g., 1,000), calculated when installment rounding occurs.
3. **Active Credit (`active_credit`)**: The total amount the client is expected to pay back over the tenure.
   - **Formula**: `Principal - Gap Fee` (e.g., 100,000 - 1,000 = 99,000).
4. **Repayment / Fixed Repayment (`loan_repay`)**: The fixed periodic installment (daily, weekly, or monthly) the client must pay.
   - **Formula**: `Active Credit / Duration in Periods` (e.g., 99,000 / 12 weeks = 8,250 weekly).
5. **Outstanding Balance**:
   - Calculated dynamically as: `active_credit` - `sum(all historical loan repayments)`.
6. **Repayment Schedule Start Dates**:
   - **Daily Loan**: Starts on the day *after* the meeting day (skipping weekends/branch holiday closures).
   - **Weekly Loan**: Starts on the *next* meeting day.
   - **Monthly Loan**: Starts on the meeting day of the *next* month.
7. **Collection Statuses (Daily/Period Portfolio)**:
   - **Full Repayment**: `paid_today >= outstanding_bal` (Client fully pays off the remaining active loan balance)
   - **Normal Repayment**: `paid_today == loan_repay` (Client pays exactly their fixed scheduled installment)
   - **Excess Repayment**: `paid_today > loan_repay` (but less than outstanding balance)
   - **Part Repayment**: `0 < paid_today < loan_repay`
   - **Overdue**: `paid_today == 0` when `loan_repay > 0`
