import uuid
from typing import List, Optional
from domain.entities.audit_event import AuditEvent
from interfaces.audit_repository import AuditRepository
from database.repositories.base_repository import BaseRepository

def resolve_officer_id(client, username: str) -> str:
    try:
        res = client.table("app_users").select("id").eq("username", username).execute()
        if res.data:
            return res.data[0]["id"]
    except Exception:
        pass
    return "00000000-0000-0000-0000-000000000000"

def is_valid_uuid(val: str) -> bool:
    try:
        uuid.UUID(str(val))
        return True
    except ValueError:
        return False

class SupabaseAuditRepository(BaseRepository[AuditEvent], AuditRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "audit_logs"
        self.columns = "id,user_id,action,description,table_name,record_id,created_at"

    def find_by_id(self, id: str) -> Optional[AuditEvent]:
        query = self.client.table(self.table_name).select("*, app_users(username)").eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        if data:
            username = data.get("app_users", {}).get("username", "System") if isinstance(data.get("app_users"), dict) else "System"
            return AuditEvent(
                id=data.get("id"),
                user=username,
                branch="",
                action=data.get("action"),
                old_value=None,
                new_value=data.get("description"),
                timestamp=data.get("created_at")
            )
        return None

    def find_all(self) -> List[AuditEvent]:
        return self.get_logs(100)

    def create(self, entity: AuditEvent) -> AuditEvent:
        user_id = resolve_officer_id(self.client, entity.user)
        data = {
            "user_id": user_id,
            "action": entity.action,
            "description": f"Old: {entity.old_value}. New: {entity.new_value}",
            "table_name": None,
            "record_id": None
        }
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        if inserted:
            entity.id = inserted.get("id")
        return entity

    def record_event(self, event: AuditEvent) -> None:
        self.create(event)

    def get_logs(self, limit: int = 100) -> List[AuditEvent]:
        query = self.client.table(self.table_name).select("*, app_users(username)").order("created_at", desc=True).limit(limit)
        res = self._execute(query)
        results = []
        for d in res.data:
            username = d.get("app_users", {}).get("username", "System") if isinstance(d.get("app_users"), dict) else "System"
            results.append(AuditEvent(
                id=d.get("id"),
                user=username,
                branch="",
                action=d.get("action"),
                old_value=None,
                new_value=d.get("description"),
                timestamp=d.get("created_at")
            ))
        return results

    def log_action(self, user: str, role: str, action: str, table_name: str, record_id: str, old_value: Optional[str] = None, new_value: Optional[str] = None) -> None:
        user_id = resolve_officer_id(self.client, user)
        rec_uuid = record_id if record_id and is_valid_uuid(record_id) else None
        data = {
            "user_id": user_id,
            "action": action,
            "description": f"Role: {role}. Old: {old_value}. New: {new_value}",
            "table_name": table_name,
            "record_id": rec_uuid
        }
        query = self.client.table(self.table_name).insert(data)
        self._execute(query)

    def update(self, entity: AuditEvent) -> AuditEvent:
        raise NotImplementedError("Audit logs cannot be updated.")

    def delete(self, id: str) -> bool:
        raise NotImplementedError("Audit logs cannot be deleted.")
