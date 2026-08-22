import uuid
from datetime import date, datetime, timedelta
from typing import Optional
from interfaces.unit_of_work import UnitOfWork

import holidays

ng_holidays = holidays.Nigeria()

class BusinessDateService:
    @staticmethod
    def is_working_day(target_date: date, custom_closures: Optional[list] = None) -> tuple[bool, str]:
        """
        Checks if target_date is a working day (returns True if valid, False + reason if weekend/holiday/closure).
        """
        if custom_closures is None:
            custom_closures = []

        if target_date.weekday() >= 5:
            day_name = "Saturday" if target_date.weekday() == 5 else "Sunday"
            return False, f"{day_name} is a weekend (non-working day)"

        if target_date in ng_holidays:
            holiday_name = ng_holidays.get(target_date)
            return False, f"{target_date.isoformat()} is a public holiday ({holiday_name})"

        for s_date, e_date, reason in custom_closures:
            if s_date <= target_date <= e_date:
                return False, f"{target_date.isoformat()} falls within branch closure ({reason})"

        return True, "Valid working day"

    @staticmethod
    def is_date_closed(uow: UnitOfWork, branch_name_or_id: str, target_date: date) -> bool:
        """
        Checks if a given date is marked as Closed/Verified for the specified branch.
        """
        if not branch_name_or_id or not target_date:
            return False
        try:
            p_date_str = target_date.isoformat() if hasattr(target_date, 'isoformat') else str(target_date)
            b_id = branch_name_or_id
            if len(str(branch_name_or_id)) < 36 or not str(branch_name_or_id).count("-") == 4:
                res_b = uow.client.table("branches").select("branch_id").eq("name", branch_name_or_id).execute()
                if res_b.data:
                    b_id = res_b.data[0]["branch_id"]
            
            res = uow.client.table("master_cashbook").select("status").eq("branch_id", b_id).eq("date", p_date_str).execute()
            if res.data and res.data[0].get("status") in ["Closed", "Verified"]:
                return True
        except Exception:
            pass
        return False

    @staticmethod
    def is_operational_open(uow: UnitOfWork, branch_name_or_id: str, target_date: date) -> tuple[bool, str]:
        """
        Unified check for operational activity on target_date:
        1. Weekend Check (Saturday / Sunday)
        2. Nigerian Public Holiday Check
        3. Emergency Branch Closure (AM / Admin / BM)
        4. Day Close Freeze (EOD Closed in master_cashbook)
        Returns (is_open: bool, reason: str)
        """
        if not target_date:
            return True, "Valid date"
        
        target_d = target_date.date() if hasattr(target_date, 'date') and not isinstance(target_date, date) else target_date
        
        # 1. Weekend Check
        if target_d.weekday() >= 5:
            day_name = "Saturday" if target_d.weekday() == 5 else "Sunday"
            return False, f"{day_name} is a weekend (non-working day)"

        # 2. Public Holiday Check
        if target_d in ng_holidays:
            holiday_name = ng_holidays.get(target_d)
            return False, f"{target_d.isoformat()} is a public holiday ({holiday_name})"

        # 3. Emergency Branch Closure Check
        if branch_name_or_id:
            try:
                b_id = branch_name_or_id
                if len(str(branch_name_or_id)) < 36 or not str(branch_name_or_id).count("-") == 4:
                    res_b = uow.client.table("branches").select("branch_id").eq("name", branch_name_or_id).execute()
                    if res_b.data:
                        b_id = res_b.data[0]["branch_id"]
                
                target_str = target_d.isoformat()
                q_cl = uow.client.table("branch_closures").select("*") \
                    .lte("start_date", target_str).gte("end_date", target_str)
                if b_id:
                    q_cl = q_cl.or_(f"branch_id.is.null,branch_id.eq.{b_id}")
                res_cl = q_cl.execute()
                if res_cl.data:
                    c_reason = res_cl.data[0].get("reason") or "Emergency closure"
                    return False, f"Branch is closed due to emergency closure ({c_reason})"
            except Exception:
                pass

        # 4. Day Close Freeze Check
        if branch_name_or_id:
            if BusinessDateService.is_date_closed(uow, branch_name_or_id, target_d):
                return False, f"Business day {target_d.isoformat()} has already been closed by Branch Manager"

        return True, "Operational business day is open"

    @staticmethod
    def get_next_working_day(target_date: date, custom_closures: Optional[list] = None) -> date:
        """
        Advances target_date until a valid working day is reached.
        """
        curr = target_date
        while True:
            is_valid, _ = BusinessDateService.is_working_day(curr, custom_closures)
            if is_valid:
                return curr
            curr += timedelta(days=1)

    @staticmethod
    def get_business_date(uow: UnitOfWork, branch_name_or_id: str) -> date:
        """
        Fetch active operational business date for the branch.
        If today is a weekend, holiday, or closed, advances to the next valid open working day.
        """
        today = datetime.now().date()
        
        if branch_name_or_id:
            try:
                res = uow.client.table("branches").select("branch_id, cashbook_defaults").eq("name", branch_name_or_id).execute()
                if not res.data:
                    res = uow.client.table("branches").select("branch_id, cashbook_defaults").eq("branch_id", branch_name_or_id).execute()
                    
                if res.data:
                    defaults = res.data[0].get("cashbook_defaults") or {}
                    if isinstance(defaults, dict) and defaults.get("business_date"):
                        stored_date = date.fromisoformat(defaults["business_date"])
                        # If stored date is valid and >= today, return it
                        if stored_date >= today:
                            return stored_date
            except Exception:
                pass

        # If today is weekend or holiday, return next valid working day
        next_open = BusinessDateService.get_next_working_day(today)
        return next_open

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
        3. Advances branch business date to the next working day.
        """
        p_date_str = posting_date.isoformat()
        next_date = BusinessDateService.get_next_working_day(posting_date + timedelta(days=1))
        next_date_str = next_date.isoformat()
        
        user_uuid = None
        if closed_by:
            try:
                res_u = uow.client.table("app_users").select("id").eq("username", closed_by).execute()
                if res_u.data:
                    user_uuid = res_u.data[0]["id"]
                else:
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

            # 4. Advance Branch Business Date to next working day
            BusinessDateService.set_business_date(uow, branch_id, next_date)
            return True
        except Exception as ex:
            print("Error closing business date:", ex)
            return False
