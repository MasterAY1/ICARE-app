import uuid
from datetime import date, datetime, timedelta
from typing import Optional
from interfaces.unit_of_work import UnitOfWork

class BusinessDateService:
    @staticmethod
    def get_business_date(uow: UnitOfWork, branch_name_or_id: str) -> date:
        """
        Fetch active business date for the branch.
        Falls back to system current date if no custom business date override is configured.
        """
        if not branch_name_or_id:
            return datetime.now().date()
            
        try:
            # Check branches table for active operational date
            res = uow.client.table("branches").select("cashbook_defaults").eq("name", branch_name_or_id).execute()
            if not res.data:
                res = uow.client.table("branches").select("cashbook_defaults").eq("branch_id", branch_name_or_id).execute()
                
            if res.data:
                defaults = res.data[0].get("cashbook_defaults") or {}
                if isinstance(defaults, dict) and defaults.get("business_date"):
                    return date.fromisoformat(defaults["business_date"])
        except Exception:
            pass
            
        return datetime.now().date()

    @staticmethod
    def set_business_date(uow: UnitOfWork, branch_name_or_id: str, new_date: date) -> bool:
        """
        Set or advance operational business date for a branch.
        """
        try:
            date_str = new_date.isoformat()
            res = uow.client.table("branches").select("branch_id, cashbook_defaults").eq("name", branch_name_or_id).execute()
            if not res.data:
                res = uow.client.table("branches").select("branch_id, cashbook_defaults").eq("branch_id", branch_name_or_id).execute()
                
            if res.data:
                b_id = res.data[0]["branch_id"]
                defaults = res.data[0].get("cashbook_defaults") or {}
                if not isinstance(defaults, dict):
                    defaults = {}
                defaults["business_date"] = date_str
                uow.client.table("branches").update({"cashbook_defaults": defaults}).eq("branch_id", b_id).execute()
                return True
        except Exception:
            pass
        return False

    @staticmethod
    def close_business_date(uow: UnitOfWork, branch_id: str, posting_date: date, closed_by: Optional[str] = None) -> bool:
        """
        Executes Branch Day Close:
        1. Freezes today's Master Cashbook & CO Cashbooks (status = 'CLOSED').
        2. Carries forward closing balance as tomorrow's opening balance.
        3. Advances branch business date to tomorrow.
        """
        p_date_str = posting_date.isoformat()
        next_date = posting_date + timedelta(days=1)
        next_date_str = next_date.isoformat()
        
        user_uuid = None
        if closed_by:
            try:
                res_u = uow.client.table("app_users").select("id").eq("username", closed_by).execute()
                if res_u.data:
                    user_uuid = res_u.data[0]["id"]
                else:
                    # Check if closed_by is already a valid UUID
                    uuid.UUID(closed_by)
                    user_uuid = closed_by
            except Exception:
                user_uuid = None
                
        try:
            # 1. Freeze Master Cashbook
            res_mb = uow.client.table("master_cashbook").select("closing_balance").eq("branch_id", branch_id).eq("date", p_date_str).execute()
            closing_bal = float(res_mb.data[0]["closing_balance"]) if res_mb.data else 0.0
            
            update_payload = {
                "status": "Closed",
                "verified_at": datetime.now().isoformat()
            }
            if user_uuid:
                update_payload["verified_by"] = user_uuid

            uow.client.table("master_cashbook").update(update_payload).eq("branch_id", branch_id).eq("date", p_date_str).execute()

            # 2. Freeze CO Cashbooks
            uow.client.table("co_cashbooks").update({"status": "Closed"}).eq("branch_id", branch_id).eq("date", p_date_str).execute()

            # 3. Initialize tomorrow's Master Cashbook with carried forward opening balance
            uow.client.table("master_cashbook").upsert({
                "date": next_date_str,
                "branch_id": branch_id,
                "opening_balance": closing_bal,
                "status": "Open",
                "version": 1
            }, on_conflict="date,branch_id").execute()

            # 4. Advance Branch Business Date
            BusinessDateService.set_business_date(uow, branch_id, next_date)
            return True
        except Exception as ex:
            print("Error closing business date:", ex)
            return False
