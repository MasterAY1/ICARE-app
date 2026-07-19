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
        self.columns = "id,date,loan_id,client_id,amount_paid,officer_id,branch_id,note,transaction_type,created_at,clients(name,client_code),branches(name),app_users(username, full_name)"

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

    def _resolve_officer_id(self, username: str) -> str:
        if not username:
            return "00000000-0000-0000-0000-000000000000"
        try:
            res = self.client.table("app_users").select("id").eq("username", username).execute()
            if res.data:
                return res.data[0]["id"]
            res_full = self.client.table("app_users").select("id").eq("full_name", username).execute()
            if res_full.data:
                return res_full.data[0]["id"]
        except Exception:
            pass
        return "00000000-0000-0000-0000-000000000000" # admin fallback

    def _resolve_loan_id(self, client_id: str) -> Optional[str]:
        if not client_id:
            return None
        # Check if it's already a loan_id (uuid)
        try:
            res = self.client.table("loans").select("loan_id").eq("loan_id", client_id).execute()
            if res.data:
                return client_id
        except Exception:
            pass
            
        # Resolve client_code to database client UUID first if needed
        import uuid
        def clean_uuid(val):
            try:
                uuid.UUID(str(val))
                return str(val)
            except ValueError:
                return None
        
        c_uuid = clean_uuid(client_id)
        if not c_uuid and not str(client_id).startswith('GROUP-') and not str(client_id).startswith('GLOBAL-'):
            try:
                res_c = self.client.table("clients").select("client_id").eq("client_code", client_id).execute()
                if res_c.data:
                    c_uuid = res_c.data[0]["client_id"]
            except Exception:
                pass
        else:
            c_uuid = client_id
            
        if not c_uuid:
            return None

        # Resolve by client active loan
        try:
            res = self.client.table("loans").select("loan_id").eq("client_id", c_uuid).eq("status", "Active").execute()
            if res.data:
                return res.data[0]["loan_id"]
            # Fallback to any loan for client
            res = self.client.table("loans").select("loan_id").eq("client_id", c_uuid).limit(1).execute()
            if res.data:
                return res.data[0]["loan_id"]
        except Exception:
            pass
        return None

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
        resolved_loan = self._resolve_loan_id(loan_id)
        if not resolved_loan:
            return []
        query = self.client.table(self.table_name).select(self.columns).eq("loan_id", resolved_loan)
        res = self._execute(query)
        return [RepaymentMapper.to_domain(d) for d in res.data]

    def find_recent(self, filters: RepaymentFilter) -> List[Repayment]:
        query = self.client.table(self.table_name).select(self.columns)
        if filters.branch:
            branch_id = self._resolve_branch_id(filters.branch)
            query = query.eq("branch_id", branch_id)
        if filters.officer:
            officer_id = self._resolve_officer_id(filters.officer)
            query = query.eq("officer_id", officer_id)
        if filters.loan_id:
            resolved_loan = self._resolve_loan_id(filters.loan_id)
            if resolved_loan:
                query = query.eq("loan_id", resolved_loan)
        if filters.start_date:
            query = query.gte("date", filters.start_date)
        if filters.end_date:
            query = query.lte("date", filters.end_date)
        
        start = (filters.page - 1) * filters.size
        end = start + filters.size - 1
        query = query.range(start, end).order("date", desc=True)
        
        res = self._execute(query)
        return [RepaymentMapper.to_domain(d) for d in res.data]

    def _prepare_db_data(self, entity: Repayment) -> dict:
        import uuid
        def clean_uuid(val):
            if not val or val in ["None", "null", "undefined"]:
                return None
            val_str = str(val).strip()
            if val_str.startswith("GROUP-") or val_str.startswith("GLOBAL-"):
                return None
            try:
                return str(uuid.UUID(val_str))
            except ValueError:
                return None

        branch_id = entity.extra_fields.get("branch_id") or self._resolve_branch_id(entity.branch)
        officer_id = entity.extra_fields.get("officer_id") or self._resolve_officer_id(entity.credit_officer)

        amt = float(entity.amount_paid or 0.0)
        if amt <= 0 and entity.loan_repayment_amount > 0:
            amt = float(entity.loan_repayment_amount)
        if amt <= 0:
            amt = 1.0

        resolved_loan = self._resolve_loan_id(entity.loan_id)
        if not resolved_loan:
            resolved_loan = self._resolve_loan_id(entity.client_id)

        c_id = entity.client_id
        if c_id and not clean_uuid(c_id):
            try:
                res_c = self.client.table("clients").select("client_id").eq("client_code", c_id).execute()
                if res_c.data:
                    c_id = res_c.data[0]["client_id"]
            except Exception:
                pass

        c_id_clean = clean_uuid(c_id)
        resolved_loan_clean = clean_uuid(resolved_loan)

        db_dict = {
            "date": entity.payment_date.isoformat() if entity.payment_date else None,
            "loan_id": resolved_loan_clean,
            "client_id": c_id_clean,
            "amount_paid": amt,
            "officer_id": officer_id,
            "branch_id": branch_id,
            "note": entity.note or "",
            "transaction_type": entity.transaction_type or "Loan"
        }
        if entity.id:
            db_dict["id"] = entity.id
        return db_dict

    def create(self, entity: Repayment) -> Repayment:
        data = self._prepare_db_data(entity)
        if "id" in data and not data["id"]:
            del data["id"]
        print(f"[SAVINGS TRACE] RepaymentRepository create called. Data: {data}")
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        print(f"[SAVINGS TRACE] SQL Insert Result for repayments: {res.data}")
        inserted = self._single_or_none(res.data)
        return RepaymentMapper.to_domain(inserted) if inserted else entity

    def create_many(self, repayments: List[Repayment]) -> None:
        if not repayments:
            return
        data = [self._prepare_db_data(R) for R in repayments]
        for d in data:
            if "id" in d and not d["id"]:
                del d["id"]
        query = self.client.table(self.table_name).insert(data)
        self._execute(query)

    def update(self, entity: Repayment) -> Repayment:
        data = self._prepare_db_data(entity)
        rep_id = data.pop("id")
        query = self.client.table(self.table_name).update(data).eq("id", rep_id)
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        return RepaymentMapper.to_domain(updated) if updated else entity

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
