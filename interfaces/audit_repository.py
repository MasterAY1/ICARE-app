from typing import Protocol, List
from domain.entities.audit_event import AuditEvent
from interfaces.base_repository import Repository

class AuditRepository(Repository[AuditEvent], Protocol):
    def record_event(self, event: AuditEvent) -> None: ...
    def get_logs(self, limit: int = 100) -> List[AuditEvent]: ...
