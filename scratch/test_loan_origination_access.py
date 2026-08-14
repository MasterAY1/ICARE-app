from database.repositories.unit_of_work import SupabaseUnitOfWork

uow = SupabaseUnitOfWork()

print("==================================================")
print("Testing User Product Permissions & Origination Flow")
print("==================================================")

res_users = uow.client.table("app_users").select("*").execute()
users = res_users.data or []
if users:
    print("Columns on app_users:", list(users[0].keys()))

finance_all = ["Daily 60 Days", "Daily 120 Days", "Weekly 12W", "Weekly 24W", "Monthly 3M", "Monthly 6M"]
asset_all = ["60-Day Asset", "120-Day Asset", "Weekly 12W Asset", "Weekly 24W Asset", "Monthly 3M Asset", "Monthly 6M Asset", "Cash and Carry"]

for u in users:
    username = u.get("username")
    role = u.get("role_alias")
    extra = u.get("extra_fields") or {}
    if isinstance(extra, str):
        import json
        try:
            extra = json.loads(extra)
        except:
            extra = {}
    
    allowed = extra.get("allowed_products", []) if isinstance(extra, dict) else []
    
    # Test Finance resolution
    prods_fin = list(finance_all)
    if isinstance(allowed, list) and len(allowed) > 0:
        filtered_fin = [p for p in prods_fin if p in allowed]
        prods_fin = filtered_fin if filtered_fin else []
        
    # Test Asset resolution
    prods_ass = list(asset_all)
    if isinstance(allowed, list) and len(allowed) > 0:
        filtered_ass = [p for p in prods_ass if p in allowed]
        prods_ass = filtered_ass if filtered_ass else []
        
    print(f"User: {username:<15} | Role: {str(role):<10} | Allowed Ext: {len(allowed)} | Finance Prods: {len(prods_fin)} | Asset Prods: {len(prods_ass)}")
    assert len(prods_fin) > 0, f"User {username} blocked from Finance products!"
    assert len(prods_ass) > 0, f"User {username} blocked from Asset products!"

print("\n>> All users can successfully originate loan products without erroneous RBAC blocking!")
