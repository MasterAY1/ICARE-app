from typing import List, Optional
from domain.entities.audit_event import AuditEvent
from interfaces.audit_repository import AuditRepository
from database.repositories.base_repository import BaseRepository

class SupabaseAuditRepository(BaseRepository[AuditEvent], AuditRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "audit_ledger"
        self.columns = "id,user,branch,action,old_value,new_value,timestamp"

    def find_by_id(self, id: str) -> Optional[AuditEvent]:
        query = self.client.table(self.table_name).select(self.columns).eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        if data:
            return AuditEvent(**data)
        return None

    def find_all(self) -> List[AuditEvent]:
        return self.get_logs(100)

    def create(self, entity: AuditEvent) -> AuditEvent:
        data = {
            "user": entity.user,
            "branch": entity.branch,
            "action": entity.action,
            "old_value": entity.old_value,
            "new_value": entity.new_value
        }
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        return AuditEvent(**inserted) if inserted else entity

    def record_event(self, event: AuditEvent) -> None:
        self.create(event)

    def get_logs(self, limit: int = 100) -> List[AuditEvent]:
        query = self.client.table(self.table_name).select(self.columns).order("timestamp", desc=True).limit(limit)
        res = self._execute(query)
        return [AuditEvent(**d) for d in res.data]

    def update(self, entity: AuditEvent) -> AuditEvent:
        raise NotImplementedError("Audit logs cannot be updated.")

    def delete(self, id: str) -> bool:
        raise NotImplementedError("Audit logs cannot be deleted.")
