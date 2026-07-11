from typing import List, Optional
from domain.entities.loan import Loan
from domain.queries import LoanFilter
from mappers.base_mappers import LoanMapper
from interfaces.loan_repository import LoanRepository
from database.repositories.base_repository import BaseRepository
from core.exceptions import RepositoryError

class SupabaseLoanRepository(BaseRepository[Loan], LoanRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "loans"
        # Avoid select("*")
        self.columns = "id,client_id,client_name,product_type,amount,duration,frequency,gap_fee,expected_installment,total_payable,status,branch,credit_officer,start_date,end_date,created_at,group_name,is_asset"

    def find_by_id(self, id: str) -> Optional[Loan]:
        query = self.client.table(self.table_name).select(self.columns).eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return LoanMapper.to_domain(data) if data else None

    def find_all(self) -> List[Loan]:
        query = self.client.table(self.table_name).select(self.columns)
        res = self._execute(query)
        return [LoanMapper.to_domain(d) for d in res.data]

    def find_by_client_id(self, client_id: str) -> List[Loan]:
        query = self.client.table(self.table_name).select(self.columns).eq("client_id", client_id)
        res = self._execute(query)
        return [LoanMapper.to_domain(d) for d in res.data]

    def find_active(self, filters: LoanFilter) -> List[Loan]:
        query = self.client.table(self.table_name).select(self.columns).eq("status", "Active")
        if filters.branch:
            query = query.eq("branch", filters.branch)
        if filters.officer:
            query = query.eq("credit_officer", filters.officer)
        if filters.client_id:
            query = query.eq("client_id", filters.client_id)
            
        start = (filters.page - 1) * filters.size
        end = start + filters.size - 1
        query = query.range(start, end)
        
        res = self._execute(query)
        return [LoanMapper.to_domain(d) for d in res.data]

    def create(self, entity: Loan) -> Loan:
        data = LoanMapper.to_database(entity)
        if "id" in data and not data["id"]:
            del data["id"]
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        return LoanMapper.to_domain(inserted) if inserted else entity

    def create_many(self, loans: List[Loan]) -> None:
        if not loans: return
        data = [LoanMapper.to_database(L) for L in loans]
        for d in data:
            if "id" in d and not d["id"]:
                del d["id"]
        # Batch insert
        query = self.client.table(self.table_name).insert(data)
        self._execute(query)

    def update(self, entity: Loan) -> Loan:
        data = LoanMapper.to_database(entity)
        loan_id = data.pop("id")
        query = self.client.table(self.table_name).update(data).eq("id", loan_id)
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        return LoanMapper.to_domain(updated) if updated else entity

    def approve(self, loan_id: str) -> None:
        query = self.client.table(self.table_name).update({"status": "Active"}).eq("id", loan_id)
        self._execute(query)

    def reject(self, loan_id: str) -> None:
        query = self.client.table(self.table_name).update({"status": "Rejected"}).eq("id", loan_id)
        self._execute(query)

    def disburse(self, loan_id: str) -> None:
        # Same as approve for now based on domain language
        self.approve(loan_id)

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
        
    def delete_by_client_id(self, client_id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("client_id", client_id)
        res = self._execute(query)
        return len(res.data) > 0
