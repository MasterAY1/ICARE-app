from typing import List, Optional
from domain.entities.user import User
from mappers.base_mappers import UserMapper
from interfaces.user_repository import UserRepository
from database.repositories.base_repository import BaseRepository

class SupabaseUserRepository(BaseRepository[User], UserRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "app_users"
        self.columns = "*, branches!app_users_branch_id_fkey(name), user_roles(role_id, roles(name))"

    def find_by_id(self, id: str) -> Optional[User]:
        query = self.client.table(self.table_name).select(self.columns).eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return UserMapper.to_domain(data) if data else None

    def find_by_username(self, username: str) -> Optional[User]:
        query = self.client.table(self.table_name).select(self.columns).ilike("username", username)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return UserMapper.to_domain(data) if data else None

    def find_all(self) -> List[User]:
        query = self.client.table(self.table_name).select(self.columns)
        res = self._execute(query)
        return [UserMapper.to_domain(d) for d in res.data]

    def find_by_branch_id(self, branch_id: str) -> List[User]:
        """Return all users that belong to the given branch."""
        query = self.client.table(self.table_name).select(self.columns).eq("branch_id", branch_id)
        res = self._execute(query)
        return [UserMapper.to_domain(d) for d in res.data]

    # ------------------------------------------------------------------
    # Area-Manager branch assignments
    # ------------------------------------------------------------------

    def load_am_assignments(self, am_id: str) -> list:
        """Return list of ``{"branch_id": ..., "name": ...}`` for an Area Manager."""
        query = (
            self.client.table("area_manager_assignments")
            .select("branch_id, branches(name)")
            .eq("am_id", am_id)
        )
        res = self._execute(query)
        results = []
        for row in res.data:
            b = row.get("branches") or {}
            results.append({
                "branch_id": row.get("branch_id"),
                "name": b.get("name", ""),
            })
        return results

    def save_am_assignments(self, am_id: str, branch_ids: list) -> bool:
        """Replace all branch assignments for an Area Manager."""
        # Delete existing
        del_query = (
            self.client.table("area_manager_assignments")
            .delete()
            .eq("am_id", am_id)
        )
        self._execute(del_query)

        if not branch_ids:
            return True

        # Insert new
        rows = [{"am_id": am_id, "branch_id": bid} for bid in branch_ids]
        ins_query = self.client.table("area_manager_assignments").insert(rows)
        res = self._execute(ins_query)
        return len(res.data) > 0

    # ------------------------------------------------------------------
    # User activation / deactivation
    # ------------------------------------------------------------------

    def activate_user(self, user_id: str) -> bool:
        """Set ``is_active = True`` for the given user."""
        query = self.client.table(self.table_name).update({"is_active": True}).eq("id", user_id)
        res = self._execute(query)
        return len(res.data) > 0

    def deactivate_user(self, user_id: str) -> bool:
        """Set ``is_active = False`` for the given user."""
        query = self.client.table(self.table_name).update({"is_active": False}).eq("id", user_id)
        res = self._execute(query)
        return len(res.data) > 0

    # ------------------------------------------------------------------
    # Timestamp helpers
    # ------------------------------------------------------------------

    def update_last_login(self, user_id: str) -> None:
        """Set ``last_login`` to the current server timestamp."""
        query = self.client.table(self.table_name).update({"last_login": "now()"}).eq("id", user_id)
        self._execute(query)

    def update_last_activity(self, user_id: str) -> None:
        """Set ``last_activity`` to the current server timestamp."""
        query = self.client.table(self.table_name).update({"last_activity": "now()"}).eq("id", user_id)
        self._execute(query)

    # ------------------------------------------------------------------
    # Internal helpers (unchanged)
    # ------------------------------------------------------------------

    def _resolve_branch_id(self, branch_name: str) -> Optional[str]:
        if not branch_name:
            return None
        try:
            res = self.client.table("branches").select("branch_id").eq("name", branch_name).execute()
            if res.data:
                return res.data[0]["branch_id"]
        except Exception:
            pass
        return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d" # Lagos fallback

    def _upsert_user_role(self, user_id: str, role_name: str) -> None:
        role_map = {
            "Super Admin": "e2a16d8a-940b-411a-828b-b892ad9622d1",
            "Admin": "59539343-690a-4286-9467-854728562d5f",
            "Area Manager": "b0c790ef-8bfa-4cda-92ee-63c631a7428f",
            "Branch Manager": "3ea1496a-0498-4a1d-872a-1c7ecdf77b06",
            "Credit Officer": "bd8790ee-c0eb-485a-8b6a-93f54519965d",
            "Account Manager": "d04a628a-789a-411d-b8aa-3dfc8296a2bf"
        }
        role_id = role_map.get(role_name, "bd8790ee-c0eb-485a-8b6a-93f54519965d")
        try:
            self.client.table("user_roles").upsert({"user_id": user_id, "role_id": role_id}).execute()
        except Exception:
            pass

    # ------------------------------------------------------------------
    # CRUD (unchanged)
    # ------------------------------------------------------------------

    def create(self, entity: User) -> User:
        branch_id = self._resolve_branch_id(entity.branch_name)
        data = {
            "username": entity.username,
            "full_name": entity.full_name,
            "password_hash": entity.password_hash,
            "branch_id": branch_id,
            "is_active": True
        }
        if entity.id:
            data["id"] = entity.id
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        if inserted:
            entity.id = inserted.get("id")
            self._upsert_user_role(entity.id, entity.role)
            return self.find_by_id(entity.id) or entity
        return entity

    def update(self, entity: User) -> User:
        branch_id = self._resolve_branch_id(entity.branch_name)
        data = {
            "username": entity.username,
            "full_name": entity.full_name,
            "branch_id": branch_id
        }
        query = self.client.table(self.table_name).update(data).eq("id", entity.id)
        res = self._execute(query)
        self._upsert_user_role(entity.id, entity.role)
        return self.find_by_id(entity.id) or entity

    def update_password(self, username: str, password_hash: str) -> bool:
        query = self.client.table(self.table_name).update({"password_hash": password_hash}).eq("username", username)
        res = self._execute(query)
        return len(res.data) > 0

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
