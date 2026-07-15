from typing import List, Optional
import uuid
from domain.entities.guarantor import Guarantor, LoanGuarantor
from mappers.base_mappers import GuarantorMapper, LoanGuarantorMapper
from interfaces.guarantor_repository import GuarantorRepository
from database.repositories.base_repository import BaseRepository

class SupabaseGuarantorRepository(BaseRepository[Guarantor], GuarantorRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "guarantors"

    def find_by_id(self, guarantor_id: str) -> Optional[Guarantor]:
        query = self.client.table(self.table_name).select("*").eq("guarantor_id", guarantor_id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return GuarantorMapper.to_domain(data) if data else None

    def find_by_phone(self, phone: str) -> Optional[Guarantor]:
        query = self.client.table(self.table_name).select("*").eq("phone", phone)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return GuarantorMapper.to_domain(data) if data else None

    def create_guarantor(self, guarantor: Guarantor) -> Guarantor:
        if not guarantor.guarantor_id:
            guarantor.guarantor_id = str(uuid.uuid4())
        db_data = GuarantorMapper.to_database(guarantor)
        self.client.table(self.table_name).insert(db_data).execute()
        return guarantor

    def link_to_loan(self, loan_guarantor: LoanGuarantor) -> LoanGuarantor:
        if not loan_guarantor.id:
            loan_guarantor.id = str(uuid.uuid4())
        db_data = LoanGuarantorMapper.to_database(loan_guarantor)
        self.client.table("loan_guarantors").insert(db_data).execute()
        return loan_guarantor

    def find_for_loan(self, loan_id: str) -> List[Guarantor]:
        query = self.client.table("loan_guarantors").select("*, guarantors(*)").eq("loan_id", loan_id)
        res = self._execute(query)
        guarantors = []
        for row in res.data:
            g_data = row.get("guarantors")
            if g_data:
                guarantors.append(GuarantorMapper.to_domain(g_data))
        return guarantors

    def find_links_for_loan(self, loan_id: str) -> List[LoanGuarantor]:
        query = self.client.table("loan_guarantors").select("*").eq("loan_id", loan_id)
        res = self._execute(query)
        return [LoanGuarantorMapper.to_domain(row) for row in res.data]
