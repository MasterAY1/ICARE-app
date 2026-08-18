import toml
from datetime import date
from supabase import create_client
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder

def inspect_co_cashbook_state():
    secrets = toml.load(".streamlit/secrets.toml")
    client = create_client(secrets["SUPABASE_URL"], secrets["SUPABASE_KEY"])

    # 1. Check financial_ledger_entries
    res_l = client.table("financial_ledger_entries").select("entry_id, account_code, amount, side, branch_id, financial_transactions(posting_date, officer_id, narration)").limit(20).execute()
    print("=== FINANCIAL LEDGER ENTRIES ===")
    for entry in (res_l.data or []):
        tx = entry.get("financial_transactions") or {}
        print(f"Entry: {entry.get('entry_id')[:8]} | Acc: {entry.get('account_code')} | Side: {entry.get('side')} | Amt: {entry.get('amount')} | Date: {tx.get('posting_date')} | Officer: {tx.get('officer_id')}")

    # 2. Check co_cashbooks table
    res_cb = client.table("co_cashbooks").select("*").execute()
    print(f"\n=== CO CASHBOOKS TABLE ({len(res_cb.data or [])} rows) ===")
    for cb in (res_cb.data or []):
        print(f"Date: {cb.get('date')} | Officer: {cb.get('officer_id')} | Opening: {cb.get('opening_balance')} | Inflows: {cb.get('total_inflows')} | Outflows: {cb.get('total_outflows')} | Closing: {cb.get('closing_balance')}")

    # 3. Test rebuild for all active officers for today
    print(f"\n=== REBUILD CO PROJECTION TEST ===")
    with SupabaseUnitOfWork() as uow:
        # Get users
        res_u = uow.client.table("app_users").select("id, username, branch_id").execute()
        for u in (res_u.data or []):
            u_id = u.get("id")
            b_id = u.get("branch_id")
            u_name = u.get("username")
            if b_id:
                cb_proj = CoCashbookProjectionBuilder.rebuild_co_projection(uow, b_id, u_id, date.today())
                if cb_proj:
                    print(f"Officer {u_name} ({u_id}): Opening={cb_proj.get('opening_balance')}, Inflows={cb_proj.get('total_inflows')}, Outflows={cb_proj.get('total_outflows')}, Closing={cb_proj.get('closing_balance')}")

if __name__ == "__main__":
    inspect_co_cashbook_state()
