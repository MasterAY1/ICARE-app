-- ============================================================
-- ICARE CORE BANKING PLATFORM SCHEMA
-- Database Schema Version: 2.3 (Greenfield Core Banking Baseline)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- DROP SYSTEM TABLES IN REVERSE DEPENDENCY ORDER
DROP TABLE IF EXISTS public.settings CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.audit_logs CASCADE;
DROP TABLE IF EXISTS public.financial_ledger_entries CASCADE;
DROP TABLE IF EXISTS public.financial_transactions CASCADE;
DROP TABLE IF EXISTS public.event_processing CASCADE;
DROP TABLE IF EXISTS public.event_store CASCADE;
DROP TABLE IF EXISTS public.posting_rules CASCADE;
DROP TABLE IF EXISTS public.chart_of_accounts CASCADE;
DROP TABLE IF EXISTS public.master_cashbook CASCADE;
DROP TABLE IF EXISTS public.treasury_transactions CASCADE;
DROP TABLE IF EXISTS public.fees CASCADE;
DROP TABLE IF EXISTS public.laps_savings CASCADE;
DROP TABLE IF EXISTS public.internal_savings CASCADE;
DROP TABLE IF EXISTS public.group_savings CASCADE;
DROP TABLE IF EXISTS public.individual_savings CASCADE;
DROP TABLE IF EXISTS public.repayments CASCADE;
DROP TABLE IF EXISTS public.loan_schedule CASCADE;
DROP TABLE IF EXISTS public.loans CASCADE;
DROP TABLE IF EXISTS public.loan_products CASCADE;
DROP TABLE IF EXISTS public.client_memberships CASCADE;
DROP TABLE IF EXISTS public.groups CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.user_roles CASCADE;
DROP TABLE IF EXISTS public.app_users CASCADE;
DROP TABLE IF EXISTS public.role_permissions CASCADE;
DROP TABLE IF EXISTS public.permissions CASCADE;
DROP TABLE IF EXISTS public.roles CASCADE;
DROP TABLE IF EXISTS public.branch_closures CASCADE;
DROP TABLE IF EXISTS public.branches CASCADE;
DROP TABLE IF EXISTS public.zones CASCADE;
DROP TABLE IF EXISTS public.regions CASCADE;

