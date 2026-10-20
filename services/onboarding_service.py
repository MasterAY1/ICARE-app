import uuid
import math
import secrets
import datetime
import re
import time
from typing import Dict, Any, List, Optional, Tuple
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.loan_product_engine import LoanProductEngine
from services.business_date_service import get_nigerian_holidays
from services.savings_service import SavingsService
from auth.password import hash_password

_LOAN_PRODUCTS_CACHE: Dict[str, Any] = {"data": None, "timestamp": 0.0}
_LOAN_PRODUCTS_CACHE_TTL = 900.0  # 15 minutes TTL

def get_cached_loan_products(uow: SupabaseUnitOfWork) -> List[Dict[str, Any]]:
    """Fetches loan products with 15-minute in-memory caching to eliminate redundant remote DB round-trips."""
    now = time.time()
    if _LOAN_PRODUCTS_CACHE["data"] is not None and (now - _LOAN_PRODUCTS_CACHE["timestamp"] < _LOAN_PRODUCTS_CACHE_TTL):
        return _LOAN_PRODUCTS_CACHE["data"]
    try:
        p_res = uow.client.table("loan_products").select("product_id, name, repayment_cycle, installments, interest_rate").order("name").execute()
        data = p_res.data or []
        _LOAN_PRODUCTS_CACHE["data"] = data
        _LOAN_PRODUCTS_CACHE["timestamp"] = now
        return data
    except Exception:
        if _LOAN_PRODUCTS_CACHE["data"] is not None:
            return _LOAN_PRODUCTS_CACHE["data"]
        raise

