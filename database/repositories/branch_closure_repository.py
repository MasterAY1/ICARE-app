from typing import List, Optional
from domain.entities.branch_closure import BranchClosure
from mappers.base_mappers import BranchClosureMapper
from interfaces.branch_closure_repository import BranchClosureRepository
from database.repositories.base_repository import BaseRepository

class SupabaseBranchClosureRepository(BaseRepository[BranchClosure], BranchClosureRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "branch_closures"
        self.columns = "id,start_date,end_date,reason"

    def find_by_id(self, id: str) -> Optional[BranchClosure]:
        query = self.client.table(self.table_name).select(self.columns).eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return BranchClosureMapper.to_domain(data) if data else None

    def find_all(self) -> List[BranchClosure]:
        query = self.client.table(self.table_name).select(self.columns)
        res = self._execute(query)
        return [BranchClosureMapper.to_domain(d) for d in res.data]

    def create(self, entity: BranchClosure) -> BranchClosure:
        data = {
            "start_date": entity.start_date.isoformat(),
            "end_date": entity.end_date.isoformat(),
            "reason": entity.reason
        }
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        return BranchClosureMapper.to_domain(inserted) if inserted else entity

    def update(self, entity: BranchClosure) -> BranchClosure:
        data = {
            "start_date": entity.start_date.isoformat(),
            "end_date": entity.end_date.isoformat(),
            "reason": entity.reason
        }
        query = self.client.table(self.table_name).update(data).eq("id", entity.id)
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        return BranchClosureMapper.to_domain(updated) if updated else entity

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
