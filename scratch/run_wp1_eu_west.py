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

regions = [
    "eu-west-1", "eu-central-1", "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    "eu-west-2", "eu-west-3", "eu-north-1", "ap-southeast-1", "ap-southeast-2",
    "ap-northeast-1", "ap-south-1", "sa-east-1", "ca-central-1"
]

project_ref = "zkphpwixqpebsctfklpd"
user = f"postgres.{project_ref}"
password = "Icare@2026"
dbname = "postgres"

for r in regions:
    host = f"aws-0-{r}.pooler.supabase.com"
    for port in [5432, 6543]:
        try:
            conn = psycopg2.connect(
                host=host,
                user=user,
                password=password,
                dbname=dbname,
                port=port,
                connect_timeout=3
            )
            print(f"!!! SUCCESS !!! Connected to {host}:{port}")
            cur = conn.cursor()
            cur.execute(sql_1a)
            print("Task 1A: collection_performance table and indexes created.")
            cur.execute(sql_1b)
            print("Task 1B: loan_products eligibility columns added.")
            conn.commit()
            cur.execute("NOTIFY pgrst, 'reload schema';")
            conn.commit()
            print("Schema reloaded successfully!")
            cur.close()
            conn.close()
            exit(0)
        except Exception as e:
            msg = str(e).strip()
            if "tenant/user postgres.zkphpwixqpebsctfklpd not found" not in msg:
                print(f"Host {host}:{port} -> {msg}")
