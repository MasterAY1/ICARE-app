import re

with open('services/portfolio_service.py', 'r', encoding='utf-8') as f:
    code = f.read()

# Fix 1: Change clients(name, nickname) back to clients(name, client_code)
code = code.replace(
    'clients(name, nickname)',
    'clients(name, client_code)'
)

# Fix 2: Change savings query to fetch deposit_amount and withdrawal_amount
old_savings = '''        # Fetch individual savings
        savings_map = {}
        try:
            if client_ids:
                s_query = uow.client.table("individual_savings").select("client_id, balance").in_("client_id", client_ids).execute()
                for s in (s_query.data or []):
                    cid_str = str(s.get("client_id"))
                    savings_map[cid_str] = savings_map.get(cid_str, 0.0) + float(s.get("balance") or 0.0)
        except Exception:
            pass'''

new_savings = '''        # Fetch individual savings
        savings_map = {}
        try:
            if client_ids:
                s_query = uow.client.table("individual_savings").select("client_id, deposit_amount, withdrawal_amount").in_("client_id", client_ids).execute()
                for s in (s_query.data or []):
                    cid_str = str(s.get("client_id"))
                    dep = float(s.get("deposit_amount") or 0.0)
                    wth = float(s.get("withdrawal_amount") or 0.0)
                    savings_map[cid_str] = savings_map.get(cid_str, 0.0) + (dep - wth)
        except Exception:
            pass'''

code = code.replace(old_savings, new_savings)

# Fix 3: c_info.get("nickname") -> c_info.get("client_code")
old_c_code = 'c_code = c_info.get("nickname") or "N/A"'
new_c_code = 'c_code = c_info.get("client_code") or "N/A"'
code = code.replace(old_c_code, new_c_code)

with open('services/portfolio_service.py', 'w', encoding='utf-8') as f:
    f.write(code)
print("Fixes applied to portfolio_service.py")
