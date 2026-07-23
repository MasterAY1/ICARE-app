-- ============================================================================
-- PHASE 8.1: ENTERPRISE AUDIT LAYER & VIRTUAL LEDGER VIEWS
-- Schema: audit
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS audit;

-- ----------------------------------------------------------------------------
-- 1. FEE LEDGER VIEWS (backed by public.fees via STI)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW audit.processing_fees AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'PROCESSING_FEE';

CREATE OR REPLACE VIEW audit.passbook_fees AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'PASSBOOK';

CREATE OR REPLACE VIEW audit.credit_forms AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'CREDIT_FORM';

CREATE OR REPLACE VIEW audit.credit_form_damage AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'CREDIT_FORM_DAMAGE';

CREATE OR REPLACE VIEW audit.bonus AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'BONUS';

CREATE OR REPLACE VIEW audit.misc_fees AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'MISC_FEE';

CREATE OR REPLACE VIEW audit.contingency AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'CONTINGENCY';

CREATE OR REPLACE VIEW audit.markup_11 AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'MARKUP_11';

CREATE OR REPLACE VIEW audit.markup_20 AS
SELECT id, posting_date, branch_id, officer_id, client_id, fee_type, amount, reference, remarks, currency_code, created_at
FROM public.fees
WHERE fee_type = 'MARKUP_20';

-- ----------------------------------------------------------------------------
-- 2. TREASURY LEDGER VIEWS (backed by public.treasury_transactions via STI)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW audit.bank_deposits AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type = 'BANK_DEPOSIT';

CREATE OR REPLACE VIEW audit.bank_withdrawals AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type = 'BANK_WITHDRAWAL';

CREATE OR REPLACE VIEW audit.office_expenses AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type = 'OFFICE_EXPENSE';

CREATE OR REPLACE VIEW audit.staff_salaries AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type = 'STAFF_SALARY';

CREATE OR REPLACE VIEW audit.head_office_transfers AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type IN ('HO_TRANSFER_IN', 'HO_TRANSFER_OUT');

CREATE OR REPLACE VIEW audit.branch_transfers AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type IN ('BRANCH_TRANSFER_IN', 'BRANCH_TRANSFER_OUT');

CREATE OR REPLACE VIEW audit.other_area_transfers AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type = 'OTHER_AREA_TRANSFER';

CREATE OR REPLACE VIEW audit.asset_program AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type = 'ASSET_PROGRAM';

CREATE OR REPLACE VIEW audit.product_finance AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type = 'PRODUCT_FINANCE';

CREATE OR REPLACE VIEW audit.cashbook_adjustments AS
SELECT id, posting_date, branch_id, officer_id, transaction_type, amount, reference, remarks, currency_code, created_at
FROM public.treasury_transactions
WHERE transaction_type IN ('CASHBOOK_ADJUSTMENT_IN', 'CASHBOOK_ADJUSTMENT_OUT');

-- ----------------------------------------------------------------------------
-- 3. OPERATIONAL AUDIT VIEWS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE VIEW audit.loan_disbursements AS
SELECT loan_id, client_id, product_id, branch_id, officer_id, date AS disbursement_date, loan_amount, active_credit, total_due, status, created_at
FROM public.loans
WHERE status IN ('Disbursed', 'Active', 'Completed', 'Closed');

CREATE OR REPLACE VIEW audit.loan_repayments AS
SELECT id, date, loan_id, client_id, officer_id, branch_id, amount_paid, note, transaction_type, created_at
FROM public.repayments;

CREATE OR REPLACE VIEW audit.full_payments AS
SELECT loan_id, client_id, product_id, branch_id, officer_id, date, loan_amount, loan_repay, status, updated_at
FROM public.loans
WHERE status IN ('Completed', 'Closed') AND active_credit <= 0;

CREATE OR REPLACE VIEW audit.part_payments AS
SELECT id, client_id, loan_id, officer_id, meeting_date, expected_amount, amount_paid, (expected_amount - amount_paid) AS shortfall, remarks, created_at
FROM public.collection_performance
WHERE status = 'PART_PAYMENT';

CREATE OR REPLACE VIEW audit.excess_payments AS
SELECT id, client_id, loan_id, officer_id, meeting_date, expected_amount, amount_paid, (amount_paid - expected_amount) AS excess, remarks, created_at
FROM public.collection_performance
WHERE amount_paid > expected_amount;

CREATE OR REPLACE VIEW audit.not_paid_clients AS
SELECT id, client_id, loan_id, officer_id, meeting_date, expected_amount, amount_paid, remarks, created_at
FROM public.collection_performance
WHERE status = 'NOT_PAID';

CREATE OR REPLACE VIEW audit.individual_savings AS
SELECT id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at
FROM public.individual_savings;

CREATE OR REPLACE VIEW audit.group_savings AS
SELECT id, posting_date, group_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at
FROM public.group_savings;

CREATE OR REPLACE VIEW audit.laps_savings AS
SELECT id, posting_date, client_id, branch_id, officer_id, deposit_amount, withdrawal_amount, reference, remarks, created_at
FROM public.laps_savings;

CREATE OR REPLACE VIEW audit.collection_performance AS
SELECT id, client_id, loan_id, officer_id, meeting_date, expected_amount, amount_paid, status, remarks, created_at
FROM public.collection_performance;

-- ----------------------------------------------------------------------------
-- 4. PERFORMANCE INDEXES
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_fees_type_branch ON public.fees(fee_type, branch_id, posting_date);
CREATE INDEX IF NOT EXISTS idx_treasury_type_branch ON public.treasury_transactions(transaction_type, branch_id, posting_date);
CREATE INDEX IF NOT EXISTS idx_repayments_branch_date ON public.repayments(branch_id, date);
