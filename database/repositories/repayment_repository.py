from typing import List, Optional
from domain.entities.repayment import Repayment
from domain.queries import RepaymentFilter
from mappers.base_mappers import RepaymentMapper
from interfaces.repayment_repository import RepaymentRepository
from database.repositories.base_repository import BaseRepository
from core.exceptions import RepositoryError

class SupabaseRepaymentRepository(BaseRepository[Repayment], RepaymentRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "repayments"
        self.columns = "id,loan_id,client_id,amount_paid,savings_amount,loan_repayment_amount,withdrawal_amount,others_amount,recovery_amount,initial_payment,payment_date,transaction_type,branch,credit_officer,created_at"

    def find_by_id(self, id: str) -> Optional[Repayment]:
        query = self.client.table(self.table_name).select(self.columns).eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return RepaymentMapper.to_domain(data) if data else None

    def find_all(self) -> List[Repayment]:
        query = self.client.table(self.table_name).select(self.columns)
        res = self._execute(query)
        return [RepaymentMapper.to_domain(d) for d in res.data]

    def find_by_loan(self, loan_id: str) -> List[Repayment]:
        query = self.client.table(self.table_name).select(self.columns).eq("loan_id", loan_id)
        res = self._execute(query)
        return [RepaymentMapper.to_domain(d) for d in res.data]

    def find_recent(self, filters: RepaymentFilter) -> List[Repayment]:
        query = self.client.table(self.table_name).select(self.columns)
        if filters.branch: query = query.eq("branch", filters.branch)
        if filters.officer: query = query.eq("credit_officer", filters.officer)
        if filters.loan_id: query = query.eq("loan_id", filters.loan_id)
        if filters.start_date: query = query.gte("payment_date", filters.start_date)
        if filters.end_date: query = query.lte("payment_date", filters.end_date)
        
        start = (filters.page - 1) * filters.size
        end = start + filters.size - 1
        query = query.range(start, end).order("payment_date", desc=True)
        
        res = self._execute(query)
        return [RepaymentMapper.to_domain(d) for d in res.data]

    def create(self, entity: Repayment) -> Repayment:
        data = RepaymentMapper.to_database(entity)
        if "id" in data and not data["id"]: del data["id"]
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        return RepaymentMapper.to_domain(inserted) if inserted else entity

    def create_many(self, repayments: List[Repayment]) -> None:
        if not repayments: return
        data = [RepaymentMapper.to_database(R) for R in repayments]
        for d in data:
            if "id" in d and not d["id"]: del d["id"]
        query = self.client.table(self.table_name).insert(data)
        self._execute(query)

    def update(self, entity: Repayment) -> Repayment:
        data = RepaymentMapper.to_database(entity)
        rep_id = data.pop("id")
        query = self.client.table(self.table_name).update(data).eq("id", rep_id)
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        return RepaymentMapper.to_domain(updated) if updated else entity

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
