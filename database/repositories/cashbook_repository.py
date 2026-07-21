from typing import List, Optional
from datetime import date, datetime
from domain.entities.cashbook_entry import CashbookEntry
from domain.queries import CashbookFilter
from mappers.base_mappers import CashbookMapper
from interfaces.cashbook_repository import CashbookRepository
from database.repositories.base_repository import BaseRepository
from core.exceptions import RepositoryError

class SupabaseCashbookRepository(BaseRepository[CashbookEntry], CashbookRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "master_cashbook"
        self.columns = "*, branches(name)"

    def _resolve_branch_id(self, branch_name: str) -> str:
        if not branch_name:
            return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"
        try:
            res = self.client.table("branches").select("branch_id").eq("name", branch_name).execute()
            if res.data:
                return res.data[0]["branch_id"]
        except Exception:
            pass
        return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d" # Lagos fallback

    def _resolve_branch_id_by_filter(self, branch: Optional[str]) -> Optional[str]:
        if not branch:
            return None
        return self._resolve_branch_id(branch)

    def find_by_id(self, id: str) -> Optional[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns).eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_all(self) -> List[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns)
        res = self._execute(query)
        return [CashbookMapper.to_domain(d) for d in res.data]

    def find_by_date_and_branch(self, date_str: str, branch: str) -> Optional[CashbookEntry]:
        branch_id = self._resolve_branch_id(branch)
        query = self.client.table(self.table_name).select(self.columns).eq("date", date_str).eq("branch_id", branch_id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_previous(self, date_str: str, branch: str) -> Optional[CashbookEntry]:
        branch_id = self._resolve_branch_id(branch)
        query = self.client.table(self.table_name).select(self.columns).eq("branch_id", branch_id).lt("date", date_str).order("date", desc=True).limit(1)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_range(self, filters: CashbookFilter) -> List[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns)
        if filters.branch:
            branch_id = self._resolve_branch_id(filters.branch)
            query = query.eq("branch_id", branch_id)
        if filters.start_date:
            query = query.gte("date", filters.start_date)
        if filters.end_date:
            query = query.lte("date", filters.end_date)
        
        query = query.order("date")
        res = self._execute(query)
        return [CashbookMapper.to_domain(d) for d in res.data]

    def rebuild_projection(self, branch_id: str, posting_date, officer_id: str = None) -> None:
        if isinstance(posting_date, str):
            posting_date = date.fromisoformat(posting_date)

        from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
        from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
        from database.repositories.unit_of_work import SupabaseUnitOfWork

        # Create temporary UOW wrapper for queries
        with SupabaseUnitOfWork() as uow:
            # 1. Resolve officer IDs for the branch
            officers = []
            if officer_id:
                officers.append(officer_id)
            else:
                try:
                    res_u = uow.client.table("app_users").select("id").eq("branch_id", branch_id).execute()
                    if res_u.data:
                        officers = [u["id"] for u in res_u.data if u.get("id")]
                except Exception:
                    pass

            # 2. Rebuild CO projections for each officer
            for o_id in officers:
                CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, o_id, posting_date)

            # 3. Aggregate Master Cashbook projection
            MasterCashbookProjectionBuilder.rebuild_master_projection(uow, branch_id, posting_date)

    def _prepare_db_data(self, entity: CashbookEntry) -> dict:
        data = CashbookMapper.to_database(entity)
        branch_name = data.pop("branch", None)
        data["branch_id"] = self._resolve_branch_id(branch_name or entity.branch)
        return data

    def create(self, entity: CashbookEntry) -> CashbookEntry:
        data = self._prepare_db_data(entity)
        if "id" in data and not data["id"]:
            del data["id"]
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        if inserted:
            entity.id = inserted.get("id")
        return entity

    def update(self, entity: CashbookEntry) -> CashbookEntry:
        data = self._prepare_db_data(entity)
        cb_id = data.pop("id", None)
        if cb_id:
            query = self.client.table(self.table_name).update(data).eq("id", cb_id)
        else:
            query = self.client.table(self.table_name).update(data).eq("date", entity.date.isoformat()).eq("branch_id", data["branch_id"])
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        if updated:
            entity.id = updated.get("id")
        return entity

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
