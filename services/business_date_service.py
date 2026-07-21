from datetime import date, datetime
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
