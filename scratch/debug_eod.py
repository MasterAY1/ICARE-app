import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from database.repositories.unit_of_work import SupabaseUnitOfWork
import uuid
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine
import traceback

with SupabaseUnitOfWork() as uow:
    target_co = "CO2"
    BRANCH = "Ogijo"
    date_str = "2026-08-16"
    client_id = f"GLOBAL-{target_co}"
    
    ev_bdep = DomainEvent(
        event_id=str(uuid.uuid4()),
        aggregate_id=str(client_id),
        aggregate_type="Bank",
        event_type="BankDeposited",
        payload={"branch": BRANCH, "officer": target_co, "amount": 2000.0, "date": date_str, "narration": f"End of Day cash deposit to bank by {target_co}"}
    )
    
    print("Testing uow.event_store.append...")
    try:
        uow.event_store.append(ev_bdep)
        print("append OK!")
    except Exception as e:
        print("append FAILED:")
        traceback.print_exc()

    print("Testing FinancialPostingEngine.post_event...")
    try:
        FinancialPostingEngine.post_event(uow, ev_bdep)
        print("post_event OK!")
    except Exception as e:
        print("post_event FAILED:")
        traceback.print_exc()
