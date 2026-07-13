from typing import Protocol, List, Optional
from domain.entities.audit_event import AuditEvent
from interfaces.base_repository import Repository

class AuditRepository(Repository[AuditEvent], Protocol):
    def record_event(self, event: AuditEvent) -> None: ...
    def get_logs(self, limit: int = 100) -> List[AuditEvent]: ...
    def log_action(
        self,
        user: str,
        role: str,
        action: str,
        table_name: str,
        record_id: str,
        old_value: Optional[str] = None,
        new_value: Optional[str] = None
    ) -> None: ...