-- 1. REGIONS
CREATE TABLE public.regions (
    region_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. ZONES
CREATE TABLE public.zones (
    zone_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id UUID REFERENCES public.regions(region_id) ON DELETE RESTRICT,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. BRANCHES
CREATE TABLE public.branches (
    branch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id UUID REFERENCES public.zones(zone_id) ON DELETE RESTRICT,
    name TEXT NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. BRANCH CLOSURES
CREATE TABLE public.branch_closures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. ROLES
CREATE TABLE public.roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. PERMISSIONS
CREATE TABLE public.permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. ROLE PERMISSIONS
CREATE TABLE public.role_permissions (
    role_id UUID REFERENCES public.roles(role_id) ON DELETE CASCADE,
    permission_id UUID REFERENCES public.permissions(permission_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- 8. APP USERS
CREATE TABLE public.app_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID
);

-- 9. USER ROLES
CREATE TABLE public.user_roles (
    user_id UUID REFERENCES public.app_users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.roles(role_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- 10. CLIENTS (Profile identity only)
CREATE TABLE public.clients (
    client_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    nickname TEXT,
    phone TEXT,
    address TEXT,
    marital_status TEXT,
    business_type TEXT,
    average_monthly_income NUMERIC DEFAULT 0,
    other_obligations TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID
);

-- 11. GROUPS
CREATE TABLE public.groups (
    group_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    meeting_day TEXT NOT NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'Active',
    leader_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    version INTEGER DEFAULT 1,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID
);

-- 12. CLIENT MEMBERSHIPS (Historical assignments)
CREATE TABLE public.client_memberships (
    membership_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES public.clients(client_id) ON DELETE CASCADE,
    group_id UUID REFERENCES public.groups(group_id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    version INTEGER DEFAULT 1
);

-- 13. LOAN PRODUCTS
CREATE TABLE public.loan_products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    repayment_cycle TEXT NOT NULL CHECK (repayment_cycle IN ('Daily', 'Weekly', 'Monthly')),
    interest_rate NUMERIC DEFAULT 0,
    max_term INTEGER NOT NULL,
    processing_fee_rate NUMERIC DEFAULT 0,
    savings_rule NUMERIC DEFAULT 0,
    penalties NUMERIC DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID,
    installments INTEGER,
    rounding_rule INTEGER DEFAULT 50,
    credit_form_fee NUMERIC DEFAULT 0,
    risk_premium NUMERIC DEFAULT 0,
    savings_requirement NUMERIC DEFAULT 0,
    grace_period INTEGER DEFAULT 0,
    penalty_rule TEXT
);

-- 14. LOANS
CREATE TABLE public.loans (
    loan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES public.clients(client_id) ON DELETE RESTRICT,
    product_id UUID REFERENCES public.loan_products(product_id) ON DELETE RESTRICT,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    date DATE NOT NULL,
    loan_amount NUMERIC DEFAULT 0 CHECK (loan_amount >= 0),
    active_credit NUMERIC DEFAULT 0 CHECK (active_credit >= 0),
    loan_repay NUMERIC DEFAULT 0 CHECK (loan_repay >= 0),
    total_due NUMERIC DEFAULT 0 CHECK (total_due >= 0),
    status TEXT DEFAULT 'Pending' CHECK (status IN (
        'Pending', 'Approved', 'Active', 'Completed',
        'Closed', 'Internal Account', 'Written Off'
    )),
    product_category TEXT DEFAULT 'Finance',
    disbursement_date DATE,
    start_date DATE,
    expected_end_date DATE,
    version INTEGER DEFAULT 1,
    extra_fields JSONB DEFAULT '{}'::jsonb,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID
);

-- 15. LOAN SCHEDULE
CREATE TABLE public.loan_schedule (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id UUID REFERENCES public.loans(loan_id) ON DELETE CASCADE,
    installment_number INTEGER NOT NULL,
    due_date DATE NOT NULL,
    principal NUMERIC DEFAULT 0 CHECK (principal >= 0),
    interest NUMERIC DEFAULT 0 CHECK (interest >= 0),
    fees NUMERIC DEFAULT 0 CHECK (fees >= 0),
    total_due NUMERIC DEFAULT 0 CHECK (total_due >= 0),
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Paid', 'Partial', 'Overdue', 'Waived')),
    paid_date DATE,
    paid_amount NUMERIC DEFAULT 0 CHECK (paid_amount >= 0),
    version INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 16. REPAYMENTS
CREATE TABLE public.repayments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    loan_id UUID REFERENCES public.loans(loan_id) ON DELETE RESTRICT,
    client_id UUID REFERENCES public.clients(client_id) ON DELETE RESTRICT,
    amount_paid NUMERIC NOT NULL CHECK (amount_paid > 0),
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    note TEXT,
    transaction_type TEXT DEFAULT 'Loan',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 17. INDIVIDUAL SAVINGS (Immutable Customer Savings Ledger)
CREATE TABLE public.individual_savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    posting_date DATE NOT NULL,
    client_id UUID REFERENCES public.clients(client_id) ON DELETE RESTRICT,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    deposit_amount NUMERIC DEFAULT 0 CHECK (deposit_amount >= 0),
    withdrawal_amount NUMERIC DEFAULT 0 CHECK (withdrawal_amount >= 0),
    reference TEXT,
    remarks TEXT,
    version INTEGER DEFAULT 1,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 18. GROUP SAVINGS (Immutable Communal Savings Ledger)
CREATE TABLE public.group_savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    posting_date DATE NOT NULL,
    group_id UUID REFERENCES public.groups(group_id) ON DELETE RESTRICT,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    deposit_amount NUMERIC DEFAULT 0 CHECK (deposit_amount >= 0),
    withdrawal_amount NUMERIC DEFAULT 0 CHECK (withdrawal_amount >= 0),
    reference TEXT,
    remarks TEXT,
    version INTEGER DEFAULT 1,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 19. INTERNAL SAVINGS (Immutable Branch Savings Ledger)
CREATE TABLE public.internal_savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    posting_date DATE NOT NULL,
    client_id UUID REFERENCES public.clients(client_id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    deposit_amount NUMERIC DEFAULT 0 CHECK (deposit_amount >= 0),
    withdrawal_amount NUMERIC DEFAULT 0 CHECK (withdrawal_amount >= 0),
    reference TEXT,
    remarks TEXT,
    version INTEGER DEFAULT 1,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 20. LAPS SAVINGS (Immutable Suspense/Settled Closed Accounts Ledger)
CREATE TABLE public.laps_savings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    posting_date DATE NOT NULL,
    client_id UUID REFERENCES public.clients(client_id) ON DELETE RESTRICT,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    deposit_amount NUMERIC DEFAULT 0 CHECK (deposit_amount >= 0),
    withdrawal_amount NUMERIC DEFAULT 0 CHECK (withdrawal_amount >= 0),
    reference TEXT,
    remarks TEXT,
    version INTEGER DEFAULT 1,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 21. FEES (Immutable Revenue Ledger)
CREATE TABLE public.fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    posting_date DATE NOT NULL,
    client_id UUID REFERENCES public.clients(client_id) ON DELETE SET NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    fee_type TEXT NOT NULL, -- 'Processing', 'Passbook', 'Credit Form', 'Bonus', 'Penalty'
    amount NUMERIC DEFAULT 0 CHECK (amount >= 0),
    reference TEXT,
    remarks TEXT,
    version INTEGER DEFAULT 1,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 22. TREASURY TRANSACTIONS (Immutable Liquidity Movements)
CREATE TABLE public.treasury_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    posting_date DATE NOT NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    transaction_type TEXT NOT NULL CHECK (transaction_type IN (
        'HO_TRANSFER_IN', 'HO_TRANSFER_OUT',
        'BANK_DEPOSIT', 'BANK_WITHDRAWAL',
        'OFFICE_EXPENSE', 'SALARY',
        'FLOAT', 'VAULT_ADJUSTMENT',
        'INTER_BRANCH_IN', 'INTER_BRANCH_OUT'
    )),
    amount NUMERIC DEFAULT 0 CHECK (amount >= 0),
    reference TEXT,
    remarks TEXT,
    version INTEGER DEFAULT 1,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 23. MASTER CASHBOOK (Operational Projection)
CREATE TABLE public.master_cashbook (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    opening_balance NUMERIC DEFAULT 0,
    rep_daily NUMERIC DEFAULT 0,
    rep_12_weeks NUMERIC DEFAULT 0,
    rep_24_weeks NUMERIC DEFAULT 0,
    rep_monthly NUMERIC DEFAULT 0,
    savings_deposit NUMERIC DEFAULT 0,
    laps_reserve NUMERIC DEFAULT 0,
    loan_received_asset NUMERIC DEFAULT 0,
    loan_received_finance NUMERIC DEFAULT 0,
    daily_11_pct NUMERIC DEFAULT 0,
    weekly_11_pct NUMERIC DEFAULT 0,
    savings_adj_no NUMERIC DEFAULT 0,
    savings_adj_amount NUMERIC DEFAULT 0,
    risk_premium_returns NUMERIC DEFAULT 0,
    passbook NUMERIC DEFAULT 0,
    app_fee NUMERIC DEFAULT 0,
    asset_credit_sales NUMERIC DEFAULT 0,
    cash_and_carry NUMERIC DEFAULT 0,
    contingency NUMERIC DEFAULT 0,
    credit_form NUMERIC DEFAULT 0,
    credit_form_damage NUMERIC DEFAULT 0,
    bonus NUMERIC DEFAULT 0,
    misc_fees NUMERIC DEFAULT 0,
    funds_received_ho NUMERIC DEFAULT 0,
    funds_received_other_branch NUMERIC DEFAULT 0,
    fund_to_asset_program NUMERIC DEFAULT 0,
    fund_to_product_finance NUMERIC DEFAULT 0,
    office_expenses NUMERIC DEFAULT 0,
    laps_returns NUMERIC DEFAULT 0,
    bank_deposit NUMERIC DEFAULT 0,
    bank_withdrawal NUMERIC DEFAULT 0,
    product_withdrawal NUMERIC DEFAULT 0,
    fund_transferred_other_branch NUMERIC DEFAULT 0,
    fund_transferred_ho NUMERIC DEFAULT 0,
    fund_to_other_area NUMERIC DEFAULT 0,
    staff_salaries NUMERIC DEFAULT 0,
    savings_withdrawal NUMERIC DEFAULT 0,
    total_inflows NUMERIC DEFAULT 0,
    total_outflows NUMERIC DEFAULT 0,
    closing_balance NUMERIC DEFAULT 0,
    adjustment_in NUMERIC DEFAULT 0,
    adjustment_out NUMERIC DEFAULT 0,
    adjustment_reason TEXT,
    status TEXT DEFAULT 'Open' CHECK (status IN ('Open', 'Closed', 'Verified')),
    verified_by UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    verified_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(date, branch_id)
);

-- 24. CHART OF ACCOUNTS
CREATE TABLE public.chart_of_accounts (
    account_code TEXT PRIMARY KEY,
    account_name TEXT NOT NULL,
    account_type TEXT NOT NULL CHECK (account_type IN ('Asset', 'Liability', 'Equity', 'Revenue', 'Expense')),
    parent_account TEXT,
    normal_balance TEXT CHECK (normal_balance IN ('Debit', 'Credit')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 25. POSTING RULES
CREATE TABLE public.posting_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    debit_account TEXT REFERENCES public.chart_of_accounts(account_code) ON DELETE RESTRICT,
    credit_account TEXT REFERENCES public.chart_of_accounts(account_code) ON DELETE RESTRICT,
    version INTEGER DEFAULT 1,
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to DATE,
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_type, version)
);

-- 26. EVENT STORE
CREATE TABLE public.event_store (
    event_id UUID PRIMARY KEY,
    aggregate_id UUID,
    aggregate_type TEXT,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    version INTEGER DEFAULT 1,
    status TEXT CHECK (status IN ('Pending', 'Processing', 'Completed', 'Failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 27. EVENT PROCESSING
CREATE TABLE public.event_processing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES public.event_store(event_id) ON DELETE CASCADE,
    processor_name TEXT NOT NULL,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Processing', 'Posted', 'Reversed', 'Cancelled', 'Failed')),
    processed_at TIMESTAMP WITH TIME ZONE,
    retry_count INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(event_id, processor_name)
);

-- 28. FINANCIAL TRANSACTIONS (Journal Entry Header)
CREATE TABLE public.financial_transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID REFERENCES public.event_store(event_id) ON DELETE SET NULL,
    posting_date DATE NOT NULL,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    officer_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    narration TEXT,
    reference TEXT,
    status TEXT DEFAULT 'Posted' CHECK (status IN ('Pending', 'Processing', 'Posted', 'Reversed', 'Cancelled', 'Failed')),
    reversal_of UUID REFERENCES public.financial_transactions(transaction_id) ON DELETE SET NULL,
    currency_code TEXT DEFAULT 'NGN',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 29. FINANCIAL LEDGER ENTRIES (Double-Entry Ledger Items)
CREATE TABLE public.financial_ledger_entries (
    entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID REFERENCES public.financial_transactions(transaction_id) ON DELETE CASCADE,
    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
    account_code TEXT REFERENCES public.chart_of_accounts(account_code) ON DELETE RESTRICT,
    side TEXT NOT NULL CHECK (side IN ('Debit', 'Credit')),
    amount NUMERIC NOT NULL CHECK (amount > 0),
    aggregate_type TEXT NOT NULL,
    aggregate_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 30. AUDIT LOGS
CREATE TABLE public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.app_users(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    description TEXT,
    table_name TEXT,
    record_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 31. NOTIFICATIONS
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL,
    recipient TEXT NOT NULL,
    payload JSONB DEFAULT '{}'::jsonb,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Sent', 'Failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 32. SETTINGS
CREATE TABLE public.settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- ============================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================

-- Security Indexes
CREATE INDEX IF NOT EXISTS idx_app_users_branch_id ON public.app_users(branch_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role_id ON public.user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id ON public.role_permissions(role_id);

-- Organization Indexes
CREATE INDEX IF NOT EXISTS idx_zones_region_id ON public.zones(region_id);
CREATE INDEX IF NOT EXISTS idx_branches_zone_id ON public.branches(zone_id);

-- Groups Indexes
CREATE INDEX IF NOT EXISTS idx_groups_branch_id ON public.groups(branch_id);
CREATE INDEX IF NOT EXISTS idx_groups_officer_id ON public.groups(officer_id);
CREATE INDEX IF NOT EXISTS idx_groups_status ON public.groups(status);

-- Client Memberships Indexes
CREATE INDEX IF NOT EXISTS idx_client_memberships_client_id ON public.client_memberships(client_id);
CREATE INDEX IF NOT EXISTS idx_client_memberships_group_id ON public.client_memberships(group_id);
CREATE INDEX IF NOT EXISTS idx_client_memberships_branch_id ON public.client_memberships(branch_id);
CREATE INDEX IF NOT EXISTS idx_client_memberships_officer_id ON public.client_memberships(officer_id);

-- Loans Indexes
CREATE INDEX IF NOT EXISTS idx_loans_client_id ON public.loans(client_id);
CREATE INDEX IF NOT EXISTS idx_loans_product_id ON public.loans(product_id);
CREATE INDEX IF NOT EXISTS idx_loans_branch_id ON public.loans(branch_id);
CREATE INDEX IF NOT EXISTS idx_loans_officer_id ON public.loans(officer_id);
CREATE INDEX IF NOT EXISTS idx_loans_date ON public.loans(date);
CREATE INDEX IF NOT EXISTS idx_loans_status ON public.loans(status);

-- Loan Schedule Indexes
CREATE INDEX IF NOT EXISTS idx_loan_schedule_loan_id ON public.loan_schedule(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_schedule_due_date ON public.loan_schedule(due_date);
CREATE INDEX IF NOT EXISTS idx_loan_schedule_status ON public.loan_schedule(status);

-- Repayments Indexes
CREATE INDEX IF NOT EXISTS idx_repayments_loan_id ON public.repayments(loan_id);
CREATE INDEX IF NOT EXISTS idx_repayments_client_id ON public.repayments(client_id);
CREATE INDEX IF NOT EXISTS idx_repayments_officer_id ON public.repayments(officer_id);
CREATE INDEX IF NOT EXISTS idx_repayments_branch_id ON public.repayments(branch_id);
CREATE INDEX IF NOT EXISTS idx_repayments_date ON public.repayments(date);

-- Savings Indexes
CREATE INDEX IF NOT EXISTS idx_individual_savings_posting_date ON public.individual_savings(posting_date);
CREATE INDEX IF NOT EXISTS idx_individual_savings_client_id ON public.individual_savings(client_id);
CREATE INDEX IF NOT EXISTS idx_individual_savings_branch_id ON public.individual_savings(branch_id);
CREATE INDEX IF NOT EXISTS idx_individual_savings_officer_id ON public.individual_savings(officer_id);

CREATE INDEX IF NOT EXISTS idx_group_savings_posting_date ON public.group_savings(posting_date);
CREATE INDEX IF NOT EXISTS idx_group_savings_group_id ON public.group_savings(group_id);
CREATE INDEX IF NOT EXISTS idx_group_savings_branch_id ON public.group_savings(branch_id);
CREATE INDEX IF NOT EXISTS idx_group_savings_officer_id ON public.group_savings(officer_id);

CREATE INDEX IF NOT EXISTS idx_internal_savings_posting_date ON public.internal_savings(posting_date);
CREATE INDEX IF NOT EXISTS idx_internal_savings_client_id ON public.internal_savings(client_id);
CREATE INDEX IF NOT EXISTS idx_internal_savings_branch_id ON public.internal_savings(branch_id);
CREATE INDEX IF NOT EXISTS idx_internal_savings_officer_id ON public.internal_savings(officer_id);

CREATE INDEX IF NOT EXISTS idx_laps_savings_posting_date ON public.laps_savings(posting_date);
CREATE INDEX IF NOT EXISTS idx_laps_savings_client_id ON public.laps_savings(client_id);
CREATE INDEX IF NOT EXISTS idx_laps_savings_branch_id ON public.laps_savings(branch_id);
CREATE INDEX IF NOT EXISTS idx_laps_savings_officer_id ON public.laps_savings(officer_id);

-- Fees Indexes
CREATE INDEX IF NOT EXISTS idx_fees_posting_date ON public.fees(posting_date);
CREATE INDEX IF NOT EXISTS idx_fees_client_id ON public.fees(client_id);
CREATE INDEX IF NOT EXISTS idx_fees_branch_id ON public.fees(branch_id);
CREATE INDEX IF NOT EXISTS idx_fees_officer_id ON public.fees(officer_id);

-- Treasury Indexes
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_posting_date ON public.treasury_transactions(posting_date);
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_branch_id ON public.treasury_transactions(branch_id);
CREATE INDEX IF NOT EXISTS idx_treasury_transactions_officer_id ON public.treasury_transactions(officer_id);

-- Master Cashbook Indexes
CREATE INDEX IF NOT EXISTS idx_master_cashbook_date ON public.master_cashbook(date);
CREATE INDEX IF NOT EXISTS idx_master_cashbook_branch_id ON public.master_cashbook(branch_id);

-- Accounting Indexes
CREATE INDEX IF NOT EXISTS idx_posting_rules_event_type ON public.posting_rules(event_type);
CREATE INDEX IF NOT EXISTS idx_posting_rules_debit_account ON public.posting_rules(debit_account);
CREATE INDEX IF NOT EXISTS idx_posting_rules_credit_account ON public.posting_rules(credit_account);

CREATE INDEX IF NOT EXISTS idx_financial_transactions_event_id ON public.financial_transactions(event_id);
CREATE INDEX IF NOT EXISTS idx_financial_transactions_posting_date ON public.financial_transactions(posting_date);
CREATE INDEX IF NOT EXISTS idx_financial_transactions_branch_id ON public.financial_transactions(branch_id);
CREATE INDEX IF NOT EXISTS idx_financial_transactions_officer_id ON public.financial_transactions(officer_id);
CREATE INDEX IF NOT EXISTS idx_financial_transactions_status ON public.financial_transactions(status);

CREATE INDEX IF NOT EXISTS idx_financial_ledger_entries_transaction_id ON public.financial_ledger_entries(transaction_id);
CREATE INDEX IF NOT EXISTS idx_financial_ledger_entries_branch_id ON public.financial_ledger_entries(branch_id);
CREATE INDEX IF NOT EXISTS idx_financial_ledger_entries_account_code ON public.financial_ledger_entries(account_code);
CREATE INDEX IF NOT EXISTS idx_financial_ledger_entries_aggregate_id ON public.financial_ledger_entries(aggregate_id);

-- Event Store Indexes
CREATE INDEX IF NOT EXISTS idx_event_store_event_type ON public.event_store(event_type);
CREATE INDEX IF NOT EXISTS idx_event_store_aggregate_id ON public.event_store(aggregate_id);
CREATE INDEX IF NOT EXISTS idx_event_store_status ON public.event_store(status);
CREATE INDEX IF NOT EXISTS idx_event_processing_event_id ON public.event_processing(event_id);

-- Audit Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON public.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at);

-- Notification Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications(status);

-- Branch Closures Indexes
CREATE INDEX IF NOT EXISTS idx_branch_closures_dates ON public.branch_closures(start_date, end_date);


-- ============================================================
-- SEED DATA
-- ============================================================

-- Seed Roles
INSERT INTO public.roles (role_id, name, description) VALUES
('59539343-690a-4286-9467-854728562d5f', 'Admin', 'Full administrative system access'),
('3ea1496a-0498-4a1d-872a-1c7ecdf77b06', 'Branch Manager', 'Branch operations supervisor'),
('bd8790ee-c0eb-485a-8b6a-93f54519965d', 'Credit Officer', 'Field officer handling loans and savings collections')
ON CONFLICT (role_id) DO NOTHING;

-- Seed Default Organization Setup
INSERT INTO public.regions (region_id, name) VALUES
('b278a9c8-0402-4b2a-89aa-0c58e7279c6d', 'Default Region')
ON CONFLICT (region_id) DO NOTHING;

INSERT INTO public.zones (zone_id, region_id, name) VALUES
('c79427b2-d3a9-450f-aa4e-c4f4b2382103', 'b278a9c8-0402-4b2a-89aa-0c58e7279c6d', 'Default Zone')
ON CONFLICT (zone_id) DO NOTHING;

INSERT INTO public.branches (branch_id, zone_id, name) VALUES
('1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d', 'c79427b2-d3a9-450f-aa4e-c4f4b2382103', 'Lagos')
ON CONFLICT (branch_id) DO NOTHING;

-- Seed Default Admin User (username: admin, password: 1234)
INSERT INTO public.app_users (id, username, password_hash, full_name, branch_id, is_active) VALUES
('00000000-0000-0000-0000-000000000000', 'admin', '$2b$12$i2YNsrLcPjBKkfi4nOpWMOSXS8UlzP5RgPohY.QdaBTYG5vthy5L6', 'System Administrator', '1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Assign Admin Role to default admin user
INSERT INTO public.user_roles (user_id, role_id) VALUES
('00000000-0000-0000-0000-000000000000', '59539343-690a-4286-9467-854728562d5f')
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Seed Loan Products
INSERT INTO public.loan_products (name, repayment_cycle, interest_rate, max_term, installments, rounding_rule) VALUES
('Daily 60 Days', 'Daily', 12.00, 60, 60, 50),
('Daily 120 Days', 'Daily', 21.00, 120, 120, 50),
('Weekly 12W', 'Weekly', 12.00, 12, 12, 50),
('Weekly 24W', 'Weekly', 21.00, 24, 24, 50),
('Monthly 3M', 'Monthly', 12.00, 3, 3, 100),
('Monthly 6M', 'Monthly', 21.00, 6, 6, 100),
('60-Day Asset', 'Daily', 12.00, 60, 60, 50),
('120-Day Asset', 'Daily', 21.00, 120, 120, 50),
('Weekly 12W Asset', 'Weekly', 12.00, 12, 12, 50),
('Weekly 24W Asset', 'Weekly', 21.00, 24, 24, 50),
('Monthly 3M Asset', 'Monthly', 12.00, 3, 3, 100),
('Monthly 6M Asset', 'Monthly', 21.00, 6, 6, 100),
('Cash and Carry', 'Monthly', 0.00, 1, 1, 1)
ON CONFLICT (name) DO UPDATE SET
    repayment_cycle = EXCLUDED.repayment_cycle,
    interest_rate = EXCLUDED.interest_rate,
    max_term = EXCLUDED.max_term,
    installments = EXCLUDED.installments,
    rounding_rule = EXCLUDED.rounding_rule;

-- Seed Chart of Accounts
INSERT INTO public.chart_of_accounts (account_code, account_name, account_type, normal_balance) VALUES
('1000', 'Vault Cash', 'Asset', 'Debit'),
('1010', 'Main Vault', 'Asset', 'Debit'),
('1020', 'Branch Vault', 'Asset', 'Debit'),
('1050', 'Bank', 'Asset', 'Debit'),
('1200', 'Loan Portfolio', 'Asset', 'Debit'),
('1300', 'Asset Inventory', 'Asset', 'Debit'),
('2000', 'Individual Deposits', 'Liability', 'Credit'),
('2010', 'Group Deposits', 'Liability', 'Credit'),
('2020', 'Internal Savings', 'Liability', 'Credit'),
('2030', 'LAPS Savings', 'Liability', 'Credit'),
('3000', 'Fee Income', 'Revenue', 'Credit'),
('3100', 'Head Office Capital', 'Equity', 'Credit'),
('3200', 'Asset Sales', 'Revenue', 'Credit'),
('4000', 'Office Expenses', 'Expense', 'Debit'),
('4100', 'Salary Expenses', 'Expense', 'Debit')
ON CONFLICT (account_code) DO UPDATE SET
    account_name = EXCLUDED.account_name,
    account_type = EXCLUDED.account_type,
    normal_balance = EXCLUDED.normal_balance;

-- Seed Posting Rules
INSERT INTO public.posting_rules (event_type, debit_account, credit_account, version, enabled) VALUES
('LoanDisbursed', '1200', '1000', 1, TRUE),
('RepaymentReceived', '1000', '1200', 1, TRUE),
('SavingsDeposited', '1000', '2000', 1, TRUE),
('SavingsWithdrawn', '2000', '1000', 1, TRUE),
('FeeCharged', '1000', '3000', 1, TRUE),
('BankDeposited', '1050', '1000', 1, TRUE),
('BankWithdrawn', '1000', '1050', 1, TRUE),
('CashTransferred_HO_In', '1000', '3100', 1, TRUE),
('CashTransferred_HO_Out', '3100', '1000', 1, TRUE),
('ExpenseRecorded', '4000', '1000', 1, TRUE),
('SalaryPaid', '4100', '1000', 1, TRUE),
('AssetSoldCash', '1000', '3200', 1, TRUE),
('PenaltyCharged', '1000', '3000', 1, TRUE)
ON CONFLICT (event_type, version) DO UPDATE SET
    debit_account = EXCLUDED.debit_account,
    credit_account = EXCLUDED.credit_account,
    enabled = EXCLUDED.enabled;

INSERT INTO public.settings (key, value, description) VALUES
('core_banking_version', '2.3', 'Core Banking Greenfield baseline schema status')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
