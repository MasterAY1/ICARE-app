import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()
url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_KEY')
supabase = create_client(url, key)

# Supabase python client doesn't directly support DDL queries like ALTER TABLE.
# We will use the REST API via RPC if we had an execute_sql function, 
# or since this is just a constraint check, we can define a list of valid types
# and ensure our mappers coerce to either 'Loan' or 'Savings', 
# or perhaps the user can run this SQL in Supabase directly.
print("To fix the constraint, run the following SQL in Supabase SQL Editor:")
print("ALTER TABLE repayments DROP CONSTRAINT IF EXISTS repayments_transaction_type_check;")
print("ALTER TABLE repayments ADD CONSTRAINT repayments_transaction_type_check CHECK (transaction_type IN ('Loan', 'Savings', 'Opening Savings Balance', 'Collection (Bulk Upload)', 'Group Global Savings (Bulk Upload)', 'Laps Savings (Bulk Upload)', 'Group Meeting', 'End of Day'));")
