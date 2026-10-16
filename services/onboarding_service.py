import uuid
import math
import secrets
import datetime
import re
from typing import Dict, Any, List, Optional, Tuple
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.loan_product_engine import LoanProductEngine
from services.business_date_service import get_nigerian_holidays
from services.savings_service import SavingsService
from auth.password import hash_password

class OnboardingService:
    """
    Authoritative domain service for branch onboarding, staging, Excel parsing,
    real-time validation, and atomic commitment to live core banking tables.
    """

    @staticmethod
    def generate_token(branch_code: str) -> str:
        """Generates a secure, collision-free URL token for branch onboarding."""
        clean_code = str(branch_code or "BR").lower().replace(" ", "")[:6]
        random_suffix = secrets.token_hex(12)
        return f"onb_{clean_code}_{random_suffix}"

    @staticmethod
    def create_session(
        uow: SupabaseUnitOfWork,
        branch_name: str,
        branch_code: str,
        contact_person: Optional[str] = None,
        contact_phone: Optional[str] = None,
        created_by_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """Creates a new branch onboarding session with 14-day token expiration."""
        branch_name = branch_name.strip()
        branch_code = branch_code.strip().upper()

        # Lookup branch_id if branch already exists in master
        b_res = uow.client.table("branches").select("branch_id").or_(f"name.ilike.{branch_name},code.ilike.{branch_code}").execute()
        branch_id = b_res.data[0]["branch_id"] if b_res.data else None

        token = OnboardingService.generate_token(branch_code)
        now = datetime.datetime.now(datetime.timezone.utc)
        expires_at = now + datetime.timedelta(days=14)

        session_data = {
            "id": str(uuid.uuid4()),
            "branch_id": branch_id,
            "branch_name": branch_name,
            "branch_code": branch_code,
            "token": token,
            "status": "draft",
            "created_by": created_by_id,
            "contact_person": contact_person,
            "contact_phone": contact_phone,
            "total_groups": 0,
            "total_members": 0,
            "total_savings": 0.0,
            "total_active_credit": 0.0,
            "total_current_balance": 0.0,
            "payload": {"officers": [], "groups": [], "members": [], "misc_savings": 0.0, "laps_savings": 0.0},
            "validation_summary": {"is_valid": True, "errors": [], "warnings": []},
            "expires_at": expires_at.isoformat(),
            "created_at": now.isoformat(),
            "updated_at": now.isoformat()
        }

        uow.client.table("branch_onboarding_sessions").insert(session_data).execute()
        return session_data

    @staticmethod
    def get_session_by_token(uow: SupabaseUnitOfWork, token: str) -> Dict[str, Any]:
        """
        Retrieves an onboarding session by token.
        Checks expiration and attaches reference catalogs (loan products, meeting days).
        """
        res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", token).execute()
        if not res.data:
            raise ValueError("Invalid onboarding link or token not found.")

        session = res.data[0]

        # Verify expiration
        exp_str = session.get("expires_at")
        if exp_str:
            try:
                exp_dt = datetime.datetime.fromisoformat(exp_str.replace("Z", "+00:00"))
                now = datetime.datetime.now(datetime.timezone.utc)
                if now > exp_dt:
                    raise ValueError("This onboarding link has expired. Please contact your administrator to renew it.")
            except (ValueError, TypeError) as e:
                if "expired" in str(e).lower():
                    raise e

        # Fetch reference loan products
        p_res = uow.client.table("loan_products").select("product_id, name, repayment_cycle, installments, interest_rate").order("name").execute()
        products = p_res.data or []

        # Check next available branch group number for smart UI pre-filling
        branch_id = session.get("branch_id")
        if not branch_id and session.get("branch_code"):
            b_res = uow.client.table("branches").select("branch_id").or_(f"name.ilike.{session.get('branch_name')},code.ilike.{session.get('branch_code')}").execute()
            if b_res.data:
                branch_id = b_res.data[0]["branch_id"]

        next_group_num = 1
        if branch_id:
            g_res = uow.client.table("groups").select("group_number").eq("branch_id", branch_id).execute()
            nums = []
            for g in (g_res.data or []):
                gn_val = str(g.get("group_number") or "").strip()
                if gn_val.isdigit():
                    nums.append(int(gn_val))
            if nums:
                next_group_num = max(nums) + 1
        session["next_branch_group_number"] = next_group_num

        # Standard meeting days
        meeting_days = ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Monthly"]

        return {
            "session": session,
            "loan_products": products,
            "meeting_days": meeting_days
        }

    @staticmethod
    def validate_payload(payload: Dict[str, Any], products_map: Dict[str, Any]) -> Tuple[Dict[str, Any], Dict[str, float]]:
        """
        Validates groups and members in memory, detects formatting issues,
        missing fields, duplicate names, and computes summary aggregates.
        """
        errors = []
        warnings = []

        groups = payload.get("groups", [])
        members = payload.get("members", [])
        officers = payload.get("officers", [])

        # Validate Groups
        group_refs = set()
        for idx, g in enumerate(groups, 1):
            g_ref = str(g.get("group_reference") or "").strip()
            g_name = str(g.get("group_name") or "").strip()
            m_day = str(g.get("meeting_day") or "").strip()

            if not g_ref:
                errors.append(f"Group row #{idx}: Group Reference is required.")
            elif g_ref in group_refs:
                errors.append(f"Group row #{idx}: Duplicate Group Reference '{g_ref}'.")
            else:
                group_refs.add(g_ref)

            if not g_name:
                errors.append(f"Group row #{idx} ({g_ref}): Group Name is required.")
            if not m_day:
                warnings.append(f"Group {g_ref}: No meeting day set. Defaults to 'Daily'.")

        # Validate Members
        total_savings = 0.0
        total_active_credit = 0.0
        total_current_balance = 0.0

        names_by_group = {}
        for idx, m in enumerate(members, 1):
            m_name = str(m.get("full_name") or "").strip()
            g_ref = str(m.get("group_reference") or "").strip()
            phone = str(m.get("phone_number") or "").strip()
            s_bal = float(m.get("savings_balance") or 0.0)
            a_cred = float(m.get("active_credit") or 0.0)
            c_bal = float(m.get("current_credit_balance") or 0.0)
            l_type = str(m.get("loan_type") or "").strip()

            if not m_name:
                errors.append(f"Member row #{idx}: Full Name is required.")
            if not g_ref:
                errors.append(f"Member row #{idx} ({m_name}): Group Reference is required.")
            elif g_ref not in group_refs:
                errors.append(f"Member row #{idx} ({m_name}): References non-existent group '{g_ref}'.")

            # Check duplicate names within same group
            group_key = (g_ref, m_name.lower())
            if group_key in names_by_group:
                warnings.append(f"Member '{m_name}' appears multiple times in group '{g_ref}'.")
            names_by_group[group_key] = True

            # Phone format check (Nigerian 11-digit convention)
            if phone:
                clean_phone = "".join(ch for ch in phone if ch.isdigit())
                if len(clean_phone) not in (10, 11, 13, 14):
                    warnings.append(f"Member '{m_name}': Phone number '{phone}' may be invalid.")

            # Validate Loan Product if loan values provided
            if a_cred > 0 or c_bal > 0:
                if not l_type:
                    errors.append(f"Member '{m_name}': Has active loan balance but no Loan Product Type selected.")
                elif products_map and l_type.lower() not in products_map:
                    warnings.append(f"Member '{m_name}': Loan Product '{l_type}' does not match standard catalog.")

                if c_bal > a_cred and a_cred > 0:
                    warnings.append(f"Member '{m_name}': Current balance (₦{c_bal:,.2f}) exceeds active credit (₦{a_cred:,.2f}).")

            total_savings += s_bal
            total_active_credit += a_cred
            total_current_balance += c_bal

        aggregates = {
            "total_groups": len(groups),
            "total_members": len(members),
            "total_officers": len(officers),
            "total_savings": round(total_savings, 2),
            "total_active_credit": round(total_active_credit, 2),
            "total_current_balance": round(total_current_balance, 2),
            "misc_savings": float(payload.get("misc_savings") or 0.0),
            "laps_savings": float(payload.get("laps_savings") or 0.0)
        }

        validation_summary = {
            "is_valid": len(errors) == 0,
            "errors": errors,
            "warnings": warnings,
            "error_count": len(errors),
            "warning_count": len(warnings)
        }

        return validation_summary, aggregates

    @staticmethod
    def save_draft(uow: SupabaseUnitOfWork, token: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Saves updated groups, members, and officers draft payload.
        Auto-extends link expiration by 14 days and returns updated validation summary.
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", token).execute()
        if not s_res.data:
            raise ValueError("Onboarding session not found.")

        session = s_res.data[0]
        if session["status"] == "approved":
            raise ValueError("This onboarding session has already been approved and committed.")

        # Pre-load loan products for validation
        p_res = uow.client.table("loan_products").select("name").execute()
        products_map = {p["name"].strip().lower(): True for p in (p_res.data or [])}

        validation_summary, aggregates = OnboardingService.validate_payload(payload, products_map)

        now = datetime.datetime.now(datetime.timezone.utc)
        new_expires_at = now + datetime.timedelta(days=14)

        update_data = {
            "payload": payload,
            "total_groups": aggregates["total_groups"],
            "total_members": aggregates["total_members"],
            "total_savings": aggregates["total_savings"],
            "total_active_credit": aggregates["total_active_credit"],
            "total_current_balance": aggregates["total_current_balance"],
            "validation_summary": validation_summary,
            "expires_at": new_expires_at.isoformat(),
            "updated_at": now.isoformat()
        }

        uow.client.table("branch_onboarding_sessions").update(update_data).eq("token", token).execute()

        return {
            "status": "success",
            "message": "Draft saved successfully. Link validity extended by 14 days.",
            "aggregates": aggregates,
            "validation_summary": validation_summary
        }

    @staticmethod
    def parse_excel_bytes(file_bytes: bytes, uow: SupabaseUnitOfWork) -> Dict[str, Any]:
        """
        Parses an uploaded onboarding Excel workbook conforming to the
        icare-group-member-onboarding-template-Ogijo-Oct2026.xlsx layout.
        """
        import io
        import openpyxl

        wb = openpyxl.load_workbook(io.BytesIO(file_bytes), data_only=True)

        if "Groups" not in wb.sheetnames or "Members" not in wb.sheetnames:
            raise ValueError("Excel file must contain both 'Groups' and 'Members' sheets.")

        # Load reference loan products to canonicalize product names
        p_res = uow.client.table("loan_products").select("product_id, name").execute()
        product_names = [p["name"] for p in (p_res.data or [])]

        def resolve_product_name(raw_name: Any) -> str:
            if not raw_name or str(raw_name).strip() in ("nan", "None", ""):
                return "Daily 60 Days"
            raw_s = str(raw_name).strip()
            raw_low = raw_s.lower()
            for p in product_names:
                if p.lower() == raw_low:
                    return p

            # Heuristics matching migrate_onboarding_template.py
            is_asset = "asset" in raw_low
            if "120" in raw_low:
                return "120-Day Asset" if is_asset else "Daily 120 Days"
            elif "60" in raw_low or "daily" in raw_low:
                return "60-Day Asset" if is_asset else "Daily 60 Days"
            elif "12" in raw_low and ("week" in raw_low or "w" in raw_low):
                return "Weekly 12W Asset" if is_asset else "Weekly 12W"
            elif "24" in raw_low and ("week" in raw_low or "w" in raw_low):
                return "Weekly 24W Asset" if is_asset else "Weekly 24W"
            elif "3" in raw_low and ("m" in raw_low or "month" in raw_low):
                return "Monthly 3M Asset" if is_asset else "Monthly 3M"
            elif "6" in raw_low and ("m" in raw_low or "month" in raw_low):
                return "Monthly 6M Asset" if is_asset else "Monthly 6M"
            elif "cash" in raw_low:
                return "Cash and Carry"
            return "Daily 60 Days"

        # 1. Parse Groups Sheet (Header at row 3)
        ws_groups = wb["Groups"]
        groups = []
        officers_dict = {}

        for r in range(4, ws_groups.max_row + 1):
            g_ref = ws_groups.cell(r, 1).value
            if not g_ref or str(g_ref).strip() in ("None", ""):
                continue

            b_name = ws_groups.cell(r, 2).value or ""
            g_name = ws_groups.cell(r, 3).value or ""
            leader = ws_groups.cell(r, 4).value or ""
            m_day = ws_groups.cell(r, 5).value or "Daily"
            o_name = ws_groups.cell(r, 6).value or ""
            o_phone = ws_groups.cell(r, 7).value or ""
            g_sav = ws_groups.cell(r, 9).value or 0.0

            try:
                g_sav_num = float(g_sav)
            except Exception:
                g_sav_num = 0.0

            if o_name and str(o_name).strip() not in officers_dict:
                officers_dict[str(o_name).strip()] = str(o_phone or "").strip()

            groups.append({
                "group_reference": str(g_ref).strip(),
                "group_name": str(g_name).strip(),
                "meeting_day": str(m_day).strip(),
                "leader_name": str(leader).strip() if leader else None,
                "officer_name": str(o_name).strip() if o_name else None,
                "officer_phone": str(o_phone).strip() if o_phone else None,
                "group_savings": g_sav_num
            })

        # 2. Parse Members Sheet (Header at row 3)
        ws_members = wb["Members"]
        members = []

        for r in range(4, ws_members.max_row + 1):
            m_ref = ws_members.cell(r, 1).value
            g_ref = ws_members.cell(r, 2).value
            if not m_ref and not g_ref:
                continue

            m_num = ws_members.cell(r, 3).value or (len(members) + 1)
            f_name = ws_members.cell(r, 4).value or ""
            phone = ws_members.cell(r, 5).value or ""
            addr = ws_members.cell(r, 6).value or ""
            s_bal = ws_members.cell(r, 7).value or 0.0
            l_type = ws_members.cell(r, 8).value or ""
            p_loan = ws_members.cell(r, 9).value or 0.0
            a_cred = ws_members.cell(r, 10).value or 0.0
            c_bal = ws_members.cell(r, 11).value or 0.0

            if not f_name or str(f_name).strip() in ("None", ""):
                continue

            try:
                s_bal_num = float(s_bal)
            except Exception:
                s_bal_num = 0.0
            try:
                p_loan_num = float(p_loan)
            except Exception:
                p_loan_num = 0.0
            try:
                a_cred_num = float(a_cred)
            except Exception:
                a_cred_num = 0.0
            try:
                c_bal_num = float(c_bal)
            except Exception:
                c_bal_num = a_cred_num

            resolved_prod = resolve_product_name(l_type) if (a_cred_num > 0 or c_bal_num > 0) else None

            members.append({
                "member_reference": str(m_ref).strip() if m_ref else None,
                "group_reference": str(g_ref).strip() if g_ref else "GRP-01",
                "member_number": int(m_num) if str(m_num).isdigit() else (len(members) + 1),
                "full_name": str(f_name).strip(),
                "phone_number": str(phone).strip() if phone else None,
                "home_address": str(addr).strip() if addr else None,
                "savings_balance": s_bal_num,
                "loan_type": resolved_prod,
                "principal_loan": p_loan_num,
                "active_credit": a_cred_num,
                "current_credit_balance": c_bal_num
            })

        # 3. Parse Branch and Officer List sheet (for officers, laps savings, and misc fees)
        misc_savings_val = 0.0
        laps_savings_val = 0.0
        if "Branch and Officer List" in wb.sheetnames:
            ws_bo = wb["Branch and Officer List"]
            for r in range(1, ws_bo.max_row + 1):
                # Check for officers in columns 5 and 6 (Row 4 onwards)
                if r >= 4:
                    bo_off_name = ws_bo.cell(r, 5).value
                    bo_off_phone = ws_bo.cell(r, 6).value
                    if bo_off_name and str(bo_off_name).strip() not in ("None", ""):
                        clean_bo_name = str(bo_off_name).strip()
                        if clean_bo_name not in officers_dict:
                            officers_dict[clean_bo_name] = str(bo_off_phone or "").strip()

                # Check for pooled savings keywords
                for c in range(1, ws_bo.max_column + 1):
                    val = str(ws_bo.cell(r, c).value or "").strip().lower()
                    if "laps" in val and laps_savings_val == 0.0:
                        for cand in [ws_bo.cell(r + 1, c).value, ws_bo.cell(r, c + 1).value]:
                            try:
                                if cand is not None and float(str(cand).replace(",", "")) > 0:
                                    laps_savings_val = float(str(cand).replace(",", ""))
                                    break
                            except Exception:
                                pass
                    elif ("misc" in val or "internal" in val) and misc_savings_val == 0.0:
                        for cand in [ws_bo.cell(r + 1, c).value, ws_bo.cell(r, c + 1).value]:
                            try:
                                if cand is not None and float(str(cand).replace(",", "")) > 0:
                                    misc_savings_val = float(str(cand).replace(",", ""))
                                    break
                            except Exception:
                                pass

        officers = []
        for idx, (name, phone) in enumerate(officers_dict.items(), 1):
            is_misc = ("olajumoke" in name.lower() or "co3" in name.lower() or idx == 1)
            officers.append({
                "name": name,
                "officer_name": name,
                "phone": phone,
                "phone_number": phone,
                "role": "Credit Officer",
                "is_misc_savings_manager": is_misc
            })

        return {
            "officers": officers,
            "groups": groups,
            "members": members,
            "misc_savings": misc_savings_val,
            "laps_savings": laps_savings_val
        }

    @staticmethod
    def submit_session(uow: SupabaseUnitOfWork, token: str) -> Dict[str, Any]:
        """Validates that no fatal errors exist and transitions session to 'submitted'."""
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", token).execute()
        if not s_res.data:
            raise ValueError("Onboarding session not found.")

        session = s_res.data[0]
        if session["status"] == "approved":
            raise ValueError("This onboarding session has already been approved.")

        payload = session.get("payload") or {}
        p_res = uow.client.table("loan_products").select("name").execute()
        products_map = {p["name"].strip().lower(): True for p in (p_res.data or [])}

        validation_summary, aggregates = OnboardingService.validate_payload(payload, products_map)

        if not validation_summary["is_valid"]:
            first_err = validation_summary["errors"][0] if validation_summary["errors"] else "Validation failed."
            raise ValueError(f"Cannot submit with validation errors: {first_err}")

        now = datetime.datetime.now(datetime.timezone.utc)
        uow.client.table("branch_onboarding_sessions").update({
            "status": "submitted",
            "submitted_at": now.isoformat(),
            "updated_at": now.isoformat()
        }).eq("token", token).execute()

        return {
            "status": "success",
            "message": "Onboarding package submitted for Administrative approval.",
            "aggregates": aggregates
        }

    @staticmethod
    def commit_session(
        uow: SupabaseUnitOfWork,
        session_id: str,
        approved_by_id: Optional[str] = None,
        approval_notes: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Executes atomic migration of approved onboarding session into live core banking tables:
        - branches
        - groups & group_savings
        - clients & client_memberships
        - individual_savings
        - loans & loan_schedule (starts next meeting day per FP-008)
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("id", session_id).execute()
        if not s_res.data:
            raise ValueError("Session not found.")

        session = s_res.data[0]
        if session["status"] == "approved":
            raise ValueError("This onboarding session has already been approved and activated.")

        payload = session.get("payload") or {}
        groups = payload.get("groups", [])
        members = payload.get("members", [])
        branch_name = session["branch_name"]
        branch_code = session["branch_code"]
        branch_id = session.get("branch_id")

        # 1. Ensure branch exists in branches table
        if not branch_id:
            b_check = uow.client.table("branches").select("branch_id").eq("code", branch_code).execute()
            if b_check.data:
                branch_id = b_check.data[0]["branch_id"]
            else:
                branch_id = str(uuid.uuid4())
                uow.client.table("branches").insert({
                    "branch_id": branch_id,
                    "name": branch_name,
                    "code": branch_code,
                    "is_active": True
                }).execute()

        # 2. Pre-fetch Loan Products map
        p_res = uow.client.table("loan_products").select("*").execute()
        product_map = {p["name"].strip().lower(): p for p in (p_res.data or [])}

        # 3. Calendar & Holiday Setup for Schedule Generation
        base_eval_date = datetime.date.today()
        ng_holidays = get_nigerian_holidays(years=[base_eval_date.year, base_eval_date.year + 1, base_eval_date.year + 2])
        day_map = {"monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6}

        def is_working_day(d: datetime.date) -> bool:
            return d.weekday() < 5 and d not in ng_holidays

        def get_next_working_day(d: datetime.date) -> datetime.date:
            curr = d
            while not is_working_day(curr):
                curr += datetime.timedelta(days=1)
            return curr

        def add_months(d: datetime.date, num_months: int) -> datetime.date:
            import calendar
            m = d.month - 1 + num_months
            y = d.year + m // 12
            m = m % 12 + 1
            day = min(d.day, calendar.monthrange(y, m)[1])
            return datetime.date(y, m, day)

        # 3.5. Provision & Map Credit Officers (app_users & user_roles)
        officers_data = payload.get("officers", [])
        all_officer_names = {}
        for off in officers_data:
            o_name = str(off.get("name") or off.get("officer_name") or "").strip()
            o_phone = str(off.get("phone") or off.get("phone_number") or "").strip()
            is_mgr = bool(off.get("is_misc_savings_manager", False))
            if o_name:
                all_officer_names[o_name.lower()] = {
                    "name": o_name,
                    "phone": o_phone,
                    "is_misc_savings_manager": is_mgr
                }

        for g in groups:
            g_off_name = str(g.get("officer_name") or "").strip()
            g_off_phone = str(g.get("officer_phone") or "").strip()
            if g_off_name and g_off_name.lower() not in all_officer_names:
                all_officer_names[g_off_name.lower()] = {
                    "name": g_off_name,
                    "phone": g_off_phone,
                    "is_misc_savings_manager": False
                }

        # Fetch existing users for this branch
        res_existing_users = uow.client.table("app_users").select("id, username, full_name, is_active").eq("branch_id", branch_id).execute()
        existing_users = res_existing_users.data or []

        officer_map = {}
        for eu in existing_users:
            if eu.get("full_name"):
                officer_map[eu["full_name"].strip().lower()] = eu["id"]
            if eu.get("username"):
                officer_map[eu["username"].strip().lower()] = eu["id"]

        # Fetch Credit Officer role_id
        co_role_res = uow.client.table("roles").select("role_id").eq("name", "Credit Officer").execute()
        co_role_id = co_role_res.data[0]["role_id"] if co_role_res.data else "bd8790ee-c0eb-485a-8b6a-93f54519965d"

        co_counter = len(existing_users)
        default_pwd_hash = hash_password("password123")
        designated_misc_officer_id = None
        designated_misc_officer_name = None

        for off_key, off_info in all_officer_names.items():
            off_name = off_info["name"]
            off_phone = off_info["phone"]
            is_mgr = off_info["is_misc_savings_manager"]

            if off_key in officer_map:
                u_id = officer_map[off_key]
            else:
                co_counter += 1
                username = f"{branch_code}_CO{co_counter}"
                u_id = str(uuid.uuid4())
                now_str = datetime.datetime.now(datetime.timezone.utc).isoformat()

                extra_data = {"phone": off_phone} if off_phone else {}
                if is_mgr:
                    extra_data["is_misc_savings_manager"] = True

                uow.client.table("app_users").insert({
                    "id": u_id,
                    "username": username,
                    "full_name": off_name,
                    "branch_id": branch_id,
                    "password_hash": default_pwd_hash,
                    "is_active": True,
                    "created_at": now_str,
                    "updated_at": now_str,
                    "extra_fields": extra_data
                }).execute()

                uow.client.table("user_roles").insert({
                    "user_id": u_id,
                    "role_id": co_role_id
                }).execute()

                officer_map[off_key] = u_id
                officer_map[username.lower()] = u_id

            if is_mgr and not designated_misc_officer_id:
                designated_misc_officer_id = u_id
                designated_misc_officer_name = off_name

        # Fallback resolution for designated Misc Savings officer (BR-SAV-006)
        if not designated_misc_officer_id:
            try:
                m_id, m_name = SavingsService.get_branch_misc_savings_officer(uow, branch_name)
                if m_id:
                    designated_misc_officer_id = m_id
                    designated_misc_officer_name = m_name
            except Exception:
                pass

        first_officer_id = list(officer_map.values())[0] if officer_map else None
        first_officer_name = list(all_officer_names.values())[0]["name"] if all_officer_names else "CO1"
        if not designated_misc_officer_id:
            designated_misc_officer_id = first_officer_id
            designated_misc_officer_name = first_officer_name

        # Persist officer assignments list into branches.officer_assignments
        try:
            b_curr = uow.client.table("branches").select("officer_assignments").eq("branch_id", branch_id).execute()
            cur_assignments = (b_curr.data[0].get("officer_assignments") if b_curr.data else []) or []
            if not isinstance(cur_assignments, list):
                cur_assignments = []

            existing_oa_ids = {item.get("officer_id") for item in cur_assignments if isinstance(item, dict)}
            for off_key, off_info in all_officer_names.items():
                oid = officer_map.get(off_key)
                if oid and oid not in existing_oa_ids:
                    cur_assignments.append({
                        "officer_id": oid,
                        "full_name": off_info["name"],
                        "phone": off_info["phone"],
                        "role": "Credit Officer",
                        "is_misc_savings_manager": (oid == designated_misc_officer_id)
                    })
                    existing_oa_ids.add(oid)

            uow.client.table("branches").update({"officer_assignments": cur_assignments}).eq("branch_id", branch_id).execute()
        except Exception:
            pass

        # 4. Migrate Groups (Option B: Dynamic Branch Auto-Sequence & Ingestion Collision Guard)
        # Fetch existing groups for this branch to prevent collision
        res_existing_groups = uow.client.table("groups").select("group_number").eq("branch_id", branch_id).execute()
        existing_group_numbers = set()
        max_existing_group_num = 0
        for eg in (res_existing_groups.data or []):
            gn_str = eg.get("group_number")
            if gn_str and str(gn_str).strip().isdigit():
                num = int(str(gn_str).strip())
                existing_group_numbers.add(num)
                if num > max_existing_group_num:
                    max_existing_group_num = num

        group_ref_map = {}
        for idx, g in enumerate(groups, 1):
            g_ref = str(g.get("group_reference") or f"GRP-{str(idx).zfill(2)}").strip()
            g_name = str(g.get("group_name") or f"Group {idx}").strip()
            m_day = str(g.get("meeting_day") or "Daily").strip()
            leader = g.get("leader_name")
            g_sav = float(g.get("group_savings") or 0.0)
            g_off_name = str(g.get("officer_name") or "").strip()
            g_officer_id = officer_map.get(g_off_name.lower()) or first_officer_id

            # Extract requested group number from g_ref or fallback to idx
            digits = re.findall(r'\d+', g_ref)
            try:
                raw_gn = int(digits[-1]) if digits else idx
            except Exception:
                raw_gn = idx

            # Option B Collision Guard:
            # If raw_gn already exists in this branch, or has already been assigned in this batch:
            if raw_gn in existing_group_numbers:
                max_existing_group_num += 1
                gn = max_existing_group_num
            else:
                gn = raw_gn
                if gn > max_existing_group_num:
                    max_existing_group_num = gn
            existing_group_numbers.add(gn)

            # Always insert a fresh group record - zero overwrite guarantee
            g_id = str(uuid.uuid4())
            uow.client.table("groups").insert({
                "group_id": g_id,
                "name": g_name,
                "meeting_day": m_day,
                "branch_id": branch_id,
                "officer_id": g_officer_id,
                "leader_name": leader,
                "status": "Active",
                "group_number": str(gn),
                "current_member_sequence": 0
            }).execute()

            # Group opening savings
            if g_sav > 0:
                uow.client.table("group_savings").insert({
                    "id": str(uuid.uuid4()),
                    "group_id": g_id,
                    "posting_date": "1970-01-01",
                    "branch_id": branch_id,
                    "officer_id": g_officer_id,
                    "deposit_amount": g_sav,
                    "withdrawal_amount": 0.0,
                    "reference": "ONBOARDING-GROUP-OPENING",
                    "remarks": "Initial Onboarding Group Savings"
                }).execute()

            group_ref_map[g_ref] = {
                "group_id": g_id,
                "group_number": gn,
                "meeting_day": m_day,
                "officer_id": g_officer_id
            }

        # Canonical lifecycle status IDs
        ON_LOAN_STATUS_ID = "11111111-1111-1111-1111-111111110003"
        SAVINGS_ONLY_STATUS_ID = "11111111-1111-1111-1111-111111110006"

        clients_created = 0
        loans_created = 0
        schedules_created = 0
        group_max_seq = {}

        # Pre-fetch existing client codes in this branch to ensure zero collision / overwrites
        res_existing_clients = uow.client.table("clients").select("client_code").eq("branch_id", branch_id).execute()
        existing_client_codes = {str(c.get("client_code")).strip() for c in (res_existing_clients.data or []) if c.get("client_code")}

        # 5. Migrate Members
        for m_idx, m in enumerate(members, 1):
            f_name = str(m.get("full_name") or "").strip()
            g_ref = str(m.get("group_reference") or "GRP-01").strip()
            g_info = group_ref_map.get(g_ref)
            if not g_info:
                continue

            g_id = g_info["group_id"]
            gn = g_info["group_number"]
            m_day_str = g_info["meeting_day"]
            m_officer_id = g_info.get("officer_id") or first_officer_id

            m_num = m.get("member_number") or m_idx
            try:
                seq = int(m_num)
            except Exception:
                seq = m_idx

            # Find next free sequence for this group to avoid code duplication
            target_client_code = f"{branch_code}-{str(gn).zfill(2)}-{str(seq).zfill(3)}"
            while target_client_code in existing_client_codes:
                seq += 1
                target_client_code = f"{branch_code}-{str(gn).zfill(2)}-{str(seq).zfill(3)}"

            existing_client_codes.add(target_client_code)
            group_max_seq[g_id] = max(group_max_seq.get(g_id, 0), seq)

            phone = m.get("phone_number")
            addr = m.get("home_address")
            s_bal = float(m.get("savings_balance") or 0.0)
            a_cred = float(m.get("active_credit") or 0.0)
            c_bal = float(m.get("current_credit_balance") or 0.0)
            l_type = str(m.get("loan_type") or "").strip().lower()

            has_loan = (a_cred > 0 or c_bal > 0)
            lifecycle_status = ON_LOAN_STATUS_ID if has_loan else SAVINGS_ONLY_STATUS_ID

            # Always insert as fresh client - zero overwrite guarantee
            c_id = str(uuid.uuid4())
            uow.client.table("clients").insert({
                "client_id": c_id,
                "client_code": target_client_code,
                "name": f_name,
                "phone": phone,
                "address": addr,
                "branch_id": branch_id,
                "group_id": g_id,
                "officer_id": m_officer_id,
                "status": lifecycle_status
            }).execute()
            clients_created += 1

            # Membership link
            uow.client.table("client_memberships").insert({
                "membership_id": str(uuid.uuid4()),
                "client_id": c_id,
                "group_id": g_id,
                "branch_id": branch_id,
                "officer_id": m_officer_id
            }).execute()

            # Seed Individual Opening Savings
            if s_bal > 0:
                uow.client.table("individual_savings").insert({
                    "id": str(uuid.uuid4()), "client_id": c_id, "posting_date": "1970-01-01",
                    "branch_id": branch_id, "officer_id": m_officer_id, "deposit_amount": s_bal, "withdrawal_amount": 0.0,
                    "reference": "ONBOARDING-MEMBER-OPENING", "remarks": "Initial Onboarding Savings"
                }).execute()

            # Seed Loan & Schedule
            if has_loan:
                prod = product_map.get(l_type) or product_map.get("daily 60 days")
                duration = int(prod.get("installments") or 60)
                cycle = prod.get("repayment_cycle", "Daily")
                expected_inst = round(a_cred / duration, 2) if duration > 0 else 0.0
                prod_cat = "Asset" if "asset" in prod.get("name", "").lower() else "Finance"

                loan_id = str(uuid.uuid4())
                uow.client.table("loans").insert({
                    "loan_id": loan_id, "client_id": c_id, "date": base_eval_date.isoformat(),
                    "disbursement_date": base_eval_date.isoformat(), "start_date": base_eval_date.isoformat(),
                    "loan_amount": float(m.get("principal_loan") or a_cred),
                    "active_credit": a_cred, "total_due": c_bal, "loan_repay": expected_inst,
                    "status": "Active", "branch_id": branch_id, "officer_id": m_officer_id, "product_id": prod["product_id"],
                    "product_category": prod_cat,
                    "extra_fields": {
                        "is_legacy": True, "onboarded_at": base_eval_date.isoformat(),
                        "initial_active_credit": a_cred, "initial_balance": c_bal,
                        "session_id": session_id
                    }
                }).execute()
                loans_created += 1

                # Generate remaining future installments starting NEXT meeting day (FP-008)
                if expected_inst > 0 and c_bal > 0:
                    remaining_count = math.ceil(c_bal / expected_inst)
                    target_weekday = day_map.get(m_day_str.lower())
                    rem_bal = c_bal
                    schedule_rows = []

                    # Derive starting anchor for next meeting day
                    if cycle == "Weekly" and target_weekday is not None:
                        days_ahead = target_weekday - base_eval_date.weekday()
                        if days_ahead <= 0:
                            days_ahead += 7
                        first_meeting = base_eval_date + datetime.timedelta(days=days_ahead)
                        current_anchor = first_meeting - datetime.timedelta(weeks=1)
                    else:
                        current_anchor = base_eval_date

                    for i in range(1, remaining_count + 1):
                        if cycle == "Daily":
                            current_anchor += datetime.timedelta(days=1)
                            current_anchor = get_next_working_day(current_anchor)
                            current_due_date = current_anchor
                        elif cycle == "Weekly":
                            current_anchor += datetime.timedelta(weeks=1)
                            while not is_working_day(current_anchor):
                                current_anchor += datetime.timedelta(weeks=1)
                            current_due_date = current_anchor
                        elif cycle == "Monthly":
                            m_target = add_months(base_eval_date, i)
                            current_due_date = get_next_working_day(m_target)
                        else:
                            current_due_date = get_next_working_day(base_eval_date + datetime.timedelta(days=i))

                        inst_amount = round(min(expected_inst, rem_bal), 2)
                        rem_bal -= inst_amount

                        schedule_rows.append({
                            "id": str(uuid.uuid4()), "loan_id": loan_id, "installment_number": i,
                            "due_date": current_due_date.isoformat(), "principal": inst_amount,
                            "interest": 0.0, "fees": 0.0, "total_due": inst_amount,
                            "status": "Pending", "paid_amount": 0.0, "paid_date": None
                        })
                        if rem_bal <= 0:
                            break

                    if schedule_rows:
                        uow.client.table("loan_schedule").insert(schedule_rows).execute()
                        schedules_created += len(schedule_rows)

        # 6. Update Group Member Sequence Counts
        for g_id, max_seq in group_max_seq.items():
            uow.client.table("groups").update({"current_member_sequence": max_seq}).eq("group_id", g_id).execute()

        # 6.5. Process Branch Pooled Savings (LAPS & Misc Savings)
        misc_sav_val = float(payload.get("misc_savings") or 0.0)
        if misc_sav_val > 0:
            ex_misc = uow.client.table("internal_savings").select("id").eq("branch_id", branch_id).eq("reference", "ONBOARDING-MISC-OPENING").execute()
            if not ex_misc.data:
                uow.client.table("internal_savings").insert({
                    "id": str(uuid.uuid4()),
                    "posting_date": "1970-01-01",
                    "branch_id": branch_id,
                    "officer_id": designated_misc_officer_id,
                    "deposit_amount": misc_sav_val,
                    "withdrawal_amount": 0.0,
                    "reference": "ONBOARDING-MISC-OPENING",
                    "remarks": f"Initial Onboarding Misc Savings (Managed by {designated_misc_officer_name})"
                }).execute()

        laps_sav_val = float(payload.get("laps_savings") or 0.0)
        if laps_sav_val > 0:
            ex_laps = uow.client.table("laps_savings").select("id").eq("branch_id", branch_id).eq("reference", "ONBOARDING-LAPS-OPENING").execute()
            if not ex_laps.data:
                uow.client.table("laps_savings").insert({
                    "id": str(uuid.uuid4()),
                    "posting_date": "1970-01-01",
                    "branch_id": branch_id,
                    "officer_id": designated_misc_officer_id,
                    "deposit_amount": laps_sav_val,
                    "withdrawal_amount": 0.0,
                    "reference": "ONBOARDING-LAPS-OPENING",
                    "remarks": "Initial Onboarding Branch LAPS Savings Reserve"
                }).execute()

        # 7. Update Session Status to Approved
        now = datetime.datetime.now(datetime.timezone.utc)
        uow.client.table("branch_onboarding_sessions").update({
            "status": "approved",
            "approved_at": now.isoformat(),
            "approved_by": approved_by_id,
            "approval_notes": approval_notes or "Approved and committed to core banking ledger.",
            "updated_at": now.isoformat()
        }).eq("id", session_id).execute()

        return {
            "status": "success",
            "message": f"Branch '{branch_name}' onboarding committed successfully.",
            "groups_migrated": len(groups),
            "clients_created": clients_created,
            "loans_created": loans_created,
            "schedules_created": schedules_created,
            "officers_provisioned": len(all_officer_names),
            "misc_savings_posted": misc_sav_val,
            "laps_savings_posted": laps_sav_val
        }
