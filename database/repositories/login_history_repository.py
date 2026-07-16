from typing import List, Optional
from database.repositories.base_repository import BaseRepository


class SupabaseLoginHistoryRepository(BaseRepository):
    """Repository for the ``login_history`` table."""

    def __init__(self, client):
        super().__init__(client)
        self.table_name = "login_history"

    # ------------------------------------------------------------------
    # Write
    # ------------------------------------------------------------------

    def record_login(self, entry_dict: dict) -> dict:
        """Insert a login-history record and return the inserted row."""
        query = self.client.table(self.table_name).insert(entry_dict)
        res = self._execute(query)
        return self._single_or_none(res.data) or entry_dict

    def record_logout(self, session_id: str) -> bool:
        """Set ``logout_time`` to NOW() for the given session."""
        query = (
            self.client.table(self.table_name)
            .update({"logout_time": "now()"})
            .eq("session_id", session_id)
            .is_("logout_time", "null")
        )
        res = self._execute(query)
        return len(res.data) > 0

    # ------------------------------------------------------------------
    # Read helpers
    # ------------------------------------------------------------------

    def find_by_user(self, user_id: str, limit: int = 50) -> List[dict]:
        """Return login records for a specific user, newest first."""
        query = (
            self.client.table(self.table_name)
            .select("*")
            .eq("user_id", user_id)
            .order("login_time", desc=True)
            .limit(limit)
        )
        res = self._execute(query)
        return res.data

    def find_recent(self, limit: int = 100) -> List[dict]:
        """Return the most recent login records across all users."""
        query = (
            self.client.table(self.table_name)
            .select("*")
            .order("login_time", desc=True)
            .limit(limit)
        )
        res = self._execute(query)
        return res.data
