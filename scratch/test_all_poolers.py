import socket
import psycopg2

regions = [
    "us-east-1", "us-east-2", "us-west-1", "us-west-2",
    "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1", "eu-north-1",
    "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "ap-south-1",
    "sa-east-1", "ca-central-1"
]

project_ref = "zkphpwixqpebsctfklpd"
user = f"postgres.{project_ref}"
password = "Icare@2026"
dbname = "postgres"

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

working_conn = None

for r in regions:
    host = f"aws-0-{r}.pooler.supabase.com"
    for port in [6543, 5432]:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1)
            res = s.connect_ex((host, port))
            s.close()
            if res == 0:
                print(f"Socket open on {host}:{port}! Attempting psycopg2...", flush=True)
                conn = psycopg2.connect(
                    host=host,
                    user=user,
                    password=password,
                    dbname=dbname,
                    port=port,
                    connect_timeout=5
                )
                print(f"!!! SUCCESS !!! Connected to {host}:{port}", flush=True)
                cur = conn.cursor()
                cur.execute(sql_1a)
                print("WP1 Task 1A executed.", flush=True)
                cur.execute(sql_1b)
                print("WP1 Task 1B executed.", flush=True)
                conn.commit()
                cur.execute("NOTIFY pgrst, 'reload schema';")
                conn.commit()
                print("Schema reloaded!", flush=True)
                cur.close()
                conn.close()
                working_conn = True
                break
        except Exception as e:
            print(f"Failed {host}:{port} -> {e}", flush=True)
    if working_conn:
        break

if not working_conn:
    print("No open pooler sockets found.", flush=True)
