from typing import List, Optional
from datetime import date
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
        self.columns = "loan_id,client_id,product_id,branch_id,officer_id,date,loan_amount,active_credit,loan_repay,total_due,status,product_category,disbursement_date,start_date,expected_end_date,version,extra_fields,currency_code,created_at,updated_at,is_deleted,clients(name,nickname,phone,address,marital_status,business_type,average_monthly_income,other_obligations),branches(name),app_users(username,full_name)"

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
        except Exception:
            pass
        return "00000000-0000-0000-0000-000000000000" # admin fallback

    def _resolve_product_id(self, prod_name: str) -> str:
        if not prod_name:
            return "11111111-1111-1111-1111-111111111111"
        try:
            res = self.client.table("loan_products").select("product_id").eq("name", prod_name).execute()
            if res.data:
                return res.data[0]["product_id"]
        except Exception:
            pass
        return "11111111-1111-1111-1111-111111111111" # Daily Loan fallback

    def _upsert_client_profile(self, entity: Loan) -> None:
        try:
            client_data = {
                "client_id": entity.client_id,
                "name": entity.client_name,
                "nickname": entity.extra_fields.get("nickname") or "",
                "phone": entity.extra_fields.get("phone") or "",
                "address": entity.extra_fields.get("address") or "",
                "marital_status": entity.extra_fields.get("marital_status") or "",
                "business_type": entity.extra_fields.get("business_type") or "",
                "average_monthly_income": float(entity.extra_fields.get("average_monthly_income") or 0.0),
                "other_obligations": entity.extra_fields.get("other_obligations") or ""
            }
            self.client.table("clients").upsert(client_data).execute()
        except Exception as e:
            raise RepositoryError(f"Failed to upsert client profile: {e}")

    def _upsert_group_relation(self, entity: Loan, branch_id: str, officer_id: str) -> None:
        if not entity.group_name:
            return
        try:
            res_g = self.client.table("groups").select("group_id").eq("name", entity.group_name).execute()
            if res_g.data:
                group_id = res_g.data[0]["group_id"]
            else:
                g_data = {
                    "name": entity.group_name,
                    "meeting_day": entity.extra_fields.get("meeting_day", "Monday"),
                    "branch_id": branch_id,
                    "officer_id": officer_id
                }
                res_ins = self.client.table("groups").insert(g_data).execute()
                group_id = res_ins.data[0]["group_id"] if res_ins.data else None
            
            if group_id:
                res_m = self.client.table("client_memberships").select("membership_id").eq("client_id", entity.client_id).eq("group_id", group_id).is_("end_date", "null").execute()
                if not res_m.data:
                    self.client.table("client_memberships").insert({
                        "client_id": entity.client_id,
                        "group_id": group_id,
                        "branch_id": branch_id,
                        "officer_id": officer_id
                    }).execute()
        except Exception:
            pass

    def _prepare_db_data(self, entity: Loan) -> dict:
        branch_id = self._resolve_branch_id(entity.branch)
        officer_id = self._resolve_officer_id(entity.credit_officer)
        product_id = self._resolve_product_id(entity.product_type)
        
        # Ensure client profile is saved first
        self._upsert_client_profile(entity)
        self._upsert_group_relation(entity, branch_id, officer_id)

        loan_id = entity.id if (entity.id and len(entity.id) == 36) else None
        
        db_dict = {
            "client_id": entity.client_id,
            "product_id": product_id,
            "branch_id": branch_id,
            "officer_id": officer_id,
            "date": entity.start_date.isoformat() if entity.start_date else date.today().isoformat(),
            "loan_amount": entity.amount,
            "active_credit": entity.extra_fields.get("active_credit", entity.amount),
            "loan_repay": entity.extra_fields.get("loan_repay", entity.expected_installment),
            "total_due": entity.extra_fields.get("total_due", entity.total_payable),
            "status": entity.status.value if hasattr(entity.status, 'value') else entity.status,
            "product_category": entity.extra_fields.get("product_category", "Finance"),
            "disbursement_date": entity.extra_fields.get("disbursement_date"),
            "start_date": entity.start_date.isoformat() if entity.start_date else None,
            "expected_end_date": entity.end_date.isoformat() if entity.end_date else None,
            "extra_fields": entity.extra_fields
        }
        if loan_id:
            db_dict["loan_id"] = loan_id
        return db_dict

    def find_by_id(self, id: str) -> Optional[Loan]:
        query = self.client.table(self.table_name).select(self.columns).eq("loan_id", id)
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
            branch_id = self._resolve_branch_id(filters.branch)
            query = query.eq("branch_id", branch_id)
        if filters.officer:
            officer_id = self._resolve_officer_id(filters.officer)
            query = query.eq("officer_id", officer_id)
        if filters.client_id:
            query = query.eq("client_id", filters.client_id)
            
        start = (filters.page - 1) * filters.size
        end = start + filters.size - 1
        query = query.range(start, end)
        
        res = self._execute(query)
        return [LoanMapper.to_domain(d) for d in res.data]

    def create(self, entity: Loan) -> Loan:
        data = self._prepare_db_data(entity)
        if "loan_id" in data and not data["loan_id"]:
            del data["loan_id"]
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        if inserted:
            entity.id = inserted.get("loan_id")
        return entity

    def create_many(self, loans: List[Loan]) -> None:
        if not loans:
            return
        data = [self._prepare_db_data(L) for L in loans]
        for d in data:
            if "loan_id" in d and not d["loan_id"]:
                del d["loan_id"]
        query = self.client.table(self.table_name).insert(data)
        self._execute(query)

    def update(self, entity: Loan) -> Loan:
        data = self._prepare_db_data(entity)
        # Primary key mapping
        loan_id = data.pop("loan_id", None)
        if loan_id:
            self._execute(self.client.table(self.table_name).update(data).eq("loan_id", loan_id))
        else:
            self._execute(self.client.table(self.table_name).update(data).eq("client_id", entity.client_id))
        
        res = self._execute(self.client.table(self.table_name).select(self.columns).eq("client_id", entity.client_id))
        updated = self._single_or_none(res.data)
        return LoanMapper.to_domain(updated) if updated else entity

    def approve(self, loan_id: str) -> None:
        query = self.client.table(self.table_name).update({"status": "Active"}).eq("client_id", loan_id)
        # Try both client_id and loan_id
        try:
            self._execute(query)
        except Exception:
            self._execute(self.client.table(self.table_name).update({"status": "Active"}).eq("loan_id", loan_id))

    def reject(self, loan_id: str) -> None:
        query = self.client.table(self.table_name).update({"status": "Rejected"}).eq("client_id", loan_id)
        try:
            self._execute(query)
        except Exception:
            self._execute(self.client.table(self.table_name).update({"status": "Rejected"}).eq("loan_id", loan_id))

    def disburse(self, loan_id: str) -> None:
        self.approve(loan_id)

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("loan_id", id)
        res = self._execute(query)
        return len(res.data) > 0
        
    def delete_by_client_id(self, client_id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("client_id", client_id)
        res = self._execute(query)
        return len(res.data) > 0
