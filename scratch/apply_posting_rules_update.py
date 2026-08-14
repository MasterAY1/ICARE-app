from database.repositories.unit_of_work import SupabaseUnitOfWork
import uuid

uow = SupabaseUnitOfWork()

rules_to_ensure = [
    {"event_type": "LapsPaidOut", "debit_account": "2030", "credit_account": "1000", "version": 1, "enabled": True},
    {"event_type": "LapsTransferred", "debit_account": "2000", "credit_account": "2030", "version": 1, "enabled": True},
    {"event_type": "LoanOffsetFromSavings", "debit_account": "2000", "credit_account": "1200", "version": 1, "enabled": True},
]

print("=== CHECKING & INSERTING POSTING RULES ===")
for r in rules_to_ensure:
    res = uow.client.table("posting_rules").select("*").eq("event_type", r["event_type"]).eq("version", r["version"]).execute()
    if not res.data:
        r["id"] = str(uuid.uuid4())
        uow.client.table("posting_rules").insert(r).execute()
        print(f"Inserted posting rule: {r['event_type']} -> Debit: {r['debit_account']}, Credit: {r['credit_account']}")
    else:
        print(f"Posting rule exists: {r['event_type']}")
