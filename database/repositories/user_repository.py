from typing import List, Optional
from domain.entities.user import User
from mappers.base_mappers import UserMapper
from interfaces.user_repository import UserRepository
from database.repositories.base_repository import BaseRepository

class SupabaseUserRepository(BaseRepository[User], UserRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "app_users"
        self.columns = "*, branches(name), user_roles(role_id, roles(name))"

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
            "Admin": "59539343-690a-4286-9467-854728562d5f",
            "Branch Manager": "3ea1496a-0498-4a1d-872a-1c7ecdf77b06",
            "Credit Officer": "bd8790ee-c0eb-485a-8b6a-93f54519965d"
        }
        role_id = role_map.get(role_name, "bd8790ee-c0eb-485a-8b6a-93f54519965d")
        try:
            self.client.table("user_roles").upsert({"user_id": user_id, "role_id": role_id}).execute()
        except Exception:
            pass

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