def get_cached_loan_products_map(uow: SupabaseUnitOfWork) -> Dict[str, bool]:
    """Returns a lowercased name -> True mapping of active loan products from cache."""
    prods = get_cached_loan_products(uow)
    return {str(p.get("name") or "").strip().lower(): True for p in prods if p.get("name")}

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
    def get_session_by_token(uow: SupabaseUnitOfWork, token: str, officer: Optional[str] = None) -> Dict[str, Any]:
        """
        Retrieves an onboarding session by token.
        Checks expiration and attaches reference catalogs (loan products, meeting days).
        If officer is supplied, attaches scoped_officer indicator to session metadata.
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

        # Fetch reference loan products from cache
        products = get_cached_loan_products(uow)

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

        clean_officer = officer.strip() if officer and officer.strip() else None
        session["scoped_officer"] = clean_officer

        # Standard meeting days
        meeting_days = ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Monthly"]

        return {
            "session": session,
            "loan_products": products,
            "meeting_days": meeting_days,
            "scoped_officer": clean_officer
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

        # Validate Groups (Scoped per Credit Officer)
        group_refs = set()
        officer_group_refs = set()
        for idx, g in enumerate(groups, 1):
            g_ref = str(g.get("group_reference") or "").strip().upper()
            g_name = str(g.get("group_name") or "").strip()
            m_day = str(g.get("meeting_day") or "").strip()
            off_name = str(g.get("officer_name") or "").strip().lower()

            if not g_ref:
                errors.append(f"Group row #{idx}: Group Reference is required.")
            elif (off_name, g_ref) in officer_group_refs:
                errors.append(f"Group row #{idx}: Duplicate Group Reference '{g_ref}' for officer '{g.get('officer_name') or 'Default'}'.")
            else:
                officer_group_refs.add((off_name, g_ref))
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
            g_ref = str(m.get("group_reference") or "").strip().upper()
            m_off_name = str(m.get("officer_name") or "").strip().lower()
            phone = str(m.get("phone_number") or "").strip()
            s_bal = float(m.get("savings_balance") or 0.0)
            a_cred = float(m.get("active_credit") or 0.0)
            c_bal = float(m.get("current_credit_balance") or 0.0)
            l_type = str(m.get("loan_type") or "").strip()

            if not m_name:
                errors.append(f"Member row #{idx}: Full Name is required.")
            if not g_ref:
                errors.append(f"Member row #{idx} ({m_name}): Group Reference is required.")
            elif (m_off_name, g_ref) not in officer_group_refs and g_ref not in group_refs:
                errors.append(f"Member row #{idx} ({m_name}): References non-existent group '{g_ref}'.")

            # Check duplicate names within same officer's group
            group_key = (m_off_name, g_ref, m_name.lower())
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

        total_member_savings = total_savings
        total_group_savings = sum(float(g.get("group_savings") or 0.0) for g in groups)
        misc_savings = float(payload.get("misc_savings") or 0.0)
        laps_savings = float(payload.get("laps_savings") or 0.0)
        total_combined_savings = total_member_savings + total_group_savings + misc_savings

        aggregates = {
            "total_groups": len(groups),
            "total_members": len(members),
            "total_officers": len(officers),
            "total_savings": round(total_combined_savings, 2),
            "total_member_savings": round(total_member_savings, 2),
            "total_group_savings": round(total_group_savings, 2),
            "misc_savings": round(misc_savings, 2),
            "laps_savings": round(laps_savings, 2),
            "total_active_credit": round(total_active_credit, 2),
            "total_current_balance": round(total_current_balance, 2)
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
    def save_draft(uow: SupabaseUnitOfWork, token: str, payload: Dict[str, Any], scoped_officer: Optional[str] = None) -> Dict[str, Any]:
        """
        Saves updated groups, members, and officers draft payload.
        If scoped_officer is specified, merges that officer's groups and members
        with the existing branch payload without clobbering other officers' data.
        Auto-extends link expiration by 14 days and returns updated validation summary.
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", token).execute()
        if not s_res.data:
            raise ValueError("Onboarding session not found.")

        session = s_res.data[0]
        if session["status"] == "approved":
            raise ValueError("This onboarding session has already been approved and committed.")

        final_payload = payload
        if scoped_officer and str(scoped_officer).strip():
            target_officer = str(scoped_officer).strip()
            target_low = target_officer.lower()
            existing_payload = session.get("payload") or {}

            # Keep other officers' groups
            other_groups = [
                g for g in existing_payload.get("groups", [])
                if (g.get("officer_name") or "").strip().lower() != target_low
            ]
            other_group_refs = {(g.get("group_reference") or "").strip().upper() for g in other_groups if (g.get("group_reference") or "").strip()}
            other_group_names = {(g.get("name") or g.get("group_name") or "").strip().lower() for g in other_groups if (g.get("name") or g.get("group_name") or "").strip()}

            # Keep other officers' members
            other_members = [
                m for m in existing_payload.get("members", [])
                if ((m.get("group_reference") or "").strip().upper() in other_group_refs)
                or ((m.get("group_name") or "").strip().lower() in other_group_names)
            ]

            # Current officer's incoming groups (ensure tagged with this officer)
            incoming_groups = payload.get("groups", [])
            for g in incoming_groups:
                g["officer_name"] = target_officer

            incoming_members = payload.get("members", [])

            # Merge officers list
            existing_officers = existing_payload.get("officers", [])
            incoming_officers = payload.get("officers", [])
            officers_by_name = {
                (o.get("name") or o.get("officer_name") or "").strip().lower(): o
                for o in existing_officers
            }
            for o in incoming_officers:
                k = (o.get("name") or o.get("officer_name") or "").strip().lower()
                if k:
                    officers_by_name[k] = o
            if target_low not in officers_by_name:
                officers_by_name[target_low] = {
                    "name": target_officer,
                    "phone": "",
                    "role": "Credit Officer",
                    "is_misc_savings_manager": False
                }

            # Preserve pooled branch reserves if not explicitly submitted by officer
            misc_s = payload.get("misc_savings")
            if misc_s is None or float(misc_s or 0.0) == 0.0:
                misc_s = existing_payload.get("misc_savings", 0.0)
            laps_s = payload.get("laps_savings")
            if laps_s is None or float(laps_s or 0.0) == 0.0:
                laps_s = existing_payload.get("laps_savings", 0.0)

            final_payload = {
                "groups": other_groups + incoming_groups,
                "members": other_members + incoming_members,
                "officers": list(officers_by_name.values()),
                "misc_savings": float(misc_s or 0.0),
                "laps_savings": float(laps_s or 0.0),
            }

        # Auto-provision dedicated officer tokens for any officers missing them
        for off in final_payload.get("officers", []):
            if not off.get("token") and not off.get("co_token"):
                co_tok = f"onb_co_{secrets.token_hex(12)}"
                off["token"] = co_tok
                off["co_token"] = co_tok
            if not off.get("id") and not off.get("officer_id"):
                new_id = str(uuid.uuid4())
                off["id"] = new_id
                off["officer_id"] = new_id

        # Pre-load loan products from cache for fast in-memory validation
        products_map = get_cached_loan_products_map(uow)

        validation_summary, aggregates = OnboardingService.validate_payload(final_payload, products_map)

        now = datetime.datetime.now(datetime.timezone.utc)
        new_expires_at = now + datetime.timedelta(days=14)

        update_data = {
            "payload": final_payload,
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
            "payload": final_payload,
            "aggregates": aggregates,
            "validation_summary": validation_summary
        }

    @staticmethod
    def provision_officer(uow: SupabaseUnitOfWork, token: str, officer_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Branch Manager provisions a Credit Officer and generates a dedicated,
        cryptographically isolated token (onb_co_...) for that officer.
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", token).execute()
        if not s_res.data:
            raise ValueError("Branch onboarding session not found.")

        session = s_res.data[0]
        if session["status"] == "approved":
            raise ValueError("This onboarding session has already been approved.")

        payload = session.get("payload") or {}
        officers = payload.get("officers", [])

        name = str(officer_data.get("name") or "").strip()
        if not name:
            raise ValueError("Credit Officer full name is required.")

        phone = str(officer_data.get("phone") or officer_data.get("phone_number") or "").strip()
        is_misc = bool(officer_data.get("is_misc_savings_manager", False))

        # Check duplicate officer name
        for off in officers:
            existing_name = (off.get("name") or off.get("officer_name") or "").strip().lower()
            if existing_name == name.lower():
                raise ValueError(f"Credit Officer '{name}' already exists in this branch session.")

        officer_id = str(uuid.uuid4())
        co_token = f"onb_co_{secrets.token_hex(12)}"
        now = datetime.datetime.now(datetime.timezone.utc)

        new_off = {
            "id": officer_id,
            "officer_id": officer_id,
            "name": name,
            "officer_name": name,
            "phone": phone,
            "phone_number": phone,
            "role": "Credit Officer",
            "is_misc_savings_manager": is_misc,
            "token": co_token,
            "co_token": co_token,
            "status": "drafting",
            "created_at": now.isoformat()
        }

        officers.append(new_off)
        payload["officers"] = officers

        # Re-validate with new officer
        products_map = get_cached_loan_products_map(uow)
        validation_summary, aggregates = OnboardingService.validate_payload(payload, products_map)

        uow.client.table("branch_onboarding_sessions").update({
            "payload": payload,
            "validation_summary": validation_summary,
            "updated_at": now.isoformat()
        }).eq("id", session["id"]).execute()

        return new_off

    @staticmethod
    def find_session_by_co_token(uow: SupabaseUnitOfWork, co_token: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        """Locates the parent session and target officer by CO token."""
        clean_token = str(co_token or "").strip()
        if not clean_token:
            raise ValueError("Credit Officer token is required.")

        res = uow.client.table("branch_onboarding_sessions").select("*").neq("status", "deleted").execute()
        for session in (res.data or []):
            payload = session.get("payload") or {}
            officers = payload.get("officers", [])
            for off in officers:
                if off.get("token") == clean_token or off.get("co_token") == clean_token:
                    return session, off

        raise ValueError("Invalid Credit Officer link or officer token not found.")

    @staticmethod
    def get_officer_workspace(uow: SupabaseUnitOfWork, co_token: str) -> Dict[str, Any]:
        """
        Retrieves the isolated workspace for a Credit Officer.
        Guarantees 100% data isolation: zero visibility into other officers,
        other officers' solidarity groups, member rosters, or branch-wide reserves.
        """
        session, target_officer = OnboardingService.find_session_by_co_token(uow, co_token)

        # Check expiration
        exp_str = session.get("expires_at")
        if exp_str:
            try:
                exp_dt = datetime.datetime.fromisoformat(exp_str.replace("Z", "+00:00"))
                now = datetime.datetime.now(datetime.timezone.utc)
                if now > exp_dt:
                    raise ValueError("This onboarding link has expired. Please contact your Branch Manager.")
            except (ValueError, TypeError) as e:
                if "expired" in str(e).lower():
                    raise e

        payload = session.get("payload") or {}
        all_groups = payload.get("groups", [])
        all_members = payload.get("members", [])
        off_name_clean = (target_officer.get("name") or "").strip().lower()

        # Extract only this officer's groups
        my_groups = [
            g for g in all_groups
            if (g.get("officer_name") or "").strip().lower() == off_name_clean
            or g.get("officer_token") == co_token
        ]
        my_group_refs = {str(g.get("group_reference") or "").strip().upper() for g in my_groups if (g.get("group_reference") or "").strip()}

        # Extract only this officer's members
        my_members = [
            m for m in all_members
            if (m.get("officer_name") or "").strip().lower() == off_name_clean
            or m.get("officer_token") == co_token
            or str(m.get("group_reference") or "").strip().upper() in my_group_refs
        ]

        # Calculate officer specific portfolio aggregates
        indiv_savings = sum(float(m.get("savings_balance") or 0.0) for m in my_members)
        grp_savings = sum(float(g.get("group_savings") or 0.0) for g in my_groups)
        tot_savings = indiv_savings + grp_savings
        active_credit = sum(float(m.get("active_credit") or 0.0) for m in my_members)
        curr_balance = sum(float(m.get("current_credit_balance") or 0.0) for m in my_members)

        aggregates = {
            "portfolio_groups": len(my_groups),
            "portfolio_members": len(my_members),
            "individual_member_savings": round(indiv_savings, 2),
            "group_savings_pool": round(grp_savings, 2),
            "total_portfolio_savings": round(tot_savings, 2),
            "active_credit": round(active_credit, 2),
            "outstanding_balance": round(curr_balance, 2)
        }

        # Loan products from cache and standard meeting days
        products = get_cached_loan_products(uow)
        meeting_days = ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Monthly"]

        is_submitted = (target_officer.get("status") == "submitted")
        is_session_locked = session.get("status") in ("submitted", "bm_submitted", "approved")

        return {
            "officer": {
                "id": target_officer.get("id"),
                "name": target_officer.get("name"),
                "phone": target_officer.get("phone"),
                "role": target_officer.get("role", "Credit Officer"),
                "status": target_officer.get("status", "drafting"),
                "is_misc_savings_manager": bool(target_officer.get("is_misc_savings_manager", False)),
                "submitted_at": target_officer.get("submitted_at")
            },
            "branch_name": session.get("branch_name"),
            "branch_code": session.get("branch_code"),
            "session_status": session.get("status"),
            "expires_at": session.get("expires_at"),
            "groups": my_groups,
            "members": my_members,
            "aggregates": aggregates,
            "loan_products": products,
            "meeting_days": meeting_days,
            "is_locked": is_submitted or is_session_locked
        }

    @staticmethod
    def save_officer_draft(uow: SupabaseUnitOfWork, co_token: str, officer_payload: Dict[str, Any]) -> Dict[str, Any]:
        """
        Saves updated groups and members belonging exclusively to this Credit Officer.
        Guarantees other officers' data remains completely untouched.
        Optimized to compute aggregates and return workspace in-memory without duplicate DB round-trips.
        """
        session, target_officer = OnboardingService.find_session_by_co_token(uow, co_token)

        if target_officer.get("status") == "submitted":
            raise ValueError("Your roster is currently submitted and locked. Contact your Branch Manager to unlock it for edits.")

        if session.get("status") in ("submitted", "bm_submitted", "approved"):
            raise ValueError("The branch onboarding session is currently submitted or approved.")

        payload = session.get("payload") or {}
        existing_groups = payload.get("groups", [])
        existing_members = payload.get("members", [])
        off_name = target_officer.get("name")
        off_name_clean = off_name.strip().lower()

        # Incoming groups for this officer
        incoming_groups = officer_payload.get("groups", [])
        for g in incoming_groups:
            g["officer_name"] = off_name
            g["officer_token"] = co_token

        # Incoming members for this officer
        incoming_members = officer_payload.get("members", [])
        for m in incoming_members:
            m["officer_name"] = off_name
            m["officer_token"] = co_token

        # Keep other officers' groups
        other_groups = [
            g for g in existing_groups
            if (g.get("officer_name") or "").strip().lower() != off_name_clean
            and g.get("officer_token") != co_token
        ]
        # Keep other officers' members
        other_members = [
            m for m in existing_members
            if (m.get("officer_name") or "").strip().lower() != off_name_clean
            and m.get("officer_token") != co_token
        ]

        final_payload = {
            "groups": other_groups + incoming_groups,
            "members": other_members + incoming_members,
            "officers": payload.get("officers", []),
            "misc_savings": float(payload.get("misc_savings") or 0.0),
            "laps_savings": float(payload.get("laps_savings") or 0.0)
        }

        # Fast in-memory validation using cached loan products
        products_map = get_cached_loan_products_map(uow)
        validation_summary, branch_aggregates = OnboardingService.validate_payload(final_payload, products_map)

        now = datetime.datetime.now(datetime.timezone.utc)
        uow.client.table("branch_onboarding_sessions").update({
            "payload": final_payload,
            "total_groups": branch_aggregates["total_groups"],
            "total_members": branch_aggregates["total_members"],
            "total_savings": branch_aggregates["total_savings"],
            "total_active_credit": branch_aggregates["total_active_credit"],
            "total_current_balance": branch_aggregates["total_current_balance"],
            "validation_summary": validation_summary,
            "updated_at": now.isoformat()
        }).eq("id", session["id"]).execute()

        # Calculate officer-specific aggregates in-memory to eliminate 3 redundant remote queries
        indiv_savings = sum(float(m.get("savings_balance") or 0.0) for m in incoming_members)
        grp_savings = sum(float(g.get("group_savings") or 0.0) for g in incoming_groups)
        tot_savings = indiv_savings + grp_savings
        active_credit = sum(float(m.get("active_credit") or 0.0) for m in incoming_members)
        curr_balance = sum(float(m.get("current_credit_balance") or 0.0) for m in incoming_members)

        officer_aggregates = {
            "portfolio_groups": len(incoming_groups),
            "portfolio_members": len(incoming_members),
            "individual_member_savings": round(indiv_savings, 2),
            "group_savings_pool": round(grp_savings, 2),
            "total_portfolio_savings": round(tot_savings, 2),
            "active_credit": round(active_credit, 2),
            "outstanding_balance": round(curr_balance, 2)
        }

        cached_products = get_cached_loan_products(uow)
        meeting_days = ["Daily", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Monthly"]
        is_submitted = (target_officer.get("status") == "submitted")
        is_session_locked = session.get("status") in ("submitted", "bm_submitted", "approved")

        return {
            "status": "success",
            "message": "Draft saved successfully.",
            "officer": {
                "id": target_officer.get("id"),
                "name": target_officer.get("name"),
                "phone": target_officer.get("phone"),
                "role": target_officer.get("role", "Credit Officer"),
                "status": target_officer.get("status", "drafting"),
                "is_misc_savings_manager": bool(target_officer.get("is_misc_savings_manager", False)),
                "submitted_at": target_officer.get("submitted_at")
            },
            "branch_name": session.get("branch_name"),
            "branch_code": session.get("branch_code"),
            "session_status": session.get("status"),
            "expires_at": session.get("expires_at"),
            "groups": incoming_groups,
            "members": incoming_members,
            "aggregates": officer_aggregates,
            "loan_products": cached_products,
            "meeting_days": meeting_days,
            "is_locked": is_submitted or is_session_locked
        }

    @staticmethod
    def submit_officer_roster(uow: SupabaseUnitOfWork, co_token: str) -> Dict[str, Any]:
        """
        Credit Officer submits their completed groups and members to the Branch Manager.
        Locks the officer workspace from further edits until Branch Manager unlocks.
        """
        session, target_officer = OnboardingService.find_session_by_co_token(uow, co_token)

        if target_officer.get("status") == "submitted":
            return {"status": "success", "message": "Roster already submitted."}

        payload = session.get("payload") or {}
        officers = payload.get("officers", [])
        now = datetime.datetime.now(datetime.timezone.utc)

        for off in officers:
            if off.get("token") == co_token or off.get("co_token") == co_token:
                off["status"] = "submitted"
                off["submitted_at"] = now.isoformat()
                break

        payload["officers"] = officers
        uow.client.table("branch_onboarding_sessions").update({
            "payload": payload,
            "updated_at": now.isoformat()
        }).eq("id", session["id"]).execute()

        return {
            "status": "success",
            "message": "Your roster has been successfully submitted to your Branch Manager."
        }

    @staticmethod
    def unlock_officer_roster(uow: SupabaseUnitOfWork, branch_token: str, officer_id: str) -> Dict[str, Any]:
        """
        Branch Manager supervisor action to unlock a submitted officer's roster for corrections.
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", branch_token).execute()
        if not s_res.data:
            raise ValueError("Branch session not found.")

        session = s_res.data[0]
        if session["status"] == "approved":
            raise ValueError("This branch session has already been approved.")

        payload = session.get("payload") or {}
        officers = payload.get("officers", [])
        target_off = None
        for off in officers:
            if str(off.get("id")) == str(officer_id) or str(off.get("officer_id")) == str(officer_id):
                target_off = off
                off["status"] = "drafting"
                off.pop("submitted_at", None)
                break

        if not target_off:
            raise ValueError(f"Credit Officer with ID '{officer_id}' not found.")

        payload["officers"] = officers
        now = datetime.datetime.now(datetime.timezone.utc)
        update_data = {
            "payload": payload,
            "updated_at": now.isoformat()
        }
        # If session was submitted to AM, revert session status to draft
        if session["status"] in ("bm_submitted", "submitted"):
            update_data["status"] = "draft"

        uow.client.table("branch_onboarding_sessions").update(update_data).eq("id", session["id"]).execute()

        return {
            "status": "success",
            "message": f"Credit Officer '{target_off.get('name')}' roster unlocked for corrections.",
            "officer": target_off
        }

    @staticmethod
    def bm_submit_session(uow: SupabaseUnitOfWork, branch_token: str) -> Dict[str, Any]:
        """
        Branch Manager confirms total combined officer balances and submits package to Area Manager.
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", branch_token).execute()
        if not s_res.data:
            raise ValueError("Branch session not found.")

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
        }).eq("id", session["id"]).execute()

        return {
            "status": "success",
            "message": "Branch package submitted to Area Manager for final approval.",
            "aggregates": aggregates
        }

    @staticmethod
    def am_approve_session(uow: SupabaseUnitOfWork, branch_token: str, approved_by_id: Optional[str] = None, approval_notes: Optional[str] = None) -> Dict[str, Any]:
        """
        Area Manager reviews the BM-confirmed branch package and commits it to the live core banking database.
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("*").eq("token", branch_token).execute()
        if not s_res.data:
            raise ValueError("Branch session not found.")

        session = s_res.data[0]
        return OnboardingService.commit_session(
            uow=uow,
            session_id=session["id"],
            approved_by_id=approved_by_id,
            approval_notes=approval_notes or "Approved and committed by Area Manager."
        )

    @staticmethod
    def parse_excel_bytes(file_bytes: bytes, uow: SupabaseUnitOfWork, scoped_officer: Optional[str] = None) -> Dict[str, Any]:
        """
        Parses an uploaded onboarding Excel workbook conforming to the
        icare-group-member-onboarding-template-Ogijo-Oct2026.xlsx layout.
        If scoped_officer is supplied, tags groups without an explicit officer to scoped_officer.
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
        clean_scoped = scoped_officer.strip() if scoped_officer and str(scoped_officer).strip() else None

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

            if clean_scoped and (not o_name or str(o_name).strip() in ("None", "")):
                o_name = clean_scoped

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

        # 4. Migrate Groups (Contiguous Officer-Block Global Group Sequencer)
        # Groups are sequentially distributed by Credit Officer in contiguous blocks:
        # e.g., CO1 groups (GRP-01 to GRP-06) -> Group 1 to 6
        # CO2 groups (GRP-01 to GRP-09) -> Group 7 to 15
        ordered_groups_with_officer = []
        assigned_group_ids = set()

        # Iterate through officers in the BM-established order
        session_officers = payload.get("officers", [])
        for off in session_officers:
            off_name_clean = (off.get("name") or off.get("officer_name") or "").strip().lower()
            off_token = off.get("token") or off.get("co_token")
            # Collect all groups assigned to this officer
            off_groups = [
                g for g in groups
                if ((g.get("officer_name") or "").strip().lower() == off_name_clean and off_name_clean != "")
                or (off_token and g.get("officer_token") == off_token)
            ]
            # Sort this officer's groups by their local reference or numeric value
            def _group_sort_key(item):
                ref_str = str(item.get("group_reference") or "")
                digits = re.findall(r'\d+', ref_str)
                return int(digits[-1]) if digits else 999999
            off_groups.sort(key=_group_sort_key)
            for g in off_groups:
                g_key = id(g)
                if g_key not in assigned_group_ids:
                    assigned_group_ids.add(g_key)
                    ordered_groups_with_officer.append((off, g))

        # Append any groups not claimed by a specific officer
        for g in groups:
            if id(g) not in assigned_group_ids:
                assigned_group_ids.add(id(g))
                ordered_groups_with_officer.append((None, g))

        next_gn = max_existing_group_num + 1
        group_ref_map = {}
        for off, g in ordered_groups_with_officer:
            g_ref = str(g.get("group_reference") or f"GRP-{str(next_gn).zfill(2)}").strip()
            g_name = str(g.get("group_name") or f"Group {next_gn}").strip()
            m_day = str(g.get("meeting_day") or "Daily").strip()
            leader = g.get("leader_name")
            g_sav = float(g.get("group_savings") or 0.0)
            g_off_name = str(g.get("officer_name") or (off.get("name") if off else "")).strip()
            g_officer_id = officer_map.get(g_off_name.lower()) or first_officer_id

            gn = next_gn
            next_gn += 1

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

            g_entry = {
                "group_id": g_id,
                "group_number": gn,
                "meeting_day": m_day,
                "officer_id": g_officer_id
            }
            # Key composite (officer_name, g_ref) to prevent namespace collision across officers
            if g_off_name:
                group_ref_map[(g_off_name.lower(), g_ref.upper())] = g_entry
            if g_ref.upper() not in group_ref_map:
                group_ref_map[g_ref.upper()] = g_entry
            if g_ref not in group_ref_map:
                group_ref_map[g_ref] = g_entry

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
            g_ref = str(m.get("group_reference") or "GRP-01").strip().upper()
            m_off_name = str(m.get("officer_name") or "").strip().lower()

            # Lookup group by composite (officer_name, g_ref) or fallback g_ref
            g_info = group_ref_map.get((m_off_name, g_ref)) or group_ref_map.get(g_ref)
            if not g_info:
                continue

            g_id = g_info["group_id"]
            gn = g_info["group_number"]
            m_day_str = g_info["meeting_day"]
            m_officer_id = g_info.get("officer_id") or first_officer_id

            m_num = m.get("member_number")
            if m_num is not None and str(m_num).strip().isdigit():
                seq = int(str(m_num).strip())
            else:
                seq = group_max_seq.get(g_id, 0) + 1

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

    @staticmethod
    def delete_session(
        uow: SupabaseUnitOfWork,
        session_id: str,
        deleted_by_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Safely deletes an uncommitted onboarding session (draft, submitted, or bm_submitted).
        Approved sessions are permanently protected from deletion under core banking immutability rules.
        """
        s_res = uow.client.table("branch_onboarding_sessions").select("id, branch_name, branch_code, status").eq("id", session_id).execute()
        if not s_res.data:
            raise ValueError("Onboarding session not found.")

        session = s_res.data[0]
        if session.get("status") == "approved":
            raise ValueError("Approved onboarding sessions cannot be deleted because core banking records and ledgers have already been committed.")

        branch_name = session.get("branch_name", "Branch")
        branch_code = session.get("branch_code", "")

        uow.client.table("branch_onboarding_sessions").delete().eq("id", session_id).execute()

        return {
            "status": "success",
            "message": f"Onboarding session for '{branch_name}' ({branch_code}) deleted successfully.",
            "session_id": session_id,
            "branch_name": branch_name,
            "branch_code": branch_code
        }
