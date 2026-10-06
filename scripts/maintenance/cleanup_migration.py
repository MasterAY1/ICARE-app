from database.repositories.unit_of_work import SupabaseUnitOfWork

def cleanup():
    print("Starting cleanup...")
    with SupabaseUnitOfWork() as uow:
        # 1. Cleanup Individual Savings
        print("Fetching Individual Savings to delete...")
        is_res = uow.client.table("individual_savings").select("id").eq("remarks", "Initial Onboarding Savings").execute()
        if is_res.data:
            ids = [r['id'] for r in is_res.data]
            print(f"Deleting {len(ids)} individual savings records...")
            # Supabase doesn't support 'in' easily with large lists in the python client sometimes, so we delete in batches
            for i in range(0, len(ids), 100):
                batch = ids[i:i+100]
                uow.client.table("individual_savings").delete().in_("id", batch).execute()
        
        # 2. Cleanup Group Savings
        print("Fetching Group Savings to delete...")
        gs_res = uow.client.table("group_savings").select("id").eq("remarks", "Initial Onboarding Group Savings").execute()
        if gs_res.data:
            ids = [r['id'] for r in gs_res.data]
            print(f"Deleting {len(ids)} group savings records...")
            for i in range(0, len(ids), 100):
                batch = ids[i:i+100]
                uow.client.table("group_savings").delete().in_("id", batch).execute()

        # 3. Cleanup Event Store (Double Entry Ledgers)
        print("Fetching Event Store records to delete...")
        # Since we can't easily query JSON in the python client, we'll fetch all events from today
        es_res = uow.client.table("event_store").select("event_id, payload").in_("event_type", ["SavingsDeposited", "GroupSavingsDeposited"]).execute()
        to_delete_events = []
        for e in es_res.data:
            payload = e.get('payload', {})
            if payload and payload.get('narration') in ["Initial Onboarding Savings", "Initial Onboarding Group Savings"]:
                to_delete_events.append(e['event_id'])
                
        if to_delete_events:
            print(f"Deleting {len(to_delete_events)} event store records...")
            for i in range(0, len(to_delete_events), 100):
                batch = to_delete_events[i:i+100]
                uow.client.table("event_store").delete().in_("event_id", batch).execute()

        # 4. Cleanup Loans with null product_id
        print("Fetching Bugged Loans to delete...")
        loans_res = uow.client.table("loans").select("loan_id").is_("product_id", "null").execute()
        if loans_res.data:
            ids = [r['loan_id'] for r in loans_res.data]
            print(f"Deleting {len(ids)} bugged loans...")
            for i in range(0, len(ids), 100):
                batch = ids[i:i+100]
                uow.client.table("loans").delete().in_("loan_id", batch).execute()

        print("Cleanup Complete!")

if __name__ == "__main__":
    cleanup()
