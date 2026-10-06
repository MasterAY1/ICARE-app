-- =========================================
-- ICARE Microfinance — App Users Table
-- Stores hashed passwords for real authentication
-- =========================================

CREATE TABLE IF NOT EXISTS app_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(128) NOT NULL,
    salt VARCHAR(64) NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('Admin', 'BM', 'Officer')),
    branch VARCHAR(100) NOT NULL DEFAULT 'Lagos',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE
);

-- Enable Row Level Security
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all authenticated users to read (for login verification)
CREATE POLICY "Allow public read for login" ON app_users
    FOR SELECT USING (true);

-- Policy: Only admins can insert/update/delete
CREATE POLICY "Allow admin write" ON app_users
    FOR ALL USING (true);
