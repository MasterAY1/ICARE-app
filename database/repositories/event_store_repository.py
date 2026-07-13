from typing import List, Optional
from datetime import datetime
from domain.entities.event_store import DomainEvent
from interfaces.event_store_repository import EventStoreRepository
from database.repositories.base_repository import BaseRepository

class SupabaseEventStoreRepository(BaseRepository[DomainEvent], EventStoreRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "event_store"

    def append(self, event: DomainEvent) -> str:
        data = {
            "event_id": event.event_id,
            "aggregate_id": event.aggregate_id,
            "aggregate_type": event.aggregate_type,
            "event_type": event.event_type,
            "payload": event.payload,
            "version": event.version,
            "status": event.status
        }
        self.client.table(self.table_name).insert(data).execute()
        return event.event_id

    def mark_processing(self, event_id: str, processor_name: str) -> None:
        self.client.table("event_processing").upsert({
            "event_id": event_id,
            "processor_name": processor_name,
            "status": "Processing",
            "processed_at": None
        }, on_conflict="event_id,processor_name").execute()
        self.client.table(self.table_name).update({"status": "Processing"}).eq("event_id", event_id).execute()

    def mark_posted(self, event_id: str, processor_name: str) -> None:
        now_str = datetime.now().isoformat()
        self.client.table("event_processing").upsert({
            "event_id": event_id,
            "processor_name": processor_name,
            "status": "Posted",
            "processed_at": now_str
        }, on_conflict="event_id,processor_name").execute()
        self.client.table(self.table_name).update({"status": "Completed"}).eq("event_id", event_id).execute()

    def mark_failed(self, event_id: str, processor_name: str, error_message: str) -> None:
        self.client.table("event_processing").upsert({
            "event_id": event_id,
            "processor_name": processor_name,
            "status": "Failed",
            "error_message": error_message
        }, on_conflict="event_id,processor_name").execute()
        self.client.table(self.table_name).update({"status": "Failed"}).eq("event_id", event_id).execute()

    def is_processed(self, event_id: str, processor_name: str) -> bool:
        res = self.client.table("event_processing").select("status").eq("event_id", event_id).eq("processor_name", processor_name).execute()
        if res.data:
            return res.data[0].get("status") == "Posted"
        return False

    def get_pending_events(self) -> List[DomainEvent]:
        res = self.client.table(self.table_name).select("*").eq("status", "Pending").order("created_at").execute()
        events = []
        for r in res.data:
            events.append(DomainEvent(
                event_id=str(r.get("event_id")),
                aggregate_id=str(r.get("aggregate_id") or ""),
                aggregate_type=str(r.get("aggregate_type") or ""),
                event_type=str(r.get("event_type")),
                payload=r.get("payload") or {},
                version=int(r.get("version") or 1),
                status=str(r.get("status")),
                created_at=datetime.fromisoformat(r.get("created_at").replace("Z", "+00:00")) if r.get("created_at") else None
            ))
        return events
