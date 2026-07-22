from typing import List, Optional
from datetime import date, datetime
from domain.entities.savings import IndividualSavings, GroupSavings, MiscSavings, LapsSavings
from database.repositories.base_repository import BaseRepository

class SupabaseSavingsRepository(BaseRepository):
    """Base repository for all savings buckets"""
    def __init__(self, client, table_name: str, entity_class):
        super().__init__(client)
        self.table_name = table_name
        self.entity_class = entity_class
        if entity_class.__name__ == "GroupSavings":
            self.select_columns = "*, branches(name), app_users(username), groups(name)"
        else:
            self.select_columns = "*, branches(name), app_users(username), clients(name)"

    def _resolve_branch_id(self, branch_name: str) -> str:
        if not branch_name:
            return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"
        try:
            res = self.client.table("branches").select("branch_id").eq("name", branch_name).execute()
            if res.data:
                return res.data[0]["branch_id"]
        except Exception:
            pass
        return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"

    def _resolve_officer_id(self, username: str) -> str:
        if not username:
            return "00000000-0000-0000-0000-000000000000"
        try:
            res = self.client.table("app_users").select("id").eq("username", username).execute()
            if res.data:
                return res.data[0]["id"]
        except Exception:
            pass
        return "00000000-0000-0000-0000-000000000000"

    def _resolve_group_id(self, group_name: str) -> str:
        if not group_name:
            return "00000000-0000-0000-0000-000000000000"
        try:
            res = self.client.table("groups").select("group_id").eq("name", group_name).execute()
            if res.data:
                return res.data[0]["group_id"]
            # Fallback to group_code check
            res_code = self.client.table("groups").select("group_id").eq("group_code", group_name).execute()
            if res_code.data:
                return res_code.data[0]["group_id"]
            try:
                code_int = int(group_name)
                res_int = self.client.table("groups").select("group_id").eq("group_code", code_int).execute()
                if res_int.data:
                    return res_int.data[0]["group_id"]
            except ValueError:
                pass
        except Exception:
            pass
        return "00000000-0000-0000-0000-000000000000"

    def _to_domain(self, dto: dict):
        c_name = ""
        if dto.get("clients") and isinstance(dto.get("clients"), dict):
            c_name = dto.get("clients", {}).get("name", "")
        else:
            c_name = dto.get("client_name", "")
            
        g_name = ""
        if dto.get("groups") and isinstance(dto.get("groups"), dict):
            g_name = dto.get("groups", {}).get("name", "")
        else:
            g_name = dto.get("group_name", "")

        b_name = dto.get("branch", "")
        if dto.get("branches") and isinstance(dto.get("branches"), dict):
            b_name = dto.get("branches", {}).get("name", b_name)

        o_name = dto.get("officer", "")
        if dto.get("app_users") and isinstance(dto.get("app_users"), dict):
            o_name = dto.get("app_users", {}).get("username", o_name)

        kwargs = {
            "id": dto.get("id"),
            "reference": dto.get("reference"),
            "remarks": dto.get("remarks"),
            "deposit_amount": float(dto.get("deposit_amount") or 0.0),
            "withdrawal_amount": float(dto.get("withdrawal_amount") or 0.0),
            "balance": 0.0,
            "date": dto.get("posting_date") or dto.get("created_at"),
            "branch": b_name,
            "officer": o_name
        }
        if self.entity_class.__name__ in ["IndividualSavings", "MiscSavings", "LapsSavings"]:
            kwargs["client_id"] = dto.get("client_id", "")
            kwargs["client_name"] = c_name
        elif self.entity_class.__name__ == "GroupSavings":
            kwargs["group_name"] = g_name
            
        return self.entity_class(**kwargs)

    def _to_database(self, entity) -> dict:
        import uuid
        def is_valid_uuid(val):
            if not val: return False
            try:
                uuid.UUID(str(val))
                return True
            except ValueError:
                return False

        branch_id = entity.branch if is_valid_uuid(entity.branch) else self._resolve_branch_id(entity.branch)
        officer_id = entity.officer if is_valid_uuid(entity.officer) else self._resolve_officer_id(entity.officer)
        
        p_date = entity.date
        if p_date:
            if isinstance(p_date, str):
                p_date = p_date.split('T')[0]
            elif isinstance(p_date, (datetime, date)):
                p_date = p_date.isoformat().split('T')[0]
        else:
            p_date = date.today().isoformat()

        d = {
            "posting_date": p_date,
            "branch_id": branch_id,
            "officer_id": officer_id,
            "deposit_amount": entity.deposit_amount,
            "withdrawal_amount": entity.withdrawal_amount,
            "reference": entity.reference or "",
            "remarks": entity.remarks or ""
        }
        if entity.id:
            d["id"] = entity.id

        import uuid
        def clean_uuid(val):
            if not val:
                return None
            try:
                uuid.UUID(str(val))
                return str(val)
            except ValueError:
                return None

        if self.entity_class.__name__ in ["IndividualSavings", "MiscSavings", "LapsSavings"]:
            c_id = entity.client_id
            if c_id and not clean_uuid(c_id) and not str(c_id).startswith('GROUP-') and not str(c_id).startswith('GLOBAL-'):
                try:
                    res_c = self.client.table("clients").select("client_id").eq("client_code", c_id).execute()
                    if res_c.data:
                        c_id = res_c.data[0]["client_id"]
                except Exception:
                    pass
            d["client_id"] = clean_uuid(c_id)
        elif self.entity_class.__name__ == "GroupSavings":
            # If it's a fake group id or name, resolve it
            g_id = self._resolve_group_id(entity.group_name)
            d["group_id"] = clean_uuid(g_id)

        return d

    def create(self, entity) -> None:
        data = self._to_database(entity)
        if "id" in data and not data["id"]:
            del data["id"]
        print(f"[SAVINGS TRACE] Repository create called for {self.entity_class.__name__}. Data: {data}")
        res = self.client.table(self.table_name).insert(data).execute()
        print(f"[SAVINGS TRACE] SQL Insert Result for {self.table_name}: {res.data}")
        if res.data:
            entity.id = str(res.data[0].get("id"))

    def find_all(self, branch: Optional[str] = None) -> List:
        query = self.client.table(self.table_name).select(self.select_columns)
        if branch:
            branch_id = self._resolve_branch_id(branch)
            query = query.eq("branch_id", branch_id)
        res = query.execute()
        return [self._to_domain(item) for item in res.data]

    def get_total_balance(self, branch: Optional[str] = None, officer: Optional[str] = None) -> float:
        query = self.client.table(self.table_name).select("deposit_amount, withdrawal_amount")
        if branch:
            branch_id = self._resolve_branch_id(branch)
            query = query.eq("branch_id", branch_id)
        if officer:
            officer_id = self._resolve_officer_id(officer)
            query = query.eq("officer_id", officer_id)
        res = query.execute()
        total = 0.0
        for row in res.data:
            total += float(row.get("deposit_amount", 0)) - float(row.get("withdrawal_amount", 0))
        return total

class SupabaseIndividualSavingsRepository(SupabaseSavingsRepository):
    def __init__(self, client):
        super().__init__(client, 'individual_savings', IndividualSavings)

class SupabaseGroupSavingsRepository(SupabaseSavingsRepository):
    def __init__(self, client):
        super().__init__(client, 'group_savings', GroupSavings)

class SupabaseMiscSavingsRepository(SupabaseSavingsRepository):
    def __init__(self, client):
        # Maps to internal_savings table in the greenfield schema
        super().__init__(client, 'internal_savings', MiscSavings)

class SupabaseLapsSavingsRepository(SupabaseSavingsRepository):
    def __init__(self, client):
        super().__init__(client, 'laps_savings', LapsSavings)
