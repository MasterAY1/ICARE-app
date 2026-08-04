import sys
sys.path.append('.')
from database.repositories.unit_of_work import SupabaseUnitOfWork

with SupabaseUnitOfWork() as uow:
    l_query = uow.client.table("loans").select("*, clients(name, client_code), loan_products(name), app_users(username), branches(name)").limit(3)
    l_res = l_query.execute()
    print("LOANS:")
    for l in l_res.data:
        print(l.get("loan_id"), " -> ", l.get("loan_products"))
