from typing import List, Optional
from domain.entities.cashbook_entry import CashbookEntry
from domain.queries import CashbookFilter
from mappers.base_mappers import CashbookMapper
from interfaces.cashbook_repository import CashbookRepository
from database.repositories.base_repository import BaseRepository

class SupabaseCashbookRepository(BaseRepository[CashbookEntry], CashbookRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "master_cashbook"
        self.columns = "id,date,branch,opening_balance,savings_deposit,loan_recovery,disbursement,savings_withdrawal,office_expenses,bank_deposit,staff_salary,closing_balance,shortage,excess,is_balanced,status"

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
        query = self.client.table(self.table_name).select(self.columns).eq("date", date_str).eq("branch", branch)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_previous(self, date_str: str, branch: str) -> Optional[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns).eq("branch", branch).lt("date", date_str).order("date", desc=True).limit(1)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_range(self, filters: CashbookFilter) -> List[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns)
        if filters.branch: query = query.eq("branch", filters.branch)
        if filters.start_date: query = query.gte("date", filters.start_date)
        if filters.end_date: query = query.lte("date", filters.end_date)
        
        query = query.order("date")
        res = self._execute(query)
        return [CashbookMapper.to_domain(d) for d in res.data]

    def create(self, entity: CashbookEntry) -> CashbookEntry:
        data = CashbookMapper.to_database(entity)
        if "id" in data and not data["id"]: del data["id"]
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        return CashbookMapper.to_domain(inserted) if inserted else entity

    def update(self, entity: CashbookEntry) -> CashbookEntry:
        data = CashbookMapper.to_database(entity)
        cb_id = data.pop("id", None)
        if cb_id:
            query = self.client.table(self.table_name).update(data).eq("id", cb_id)
        else:
            query = self.client.table(self.table_name).update(data).eq("date", entity.date.isoformat()).eq("branch", entity.branch)
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        return CashbookMapper.to_domain(updated) if updated else entity

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
