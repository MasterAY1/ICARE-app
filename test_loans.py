import sys
sys.path.append('.')
from database.repositories.unit_of_work import SupabaseUnitOfWork
import json

with SupabaseUnitOfWork() as uow:
    l_query = uow.client.table("loans").select("*").limit(1)
    l_res = l_query.execute()
    print("LOANS:")
    for l in l_res.data:
        print(json.dumps(l, indent=2))
