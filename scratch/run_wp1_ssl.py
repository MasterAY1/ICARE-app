import psycopg2

sql_1a = """
CREATE TABLE IF NOT EXISTS public.collection_performance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID NOT NULL REFERENCES public.clients(client_id),
    loan_id UUID NOT NULL REFERENCES public.loans(loan_id),
    officer_id UUID NOT NULL REFERENCES public.app_users(id),
    meeting_date DATE NOT NULL,
    expected_amount NUMERIC(15, 2) NOT NULL DEFAULT 0,
    amount_paid NUMERIC(15, 2) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PAID', 'PART_PAYMENT', 'NOT_PAID')),
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cp_client_date ON public.collection_performance(client_id, meeting_date);
CREATE INDEX IF NOT EXISTS idx_cp_officer_date ON public.collection_performance(officer_id, meeting_date);
CREATE INDEX IF NOT EXISTS idx_cp_loan ON public.collection_performance(loan_id);
"""

sql_1b = """
ALTER TABLE public.loan_products 
    ADD COLUMN IF NOT EXISTS eligibility_threshold NUMERIC(5, 2) DEFAULT 90.0,
    ADD COLUMN IF NOT EXISTS review_meeting_count INTEGER DEFAULT 12;
"""

hosts = [
    'aws-0-eu-west-1.pooler.supabase.com',
    'aws-0-eu-central-1.pooler.supabase.com',
    'aws-0-us-east-1.pooler.supabase.com'
]

success = False
for host in hosts:
    for port in [5432, 6543]:
        for user in ['postgres.zkphpwixqpebsctfklpd', 'postgres']:
            try:
                print(f"Testing {host}:{port} user={user}...")
                conn = psycopg2.connect(
                    host=host,
                    user=user,
                    password='Icare@2026',
                    dbname='postgres',
                    port=port,
                    sslmode='require',
                    connect_timeout=5
                )
                print(f"SUCCESS! Connected to {host}:{port} as {user}")
                cur = conn.cursor()
                cur.execute(sql_1a)
                cur.execute(sql_1b)
                conn.commit()
                cur.execute("NOTIFY pgrst, 'reload schema';")
                conn.commit()
                print("Migrations executed successfully!")
                cur.close()
                conn.close()
                success = True
                break
            except Exception as e:
                print(f"Failed {host}:{port} ({user}): {e}")
        if success:
            break
    if success:
        break

if not success:
    print("Could not connect with sslmode=require.")
