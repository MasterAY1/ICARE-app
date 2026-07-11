from typing import List, Optional
from domain.entities.user import User
from mappers.base_mappers import UserMapper
from interfaces.user_repository import UserRepository
from database.repositories.base_repository import BaseRepository

class SupabaseUserRepository(BaseRepository[User], UserRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "app_users"
        self.columns = "id,username,full_name,role,branch_name,password,created_at"

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

    def create(self, entity: User) -> User:
        data = {
            "username": entity.username,
            "full_name": entity.full_name,
            "role": entity.role,
            "branch_name": entity.branch_name,
            "password": entity.password_hash
        }
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        return UserMapper.to_domain(inserted) if inserted else entity

    def update(self, entity: User) -> User:
        data = {
            "username": entity.username,
            "full_name": entity.full_name,
            "role": entity.role,
            "branch_name": entity.branch_name
        }
        query = self.client.table(self.table_name).update(data).eq("id", entity.id)
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        return UserMapper.to_domain(updated) if updated else entity

    def update_password(self, username: str, password_hash: str) -> bool:
        query = self.client.table(self.table_name).update({"password": password_hash}).eq("username", username)
        res = self._execute(query)
        return len(res.data) > 0

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
