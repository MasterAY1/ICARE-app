import psycopg2
import sys

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

all_hosts = ["3.249.49.8", "54.210.158.42"]

password = "Icare@2026"
dbname = "postgres"

connected = False
for host in all_hosts:
    for port in [5432, 6543]:
        for user in ["postgres.zkphpwixqpebsctfklpd", "postgres"]:
            try:
                print(f"Trying host={host}:{port} user={user}...", flush=True)
                conn = psycopg2.connect(
                    host=host,
                    user=user,
                    password=password,
                    dbname=dbname,
                    port=port,
                    connect_timeout=5
                )
                print(f"CONNECTED! host={host}:{port} user={user}", flush=True)
                cur = conn.cursor()
                cur.execute(sql_1a)
                print("Task 1A migration executed successfully.", flush=True)
                cur.execute(sql_1b)
                print("Task 1B migration executed successfully.", flush=True)
                conn.commit()
                cur.execute("NOTIFY pgrst, 'reload schema';")
                conn.commit()
                print("Schema reloaded!", flush=True)
                cur.close()
                conn.close()
                connected = True
                break
            except Exception as e:
                print(f"Fail: {e}", flush=True)
        if connected:
            break
    if connected:
        break

if not connected:
    print("Could not connect to any host.", flush=True)
    sys.exit(1)
