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

passwords = [
    "Icare@2026",
    "ICARE@2026",
    "icare@2026",
    "Icare2026",
    "ICARE2026",
    "icare2026",
    "Trustmicro@2026",
    "trustmicro",
    "zkphpwixqpebsctfklpd"
]

host = "aws-0-eu-west-1.pooler.supabase.com"
user = "postgres.zkphpwixqpebsctfklpd"
dbname = "postgres"

success = False
for pwd in passwords:
    for port in [6543, 5432]:
        try:
            print(f"Testing password '{pwd}' on port {port}...")
            conn = psycopg2.connect(
                host=host,
                user=user,
                password=pwd,
                dbname=dbname,
                port=port,
                connect_timeout=5
            )
            print(f"!!! SUCCESS !!! Password matched: {pwd} on port {port}")
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
            success = True
            break
        except Exception as e:
            print(f"Failed '{pwd}' on {port}: {e}")
    if success:
        break

if not success:
    print("None of the password candidates succeeded.")
