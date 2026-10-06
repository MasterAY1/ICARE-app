import re

# --- Fix portfolio_service.py ---
with open('services/portfolio_service.py', 'r', encoding='utf-8') as f:
    ps_content = f.read()

missing_filter = '''        # Fetch group memberships
        group_map = {}'''

added_filter = '''        # 2.5 Filter by Loan Product
        if selected_product and selected_product != "All":
            filtered_loans = []
            valid_client_ids = set()
            for l in loans_raw:
                p_name = (l.get("loan_products") or {}).get("name")
                if p_name == selected_product:
                    filtered_loans.append(l)
                    valid_client_ids.add(str(l.get("client_id")))
            
            loans_raw = filtered_loans
            clients_raw = [c for c in clients_raw if str(c.get("client_id") or c.get("id")) in valid_client_ids]

        # Fetch group memberships
        group_map = {}'''

if "# 2.5 Filter by Loan Product" not in ps_content:
    ps_content = ps_content.replace(missing_filter, added_filter)
    with open('services/portfolio_service.py', 'w', encoding='utf-8') as f:
        f.write(ps_content)
    print("Fixed portfolio_service.py")

# --- Fix app.py ---
with open('app.py', 'r', encoding='utf-8') as f:
    app_content = f.read()

app_old_prods = '''        all_prods = ["All"]
        try:
            p_res = uow_p.client.table("loan_products").select("name").execute()
            all_prods += sorted(list(set(p["name"] for p in (p_res.data or []) if p.get("name"))))
        except Exception:
            pass'''

app_new_prods = '''        all_prods = ["All"]
        allowed_p = []
        try:
            # Check if user is specific to loan products
            target_username = sel_officer if (sel_officer and sel_officer != "All") else (p_scope.username if p_scope.role == "CO" else None)
            if target_username:
                u_res = uow_p.client.table("app_users").select("extra_fields").eq("username", target_username).execute()
                if u_res.data:
                    extra = u_res.data[0].get("extra_fields") or {}
                    allowed_p = extra.get("allowed_products", [])
            
            p_res = uow_p.client.table("loan_products").select("name").execute()
            fetched_prods = sorted(list(set(p["name"] for p in (p_res.data or []) if p.get("name"))))
            
            if allowed_p:
                fetched_prods = [p for p in fetched_prods if p in allowed_p]
                
            all_prods += fetched_prods
        except Exception:
            pass'''

if "allowed_p = []" not in app_content:
    app_content = app_content.replace(app_old_prods, app_new_prods)
    with open('app.py', 'w', encoding='utf-8') as f:
        f.write(app_content)
    print("Fixed app.py")
