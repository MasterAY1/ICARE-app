-- TrustMicro Credit Database Schema
-- Run this in Supabase SQL Editor to set up your database

-- ============================================
-- LOANS TABLE
-- Stores all loan applications and active loans
-- ============================================
CREATE TABLE IF NOT EXISTS loans (
    client_id UUID PRIMARY KEY,
    date DATE NOT NULL,
    branch TEXT,
    officer TEXT,
    client_name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    business_type TEXT,
    group_name TEXT,
    meeting_day TEXT,
    loan_product TEXT,
    loan_amount NUMERIC DEFAULT 0,
    active_credit NUMERIC DEFAULT 0,
    loan_repay NUMERIC DEFAULT 0,
    total_due NUMERIC DEFAULT 0,
    status TEXT DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Active', 'Completed'))
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_loans_officer ON loans(officer);
CREATE INDEX IF NOT EXISTS idx_loans_branch ON loans(branch);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_loans_date ON loans(date);

-- ============================================
-- REPAYMENTS TABLE
-- Stores all payment transactions
-- ============================================
CREATE TABLE IF NOT EXISTS repayments (
    id SERIAL PRIMARY KEY,
    date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    branch TEXT,
    client_id UUID REFERENCES loans(client_id) ON DELETE CASCADE,
    client_name TEXT,
    amount_paid NUMERIC DEFAULT 0,
    officer TEXT,
    note TEXT,
    transaction_type TEXT DEFAULT 'Loan' CHECK (transaction_type IN ('Loan', 'Savings'))
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_repayments_client_id ON repayments(client_id);
CREATE INDEX IF NOT EXISTS idx_repayments_date ON repayments(date);
CREATE INDEX IF NOT EXISTS idx_repayments_officer ON repayments(officer);

-- ============================================
-- AUDIT LOG TABLE (Optional)
-- Tracks all changes for compliance
-- ============================================
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_name TEXT,
    user_role TEXT,
    action TEXT,
    table_name TEXT,
    record_id TEXT,
    old_values JSONB,
    new_values JSONB
);

CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_name);

-- ============================================
-- ROW LEVEL SECURITY POLICIES
-- Enable RLS for security
-- ============================================

-- Enable RLS on loans table
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;

-- Enable RLS on repayments table
ALTER TABLE repayments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view all loans (adjust as needed)
CREATE POLICY "Enable read access for all users" ON loans
    FOR SELECT USING (true);

-- Policy: Users can insert loans
CREATE POLICY "Enable insert access for all users" ON loans
    FOR INSERT WITH CHECK (true);

-- Policy: Users can update loans
CREATE POLICY "Enable update access for all users" ON loans
    FOR UPDATE USING (true);

-- Policy: Users can view all repayments
CREATE POLICY "Enable read access for all users" ON repayments
    FOR SELECT USING (true);

-- Policy: Users can insert repayments
CREATE POLICY "Enable insert access for all users" ON repayments
    FOR INSERT WITH CHECK (true);

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- Uncomment to add sample data
-- ============================================
/*
INSERT INTO loans (client_id, date, branch, officer, client_name, phone, address, business_type, group_name, meeting_day, loan_product, loan_amount, active_credit, loan_repay, total_due, status)
VALUES 
    ('550e8400-e29b-41d4-a716-446655440000', '2024-01-15', 'Lagos', 'John', 'Test Client 1', '08012345678', 'Lagos Island', 'Trader', 'Market Women A', 'Monday', 'Daily Loan (60 Days)', 100000, 95000, 2000, 95000, 'Active'),
    ('550e8400-e29b-41d4-a716-446655440001', '2024-01-20', 'Lagos', 'Jane', 'Test Client 2', '08087654321', 'Ikeja', 'Artisan', 'Artisans B', 'Tuesday', 'Weekly Loan (12 Weeks)', 200000, 190000, 17000, 190000, 'Active');

INSERT INTO repayments (date, branch, client_id, client_name, amount_paid, officer, note, transaction_type)
VALUES 
    ('2024-01-15 10:00:00', 'Lagos', '550e8400-e29b-41d4-a716-446655440000', 'Test Client 1', 2000, 'John', 'First payment', 'Loan'),
    ('2024-01-16 10:00:00', 'Lagos', '550e8400-e29b-41d4-a716-446655440000', 'Test Client 1', 2000, 'John', 'Second payment', 'Loan');
*/

-- ============================================
-- VIEWS FOR REPORTING
-- ============================================

-- View: Active Loans Summary
CREATE OR REPLACE VIEW vw_active_loans AS
SELECT 
    l.*,
    COALESCE(SUM(r.amount_paid), 0) as total_paid
FROM loans l
LEFT JOIN repayments r ON l.client_id = r.client_id
WHERE l.status IN ('Approved', 'Active')
GROUP BY l.client_id;

-- View: Officer Performance
CREATE OR REPLACE VIEW vw_officer_performance AS
SELECT 
    officer,
    COUNT(*) as total_loans,
    SUM(active_credit) as total_portfolio,
    SUM(COALESCE(r.total_repaid, 0)) as total_repaid
FROM loans l
LEFT JOIN (
    SELECT client_id, SUM(amount_paid) as total_repaid
    FROM repayments
    GROUP BY client_id
) r ON l.client_id = r.client_id
WHERE l.status IN ('Approved', 'Active')
GROUP BY officer;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function: Calculate overdue amount
CREATE OR REPLACE FUNCTION calculate_overdue(
    p_start_date DATE,
    p_product TEXT,
    p_fixed_repay NUMERIC,
    p_total_paid NUMERIC
) RETURNS NUMERIC AS $$
DECLARE
    v_expected NUMERIC := 0;
    v_overdue NUMERIC := 0;
    v_days_passed INTEGER;
    v_weeks_passed INTEGER;
BEGIN
    IF p_product LIKE '%Daily%' THEN
        v_days_passed := LEAST(GREATEST(EXTRACT(DAY FROM CURRENT_DATE - p_start_date) - 1, 0), 60);
        v_expected := v_days_passed * p_fixed_repay;
    ELSIF p_product LIKE '%12 Weeks%' THEN
        v_weeks_passed := LEAST(GREATEST(EXTRACT(DAY FROM CURRENT_DATE - p_start_date) / 7, 0), 12);
        v_expected := v_weeks_passed * p_fixed_repay;
    ELSIF p_product LIKE '%24 Weeks%' THEN
        v_weeks_passed := LEAST(GREATEST(EXTRACT(DAY FROM CURRENT_DATE - p_start_date) / 7, 0), 24);
        v_expected := v_weeks_passed * p_fixed_repay;
    END IF;
    
    v_overdue := GREATEST(v_expected - p_total_paid, 0);
    RETURN v_overdue;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- END OF SCHEMA
-- ============================================
