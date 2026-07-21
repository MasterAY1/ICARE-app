import psycopg2

hosts = [
    "db.zkphpwixqpebsctfklpd.supabase.co",
    "aws-0-us-east-1.pooler.supabase.com",
    "aws-0-eu-west-1.pooler.supabase.com",
    "aws-0-eu-central-1.pooler.supabase.com",
    "aws-0-ap-southeast-1.pooler.supabase.com",
    "aws-0-us-west-1.pooler.supabase.com",
    "aws-0-sa-east-1.pooler.supabase.com"
]

password = "Icare@2026"
dbname = "postgres"

for host in hosts:
    for port in [5432, 6543]:
        for user in ["postgres.zkphpwixqpebsctfklpd", "postgres"]:
            try:
                conn = psycopg2.connect(
                    host=host,
                    user=user,
                    password=password,
                    dbname=dbname,
                    port=port,
                    connect_timeout=3
                )
                print(f"!!! SUCCESS !!! Connected to {host}:{port} as {user}")
                cursor = conn.cursor()
                cursor.execute("""
                CREATE TABLE IF NOT EXISTS public.co_cashbooks (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    date DATE NOT NULL,
                    branch_id UUID REFERENCES public.branches(branch_id) ON DELETE RESTRICT,
                    officer_id UUID REFERENCES public.app_users(id) ON DELETE RESTRICT,
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
                    status TEXT DEFAULT 'COMPLETED',
                    version INTEGER DEFAULT 1,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    UNIQUE(date, branch_id, officer_id)
                );
                """)
                cursor.execute("ALTER TABLE public.master_cashbook ADD COLUMN IF NOT EXISTS version INTEGER DEFAULT 1;")
                conn.commit()
                cursor.execute("NOTIFY pgrst, 'reload schema';")
                conn.commit()
                print("DDL and Schema reload successful!")
                cursor.close()
                conn.close()
                exit(0)
            except Exception as e:
                print(f"Failed {host}:{port} ({user}): {e}")
