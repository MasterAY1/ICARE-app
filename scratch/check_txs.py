import toml
from supabase import create_client

def check_txs():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    res_tx = client.table("financial_transactions").select("*").order("created_at", desc=True).limit(20).execute()
    txs = res_tx.data or []
    print(f"--- Financial Transactions ({len(txs)}) ---")
    for t in txs:
        print(f"TX: {t.get('transaction_id')} | Date: {t.get('posting_date')} | Officer: {t.get('officer_id')} | Narr: {t.get('narration')} | Ref: {t.get('reference')}")

    res_evt = client.table("event_store").select("*").order("created_at", desc=True).limit(20).execute()
    evts = res_evt.data or []
    print(f"\n--- Event Store ({len(evts)}) ---")
    for e in evts:
        print(f"Event: {e.get('event_id')} | Type: {e.get('event_type')} | Agg: {e.get('aggregate_type')} | AggID: {e.get('aggregate_id')} | Payload: {e.get('payload')}")

if __name__ == "__main__":
    check_txs()
