import uuid
from datetime import date, datetime, timedelta
from typing import Optional
from interfaces.unit_of_work import UnitOfWork

import holidays

def get_nigerian_holidays(years=None):
    """
    Authoritative Nigerian public holiday provider with operational calendar overrides.
    Purges unobserved estimated lunar dates where MFI business operations are active.
    """
    h = holidays.NG(years=years) if years else holidays.Nigeria()
    unobserved_estimated_holidays = [
        date(2026, 8, 26),  # Id el Maulud (estimated) - Active business day per MFI operations
    ]
    for d in unobserved_estimated_holidays:
        if d in h:
            del h[d]
    return h

ng_holidays = get_nigerian_holidays()

class BusinessDateService:
    _operational_cache = {}

    @staticmethod
    def get_branch_closures(uow: UnitOfWork, branch_name_or_id: Optional[str] = None) -> list[tuple[date, date, str]]:
        """
        Loads active closure windows from public.branch_closures as 3-tuples:
        (start_date, end_date, reason).
        Includes system-wide (branch_id IS NULL) and branch-specific closures.
        """
        closures: list[tuple[date, date, str]] = []
        try:
            b_id = None
            if branch_name_or_id:
                b_str = str(branch_name_or_id).strip()
                if len(b_str) == 36 and b_str.count("-") == 4:
                    b_id = b_str
                else:
                    res_b = uow.client.table("branches").select("branch_id").eq("name", b_str).execute()
                    if res_b.data:
                        b_id = res_b.data[0]["branch_id"]

            q = uow.client.table("branch_closures").select("start_date, end_date, reason, branch_id")
            if b_id:
                q = q.or_(f"branch_id.is.null,branch_id.eq.{b_id}")
            else:
                q = q.is_("branch_id", "null")
            res = q.execute()
            for row in (res.data or []):
                s_raw = row.get("start_date")
                e_raw = row.get("end_date")
                if not s_raw:
                    continue
                s_dt = date.fromisoformat(str(s_raw)[:10])
                e_dt = date.fromisoformat(str(e_raw)[:10]) if e_raw else s_dt
                closures.append((s_dt, e_dt, row.get("reason") or "Branch Closure"))
        except Exception:
            pass
        return closures

    @staticmethod
    def expand_closure_dates(closures: Optional[list]) -> list[date]:
        """
        Expands (start_date, end_date, reason) closure tuples or discrete dates
        into a flat list of closed date objects for LoanProductEngine schedules.
        """
        dates_out: list[date] = []
        for item in (closures or []):
            if isinstance(item, date):
                dates_out.append(item)
            elif isinstance(item, (tuple, list)) and len(item) >= 2:
                s_dt = item[0] if isinstance(item[0], date) else date.fromisoformat(str(item[0])[:10])
                e_dt = item[1] if isinstance(item[1], date) else date.fromisoformat(str(item[1])[:10])
                curr = s_dt
                while curr <= e_dt:
                    dates_out.append(curr)
                    curr += timedelta(days=1)
        return dates_out

    @classmethod
    def invalidate_operational_cache(
        cls,
        branch_name_or_id: Optional[str] = None,
        target_date: Optional[date] = None,
    ) -> None:
        """
        Clears cached operational open/closed status after Day Close, Business Date shift,
        branch closure updates, or Area Lock changes so closed-day restrictions take effect immediately.
        """
        if not branch_name_or_id and not target_date:
            cls._operational_cache.clear()
            return
        target_iso = target_date.isoformat() if target_date and hasattr(target_date, "isoformat") else (str(target_date)[:10] if target_date else None)
        branch_key = str(branch_name_or_id).strip().lower() if branch_name_or_id else None
        keys_to_drop = [
            k for k in list(cls._operational_cache.keys())
            if (target_iso is None or k[1] == target_iso)
            and (branch_key is None or k[0] == branch_key or k[0] == "" or len(k[0]) > 0)
        ]
        # Clear any matching date entries (since cache key may store branch name OR branch UUID)
        for k in keys_to_drop:
            cls._operational_cache.pop(k, None)

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

    @classmethod
    def is_operational_open(cls, uow: UnitOfWork, branch_name_or_id: str, target_date: date) -> tuple[bool, str]:
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
        
        cache_key = (str(branch_name_or_id).strip().lower() if branch_name_or_id else "", target_d.isoformat())
        if cache_key in cls._operational_cache:
            return cls._operational_cache[cache_key]

        # 1. Weekend Check
        if target_d.weekday() >= 5:
            day_name = "Saturday" if target_d.weekday() == 5 else "Sunday"
            res = (False, f"{day_name} is a weekend (non-working day)")
            cls._operational_cache[cache_key] = res
            return res

        # 2. Public Holiday Check
        if target_d in ng_holidays:
            holiday_name = ng_holidays.get(target_d)
            res = (False, f"{target_d.isoformat()} is a public holiday ({holiday_name})")
            cls._operational_cache[cache_key] = res
            return res

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
                cl_rows = getattr(res_cl, "data", None)
                if isinstance(cl_rows, list) and cl_rows:
                    c_reason = cl_rows[0].get("reason") or "Emergency closure"
                    res = (False, f"Branch is closed due to emergency closure ({c_reason})")
                    cls._operational_cache[cache_key] = res
                    return res
            except Exception:
                pass

        # 4. Day Close Freeze Check
        if branch_name_or_id:
            if BusinessDateService.is_date_closed(uow, branch_name_or_id, target_d):
                res = (False, f"Business day {target_d.isoformat()} has already been closed by Branch Manager")
                cls._operational_cache[cache_key] = res
                return res

            # 5. Area Lock Regional Freeze Check
            try:
                target_str = target_d.isoformat()
                b_id = branch_name_or_id
                if len(str(branch_name_or_id)) < 36 or str(branch_name_or_id).count("-") != 4:
                    res_b = uow.client.table("branches").select("branch_id").eq("name", branch_name_or_id).execute()
                    if res_b.data:
                        b_id = res_b.data[0]["branch_id"]
                if b_id:
                    res_al = uow.client.table("area_eod_confirmations").select("status").eq("branch_id", b_id).eq("closure_date", target_str).execute()
                    if res_al.data and res_al.data[0].get("status") == "AREA_LOCKED":
                        res = (False, f"Operations for {target_str} are sealed and locked under Area Manager regional lock.")
                        cls._operational_cache[cache_key] = res
                        return res
            except Exception:
                pass

        res = (True, "Operational business day is open")
        cls._operational_cache[cache_key] = res
        return res

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
    def get_previous_working_day(target_date: date, custom_closures: Optional[list] = None) -> date:
        """
        Steps target_date backward until a valid working day is reached.
        """
        curr = target_date - timedelta(days=1)
        while True:
            is_valid, _ = BusinessDateService.is_working_day(curr, custom_closures)
            if is_valid:
                return curr
            curr -= timedelta(days=1)

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
                        # If stored date is valid and within a reasonable operational cycle (past 30 days to next 7 days), return it
                        if (today - timedelta(days=30)) <= stored_date <= (today + timedelta(days=7)):
                            return stored_date
            except Exception:
                pass

        # If today is weekend, holiday, or branch closure, return next valid working day
        closures = BusinessDateService.get_branch_closures(uow, branch_name_or_id) if uow else []
        next_open = BusinessDateService.get_next_working_day(today, custom_closures=closures)
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
                BusinessDateService.invalidate_operational_cache()
            return True
        except Exception:
            pass
        return False

    @staticmethod
    def close_business_date(
        uow: UnitOfWork,
        branch_id: str,
        posting_date: date,
        closed_by: Optional[str] = None,
        notes: Optional[str] = None
    ) -> bool:
        """
        Executes Branch Day Close:
        1. Freezes today's Master Cashbook & CO Cashbooks (status = 'Closed').
        2. Carries forward closing balance as tomorrow's opening balance.
        3. Advances branch business date to the next working day.
        4. Auto-populates area_eod_confirmations with status = 'PENDING' for Area Manager sign-off.
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

            # 5. Derive Account 1000 vault cash as of closure date and auto-populate area_eod_confirmations
            vault_cash = 0.0
            try:
                res_leg = uow.client.table("financial_ledger_entries") \
                    .select("amount, side") \
                    .eq("branch_id", branch_id) \
                    .eq("account_code", "1000") \
                    .lte("created_at", f"{p_date_str}T23:59:59") \
                    .execute()
                leg_rows = res_leg.data or []
                deb = sum(float(r["amount"]) for r in leg_rows if r.get("side") == "Debit")
                crd = sum(float(r["amount"]) for r in leg_rows if r.get("side") == "Credit")
                vault_cash = max(0.0, deb - crd)
            except Exception:
                pass

            cash_diff = round(closing_bal - vault_cash, 2)

            try:
                auto_note = notes or (
                    "Balanced (All collections banked)." if closing_bal == 0
                    else (f"Cash in safe: ₦{closing_bal:,.2f}." if closing_bal > 0
                          else f"Advance money banked ahead / savings paid out: ₦{abs(closing_bal):,.2f}.")
                )
                from services.area_manager_service import AreaManagerService
                resolved_area = AreaManagerService.resolve_area_name(uow, branch_id=branch_id)
                uow.client.table("area_eod_confirmations").upsert({
                    "area_name": resolved_area,
                    "branch_id": branch_id,
                    "closure_date": p_date_str,
                    "status": "PENDING",
                    "confirmed_by": None,
                    "acct_1000_balance": vault_cash,
                    "cash_variance": cash_diff,
                    "notes": auto_note,
                    "created_at": datetime.now().isoformat()
                }, on_conflict="branch_id,closure_date").execute()
            except Exception as ex_eod:
                print(f"[EOD BRIDGE] area_eod_confirmations upsert notice: {ex_eod}")

            BusinessDateService.invalidate_operational_cache(target_date=posting_date)
            return True
        except Exception as ex:
            print("Error closing business date:", ex)
            return False
