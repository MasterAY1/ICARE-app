import sys
from datetime import date
from database.connection import get_supabase_client

def verify():
    client = get_supabase_client()
    p_date = date.today().isoformat()
    
    # Get total ledger changes for today for Account 1000
    res = client.table("financial_ledger_entries") \
        .select("amount, side, branch_id") \
        .eq("account_code", "1000") \
        .execute()
        
    res_tx = client.table("financial_ledger_entries") \
        .select("amount, side, branch_id, financial_transactions!inner(posting_date)") \
        .eq("account_code", "1000") \
        .eq("financial_transactions.posting_date", p_date) \
        .execute()
        
    ledger_net = 0.0
    for r in res_tx.data or []:
        amt = float(r.get("amount") or 0.0)
        if r.get("side") == "Debit":
            ledger_net += amt
        else:
            ledger_net -= amt
            
    print(f"Total Net Flow (Debit - Credit) in Ledger 1000 for today: {ledger_net}")
    
    # Get sum of all Master Cashbooks for today (inflows - outflows)
    res_mc = client.table("master_cashbook").select("total_inflows, total_outflows").eq("date", p_date).execute()
    cb_net = 0.0
    for r in res_mc.data or []:
        cb_net += float(r.get("total_inflows") or 0.0) - float(r.get("total_outflows") or 0.0)
        
    print(f"Total Net Flow (Inflows - Outflows) in Master Cashbooks for today: {cb_net}")
    print(f"Match: {ledger_net == cb_net}")
    
if __name__ == "__main__":
    verify()
