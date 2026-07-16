from typing import List
from database.repositories.base_repository import BaseRepository


class SupabaseUserAuditLogRepository(BaseRepository):
    """INSERT-ONLY repository for the immutable ``user_audit_logs`` table."""

    def __init__(self, client):
        super().__init__(client)
        self.table_name = "user_audit_logs"

    # ------------------------------------------------------------------
    # Write
    # ------------------------------------------------------------------

    def create(self, entry_dict: dict) -> dict:
        """Insert a single audit-log entry and return the inserted row."""
        query = self.client.table(self.table_name).insert(entry_dict)
        res = self._execute(query)
        return self._single_or_none(res.data) or entry_dict

    # ------------------------------------------------------------------
    # Read helpers
    # ------------------------------------------------------------------

    def find_recent(self, limit: int = 100) -> List[dict]:
        """Return the most recent audit entries, newest first."""
        query = (
            self.client.table(self.table_name)
            .select("*")
            .order("timestamp", desc=True)
            .limit(limit)
        )
        res = self._execute(query)
        return res.data

    def find_by_user(self, user_id: str, limit: int = 50) -> List[dict]:
        """Return audit entries for a specific user."""
        query = (
            self.client.table(self.table_name)
            .select("*")
            .eq("user_id", user_id)
            .order("timestamp", desc=True)
            .limit(limit)
        )
        res = self._execute(query)
        return res.data

    def find_by_entity(self, entity_type: str, entity_id: str, limit: int = 50) -> List[dict]:
        """Return audit entries for a specific entity."""
        query = (
            self.client.table(self.table_name)
            .select("*")
            .eq("entity_type", entity_type)
            .eq("entity_id", entity_id)
            .order("timestamp", desc=True)
            .limit(limit)
        )
        res = self._execute(query)
        return res.data

    def find_by_action(self, action: str, limit: int = 50) -> List[dict]:
        """Return audit entries filtered by action type."""
        query = (
            self.client.table(self.table_name)
            .select("*")
            .eq("action", action)
            .order("timestamp", desc=True)
            .limit(limit)
        )
        res = self._execute(query)
        return res.data

    # ------------------------------------------------------------------
    # Immutability guards
    # ------------------------------------------------------------------

    def update(self, *args, **kwargs):
        raise NotImplementedError("Audit logs are immutable")

    def delete(self, *args, **kwargs):
        raise NotImplementedError("Audit logs are immutable")
