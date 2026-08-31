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
        rpc_seq = int(res.data) if res.data else 1
        
        # Collision safeguard: Verify against actual existing clients for this group
        try:
            cl_res = self.client.table(self.table_name).select("client_code").eq("group_id", group_id).execute()
            if cl_res.data:
                import re
                max_cl_seq = 0
                for row in cl_res.data:
                    code = row.get("client_code") or ""
                    digits = re.findall(r'\d+', code)
                    if digits:
                        max_cl_seq = max(max_cl_seq, int(digits[-1]))
                if rpc_seq <= max_cl_seq:
                    rpc_seq = max_cl_seq + 1
                    self.client.table("groups").update({"current_member_sequence": rpc_seq}).eq("group_id", group_id).execute()
        except Exception:
            pass
        return rpc_seq

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
