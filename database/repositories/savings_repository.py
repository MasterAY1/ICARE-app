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

    def _resolve_branch_id(self, branch_name: str) -> Optional[str]:
        if not branch_name:
            return None
        import uuid
        try:
            u = uuid.UUID(str(branch_name).strip())
            if u.int != 0:
                return str(u)
            return None
        except (ValueError, TypeError, AttributeError):
            pass
        try:
            res = self.client.table("branches").select("branch_id").eq("name", branch_name).execute()
            if res.data:
                return res.data[0]["branch_id"]
            res_ci = self.client.table("branches").select("branch_id").ilike("name", branch_name).execute()
            if res_ci.data:
                return res_ci.data[0]["branch_id"]
        except Exception:
            pass
        return None

    def _resolve_officer_id(self, username: str) -> Optional[str]:
        if not username:
            return None
        import uuid
        try:
            u = uuid.UUID(str(username).strip())
            if u.int != 0:
                return str(u)
            return None
        except (ValueError, TypeError, AttributeError):
            pass
        try:
            res = self.client.table("app_users").select("id").eq("username", username).execute()
            if res.data:
                return res.data[0]["id"]
            res_ci = self.client.table("app_users").select("id").ilike("username", username).execute()
            if res_ci.data:
                return res_ci.data[0]["id"]
        except Exception:
            pass
        return None

    def _resolve_group_id(self, group_name: str) -> Optional[str]:
        if not group_name:
            return None
        import uuid
        import re
        str_name = str(group_name).strip()
        try:
            u = uuid.UUID(str_name)
            if u.int != 0:
                return str(u)
            return None
        except (ValueError, TypeError, AttributeError):
            pass

        # Check for disambiguated label: "GroupName (#Number - MeetingDay)" or "GroupName (#Number)"
        m = re.match(r"^(.+?)\s*\(\s*#(\d+)(?:\s*-\s*[^)]+)?\s*\)$", str_name)
        if m:
            base_name = m.group(1).strip()
            group_num = m.group(2).strip()
            try:
                res = self.client.table("groups").select("group_id").eq("group_number", group_num).ilike("name", base_name).execute()
                if res.data:
                    return res.data[0]["group_id"]
                res_num = self.client.table("groups").select("group_id").eq("group_number", group_num).execute()
                if res_num.data:
                    return res_num.data[0]["group_id"]
            except Exception:
                pass
            str_name = base_name

        try:
            # 1. Exact name match
            res = self.client.table("groups").select("group_id").eq("name", str_name).execute()
            if res.data:
                return res.data[0]["group_id"]
            # 2. Case-insensitive name match
            res_ci = self.client.table("groups").select("group_id").ilike("name", str_name).execute()
            if res_ci.data:
                return res_ci.data[0]["group_id"]
            # 3. Fallback to group_number check if numeric
            if str_name.isdigit():
                res_num = self.client.table("groups").select("group_id").eq("group_number", str_name).execute()
                if res_num.data:
                    return res_num.data[0]["group_id"]
            # 4. Partial substring match
            res_part = self.client.table("groups").select("group_id").ilike("name", f"%{str_name}%").execute()
            if res_part.data:
                return res_part.data[0]["group_id"]
        except Exception:
            pass
        return None

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
            if self.entity_class.__name__ == "LapsSavings":
                kwargs["migration_batch_id"] = dto.get("migration_batch_id")
                kwargs["migration_source"] = dto.get("migration_source", "SYSTEM")
                kwargs["owner_known"] = dto.get("owner_known", True)
        elif self.entity_class.__name__ == "GroupSavings":
            kwargs["group_name"] = g_name
            kwargs["group_id"] = dto.get("group_id")
            
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

        if self.entity_class.__name__ == "LapsSavings":
            d["migration_batch_id"] = getattr(entity, "migration_batch_id", None)
            d["migration_source"] = getattr(entity, "migration_source", "SYSTEM")
            d["owner_known"] = getattr(entity, "owner_known", True)

        import uuid
        def clean_uuid(val):
            if not val or str(val) == "00000000-0000-0000-0000-000000000000":
                return None
            try:
                u = uuid.UUID(str(val))
                if u.int == 0:
                    return None
                return str(u)
            except (ValueError, TypeError, AttributeError):
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
            g_id = getattr(entity, 'group_id', None)
            cleaned = clean_uuid(g_id)
            if not cleaned:
                g_id = self._resolve_group_id(entity.group_name)
                cleaned = clean_uuid(g_id)
            d["group_id"] = cleaned

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
            if "group_id" in res.data[0] and res.data[0]["group_id"]:
                entity.group_id = str(res.data[0]["group_id"])

    def find_all(self, branch: Optional[str] = None) -> List:
        query = self.client.table(self.table_name).select(self.select_columns)
        if branch:
            branch_id = self._resolve_branch_id(branch)
            if branch_id:
                query = query.eq("branch_id", branch_id)
        res = query.execute()
        return [self._to_domain(item) for item in res.data]

    def get_total_balance(self, branch: Optional[str] = None, officer: Optional[str] = None, client_id: Optional[str] = None, group_name: Optional[str] = None, group_id: Optional[str] = None) -> float:
        query = self.client.table(self.table_name).select("deposit_amount, withdrawal_amount")
        if branch:
            branch_id = self._resolve_branch_id(branch)
            if branch_id:
                query = query.eq("branch_id", branch_id)
        if officer:
            officer_id = self._resolve_officer_id(officer)
            if officer_id:
                query = query.eq("officer_id", officer_id)
        if client_id and self.entity_class.__name__ in ["IndividualSavings", "MiscSavings", "LapsSavings"]:
            query = query.eq("client_id", client_id)
        if self.entity_class.__name__ == "GroupSavings":
            if group_id:
                query = query.eq("group_id", group_id)
            elif group_name:
                resolved_gid = self._resolve_group_id(group_name)
                if resolved_gid:
                    query = query.eq("group_id", resolved_gid)
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
