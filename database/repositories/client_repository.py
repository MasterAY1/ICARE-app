from typing import List, Optional
import uuid
from domain.entities.client import Client
from mappers.base_mappers import ClientMapper
from interfaces.client_repository import ClientRepository
from database.repositories.base_repository import BaseRepository

class SupabaseClientRepository(BaseRepository[Client], ClientRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "clients"
        self.columns = "*"

    def find_by_id(self, id: str) -> Optional[Client]:
        query = self.client.table(self.table_name).select(self.columns).eq("client_id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return ClientMapper.to_domain(data) if data else None

    def find_by_code(self, client_code: str) -> Optional[Client]:
        query = self.client.table(self.table_name).select(self.columns).eq("client_code", client_code)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return ClientMapper.to_domain(data) if data else None

    def search_by_name_or_code(self, query_str: str) -> List[Client]:
        if not query_str:
            return []
        safe_query = query_str.replace(",", "").replace('"', "")
        query = self.client.table(self.table_name).select(self.columns).or_(f"name.ilike.%{safe_query}%,client_code.ilike.%{safe_query}%")
        res = self._execute(query)
        return [ClientMapper.to_domain(d) for d in res.data]

    def find_all(self) -> List[Client]:
        query = self.client.table(self.table_name).select(self.columns)
        res = self._execute(query)
        return [ClientMapper.to_domain(d) for d in res.data]

    def get_next_member_sequence(self, group_id: str) -> int:
        res = self.client.rpc("increment_group_member_sequence", {"group_uuid": group_id}).execute()
        return int(res.data) if res.data else 1

    def create(self, entity: Client) -> Client:
        if not entity.id:
            entity.id = str(uuid.uuid4())
        db_data = ClientMapper.to_database(entity)
        self.client.table(self.table_name).insert(db_data).execute()
        return entity

    def update(self, entity: Client) -> Client:
        db_data = ClientMapper.to_database(entity)
        self.client.table(self.table_name).update(db_data).eq("client_id", entity.id).execute()
        return entity

    def delete(self, id: str) -> bool:
        self.client.table(self.table_name).delete().eq("client_id", id).execute()
        return True
