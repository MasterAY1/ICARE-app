import uuid
from datetime import datetime, date
from typing import Optional, Any, List, Dict
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.savings import IndividualSavings, GroupSavings, MiscSavings, LapsSavings
from domain.entities.repayment import Repayment
from domain.entities.event_store import DomainEvent
from domain.enums import TransactionClassification
from services.withdrawal_classification_engine import WithdrawalClassificationEngine
from services.posting_engine import FinancialPostingEngine

class SavingsService:
    _MANAGER_ROLES = {"BM", "Branch Manager", "AM", "Area Manager", "Admin", "Super Admin", "Director", "Executive"}

    @staticmethod
    def _is_valid_non_zero_uuid(val: Any) -> bool:
        if not val or not isinstance(val, str):
            return False
        try:
            u = uuid.UUID(str(val).strip())
            return u.int != 0
        except (ValueError, TypeError, AttributeError):
            return False

    @staticmethod
    def _resolve_actor_audit_info(
        uow: SupabaseUnitOfWork,
        actor_username: Optional[str],
        role_fallback: str = "Credit Officer",
        branch_fallback: Optional[str] = None,
    ) -> tuple[Optional[str], str, str, Optional[str]]:
        """
        Resolves (user_id_or_None, username, role, branch) for audit attribution.
        Never returns the zero UUID so FK checks on audit_logs / user_audit_logs stay valid.
        """
        uname = str(actor_username or "").strip() or "System"
        role = role_fallback or "Credit Officer"
        user_id: Optional[str] = None
        try:
            res = uow.client.table("app_users").select("id, username, role").eq("username", uname).limit(1).execute()
            rows = getattr(res, "data", None)
            if isinstance(rows, list) and len(rows) > 0 and isinstance(rows[0], dict):
                row = rows[0]
                raw_id = row.get("id")
                if SavingsService._is_valid_non_zero_uuid(raw_id):
                    user_id = str(raw_id)
                if row.get("username"):
                    uname = str(row["username"])
                if row.get("role"):
                    role = str(row["role"])
        except Exception:
            pass
        if not user_id:
            try:
                from database.repositories.audit_repository import resolve_officer_id
                cand = resolve_officer_id(uow.client, uname)
                if SavingsService._is_valid_non_zero_uuid(cand):
                    user_id = str(cand)
            except Exception:
                pass
        return user_id, uname, role, branch_fallback

    @staticmethod
    def _build_user_audit_op(
        user_id: Optional[str],
        username: str,
        role: str,
        branch: Optional[str],
        action: str,
        module: str,
        entity_type: str,
        entity_id: Optional[str],
        display_name: Optional[str],
        previous_value: Optional[dict],
        new_value: Optional[dict],
        audit_status: str = "SUCCESS",
    ) -> dict:
        safe_uid = str(user_id) if SavingsService._is_valid_non_zero_uuid(user_id) else None
        safe_eid = str(entity_id) if SavingsService._is_valid_non_zero_uuid(entity_id) else None
        return {
            "type": "insert",
            "table": "user_audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": safe_uid,
                "username": str(username or "System"),
                "role": str(role or "Credit Officer"),
                "branch": str(branch) if branch is not None else None,
                "action": str(action),
                "module": str(module),
                "entity_type": entity_type,
                "entity_id": safe_eid,
                "display_name": str(display_name) if display_name is not None else None,
                "previous_value": previous_value,
                "new_value": new_value,
                "status": audit_status,
                "timestamp": datetime.now().isoformat(),
            },
        }

    @staticmethod
    def _build_savings_db_record(
        uow: SupabaseUnitOfWork,
        repo_attr: str,
        entity: Any,
        table_name: str,
    ) -> dict:
        repo = getattr(uow, repo_attr, None)
        db_rec = None
        if repo is not None and hasattr(repo, "_to_database"):
            try:
                candidate = repo._to_database(entity)
                if isinstance(candidate, dict):
                    db_rec = dict(candidate)
            except Exception:
                db_rec = None

        p_dt = getattr(entity, "date", None) or datetime.now()
        p_date_str = p_dt.date().isoformat() if isinstance(p_dt, datetime) else (p_dt.isoformat() if isinstance(p_dt, date) else str(p_dt)[:10])

        if not db_rec:
            branch_id = repo._resolve_branch_id(entity.branch) if repo and hasattr(repo, "_resolve_branch_id") else None
            if not SavingsService._is_valid_non_zero_uuid(branch_id):
                branch_id = str(entity.branch) if SavingsService._is_valid_non_zero_uuid(entity.branch) else None
            officer_id = repo._resolve_officer_id(entity.officer) if repo and hasattr(repo, "_resolve_officer_id") else None
            if not SavingsService._is_valid_non_zero_uuid(officer_id):
                officer_id = str(entity.officer) if SavingsService._is_valid_non_zero_uuid(entity.officer) else None

            db_rec = {
                "id": getattr(entity, "id", None) or str(uuid.uuid4()),
                "branch_id": branch_id,
                "officer_id": officer_id,
                "deposit_amount": float(getattr(entity, "deposit_amount", 0.0) or 0.0),
                "withdrawal_amount": float(getattr(entity, "withdrawal_amount", 0.0) or 0.0),
                "posting_date": p_date_str,
                "reference": getattr(entity, "reference", None),
                "remarks": getattr(entity, "remarks", None),
            }
            if table_name == "group_savings":
                gid = getattr(entity, "group_id", None)
                if not SavingsService._is_valid_non_zero_uuid(gid) and repo and hasattr(repo, "_resolve_group_id"):
                    gid = repo._resolve_group_id(getattr(entity, "group_name", None))
                db_rec["group_id"] = str(gid) if SavingsService._is_valid_non_zero_uuid(gid) else gid
            else:
                raw_cid = getattr(entity, "client_id", None)
                db_rec["client_id"] = str(raw_cid) if SavingsService._is_valid_non_zero_uuid(raw_cid) else None

        if not db_rec.get("id"):
            db_rec["id"] = getattr(entity, "id", None) or str(uuid.uuid4())
        if "posting_date" not in db_rec and "date" not in db_rec:
            db_rec["posting_date"] = p_date_str
        if getattr(entity, "idempotency_key", None):
            db_rec["idempotency_key"] = entity.idempotency_key
        if table_name == "internal_savings" and not SavingsService._is_valid_non_zero_uuid(db_rec.get("client_id")):
            db_rec["client_id"] = None
        if table_name == "group_savings" and getattr(entity, "group_id", None) and SavingsService._is_valid_non_zero_uuid(entity.group_id):
            db_rec["group_id"] = entity.group_id
        return db_rec

    @staticmethod
    def _resolve_assigned_co_username(
        uow: SupabaseUnitOfWork,
        officer: str,
        client_id: Optional[str] = None,
        group_id: Optional[str] = None,
        group_name: Optional[str] = None,
    ) -> str:
        """
        Ensures BM/AM-initiated or approved member/group savings transactions attribute
        to the client/group's assigned Credit Officer when available.
        """
        if not officer:
            return officer
        try:
            u_res = uow.client.table("app_users").select("id, role").eq("username", officer).limit(1).execute()
            rows = getattr(u_res, "data", None)
            role = (rows[0].get("role") if isinstance(rows, list) and rows and isinstance(rows[0], dict) else None) or ""
            if role not in SavingsService._MANAGER_ROLES:
                return officer

            co_id = None
            if client_id and SavingsService._is_valid_non_zero_uuid(client_id):
                c_res = uow.client.table("clients").select("officer_id").eq("client_id", client_id).limit(1).execute()
                if isinstance(c_res.data, list) and c_res.data and isinstance(c_res.data[0], dict) and c_res.data[0].get("officer_id"):
                    co_id = c_res.data[0]["officer_id"]
            if not co_id and group_id and SavingsService._is_valid_non_zero_uuid(group_id):
                g_res = uow.client.table("groups").select("officer_id").eq("group_id", group_id).limit(1).execute()
                if isinstance(g_res.data, list) and g_res.data and isinstance(g_res.data[0], dict) and g_res.data[0].get("officer_id"):
                    co_id = g_res.data[0]["officer_id"]
            if not co_id and group_name:
                g_res = uow.client.table("groups").select("officer_id").eq("name", group_name).limit(1).execute()
                if isinstance(g_res.data, list) and g_res.data and isinstance(g_res.data[0], dict) and g_res.data[0].get("officer_id"):
                    co_id = g_res.data[0]["officer_id"]
            if co_id:
                co_res = uow.client.table("app_users").select("username").eq("id", co_id).limit(1).execute()
                if isinstance(co_res.data, list) and co_res.data and isinstance(co_res.data[0], dict) and co_res.data[0].get("username"):
                    return str(co_res.data[0]["username"])
        except Exception:
            pass
        return officer

    @staticmethod
    def _safe_rebuild_co_projection(uow: SupabaseUnitOfWork, branch: str, check_date: date, officer_id: Optional[str]) -> None:
        try:
            if not hasattr(uow, "cashbook") or not branch or not SavingsService._is_valid_non_zero_uuid(officer_id):
                return
            b_id = uow.cashbook._resolve_branch_id(branch)
            if SavingsService._is_valid_non_zero_uuid(b_id):
                uow.cashbook.rebuild_projection(b_id, check_date, officer_id=officer_id)
        except Exception as ex_rb:
            print(f"[SAVINGS TRACE] Cashbook projection rebuild warning: {ex_rb}")

    @staticmethod
    def post_individual_savings(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        branch: str,
        officer: str,
        deposit_amount: float,
        withdrawal_amount: float = 0.0,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        savings_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        cash_paid: bool = False,
        payout_method: str = "Bank Transfer",
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        defer_operations: Optional[List[dict]] = None,
        allow_closed_date: bool = False,
        skip_ledger_posting: bool = False,
    ):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        p_dt = posting_date if posting_date else datetime.now()
        # Check Business Date Freeze & Working Day (BR-DATE-002)
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        if not allow_closed_date:
            is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
            if not is_open:
                raise ValueError(f"Operational Restriction: Cannot post savings. {reason}.")

        # Option A: Direct savings withdrawals always pay via Bank Transfer (1050) unless non-cash UPF auto-deduction
        effective_cash_paid = False
        effective_payout = "AUTOMATIC_DEDUCTION" if skip_ledger_posting else "Bank Transfer"

        # Check Account Cancellation Invariant (Zero balance on Member Savings withdrawal)
        is_account_cancellation = False
        if withdrawal_amount > 0 and client_id:
            try:
                curr_bal = uow.individual_savings.get_total_balance(client_id=client_id)
                if curr_bal > 0 and withdrawal_amount >= (curr_bal - 0.01):
                    is_account_cancellation = True
                    if remarks and "[ACCOUNT CANCELLATION]" not in remarks:
                        remarks = f"[ACCOUNT CANCELLATION] {remarks}"
                    elif not remarks:
                        remarks = "[ACCOUNT CANCELLATION] Full balance withdrawal (Account Cancellation)"
            except Exception:
                pass

        effective_officer = SavingsService._resolve_assigned_co_username(uow, officer, client_id=client_id)

        entity = IndividualSavings(
            id=savings_id or str(uuid.uuid4()),
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=effective_officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=p_dt,
            idempotency_key=idempotency_key
        )
        db_rec = SavingsService._build_savings_db_record(uow, "individual_savings", entity, "individual_savings")

        operations = [{
            "type": "insert",
            "table": "individual_savings",
            "record": db_rec
        }]

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        officer_uid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(officer_uid):
            officer_uid = None
        rec_uuid = entity.id if SavingsService._is_valid_non_zero_uuid(entity.id) else None
        action = "Individual Savings Deposit" if deposit_amount > 0 else ("Account Cancellation" if is_account_cancellation else "Individual Savings Withdrawal")
        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": actor_uid or officer_uid,
                "action": action,
                "description": (
                    f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                    f"Client: {client_name}. Old: None. New: {{'deposit': {deposit_amount}, 'withdrawal': {withdrawal_amount}, 'payout_method': '{effective_payout}'}}"
                ),
                "table_name": "individual_savings",
                "record_id": rec_uuid
            }
        })
        operations.append(SavingsService._build_user_audit_op(
            user_id=actor_uid or officer_uid,
            username=actor_uname,
            role=resolved_role,
            branch=branch,
            action=action.upper().replace(" ", "_"),
            module="savings",
            entity_type="IndividualSavings",
            entity_id=rec_uuid,
            display_name=client_name,
            previous_value=None,
            new_value={
                "deposit_amount": deposit_amount,
                "withdrawal_amount": withdrawal_amount,
                "payout_method": effective_payout,
                "cash_paid": effective_cash_paid,
                "reference": reference,
                "officer": effective_officer,
            },
        ))

        event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
        amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
        ev_payload = {
            "branch": branch,
            "officer": effective_officer,
            "client_id": client_id,
            "amount": amt,
            "reference": reference or entity.id,
            "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt),
            "narration": remarks or f"Individual savings transaction for client {client_name}",
        }
        if withdrawal_amount > 0:
            ev_payload["cash_paid"] = effective_cash_paid
            ev_payload["payout_method"] = effective_payout

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=entity.id,
            aggregate_type="IndividualSavings",
            event_type=event_type,
            payload=ev_payload
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed"
            }
        })

        if not skip_ledger_posting:
            tx_id, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
            operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        if defer_operations is not None:
            defer_operations.extend(operations)
            return entity

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, officer_uid)
        return entity

    @staticmethod
    def post_group_savings(
        uow: SupabaseUnitOfWork,
        group_name: str,
        branch: str,
        officer: str,
        deposit_amount: float,
        withdrawal_amount: float = 0.0,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        group_id: Optional[str] = None,
        group_savings_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        cash_paid: bool = False,
        payout_method: str = "Bank Transfer",
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        defer_operations: Optional[List[dict]] = None,
        allow_closed_date: bool = False,
    ):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return
            
        p_dt = posting_date if posting_date else datetime.now()
        # Check Business Date Freeze & Working Day (BR-DATE-002)
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        if not allow_closed_date:
            is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
            if not is_open:
                raise ValueError(f"Operational Restriction: Cannot post group savings. {reason}.")

        effective_cash_paid = False
        effective_payout = "Bank Transfer"

        resolved_gid = group_id
        if not SavingsService._is_valid_non_zero_uuid(resolved_gid) and hasattr(uow, "group_savings") and hasattr(uow.group_savings, "_resolve_group_id"):
            try:
                cand_gid = uow.group_savings._resolve_group_id(group_name)
                if SavingsService._is_valid_non_zero_uuid(cand_gid):
                    resolved_gid = cand_gid
            except Exception:
                pass

        effective_officer = SavingsService._resolve_assigned_co_username(
            uow, officer, group_id=resolved_gid, group_name=group_name
        )

        entity = GroupSavings(
            id=group_savings_id or str(uuid.uuid4()),
            group_name=group_name,
            branch=branch,
            officer=effective_officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=p_dt,
            group_id=resolved_gid,
            idempotency_key=idempotency_key
        )
        db_rec = SavingsService._build_savings_db_record(uow, "group_savings", entity, "group_savings")

        operations = [{
            "type": "insert",
            "table": "group_savings",
            "record": db_rec
        }]

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        officer_uid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(officer_uid):
            officer_uid = None
        rec_uuid = entity.id if SavingsService._is_valid_non_zero_uuid(entity.id) else None
        action = "Group Savings Deposit" if deposit_amount > 0 else "Group Savings Withdrawal"
        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": actor_uid or officer_uid,
                "action": action,
                "description": (
                    f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                    f"Group: {group_name}. Old: None. New: {{'deposit': {deposit_amount}, 'withdrawal': {withdrawal_amount}, 'payout_method': '{effective_payout}'}}"
                ),
                "table_name": "group_savings",
                "record_id": rec_uuid
            }
        })
        operations.append(SavingsService._build_user_audit_op(
            user_id=actor_uid or officer_uid,
            username=actor_uname,
            role=resolved_role,
            branch=branch,
            action=action.upper().replace(" ", "_"),
            module="savings",
            entity_type="GroupSavings",
            entity_id=rec_uuid,
            display_name=group_name,
            previous_value=None,
            new_value={
                "deposit_amount": deposit_amount,
                "withdrawal_amount": withdrawal_amount,
                "payout_method": effective_payout,
                "cash_paid": effective_cash_paid,
                "reference": reference,
                "group_id": resolved_gid,
                "officer": effective_officer,
            },
        ))

        event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
        amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
        final_gid = getattr(entity, 'group_id', None) or resolved_gid
        ev_payload = {
            "branch": branch,
            "officer": effective_officer,
            "amount": amt,
            "reference": reference or entity.id,
            "date": p_dt.isoformat() if hasattr(p_dt, 'isoformat') else str(p_dt),
            "narration": remarks or f"Group savings transaction for group {group_name}",
            "group_id": final_gid
        }
        if withdrawal_amount > 0:
            ev_payload["cash_paid"] = effective_cash_paid
            ev_payload["payout_method"] = effective_payout

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=entity.id,
            aggregate_type="GroupSavings",
            event_type=event_type,
            payload=ev_payload
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed"
            }
        })

        tx_id, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        if defer_operations is not None:
            defer_operations.extend(operations)
            return entity

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, officer_uid)
        return entity

    @staticmethod
    def get_branch_misc_savings_officer(uow: SupabaseUnitOfWork, branch: str) -> tuple[str, str]:
        """
        BR-SAV-006: Resolves the designated managing officer for Misc Savings per branch.
        Returns tuple: (officer_id, officer_name/username)
        """
        # Resolve designated Misc Savings officer dynamically (FP-001: zero hardcoded branch/officer fallbacks)
        branch_val = (branch or "").strip()
        if not branch_val:
            return ("", "")

        # Look up from branch officer_assignments or app_users
        try:
            if SavingsService._is_valid_non_zero_uuid(branch_val):
                b_res = uow.client.table("branches").select("*").eq("branch_id", branch_val).execute()
            else:
                b_res = uow.client.table("branches").select("*").ilike("name", f"%{branch_val}%").execute()
            if b_res.data:
                b_info = b_res.data[0]
                o_assign = b_info.get("officer_assignments") or []
                if isinstance(o_assign, list):
                    for oa in o_assign:
                        if isinstance(oa, dict) and oa.get("is_misc_savings_manager"):
                            return (str(oa.get("officer_id") or ""), str(oa.get("full_name") or oa.get("username") or ""))

                # Look up active users for this branch
                u_res = uow.client.table("app_users").select("id, username, full_name, is_active, extra_fields").eq("branch_id", b_info["branch_id"]).execute()
                active_users = [
                    u for u in (u_res.data or [])
                    if isinstance(u, dict) and u.get("is_active", True) is not False
                ]
                for u in active_users:
                    u_ext = u.get("extra_fields") or {}
                    if isinstance(u_ext, dict) and u_ext.get("is_misc_savings_manager"):
                        return (str(u["id"]), str(u.get("full_name") or u["username"]))

                # Secondary fallback: first active Credit Officer in this branch via role or username
                role_by_uid = {}
                try:
                    u_ids = [str(u["id"]) for u in active_users if u.get("id")]
                    if u_ids:
                        ur_res = uow.client.table("user_roles").select("user_id, roles(name)").in_("user_id", u_ids).execute()
                        for ur in (ur_res.data or []):
                            r_obj = ur.get("roles") or {}
                            if isinstance(r_obj, dict) and r_obj.get("name"):
                                role_by_uid[str(ur.get("user_id") or "")] = str(r_obj["name"]).strip().lower()
                except Exception:
                    pass
                for u in active_users:
                    uid_s = str(u.get("id") or "")
                    r_name = role_by_uid.get(uid_s, "")
                    if r_name in ("credit officer", "co", "officer") or (not role_by_uid and "co" in str(u.get("username", "")).lower()):
                        return (uid_s, str(u.get("full_name") or u["username"]))
        except Exception:
            pass
        return ("", "")

    @staticmethod
    def post_misc_savings(
        uow: SupabaseUnitOfWork,
        client_id: Optional[str],
        client_name: str,
        branch: str,
        officer: str,
        deposit_amount: float,
        withdrawal_amount: float = 0.0,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        misc_savings_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        cash_paid: bool = False,
        payout_method: str = "Bank Transfer",
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        defer_operations: Optional[List[dict]] = None,
        allow_closed_date: bool = False,
    ):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        if not allow_closed_date:
            is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
            if not is_open:
                raise ValueError(f"Operational Restriction: Cannot post misc savings. {reason}.")

        effective_cash_paid = False
        effective_payout = "Bank Transfer"

        managing_id, managing_name = SavingsService.get_branch_misc_savings_officer(uow, branch)
        collecting_officer = officer or "Unknown Officer"
        target_officer = managing_name or collecting_officer

        if deposit_amount > 0:
            base_rem = str(remarks or "").strip()
            if not base_rem or base_rem in ("Single Client Collection", "Daily Collection"):
                narr = f"Misc savings collected by {collecting_officer} (Managed by {target_officer})"
            elif collecting_officer not in base_rem:
                narr = f"{base_rem} | Collected by {collecting_officer} (Managed by {target_officer})"
            else:
                narr = base_rem
        else:
            narr = remarks or f"Misc savings withdrawal for {client_name}"
        safe_cid = str(client_id) if SavingsService._is_valid_non_zero_uuid(client_id) else None

        entity = MiscSavings(
            id=misc_savings_id or str(uuid.uuid4()),
            client_id=safe_cid,
            client_name=client_name,
            branch=branch,
            officer=target_officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=narr,
            date=p_dt,
            idempotency_key=idempotency_key,
        )
        db_rec = SavingsService._build_savings_db_record(uow, "misc_savings", entity, "internal_savings")

        operations = [{
            "type": "insert",
            "table": "internal_savings",
            "record": db_rec,
        }]

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or collecting_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        rebuild_oid = managing_id if SavingsService._is_valid_non_zero_uuid(managing_id) else resolve_officer_id(uow.client, target_officer)
        if not SavingsService._is_valid_non_zero_uuid(rebuild_oid):
            rebuild_oid = None

        rec_uuid = entity.id if SavingsService._is_valid_non_zero_uuid(entity.id) else None
        action = "Misc Savings Deposit" if deposit_amount > 0 else "Misc Savings Withdrawal"
        amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": actor_uid or rebuild_oid,
                "action": action,
                "description": (
                    f"Actor: {actor_uname} ({resolved_role}). Collector: {collecting_officer}. Manager: {target_officer}. "
                    f"Client: {client_name}. New: {{'deposit': {deposit_amount}, 'withdrawal': {withdrawal_amount}, 'payout_method': '{effective_payout}'}}"
                ),
                "table_name": "internal_savings",
                "record_id": rec_uuid,
            },
        })
        operations.append(SavingsService._build_user_audit_op(
            user_id=actor_uid or rebuild_oid,
            username=actor_uname,
            role=resolved_role,
            branch=branch,
            action=action.upper().replace(" ", "_"),
            module="savings",
            entity_type="MiscSavings",
            entity_id=rec_uuid,
            display_name=client_name,
            previous_value=None,
            new_value={
                "deposit_amount": deposit_amount,
                "withdrawal_amount": withdrawal_amount,
                "collecting_officer": collecting_officer,
                "managing_officer": target_officer,
                "payout_method": effective_payout,
                "cash_paid": effective_cash_paid,
                "reference": reference,
            },
        ))

        event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
        ev_payload = {
            "branch": branch,
            "officer": target_officer,
            "collecting_officer": collecting_officer,
            "amount": amt,
            "reference": reference or entity.id,
            "narration": narr,
            "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt),
        }
        if withdrawal_amount > 0:
            ev_payload["cash_paid"] = effective_cash_paid
            ev_payload["payout_method"] = effective_payout

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=entity.id,
            aggregate_type="MiscSavings",
            event_type=event_type,
            payload=ev_payload,
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        if defer_operations is not None:
            defer_operations.extend(operations)
            return entity

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, rebuild_oid)
        return entity

    @staticmethod
    def post_laps_savings(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        branch: str,
        officer: str,
        deposit_amount: float,
        withdrawal_amount: float = 0.0,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        laps_savings_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        cash_paid: bool = False,
        payout_method: str = "Bank Transfer",
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        defer_operations: Optional[List[dict]] = None,
    ):
        if deposit_amount == 0 and withdrawal_amount == 0:
            return

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot post LAPS savings. {reason}.")

        effective_cash_paid = False
        effective_payout = "Bank Transfer"
        effective_officer = SavingsService._resolve_assigned_co_username(uow, officer, client_id=client_id)

        entity = LapsSavings(
            id=laps_savings_id or str(uuid.uuid4()),
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=effective_officer,
            deposit_amount=deposit_amount,
            withdrawal_amount=withdrawal_amount,
            reference=reference,
            remarks=remarks,
            date=p_dt,
        )
        db_rec = SavingsService._build_savings_db_record(uow, "laps_savings", entity, "laps_savings")
        if idempotency_key:
            db_rec["idempotency_key"] = idempotency_key

        operations = [{
            "type": "insert",
            "table": "laps_savings",
            "record": db_rec,
        }]

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        rebuild_oid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(rebuild_oid):
            rebuild_oid = None
        rec_uuid = entity.id if SavingsService._is_valid_non_zero_uuid(entity.id) else None
        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": actor_uid or rebuild_oid,
                "action": "LAPS Transaction",
                "description": (
                    f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                    f"Client: {client_name}. New: {{'deposit': {deposit_amount}, 'withdrawal': {withdrawal_amount}}}"
                ),
                "table_name": "laps_savings",
                "record_id": rec_uuid,
            },
        })
        operations.append(SavingsService._build_user_audit_op(
            user_id=actor_uid or rebuild_oid,
            username=actor_uname,
            role=resolved_role,
            branch=branch,
            action="LAPS_TRANSACTION",
            module="savings",
            entity_type="LapsSavings",
            entity_id=rec_uuid,
            display_name=client_name,
            previous_value=None,
            new_value={
                "deposit_amount": deposit_amount,
                "withdrawal_amount": withdrawal_amount,
                "payout_method": effective_payout,
                "reference": reference,
            },
        ))

        event_type = "SavingsDeposited" if deposit_amount > 0 else "SavingsWithdrawn"
        amt = deposit_amount if deposit_amount > 0 else withdrawal_amount
        ev_payload = {
            "branch": branch,
            "officer": effective_officer,
            "client_id": client_id,
            "amount": amt,
            "reference": reference or entity.id,
            "narration": remarks or f"LAPS savings transaction for client {client_name}",
            "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt),
        }
        if withdrawal_amount > 0:
            ev_payload["cash_paid"] = effective_cash_paid
            ev_payload["payout_method"] = effective_payout

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=entity.id,
            aggregate_type="LapsSavings",
            event_type=event_type,
            payload=ev_payload,
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        if defer_operations is not None:
            defer_operations.extend(operations)
            return entity

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, rebuild_oid)
        return entity

    @staticmethod
    def get_branch_totals(uow: SupabaseUnitOfWork, branch: str) -> dict:
        ind = uow.individual_savings.get_total_balance(branch)
        grp = uow.group_savings.get_total_balance(branch)
        msc = uow.misc_savings.get_total_balance(branch)
        laps = uow.laps_savings.get_total_balance(branch)
        
        return {
            "individual_savings": ind,
            "group_savings": grp,
            "misc_savings": msc,
            "laps_savings": laps,
            "total_active_savings": ind + grp + msc
        }

    @staticmethod
    def get_officer_totals(uow: SupabaseUnitOfWork, branch: str, officer: str) -> dict:
        ind = uow.individual_savings.get_total_balance(branch, officer)
        grp = uow.group_savings.get_total_balance(branch, officer)
        laps = uow.laps_savings.get_total_balance(branch, officer)
        
        managing_id, managing_name = SavingsService.get_branch_misc_savings_officer(uow, branch)
        officer_clean = str(officer or "").strip().lower()
        
        # BR-SAV-002: If officer is the designated Misc Savings manager, include all branch Misc Savings
        if managing_name and (officer_clean == managing_name.lower() or officer_clean == str(managing_id).lower()):
            msc = uow.misc_savings.get_total_balance(branch)
        else:
            msc = 0.0
        
        return {
            "individual_savings": ind,
            "group_savings": grp,
            "misc_savings": msc,
            "laps_savings": laps,
            "total_active_savings": ind + grp + msc
        }

    @staticmethod
    def _build_source_savings_entity_and_op(
        uow: SupabaseUnitOfWork,
        source_savings_type: str,
        source_id: Optional[str],
        source_name: str,
        branch: str,
        officer: str,
        withdrawal_amount: float = 0.0,
        deposit_amount: float = 0.0,
        reference: Optional[str] = None,
        remarks: Optional[str] = None,
        posting_date: Optional[Any] = None,
        group_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        source_savings_id: Optional[str] = None,
    ) -> tuple[Any, str, dict]:
        entity_id = source_savings_id if SavingsService._is_valid_non_zero_uuid(source_savings_id) else str(uuid.uuid4())
        if source_savings_type == "GroupSavings":
            resolved_gid = group_id
            if not SavingsService._is_valid_non_zero_uuid(resolved_gid):
                if SavingsService._is_valid_non_zero_uuid(source_id):
                    resolved_gid = source_id
                elif hasattr(uow, "group_savings") and hasattr(uow.group_savings, "_resolve_group_id"):
                    try:
                        cand_gid = uow.group_savings._resolve_group_id(source_name)
                        if SavingsService._is_valid_non_zero_uuid(cand_gid):
                            resolved_gid = cand_gid
                    except Exception:
                        pass
            entity = GroupSavings(
                id=entity_id,
                group_name=source_name,
                branch=branch,
                officer=officer,
                deposit_amount=deposit_amount,
                withdrawal_amount=withdrawal_amount,
                reference=reference,
                remarks=remarks,
                date=posting_date,
                group_id=resolved_gid,
                idempotency_key=idempotency_key,
            )
            tbl = "group_savings"
            db_rec = SavingsService._build_savings_db_record(uow, "group_savings", entity, tbl)
        elif source_savings_type == "MiscSavings":
            safe_cid = str(source_id) if SavingsService._is_valid_non_zero_uuid(source_id) else None
            entity = MiscSavings(
                id=entity_id,
                client_id=safe_cid,
                client_name=source_name,
                branch=branch,
                officer=officer,
                deposit_amount=deposit_amount,
                withdrawal_amount=withdrawal_amount,
                reference=reference,
                remarks=remarks,
                date=posting_date,
                idempotency_key=idempotency_key,
            )
            tbl = "internal_savings"
            db_rec = SavingsService._build_savings_db_record(uow, "misc_savings", entity, tbl)
        else:
            entity = IndividualSavings(
                id=entity_id,
                client_id=source_id,
                client_name=source_name,
                branch=branch,
                officer=officer,
                deposit_amount=deposit_amount,
                withdrawal_amount=withdrawal_amount,
                reference=reference,
                remarks=remarks,
                date=posting_date,
                idempotency_key=idempotency_key,
            )
            tbl = "individual_savings"
            db_rec = SavingsService._build_savings_db_record(uow, "individual_savings", entity, tbl)

        return entity, tbl, {"type": "insert", "table": tbl, "record": db_rec}

    @staticmethod
    def _build_repayment_db_record(
        uow: SupabaseUnitOfWork,
        repayment_entity: Repayment,
        idempotency_key: Optional[str] = None,
    ) -> dict:
        db_rec = None
        if hasattr(uow, "repayments") and hasattr(uow.repayments, "_to_database"):
            try:
                cand = uow.repayments._to_database(repayment_entity)
                if isinstance(cand, dict):
                    db_rec = dict(cand)
            except Exception:
                db_rec = None

        p_dt = repayment_entity.payment_date
        p_date_str = p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt)

        if not db_rec:
            branch_id = uow.cashbook._resolve_branch_id(repayment_entity.branch) if hasattr(uow, "cashbook") else None
            if not SavingsService._is_valid_non_zero_uuid(branch_id):
                branch_id = str(repayment_entity.branch) if SavingsService._is_valid_non_zero_uuid(repayment_entity.branch) else None
            from database.repositories.audit_repository import resolve_officer_id
            officer_id = resolve_officer_id(uow.client, repayment_entity.credit_officer)
            if not SavingsService._is_valid_non_zero_uuid(officer_id):
                officer_id = None
            db_rec = {
                "id": repayment_entity.id or str(uuid.uuid4()),
                "date": p_date_str,
                "loan_id": repayment_entity.loan_id,
                "client_id": repayment_entity.client_id,
                "amount_paid": float(repayment_entity.amount_paid),
                "officer_id": officer_id,
                "branch_id": branch_id,
                "payment_status": repayment_entity.payment_status or "PAID",
                "expected_amount": float(getattr(repayment_entity, "expected_amount", 0.0) or 0.0),
                "overdue_amount": float(getattr(repayment_entity, "overdue_amount", 0.0) or 0.0),
                "note": repayment_entity.note or "",
                "transaction_type": repayment_entity.transaction_type or "LOAN_OFFSET",
            }
        if not db_rec.get("id"):
            db_rec["id"] = repayment_entity.id or str(uuid.uuid4())
        if idempotency_key:
            db_rec["idempotency_key"] = idempotency_key
        return db_rec

    @staticmethod
    def post_loan_offset_from_savings(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        loan_id: str,
        source_savings_type: str,
        branch: str,
        officer: str,
        amount: float,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        group_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        defer_operations: Optional[List[dict]] = None,
        skip_repayment: bool = False,
        source_savings_id: Optional[str] = None,
    ) -> dict:
        """
        Executes atomic loan offset using client or group savings balance:
        - Reduces savings (source_savings_type)
        - Creates loan repayment record against loan_id
        - Emits LoanOffsetFromSavings domain event (ZERO physical cash movement)
        - Commits savings, repayment, audit, event, and ledger atomically via RPC
        """
        if amount <= 0:
            raise ValueError("Offset amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot post loan offset. {reason}.")

        effective_officer = SavingsService._resolve_assigned_co_username(
            uow,
            officer,
            client_id=client_id if source_savings_type != "GroupSavings" else None,
            group_id=group_id if source_savings_type == "GroupSavings" else None,
            group_name=client_name if source_savings_type == "GroupSavings" else None,
        )

        cls_info = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LOAN_OFFSET, amount
        )

        # Check Account Cancellation Invariant on IndividualSavings loan offset
        final_remarks = remarks
        if source_savings_type not in ("GroupSavings", "MiscSavings") and client_id:
            try:
                curr_bal = uow.individual_savings.get_total_balance(client_id=client_id)
                if isinstance(curr_bal, (int, float)) and curr_bal > 0 and amount >= (curr_bal - 0.01):
                    if final_remarks and "[ACCOUNT CANCELLATION]" not in final_remarks:
                        final_remarks = f"[ACCOUNT CANCELLATION] {final_remarks}"
                    elif not final_remarks:
                        final_remarks = f"[ACCOUNT CANCELLATION] Loan offset of ₦{amount:,.2f} from IndividualSavings"
            except Exception:
                pass

        # Fetch target loan product details for projection routing & atomic payoff checks
        prod_name = ""
        cycle = "Weekly"
        duration = 0
        is_asset = False
        target_client_id = client_id
        l_row = None
        try:
            res_l = uow.client.table("loans").select("loan_id, client_id, officer_id, branch_id, product_category, product_type, repayment_cycle, duration, active_credit, total_due, loan_amount, loan_repay, status, extra_fields, loan_products(name, repayment_cycle)").eq("loan_id", loan_id).execute()
            rows_l = getattr(res_l, "data", None)
            if isinstance(rows_l, list) and rows_l and isinstance(rows_l[0], dict):
                l_row = rows_l[0]
                target_client_id = l_row.get("client_id") or client_id
                lp = l_row.get("loan_products") or {}
                is_asset = bool(l_row.get("product_category") == "Asset" or ("asset" in str(l_row.get("product_category") or "").lower()) or (l_row.get("extra_fields") or {}).get("is_asset") or ("asset" in str(lp.get("name") or l_row.get("product_type") or "").lower()))
                prod_name = str(lp.get("name") or l_row.get("product_type") or "").lower()
                cycle = lp.get("repayment_cycle") or l_row.get("repayment_cycle") or ("Daily" if "daily" in prod_name else ("Weekly" if "weekly" in prod_name else "Monthly"))
                duration = int(l_row.get("duration") or 0)
        except Exception:
            pass
        if target_client_id and effective_officer == officer:
            effective_officer = SavingsService._resolve_assigned_co_username(uow, officer, client_id=target_client_id)

        source_entity, source_tbl, source_op = SavingsService._build_source_savings_entity_and_op(
            uow=uow,
            source_savings_type=source_savings_type,
            source_id=group_id if source_savings_type == "GroupSavings" else client_id,
            source_name=client_name,
            branch=branch,
            officer=effective_officer,
            withdrawal_amount=amount,
            reference=reference,
            remarks=final_remarks or f"Loan offset withdrawal from {source_savings_type}",
            posting_date=p_dt,
            group_id=group_id,
            idempotency_key=f"{idempotency_key}-src" if idempotency_key else None,
            source_savings_id=source_savings_id,
        )

        repayment_id_out: Optional[str] = None
        repayment_entity: Optional[Repayment] = None
        operations = [source_op]
        if not skip_repayment:
            repayment_entity = Repayment(
                id=str(uuid.uuid4()),
                loan_id=loan_id,
                client_id=target_client_id,
                amount_paid=amount,
                savings_amount=0.0,
                loan_repayment_amount=amount,
                withdrawal_amount=0.0,
                others_amount=0.0,
                recovery_amount=0.0,
                initial_payment=0.0,
                payment_date=p_dt.date() if hasattr(p_dt, "date") and callable(p_dt.date) else p_dt,
                transaction_type="LOAN_OFFSET",
                branch=branch,
                credit_officer=effective_officer,
                payment_status="PAID",
                note=final_remarks or f"Loan offset of {amount} from {source_savings_type}"
            )
            repayment_id_out = repayment_entity.id
            rep_rec = SavingsService._build_repayment_db_record(
                uow,
                repayment_entity,
                idempotency_key=f"{idempotency_key}-rep" if idempotency_key else None,
            )
            operations.append({"type": "insert", "table": "repayments", "record": rep_rec})

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        rebuild_oid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(rebuild_oid):
            rebuild_oid = None

        operations.extend([
            {
                "type": "insert",
                "table": "audit_logs",
                "record": {
                    "id": str(uuid.uuid4()),
                    "user_id": actor_uid or rebuild_oid,
                    "action": "Loan Offset From Savings",
                    "description": (
                        f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                        f"Amount: {amount}. Source: {source_savings_type} ({source_entity.id}). Loan: {loan_id}."
                    ),
                    "table_name": "loans",
                    "record_id": loan_id if SavingsService._is_valid_non_zero_uuid(loan_id) else None,
                },
            },
            SavingsService._build_user_audit_op(
                user_id=actor_uid or rebuild_oid,
                username=actor_uname,
                role=resolved_role,
                branch=branch,
                action="LOAN_OFFSET_FROM_SAVINGS",
                module="savings",
                entity_type="LoanOffset",
                entity_id=loan_id if SavingsService._is_valid_non_zero_uuid(loan_id) else None,
                display_name=client_name,
                previous_value=None,
                new_value={
                    "amount": amount,
                    "source_savings_type": source_savings_type,
                    "source_savings_id": source_entity.id,
                    "repayment_id": repayment_id_out,
                    "loan_id": loan_id,
                    "reference": reference,
                },
            ),
        ])

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=source_entity.id,
            aggregate_type="LoanOffset",
            event_type="LoanOffsetFromSavings",
            payload={
                "client_id": target_client_id,
                "source_client_id": client_id,
                "loan_id": loan_id,
                "source_savings_type": source_savings_type,
                "branch": branch,
                "officer": effective_officer,
                "amount": amount,
                "loan_product": prod_name,
                "cycle": cycle,
                "duration": duration,
                "is_asset": is_asset,
                "reference": reference or source_entity.id,
                "classification": TransactionClassification.LOAN_OFFSET.value,
                "narration": final_remarks or f"Loan offset of {amount:,.2f} from {source_savings_type} for loan {loan_id}",
                "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt)
            }
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        if not skip_repayment and repayment_entity is not None:
            from services.schedule_service import ScheduleService
            from services.client_status_service import ClientStatusService
            from services.repayment_service import RepaymentService

            ScheduleService.record_repayment(
                uow, loan_id, amount, p_check_date, defer_operations=operations
            )
            ClientStatusService.on_loan_repayment_check(
                uow,
                target_client_id,
                loan_id,
                defer_operations=operations,
                preloaded_loan=l_row,
                current_repayment_amount=amount,
                current_repayment_id=repayment_entity.id,
            )
            RepaymentService._record_payoff_and_excess_if_applicable(
                uow,
                repayment_entity,
                preloaded_loan=l_row,
                defer_operations=operations,
            )

        if defer_operations is not None:
            defer_operations.extend(operations)
            return {
                "status": "DEFERRED",
                "event_id": event.event_id,
                "amount": amount,
                "source_savings_id": source_entity.id,
                "repayment_id": repayment_id_out,
                "affects_cash_vault": cls_info["affects_cash_vault"]
            }

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, rebuild_oid)

        return {
            "status": "SUCCESS",
            "event_id": event.event_id,
            "amount": amount,
            "source_savings_id": source_entity.id,
            "repayment_id": repayment_id_out,
            "affects_cash_vault": cls_info["affects_cash_vault"]
        }

    @staticmethod
    def post_fee_offset_from_savings(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        source_savings_type: str,
        branch: str,
        officer: str,
        fee_type: str,
        amount: float,
        target_client_id: Optional[str] = None,
        target_client_name: Optional[str] = None,
        reference: Optional[str] = None,
        remarks: Optional[str] = None,
        posting_date: Optional[Any] = None,
        group_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        source_savings_id: Optional[str] = None,
    ) -> dict:
        """
        Executes atomic non-cash fee payment deducted from savings:
        - Reduces client or group savings (source_savings_type)
        - Inserts into public.fees when fee_type != 'other' (matching Account 3000)
        - Emits FeeOffsetFromSavings domain event (DR 2000, CR 3000 or 1000 for 'other')
        """
        if amount <= 0:
            raise ValueError("Fee offset amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot post fee offset. {reason}.")

        effective_officer = SavingsService._resolve_assigned_co_username(
            uow,
            officer,
            client_id=target_client_id or (client_id if source_savings_type != "GroupSavings" else None),
            group_id=group_id if source_savings_type == "GroupSavings" else None,
            group_name=client_name if source_savings_type == "GroupSavings" else None,
        )

        source_entity, _, source_op = SavingsService._build_source_savings_entity_and_op(
            uow=uow,
            source_savings_type=source_savings_type,
            source_id=group_id if source_savings_type == "GroupSavings" else client_id,
            source_name=client_name,
            branch=branch,
            officer=effective_officer,
            withdrawal_amount=amount,
            reference=reference,
            remarks=remarks or f"Fee offset ({fee_type}) from {source_savings_type}",
            posting_date=p_dt,
            group_id=group_id,
            idempotency_key=f"{idempotency_key}-src" if idempotency_key else None,
            source_savings_id=source_savings_id,
        )

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        rebuild_oid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(rebuild_oid):
            rebuild_oid = None

        rec_uuid = source_entity.id if SavingsService._is_valid_non_zero_uuid(source_entity.id) else None
        fee_id = None
        operations = [source_op]

        # Record operational fee row when crediting Account 3000 (Fee Income).
        # 'other' credits Account 1000 (vault shortage offset) and is NOT Fee Income.
        if str(fee_type or "").strip().lower() != "other":
            fee_id = str(uuid.uuid4())
            b_id = uow.cashbook._resolve_branch_id(branch) if hasattr(uow, "cashbook") else None
            if not SavingsService._is_valid_non_zero_uuid(b_id):
                b_id = branch if SavingsService._is_valid_non_zero_uuid(branch) else None
            effective_gid = group_id if SavingsService._is_valid_non_zero_uuid(group_id) else (
                client_id if source_savings_type == "GroupSavings" and SavingsService._is_valid_non_zero_uuid(client_id) else None
            )
            raw_fee_cid = target_client_id or (client_id if source_savings_type != "GroupSavings" else None)
            fee_cid = raw_fee_cid if (SavingsService._is_valid_non_zero_uuid(raw_fee_cid) and str(raw_fee_cid) != str(effective_gid)) else None
            operations.append({
                "type": "insert",
                "table": "fees",
                "record": {
                    "id": fee_id,
                    "posting_date": p_check_date.isoformat() if isinstance(p_check_date, date) else str(p_check_date)[:10],
                    "client_id": fee_cid,
                    "group_id": effective_gid,
                    "branch_id": b_id,
                    "officer_id": rebuild_oid,
                    "fee_type": fee_type,
                    "amount": round(float(amount), 2),
                    "reference": reference or source_entity.id,
                    "remarks": remarks or f"Fee offset ({fee_type}) from {source_savings_type}",
                    "idempotency_key": f"{idempotency_key}-fee" if idempotency_key else None,
                },
            })

        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": actor_uid or rebuild_oid,
                "action": "Fee Offset From Savings",
                "description": (
                    f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                    f"Fee: {fee_type}. Amount: {amount}. Source: {source_savings_type} ({source_entity.id})."
                ),
                "table_name": "fees",
                "record_id": rec_uuid,
            },
        })
        operations.append(SavingsService._build_user_audit_op(
            user_id=actor_uid or rebuild_oid,
            username=actor_uname,
            role=resolved_role,
            branch=branch,
            action="FEE_OFFSET_FROM_SAVINGS",
            module="savings",
            entity_type="FeeOffset",
            entity_id=rec_uuid,
            display_name=target_client_name or client_name,
            previous_value=None,
            new_value={
                "amount": amount,
                "fee_type": fee_type,
                "source_savings_type": source_savings_type,
                "source_savings_id": source_entity.id,
                "fee_id": fee_id,
                "reference": reference,
            },
        ))

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=source_entity.id,
            aggregate_type="FeeOffset",
            event_type="FeeOffsetFromSavings",
            payload={
                "client_id": target_client_id or client_id,
                "client_name": target_client_name or client_name,
                "source_savings_type": source_savings_type,
                "fee_type": fee_type,
                "branch": branch,
                "officer": effective_officer,
                "amount": amount,
                "reference": reference or source_entity.id,
                "classification": "FeeOffset",
                "narration": remarks or f"Fee offset ({fee_type}) of {amount:,.2f} from {source_savings_type}",
                "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt),
            },
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, rebuild_oid)

        res_dict = {
            "status": "SUCCESS",
            "event_id": event.event_id,
            "amount": amount,
            "source_savings_id": source_entity.id,
            "fee_type": fee_type,
            "affects_cash_vault": False,
        }
        if fee_id:
            res_dict["fee_id"] = fee_id
        return res_dict

    @staticmethod
    def transfer_savings(
        uow: SupabaseUnitOfWork,
        source_id: str,
        source_name: str,
        source_type: str,
        destination_id: str,
        destination_name: str,
        destination_type: str,
        branch: str,
        officer: str,
        amount: float,
        reference: Optional[str] = None,
        remarks: Optional[str] = None,
        posting_date: Optional[Any] = None,
        source_group_id: Optional[str] = None,
        dest_group_id: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        source_savings_id: Optional[str] = None,
    ) -> dict:
        """
        Executes atomic peer-to-peer or peer-to-group savings reallocation:
        - Decreases source savings (withdrawal_amount = amount)
        - Increases destination savings (deposit_amount = amount)
        - Emits SavingsTransferred domain event (DR 2000, CR 2000)
        - Zero physical vault cash movement (Account 1000 untouched)
        """
        if amount <= 0:
            raise ValueError("Transfer amount must be greater than zero.")
        if not destination_id and not destination_name:
            raise ValueError("Transfer destination is required.")
        if source_id and destination_id and str(source_id) == str(destination_id) and source_type == destination_type:
            raise ValueError("Source and destination accounts must be different.")

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot transfer savings. {reason}.")

        src_officer = SavingsService._resolve_assigned_co_username(
            uow,
            officer,
            client_id=source_id if source_type != "GroupSavings" else None,
            group_id=source_group_id or (source_id if source_type == "GroupSavings" else None),
            group_name=source_name if source_type == "GroupSavings" else None,
        )
        dst_officer = SavingsService._resolve_assigned_co_username(
            uow,
            officer,
            client_id=destination_id if destination_type != "GroupSavings" else None,
            group_id=dest_group_id or (destination_id if destination_type == "GroupSavings" else None),
            group_name=destination_name if destination_type == "GroupSavings" else None,
        )

        source_entity, _, source_op = SavingsService._build_source_savings_entity_and_op(
            uow=uow,
            source_savings_type=source_type,
            source_id=source_id,
            source_name=source_name,
            branch=branch,
            officer=src_officer,
            withdrawal_amount=amount,
            reference=reference,
            remarks=remarks or f"Transfer to {destination_name} ({destination_type})",
            posting_date=p_dt,
            group_id=source_group_id or (source_id if source_type == "GroupSavings" else None),
            idempotency_key=f"{idempotency_key}-src" if idempotency_key else None,
            source_savings_id=source_savings_id,
        )
        dest_entity, _, dest_op = SavingsService._build_source_savings_entity_and_op(
            uow=uow,
            source_savings_type=destination_type,
            source_id=destination_id,
            source_name=destination_name,
            branch=branch,
            officer=dst_officer,
            deposit_amount=amount,
            reference=reference,
            remarks=remarks or f"Transfer from {source_name} ({source_type})",
            posting_date=p_dt,
            group_id=dest_group_id or (destination_id if destination_type == "GroupSavings" else None),
            idempotency_key=f"{idempotency_key}-dst" if idempotency_key else None,
        )

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or src_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        src_oid = resolve_officer_id(uow.client, src_officer)
        dst_oid = resolve_officer_id(uow.client, dst_officer)
        if not SavingsService._is_valid_non_zero_uuid(src_oid):
            src_oid = None
        if not SavingsService._is_valid_non_zero_uuid(dst_oid):
            dst_oid = None

        rec_uuid = source_entity.id if SavingsService._is_valid_non_zero_uuid(source_entity.id) else None
        operations = [
            source_op,
            dest_op,
            {
                "type": "insert",
                "table": "audit_logs",
                "record": {
                    "id": str(uuid.uuid4()),
                    "user_id": actor_uid or src_oid,
                    "action": "Savings Transfer",
                    "description": (
                        f"Actor: {actor_uname} ({resolved_role}). From: {source_name} ({source_type}) -> "
                        f"To: {destination_name} ({destination_type}). Amount: {amount}."
                    ),
                    "table_name": "savings",
                    "record_id": rec_uuid,
                },
            },
            SavingsService._build_user_audit_op(
                user_id=actor_uid or src_oid,
                username=actor_uname,
                role=resolved_role,
                branch=branch,
                action="SAVINGS_TRANSFER",
                module="savings",
                entity_type="SavingsTransfer",
                entity_id=rec_uuid,
                display_name=f"{source_name} -> {destination_name}",
                previous_value=None,
                new_value={
                    "amount": amount,
                    "source_id": source_id,
                    "source_type": source_type,
                    "destination_id": destination_id,
                    "destination_type": destination_type,
                    "source_savings_id": source_entity.id,
                    "destination_savings_id": dest_entity.id,
                    "reference": reference,
                },
            ),
        ]

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=source_entity.id,
            aggregate_type="SavingsTransfer",
            event_type="SavingsTransferred",
            payload={
                "source_id": source_id,
                "source_name": source_name,
                "source_type": source_type,
                "destination_id": destination_id,
                "destination_name": destination_name,
                "destination_type": destination_type,
                "branch": branch,
                "officer": src_officer,
                "destination_officer": dst_officer,
                "amount": amount,
                "reference": reference or source_entity.id,
                "classification": "SavingsTransfer",
                "narration": remarks or f"Savings transfer of {amount:,.2f} from {source_name} to {destination_name}",
                "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt),
            },
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        for oid in {o for o in (src_oid, dst_oid) if o}:
            SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, oid)

        return {
            "status": "SUCCESS",
            "event_id": event.event_id,
            "amount": amount,
            "source_savings_id": source_entity.id,
            "destination_savings_id": dest_entity.id,
            "affects_cash_vault": False,
        }

    @staticmethod
    def transfer_to_laps(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        source_savings_type: str,
        branch: str,
        officer: str,
        amount: float,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        group_id: Optional[str] = None,
        group_name: Optional[str] = None,
        idempotency_key: Optional[str] = None,
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        source_savings_id: Optional[str] = None,
        laps_savings_id: Optional[str] = None,
    ) -> dict:
        """
        Executes atomic internal savings transfer into LAPS:
        - Decreases source savings (IndividualSavings, GroupSavings, MiscSavings)
        - Increases LAPS balance in laps_savings
        - Emits ONE LapsTransferred domain event (ZERO physical cash movement)
        - Commits atomically via atomic_execute_operations RPC
        """
        if amount <= 0:
            raise ValueError("Transfer amount must be greater than zero.")
        if not client_id or not SavingsService._is_valid_non_zero_uuid(client_id):
            raise ValueError("Valid beneficiary client_id is required for LAPS transfer.")

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot transfer to LAPS. {reason}.")

        effective_officer = SavingsService._resolve_assigned_co_username(
            uow,
            officer,
            client_id=client_id if source_savings_type != "GroupSavings" else None,
            group_id=group_id if source_savings_type == "GroupSavings" else None,
            group_name=(group_name or client_name) if source_savings_type == "GroupSavings" else None,
        )

        cls_info = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_TRANSFER, amount
        )

        source_name = (group_name or client_name) if source_savings_type == "GroupSavings" else client_name
        source_entity, _, source_op = SavingsService._build_source_savings_entity_and_op(
            uow=uow,
            source_savings_type=source_savings_type,
            source_id=group_id if source_savings_type == "GroupSavings" else client_id,
            source_name=source_name,
            branch=branch,
            officer=effective_officer,
            withdrawal_amount=amount,
            reference=reference,
            remarks=remarks or f"LAPS transfer withdrawal from {source_savings_type}",
            posting_date=p_dt,
            group_id=group_id,
            idempotency_key=f"{idempotency_key}-src" if idempotency_key else None,
            source_savings_id=source_savings_id,
        )

        laps_entity = LapsSavings(
            id=laps_savings_id if SavingsService._is_valid_non_zero_uuid(laps_savings_id) else str(uuid.uuid4()),
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=effective_officer,
            deposit_amount=amount,
            withdrawal_amount=0.0,
            reference=reference,
            remarks=remarks or f"LAPS transfer deposit from {source_savings_type}",
            date=p_dt,
        )
        laps_rec = SavingsService._build_savings_db_record(uow, "laps_savings", laps_entity, "laps_savings")
        if idempotency_key:
            laps_rec["idempotency_key"] = f"{idempotency_key}-laps"

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        rebuild_oid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(rebuild_oid):
            rebuild_oid = None

        rec_uuid = laps_entity.id if SavingsService._is_valid_non_zero_uuid(laps_entity.id) else None
        operations = [
            source_op,
            {"type": "insert", "table": "laps_savings", "record": laps_rec},
            {
                "type": "insert",
                "table": "audit_logs",
                "record": {
                    "id": str(uuid.uuid4()),
                    "user_id": actor_uid or rebuild_oid,
                    "action": "LAPS Transfer",
                    "description": (
                        f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                        f"Client: {client_name}. Amount: {amount}. Source: {source_savings_type} ({source_entity.id})."
                    ),
                    "table_name": "laps_savings",
                    "record_id": rec_uuid,
                },
            },
            SavingsService._build_user_audit_op(
                user_id=actor_uid or rebuild_oid,
                username=actor_uname,
                role=resolved_role,
                branch=branch,
                action="LAPS_TRANSFER",
                module="savings",
                entity_type="LapsSavings",
                entity_id=rec_uuid,
                display_name=client_name,
                previous_value=None,
                new_value={
                    "amount": amount,
                    "source_savings_type": source_savings_type,
                    "source_savings_id": source_entity.id,
                    "laps_savings_id": laps_entity.id,
                    "reference": reference,
                },
            ),
        ]

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=laps_entity.id,
            aggregate_type="LapsSavings",
            event_type="LapsTransferred",
            payload={
                "client_id": client_id,
                "source_savings_type": source_savings_type,
                "destination": "LAPS",
                "branch": branch,
                "officer": effective_officer,
                "amount": amount,
                "reference": reference or laps_entity.id,
                "classification": TransactionClassification.LAPS_TRANSFER.value,
                "narration": remarks or f"LAPS transfer of {amount:,.2f} from {source_savings_type} for client {client_name}",
                "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt),
            },
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, rebuild_oid)

        return {
            "status": "SUCCESS",
            "event_id": event.event_id,
            "amount": amount,
            "source_savings_id": source_entity.id,
            "laps_savings_id": laps_entity.id,
            "affects_cash_vault": cls_info["affects_cash_vault"],
        }

    @staticmethod
    def pay_laps(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        branch: str,
        officer: str,
        amount: float,
        cash_paid: bool = False,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        idempotency_key: Optional[str] = None,
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        laps_savings_id: Optional[str] = None,
    ) -> dict:
        """
        Executes LAPS payout to client atomically:
        - Decreases LAPS balance in laps_savings (withdrawal_amount = amount)
        - Option A: Routes direct LAPS payouts exclusively via Bank Transfer (Account 1050)
        - Commits atomically via atomic_execute_operations RPC
        """
        if amount <= 0:
            raise ValueError("Payout amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot pay out LAPS. {reason}.")

        effective_officer = SavingsService._resolve_assigned_co_username(uow, officer, client_id=client_id)
        effective_cash_paid = False

        cls_info = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_PAYOUT, amount, is_cash_paid=effective_cash_paid
        )

        laps_entity = LapsSavings(
            id=laps_savings_id if SavingsService._is_valid_non_zero_uuid(laps_savings_id) else str(uuid.uuid4()),
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=effective_officer,
            deposit_amount=0.0,
            withdrawal_amount=amount,
            reference=reference,
            remarks=remarks or f"LAPS payout (Bank Transfer) for client {client_name}",
            date=p_dt,
        )
        laps_rec = SavingsService._build_savings_db_record(uow, "laps_savings", laps_entity, "laps_savings")
        if idempotency_key:
            laps_rec["idempotency_key"] = idempotency_key

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        rebuild_oid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(rebuild_oid):
            rebuild_oid = None

        rec_uuid = laps_entity.id if SavingsService._is_valid_non_zero_uuid(laps_entity.id) else None
        operations = [
            {"type": "insert", "table": "laps_savings", "record": laps_rec},
            {
                "type": "insert",
                "table": "audit_logs",
                "record": {
                    "id": str(uuid.uuid4()),
                    "user_id": actor_uid or rebuild_oid,
                    "action": "LAPS Payout",
                    "description": (
                        f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                        f"Client: {client_name}. Amount: {amount}. CashPaid: {effective_cash_paid}."
                    ),
                    "table_name": "laps_savings",
                    "record_id": rec_uuid,
                },
            },
            SavingsService._build_user_audit_op(
                user_id=actor_uid or rebuild_oid,
                username=actor_uname,
                role=resolved_role,
                branch=branch,
                action="LAPS_PAYOUT",
                module="savings",
                entity_type="LapsSavings",
                entity_id=rec_uuid,
                display_name=client_name,
                previous_value=None,
                new_value={
                    "amount": amount,
                    "cash_paid": effective_cash_paid,
                    "payout_method": "Bank Transfer",
                    "reference": reference,
                },
            ),
        ]

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=laps_entity.id,
            aggregate_type="LapsSavings",
            event_type="LapsPaidOut",
            payload={
                "client_id": client_id,
                "amount": amount,
                "branch": branch,
                "officer": effective_officer,
                "cash_paid": effective_cash_paid,
                "payout_method": "Bank Transfer",
                "reference": reference or laps_entity.id,
                "classification": TransactionClassification.LAPS_PAYOUT.value,
                "narration": remarks or f"LAPS payout of {amount:,.2f} (Bank Transfer) for client {client_name}",
                "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt),
            },
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, rebuild_oid)

        return {
            "status": "SUCCESS",
            "event_id": event.event_id,
            "amount": amount,
            "laps_savings_id": laps_entity.id,
            "cash_paid": effective_cash_paid,
            "affects_cash_vault": cls_info["affects_cash_vault"],
        }

    @staticmethod
    def return_laps_to_savings(
        uow: SupabaseUnitOfWork,
        client_id: str,
        client_name: str,
        branch: str,
        officer: str,
        amount: float,
        reference: str = None,
        remarks: str = None,
        posting_date: Optional[Any] = None,
        idempotency_key: Optional[str] = None,
        actor_username: Optional[str] = None,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        laps_savings_id: Optional[str] = None,
    ) -> dict:
        """
        Executes LAPS restoration / return to customer savings atomically:
        - Decreases LAPS balance in laps_savings (withdrawal_amount = amount)
        - Increases Individual Savings balance in individual_savings (deposit_amount = amount)
        - Reactivates client status from Dormant/Closed/Inactive/Suspended -> Registered (inside same RPC)
        - Emits LapsRestoredToSavings domain event (DR 2030, CR 2000; ZERO cash vault movement)
        """
        if amount <= 0:
            raise ValueError("Restoration amount must be greater than zero.")

        p_dt = posting_date if posting_date else datetime.now()
        from services.business_date_service import BusinessDateService
        p_check_date = p_dt.date() if isinstance(p_dt, datetime) else p_dt
        is_open, reason = BusinessDateService.is_operational_open(uow, branch, p_check_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot restore LAPS to savings. {reason}.")

        effective_officer = SavingsService._resolve_assigned_co_username(uow, officer, client_id=client_id)
        ref_code = reference or f"LAPS-RET-{uuid.uuid4().hex[:8].upper()}"

        laps_entity = LapsSavings(
            id=laps_savings_id if SavingsService._is_valid_non_zero_uuid(laps_savings_id) else str(uuid.uuid4()),
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=effective_officer,
            deposit_amount=0.0,
            withdrawal_amount=amount,
            reference=ref_code,
            remarks=remarks or f"LAPS restoration to Individual Savings for client {client_name}",
            date=p_dt,
        )
        laps_rec = SavingsService._build_savings_db_record(uow, "laps_savings", laps_entity, "laps_savings")
        if idempotency_key:
            laps_rec["idempotency_key"] = f"{idempotency_key}-laps"

        indiv_entity = IndividualSavings(
            id=str(uuid.uuid4()),
            client_id=client_id,
            client_name=client_name,
            branch=branch,
            officer=effective_officer,
            deposit_amount=amount,
            withdrawal_amount=0.0,
            reference=ref_code,
            remarks=remarks or "Restored from LAPS Savings balance",
            date=p_dt,
            idempotency_key=f"{idempotency_key}-ind" if idempotency_key else None,
        )
        indiv_rec = SavingsService._build_savings_db_record(uow, "individual_savings", indiv_entity, "individual_savings")

        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, actor_username or officer or effective_officer, role_fallback=actor_role or "Credit Officer", branch_fallback=branch
        )
        from database.repositories.audit_repository import resolve_officer_id
        rebuild_oid = resolve_officer_id(uow.client, effective_officer)
        if not SavingsService._is_valid_non_zero_uuid(rebuild_oid):
            rebuild_oid = None

        operations = [
            {"type": "insert", "table": "laps_savings", "record": laps_rec},
            {"type": "insert", "table": "individual_savings", "record": indiv_rec},
        ]

        # Atomic client lifecycle re-activation when Dormant/Closed/Inactive/Suspended via canonical ClientStatusService
        res_c = uow.client.table("clients").select("status, status_id, client_statuses(name)").eq("client_id", client_id).execute()
        c_rows = getattr(res_c, "data", None)
        if isinstance(c_rows, list) and c_rows and isinstance(c_rows[0], dict):
            curr_status = (
                (c_rows[0].get("client_statuses") or {}).get("name")
                if isinstance(c_rows[0].get("client_statuses"), dict)
                else None
            ) or c_rows[0].get("status")
            if curr_status in ["Dormant", "Closed", "Inactive (Savings Only)", "Suspended"]:
                from services.client_status_service import ClientStatusService
                ClientStatusService.transition_status(
                    uow=uow,
                    client_id=client_id,
                    new_status_name="Registered",
                    changed_by=actor_uid or actor_uname,
                    reason=f"Reactivated upon LAPS restoration ({ref_code})",
                    trigger_type="LAPS_RESTORATION",
                    trigger_reference=ref_code,
                    defer_operations=operations,
                )

        rec_uuid = laps_entity.id if SavingsService._is_valid_non_zero_uuid(laps_entity.id) else None
        operations.extend([
            {
                "type": "insert",
                "table": "audit_logs",
                "record": {
                    "id": str(uuid.uuid4()),
                    "user_id": actor_uid or rebuild_oid,
                    "action": "LAPS Return to Savings",
                    "description": (
                        f"Actor: {actor_uname} ({resolved_role}). Officer: {effective_officer}. "
                        f"Client: {client_name}. Restored: {amount} -> IndividualSavings ({indiv_entity.id})."
                    ),
                    "table_name": "laps_savings",
                    "record_id": rec_uuid,
                },
            },
            SavingsService._build_user_audit_op(
                user_id=actor_uid or rebuild_oid,
                username=actor_uname,
                role=resolved_role,
                branch=branch,
                action="LAPS_RETURN_TO_SAVINGS",
                module="savings",
                entity_type="LapsSavings",
                entity_id=rec_uuid,
                display_name=client_name,
                previous_value=None,
                new_value={
                    "amount": amount,
                    "destination": "IndividualSavings",
                    "laps_savings_id": laps_entity.id,
                    "individual_savings_id": indiv_entity.id,
                    "reference": ref_code,
                },
            ),
        ])

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=laps_entity.id,
            aggregate_type="LapsSavings",
            event_type="LapsRestoredToSavings",
            payload={
                "client_id": client_id,
                "amount": amount,
                "branch": branch,
                "officer": effective_officer,
                "cash_paid": False,
                "reference": ref_code,
                "classification": "LAPS_RETURN_TO_SAVINGS",
                "narration": remarks or f"LAPS return of {amount:,.2f} to Individual Savings for client {client_name}",
                "date": p_dt.isoformat() if hasattr(p_dt, "isoformat") else str(p_dt),
            },
        )
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "metadata": getattr(event, "metadata", {}) or {},
                "status": "Completed",
            },
        })
        _, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)
        if extra_operations:
            operations.extend(extra_operations)

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
        SavingsService._safe_rebuild_co_projection(uow, branch, p_check_date, rebuild_oid)

        return {
            "status": "SUCCESS",
            "event_id": event.event_id,
            "amount": amount,
            "laps_savings_id": laps_entity.id,
            "individual_savings_id": indiv_entity.id,
            "affects_cash_vault": False,
        }

    @staticmethod
    def _parse_wr_metadata(wr_item: dict, uow: SupabaseUnitOfWork) -> dict:
        import re
        wr_remarks = str(wr_item.get("remarks") or "")
        wr_op = str(wr_item.get("operation_type") or "").strip()
        wr_payout = str(wr_item.get("payout_method") or "").strip()

        fee_type = wr_item.get("fee_type")
        if not fee_type and "[FEE:" in wr_remarks:
            m_fee = re.search(r"\[FEE:([^\]]+)\]", wr_remarks)
            if m_fee:
                fee_type = m_fee.group(1).strip()

        dest_id = wr_item.get("destination_id")
        if not dest_id and "[DEST_ID:" in wr_remarks:
            m_did = re.search(r"\[DEST_ID:([^\]]+)\]", wr_remarks)
            if m_did:
                dest_id = m_did.group(1).strip()

        dest_name = None
        if "[DEST_NAME:" in wr_remarks:
            m_dname = re.search(r"\[DEST_NAME:([^\]]+)\]", wr_remarks)
            if m_dname:
                dest_name = m_dname.group(1).strip()

        dest_type = wr_item.get("destination_type")
        if not dest_type and "[DEST_TYPE:" in wr_remarks:
            m_dtype = re.search(r"\[DEST_TYPE:([^\]]+)\]", wr_remarks)
            if m_dtype:
                dest_type = m_dtype.group(1).strip()
        if dest_type in {"Group", "Group Account", "GroupSavings"}:
            dest_type = "GroupSavings"
        elif dest_type in {"Individual", "Individual Member", "Group Member", "IndividualSavings"}:
            dest_type = "IndividualSavings"

        loan_id = wr_item.get("loan_id") or (dest_id if dest_type == "Loan" else None)
        if not loan_id and "[LOAN_OFFSET:" in wr_remarks:
            m_lid = re.search(r"\[LOAN_OFFSET:([^\]]+)\]", wr_remarks)
            if m_lid:
                loan_id = m_lid.group(1).strip()

        # Resolve dest_name safely from DB if dest_id exists without [DEST_NAME:]
        if dest_id and not dest_name:
            try:
                if dest_type == "GroupSavings":
                    g_res = uow.client.table("groups").select("name").eq("group_id", dest_id).limit(1).execute()
                    if isinstance(g_res.data, list) and g_res.data and isinstance(g_res.data[0], dict):
                        dest_name = g_res.data[0].get("name")
                else:
                    c_res = uow.client.table("clients").select("name").eq("client_id", dest_id).limit(1).execute()
                    if isinstance(c_res.data, list) and c_res.data and isinstance(c_res.data[0], dict):
                        dest_name = c_res.data[0].get("name")
            except Exception:
                pass

        is_return_to_savings = str(wr_op).strip().lower() in {
            "return to savings",
            "return to client savings",
            "laps return to customer savings",
        } or str(wr_payout).strip().lower() == "return to savings"
        # Option A: All direct payouts settle exclusively via Bank Transfer (1050)
        cash_paid = False

        return {
            "fee_type": fee_type or "misc_fees",
            "dest_id": dest_id,
            "dest_name": dest_name,
            "dest_type": dest_type,
            "loan_id": loan_id,
            "cash_paid": cash_paid,
            "payout_method": "Return to Savings" if is_return_to_savings else "Bank Transfer",
        }

    @staticmethod
    def _get_live_source_balance(
        uow: SupabaseUnitOfWork,
        wr_type: str,
        client_id: Optional[str],
        group_id: Optional[str],
        group_name: Optional[str],
        branch: str,
    ) -> Optional[float]:
        """Returns numeric live balance if measurable, else None (never crashes on MagicMock)."""
        try:
            raw = None
            if wr_type == "Individual" and client_id and hasattr(uow, "individual_savings"):
                raw = uow.individual_savings.get_total_balance(client_id=client_id)
            elif wr_type == "Group" and hasattr(uow, "group_savings"):
                raw = uow.group_savings.get_total_balance(group_id=group_id or group_name)
            elif wr_type == "Misc" and hasattr(uow, "misc_savings"):
                raw = uow.misc_savings.get_total_balance(branch=branch)
            elif wr_type == "LAPS" and client_id:
                if hasattr(uow, "laps_savings"):
                    raw = uow.laps_savings.get_total_balance(client_id=client_id, branch=branch)
                if not isinstance(raw, (int, float)):
                    q = uow.client.table("laps_savings").select("deposit_amount, withdrawal_amount").eq("client_id", client_id)
                    res = q.execute()
                    if isinstance(res.data, list):
                        raw = sum(float(r.get("deposit_amount") or 0.0) - float(r.get("withdrawal_amount") or 0.0) for r in res.data if isinstance(r, dict))
            if isinstance(raw, (int, float)):
                return float(raw)
        except Exception:
            pass
        return None

    @staticmethod
    def _attach_executed_target(extra_operations: Optional[List[dict]], record_id: Optional[str], table_name: str) -> Optional[List[dict]]:
        if not extra_operations:
            return extra_operations
        updated = []
        for op in extra_operations:
            if isinstance(op, dict) and op.get("table") == "withdrawal_requests" and isinstance(op.get("record"), dict):
                op_copy = dict(op)
                rec_copy = dict(op["record"])
                if record_id and SavingsService._is_valid_non_zero_uuid(str(record_id)) and not rec_copy.get("executed_record_id"):
                    rec_copy["executed_record_id"] = str(record_id)
                if table_name and not rec_copy.get("executed_table"):
                    rec_copy["executed_table"] = table_name
                op_copy["record"] = rec_copy
                updated.append(op_copy)
            else:
                updated.append(op)
        return updated

    @staticmethod
    def execute_approved_withdrawal(
        uow: SupabaseUnitOfWork,
        wr_item: dict,
        op_date: date,
        branch: str,
        actor_username: str,
        actor_role: Optional[str] = None,
        extra_operations: Optional[List[dict]] = None,
        validate_balance: bool = True,
        narration_prefix: str = "[BM APPROVED]",
    ) -> dict:
        """
        Single canonical dispatcher for executing approved or BM-direct withdrawals
        across all savings buckets (Individual, Group, Misc, LAPS) and all operation types.
        Fails closed with ValueError on unsupported operations, missing targets, or insufficient balance.
        """
        wr_id = str(wr_item.get("id") or "")
        wr_type = str(wr_item.get("savings_type") or "").strip()
        wr_op = str(wr_item.get("operation_type") or "").strip()
        wr_amt = float(wr_item.get("amount") or 0.0)
        if wr_amt <= 0:
            raise ValueError("Withdrawal amount must be greater than zero.")

        wr_client_id = wr_item.get("client_id")
        wr_name = str(wr_item.get("client_name") or wr_item.get("group_name") or "Client")
        wr_group_name = wr_item.get("group_name") or (wr_name if wr_type == "Group" else None)
        wr_by = str(wr_item.get("requested_by") or actor_username)
        wr_remarks = str(wr_item.get("remarks") or "")
        wr_ref = wr_item.get("reference")
        idem_base = wr_item.get("idempotency_key") or (f"WR-EXEC-{wr_id}" if wr_id else None)

        resolved_gid = wr_item.get("group_id")
        if wr_type == "Group" and not SavingsService._is_valid_non_zero_uuid(resolved_gid):
            if SavingsService._is_valid_non_zero_uuid(wr_client_id):
                resolved_gid = wr_client_id
            elif hasattr(uow, "group_savings") and hasattr(uow.group_savings, "_resolve_group_id"):
                try:
                    cand_gid = uow.group_savings._resolve_group_id(wr_group_name or wr_name)
                    if SavingsService._is_valid_non_zero_uuid(cand_gid):
                        resolved_gid = cand_gid
                except Exception:
                    pass

        if validate_balance:
            live_bal = SavingsService._get_live_source_balance(
                uow, wr_type, wr_client_id, resolved_gid, wr_group_name, branch
            )
            if live_bal is not None and wr_amt > (live_bal + 0.01):
                raise ValueError(f"Insufficient {wr_type} savings balance. Available: ₦{live_bal:,.2f}, Requested: ₦{wr_amt:,.2f}.")

        meta = SavingsService._parse_wr_metadata(wr_item, uow)
        full_remark = f"{narration_prefix} {wr_remarks}".strip() if narration_prefix and narration_prefix not in wr_remarks else (wr_remarks or wr_op)

        direct_payout_ops = {
            "Cash Withdrawal",
            "Withdrawal",
            "Bank Transfer",
            "Bank Account (Transfer)",
            "Client Bank Account (Transfer)",
            "Group Bank Account (Transfer)",
        }
        loan_offset_ops = {
            "Loan Offset",
            "Asset Downpayment",
            "Loan Repayment / Asset Debt Offset",
            "Loan Repayment / Asset Debt Offset (Member Debt)",
        }
        fee_offset_ops = {
            "Fee Offset",
            "Fee Payment from Savings",
            "Fee Payment from Group Savings",
            "Fee Payment",
        }
        transfer_ops = {
            "Savings Transfer",
            "Transfer to Another Savings",
            "Another Member or Group Savings",
        }
        laps_transfer_ops = {
            "LAPS Transfer",
            "LAPS Reserve",
            "LAPS Reserve (Group Closed)",
        }
        laps_return_ops = {
            "Return to Savings",
            "Return to Client Savings",
            "LAPS Return to Customer Savings",
        }
        laps_payout_ops = {
            "LAPS Payout",
            "LAPS Payout (Cash)",
            "LAPS Payout (Bank Transfer)",
        }

        source_type = "GroupSavings" if wr_type == "Group" else ("MiscSavings" if wr_type == "Misc" else "IndividualSavings")
        exec_record_id = str(uuid.uuid4())

        # Execute via canonical domain methods, binding withdrawal_requests transition atomically
        if wr_op in direct_payout_ops and wr_type != "LAPS":
            if wr_type == "Individual":
                if not wr_client_id:
                    raise ValueError("Client ID is required for Individual withdrawal.")
                attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, "individual_savings")
                entity = SavingsService.post_individual_savings(
                    uow=uow,
                    client_id=wr_client_id,
                    client_name=wr_name,
                    branch=branch,
                    officer=wr_by,
                    deposit_amount=0.0,
                    withdrawal_amount=wr_amt,
                    reference=wr_ref,
                    remarks=full_remark,
                    posting_date=op_date,
                    savings_id=exec_record_id,
                    idempotency_key=idem_base,
                    cash_paid=meta["cash_paid"],
                    payout_method=meta["payout_method"],
                    actor_username=actor_username,
                    actor_role=actor_role,
                    extra_operations=attached_ops,
                )
                return {"status": "SUCCESS", "executed_record_id": entity.id, "executed_table": "individual_savings", "cash_paid": meta["cash_paid"]}
            elif wr_type == "Group":
                if not wr_group_name:
                    raise ValueError("Group name is required for Group withdrawal.")
                attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, "group_savings")
                entity = SavingsService.post_group_savings(
                    uow=uow,
                    group_name=wr_group_name,
                    branch=branch,
                    officer=wr_by,
                    deposit_amount=0.0,
                    withdrawal_amount=wr_amt,
                    reference=wr_ref,
                    remarks=full_remark,
                    posting_date=op_date,
                    group_id=resolved_gid,
                    group_savings_id=exec_record_id,
                    idempotency_key=idem_base,
                    cash_paid=meta["cash_paid"],
                    payout_method=meta["payout_method"],
                    actor_username=actor_username,
                    actor_role=actor_role,
                    extra_operations=attached_ops,
                )
                return {"status": "SUCCESS", "executed_record_id": entity.id, "executed_table": "group_savings", "cash_paid": meta["cash_paid"]}
            elif wr_type == "Misc":
                attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, "internal_savings")
                entity = SavingsService.post_misc_savings(
                    uow=uow,
                    client_id=wr_client_id,
                    client_name=wr_name,
                    branch=branch,
                    officer=wr_by,
                    deposit_amount=0.0,
                    withdrawal_amount=wr_amt,
                    reference=wr_ref,
                    remarks=full_remark,
                    posting_date=op_date,
                    misc_savings_id=exec_record_id,
                    idempotency_key=idem_base,
                    cash_paid=meta["cash_paid"],
                    payout_method=meta["payout_method"],
                    actor_username=actor_username,
                    actor_role=actor_role,
                    extra_operations=attached_ops,
                )
                return {"status": "SUCCESS", "executed_record_id": entity.id, "executed_table": "internal_savings", "cash_paid": meta["cash_paid"]}
            else:
                raise ValueError(f"Unsupported savings_type '{wr_type}' for direct payout '{wr_op}'.")

        elif wr_op in loan_offset_ops:
            target_loan_id = meta["loan_id"]
            if not target_loan_id:
                raise ValueError(f"Target loan_id is required for '{wr_op}'.")
            src_tbl = "group_savings" if wr_type == "Group" else ("internal_savings" if wr_type == "Misc" else "individual_savings")
            attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, src_tbl)
            res = SavingsService.post_loan_offset_from_savings(
                uow=uow,
                client_id=wr_client_id,
                client_name=wr_group_name if wr_type == "Group" else wr_name,
                loan_id=target_loan_id,
                source_savings_type=source_type,
                branch=branch,
                officer=wr_by,
                amount=wr_amt,
                reference=wr_ref,
                remarks=full_remark,
                posting_date=op_date,
                group_id=resolved_gid,
                idempotency_key=idem_base,
                actor_username=actor_username,
                actor_role=actor_role,
                extra_operations=attached_ops,
                source_savings_id=exec_record_id,
            )
            return {"status": "SUCCESS", "executed_record_id": res.get("source_savings_id") or exec_record_id, "executed_table": source_type.lower(), "cash_paid": False, "result": res}

        elif wr_op in fee_offset_ops:
            src_tbl = "group_savings" if wr_type == "Group" else ("internal_savings" if wr_type == "Misc" else "individual_savings")
            attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, src_tbl)
            target_cid = meta["dest_id"] if wr_type == "Group" and SavingsService._is_valid_non_zero_uuid(meta["dest_id"]) else wr_client_id
            target_cname = meta["dest_name"] or wr_name
            res = SavingsService.post_fee_offset_from_savings(
                uow=uow,
                client_id=wr_client_id,
                client_name=wr_group_name if wr_type == "Group" else wr_name,
                source_savings_type=source_type,
                branch=branch,
                officer=wr_by,
                fee_type=meta["fee_type"],
                amount=wr_amt,
                target_client_id=target_cid if wr_type == "Group" else None,
                target_client_name=target_cname if wr_type == "Group" else None,
                reference=wr_ref,
                remarks=full_remark,
                posting_date=op_date,
                group_id=resolved_gid,
                idempotency_key=idem_base,
                actor_username=actor_username,
                actor_role=actor_role,
                extra_operations=attached_ops,
                source_savings_id=exec_record_id,
            )
            return {"status": "SUCCESS", "executed_record_id": res.get("source_savings_id") or exec_record_id, "executed_table": "fees", "cash_paid": False, "result": res}

        elif wr_op in transfer_ops:
            dest_id = meta["dest_id"]
            dest_type = meta["dest_type"] or "IndividualSavings"
            dest_name = meta["dest_name"] or "Recipient"
            if not dest_id:
                raise ValueError(f"Transfer destination ID is required for '{wr_op}'.")
            source_ident = resolved_gid if wr_type == "Group" else wr_client_id
            src_tbl = "group_savings" if wr_type == "Group" else ("internal_savings" if wr_type == "Misc" else "individual_savings")
            attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, src_tbl)
            res = SavingsService.transfer_savings(
                uow=uow,
                source_id=source_ident,
                source_name=wr_group_name if wr_type == "Group" else wr_name,
                source_type=source_type,
                destination_id=dest_id,
                destination_name=dest_name,
                destination_type=dest_type,
                branch=branch,
                officer=wr_by,
                amount=wr_amt,
                reference=wr_ref,
                remarks=full_remark,
                posting_date=op_date,
                source_group_id=resolved_gid,
                dest_group_id=dest_id if dest_type == "GroupSavings" else None,
                idempotency_key=idem_base,
                actor_username=actor_username,
                actor_role=actor_role,
                extra_operations=attached_ops,
                source_savings_id=exec_record_id,
            )
            return {"status": "SUCCESS", "executed_record_id": res.get("source_savings_id") or exec_record_id, "executed_table": "savings_transfer", "cash_paid": False, "result": res}

        elif wr_op in laps_transfer_ops:
            target_laps_cid = meta["dest_id"] if wr_type == "Group" and SavingsService._is_valid_non_zero_uuid(meta["dest_id"]) else wr_client_id
            target_laps_name = meta["dest_name"] or wr_name
            if not target_laps_cid:
                raise ValueError("Beneficiary client_id is required for LAPS Reserve transfer.")
            attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, "laps_savings")
            res = SavingsService.transfer_to_laps(
                uow=uow,
                client_id=target_laps_cid,
                client_name=target_laps_name,
                source_savings_type=source_type,
                branch=branch,
                officer=wr_by,
                amount=wr_amt,
                reference=wr_ref,
                remarks=full_remark,
                posting_date=op_date,
                group_id=resolved_gid,
                group_name=wr_group_name,
                idempotency_key=idem_base,
                actor_username=actor_username,
                actor_role=actor_role,
                extra_operations=attached_ops,
                laps_savings_id=exec_record_id,
            )
            return {"status": "SUCCESS", "executed_record_id": res.get("laps_savings_id") or exec_record_id, "executed_table": "laps_savings", "cash_paid": False, "result": res}

        elif wr_op in laps_return_ops or (wr_type == "LAPS" and str(meta["payout_method"]).lower() == "return to savings"):
            if not wr_client_id:
                raise ValueError("Client ID is required for LAPS return to savings.")
            attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, "laps_savings")
            res = SavingsService.return_laps_to_savings(
                uow=uow,
                client_id=wr_client_id,
                client_name=wr_name,
                branch=branch,
                officer=wr_by,
                amount=wr_amt,
                reference=wr_ref,
                remarks=full_remark,
                posting_date=op_date,
                idempotency_key=idem_base,
                actor_username=actor_username,
                actor_role=actor_role,
                extra_operations=attached_ops,
                laps_savings_id=exec_record_id,
            )
            return {"status": "SUCCESS", "executed_record_id": res.get("laps_savings_id") or exec_record_id, "executed_table": "laps_savings", "cash_paid": False, "result": res}

        elif wr_op in laps_payout_ops or (wr_type == "LAPS" and wr_op in direct_payout_ops):
            if not wr_client_id:
                raise ValueError("Client ID is required for LAPS payout.")
            attached_ops = SavingsService._attach_executed_target(extra_operations, exec_record_id, "laps_savings")
            res = SavingsService.pay_laps(
                uow=uow,
                client_id=wr_client_id,
                client_name=wr_name,
                branch=branch,
                officer=wr_by,
                amount=wr_amt,
                cash_paid=meta["cash_paid"],
                reference=wr_ref,
                remarks=full_remark,
                posting_date=op_date,
                idempotency_key=idem_base,
                actor_username=actor_username,
                actor_role=actor_role,
                extra_operations=attached_ops,
                laps_savings_id=exec_record_id,
            )
            return {"status": "SUCCESS", "executed_record_id": res.get("laps_savings_id") or exec_record_id, "executed_table": "laps_savings", "cash_paid": meta["cash_paid"], "result": res}

        raise ValueError(f"Unsupported withdrawal operation '{wr_op}' for savings type '{wr_type}'.")

    @staticmethod
    def reverse_savings(uow: SupabaseUnitOfWork, original_savings_id: str, reason: str, reversed_by: str, reversal_date: Optional[Any] = None):
        """
        Executes a compensating negative savings record to reverse an error (BR-ERR-002).
        Supports all 4 savings tables (individual_savings, group_savings, internal_savings, laps_savings)
        atomically with immutable compensating Ledger entries.
        """
        table_name = None
        orig = None
        for cand_tbl in ("individual_savings", "group_savings", "internal_savings", "laps_savings"):
            res = uow.client.table(cand_tbl).select("*").eq("id", original_savings_id).execute()
            rows = getattr(res, "data", None)
            if isinstance(rows, list) and rows and isinstance(rows[0], dict):
                table_name = cand_tbl
                orig = rows[0]
                break

        if not orig or not table_name:
            raise ValueError(f"Savings record {original_savings_id} not found in any savings ledger table.")

        operations = []
        dep_amt = float(orig.get("deposit_amount") or 0.0)
        wd_amt = float(orig.get("withdrawal_amount") or 0.0)

        # Guard: Cannot reverse a transaction with zero or negative amount, or an existing reversal
        if dep_amt <= 0 and wd_amt <= 0:
            raise ValueError(f"Cannot reverse savings record {original_savings_id}: transaction has no positive amount or is already a reversal.")

        # Guard: Prevent duplicate reversals across BOTH deposit_amount < 0 and withdrawal_amount < 0
        neg_dep = uow.client.table(table_name).select("id, remarks").lt("deposit_amount", 0).execute().data or []
        neg_wth = uow.client.table(table_name).select("id, remarks").lt("withdrawal_amount", 0).execute().data or []
        combined_negs = []
        if isinstance(neg_dep, list):
            combined_negs.extend(neg_dep)
        if isinstance(neg_wth, list):
            combined_negs.extend(neg_wth)
        existing_rev = [
            r for r in combined_negs
            if isinstance(r, dict) and str(original_savings_id) in str(r.get("remarks") or "")
        ]
        if existing_rev:
            raise ValueError(f"Savings transaction {original_savings_id} has already been reversed by record #{existing_rev[0]['id'][:8]}.")

        # Collect linked Domain Events and Withdrawal Requests to:
        # 1) Fail closed on compound non-cash operations (offsets, transfers, LAPS reserve/return)
        # 2) Detect cash vs bank payout when reversing a direct withdrawal
        orig_ref_val = str(orig.get("reference") or "").strip()
        matched_es: list = []
        matched_wrs: list = []
        try:
            es_res = uow.client.table("event_store").select("event_type, aggregate_id, payload").eq("aggregate_id", original_savings_id).execute()
            for r in (getattr(es_res, "data", None) or []):
                if isinstance(r, dict) and (not r.get("aggregate_id") or str(r.get("aggregate_id")) == str(original_savings_id)):
                    matched_es.append(r)
        except Exception:
            pass
        if not matched_es and orig_ref_val:
            try:
                es_ref_res = uow.client.table("event_store").select("event_type, aggregate_id, payload").filter("payload->>reference", "eq", orig_ref_val).execute()
                for r in (getattr(es_ref_res, "data", None) or []):
                    if isinstance(r, dict):
                        pl = r.get("payload") if isinstance(r.get("payload"), dict) else {}
                        if not pl.get("reference") or str(pl.get("reference")) == orig_ref_val:
                            matched_es.append(r)
            except Exception:
                pass

        try:
            wr_res = uow.client.table("withdrawal_requests").select("id, operation_type, savings_type, payout_method, executed_record_id, reference").eq("executed_record_id", original_savings_id).execute()
            for r in (getattr(wr_res, "data", None) or []):
                if isinstance(r, dict) and (not r.get("executed_record_id") or str(r.get("executed_record_id")) == str(original_savings_id)):
                    matched_wrs.append(r)
        except Exception:
            pass
        if not matched_wrs and orig_ref_val:
            try:
                wr_ref_res = uow.client.table("withdrawal_requests").select("id, operation_type, savings_type, payout_method, executed_record_id, reference").eq("reference", orig_ref_val).execute()
                for r in (getattr(wr_ref_res, "data", None) or []):
                    if isinstance(r, dict) and (not r.get("reference") or str(r.get("reference")) == orig_ref_val):
                        matched_wrs.append(r)
            except Exception:
                pass

        compound_event_types = {
            "LoanOffsetFromSavings",
            "FeeOffsetFromSavings",
            "SavingsTransferred",
            "LapsTransferred",
            "LapsRestoredToSavings",
        }
        compound_wr_ops = {
            "Loan Repayment / Asset Debt Offset",
            "Loan Offset",
            "Asset Debt Offset",
            "Member Debt Offset",
            "Pay Group Member Debt",
            "Fee Payment (from Savings)",
            "Fee Payment from Group Savings",
            "Fee Payment",
            "Transfer to Another Account",
            "Peer Transfer",
            "Group-to-Member Transfer",
            "Group Transfer",
            "LAPS Transfer",
            "LAPS Reserve",
            "LAPS Reserve (Group Closed)",
            "Return to Savings",
            "Return to Client Savings",
            "LAPS Return to Customer Savings",
        }
        for es_row in matched_es:
            ev_t = str(es_row.get("event_type") or "").strip()
            if ev_t in compound_event_types:
                raise ValueError(
                    f"Cannot reverse compound savings operation '{ev_t}' via simple savings reversal."
                )
        for wr_row in matched_wrs:
            wr_op_chk = str(wr_row.get("operation_type") or "").strip()
            wr_type_chk = str(wr_row.get("savings_type") or "").strip()
            wr_pm_chk = str(wr_row.get("payout_method") or "").strip().lower()
            if wr_op_chk in compound_wr_ops or (wr_type_chk == "LAPS" and wr_pm_chk == "return to savings"):
                raise ValueError(
                    f"Cannot reverse compound withdrawal operation '{wr_op_chk or 'LAPS Return to Savings'}' via simple savings reversal."
                )
        if orig_ref_val.startswith("LAPS-RET-"):
            raise ValueError(
                "Cannot reverse LAPS Return to Customer Savings operation via simple savings reversal."
            )

        # Detect cash vs bank payout when reversing a withdrawal (default Bank Transfer under Option A,
        # while honoring original ledger account 1000 for pre-cutover cash withdrawals).
        cash_paid = False
        payout_method = "Bank Transfer"
        original_cash_account = "1050"
        if wd_amt > 0:
            determined = False
            try:
                lookup_ref = orig_ref_val or str(original_savings_id)
                res_ft = (
                    uow.client.table("financial_transactions")
                    .select("transaction_id, financial_ledger_entries(account_code)")
                    .eq("reference", lookup_ref)
                    .execute()
                )
                for tx_r in (getattr(res_ft, "data", None) or []):
                    for leg in (tx_r.get("financial_ledger_entries") or []):
                        acc_c = str(leg.get("account_code") or "").strip()
                        if acc_c == "1000":
                            cash_paid = True
                            payout_method = "Cash"
                            original_cash_account = "1000"
                            determined = True
                            break
                        if acc_c == "1050":
                            cash_paid = False
                            payout_method = "Bank Transfer"
                            original_cash_account = "1050"
                            determined = True
                            break
                    if determined:
                        break
            except Exception:
                pass
            if not determined:
                for es_row in matched_es:
                    es_pl = es_row.get("payload") or {}
                    if isinstance(es_pl, dict) and ("cash_paid" in es_pl or "payout_method" in es_pl):
                        if es_pl.get("cash_paid") is True and "bank" not in str(es_pl.get("payout_method") or "").lower():
                            cash_paid = True
                            payout_method = "Cash"
                            original_cash_account = "1000"
                        determined = True
                        break
            if not determined:
                for wr_row in matched_wrs:
                    pm = str(wr_row.get("payout_method") or wr_row.get("operation_type") or "").lower()
                    if "cash" in pm and "bank" not in pm:
                        cash_paid = True
                        payout_method = "Cash"
                        original_cash_account = "1000"
                        determined = True
                        break

        # 1. Operational data: Compensating negative record
        new_id = str(uuid.uuid4())
        comp_record = {
            k: v for k, v in orig.items()
            if k not in ("branches", "app_users", "clients", "groups")
        }
        comp_record["id"] = new_id
        comp_record["idempotency_key"] = f"REV-{original_savings_id}"
        orig_ref = orig.get("reference") or str(original_savings_id)[:8]
        comp_record["reference"] = f"REV-{orig_ref}"

        if dep_amt > 0:
            comp_record["deposit_amount"] = -abs(dep_amt)
            comp_record["withdrawal_amount"] = 0.0
            reversal_amount = abs(dep_amt)
            event_type = "SavingsReversed"
        else:
            comp_record["withdrawal_amount"] = -abs(wd_amt)
            comp_record["deposit_amount"] = 0.0
            reversal_amount = abs(wd_amt)
            event_type = "SavingsWithdrawalReversed"

        comp_record["remarks"] = f"REVERSAL of {original_savings_id}. Reason: {reason} (by {reversed_by})"
        comp_record["created_at"] = datetime.now().isoformat()

        rev_dt = reversal_date if reversal_date else datetime.now()
        rev_dt_str = rev_dt.isoformat() if hasattr(rev_dt, "isoformat") else str(rev_dt)
        if "posting_date" in comp_record:
            comp_record["posting_date"] = rev_dt_str[:10]
        if "date" in comp_record:
            comp_record["date"] = rev_dt_str

        operations.append({
            "type": "insert",
            "table": table_name,
            "record": comp_record,
        })

        # 2. Audit logs (attributing the actual approver)
        actor_uid, actor_uname, resolved_role, _ = SavingsService._resolve_actor_audit_info(
            uow, reversed_by, role_fallback="Branch Manager"
        )
        operations.append({
            "type": "insert",
            "table": "audit_logs",
            "record": {
                "id": str(uuid.uuid4()),
                "user_id": actor_uid,
                "action": "Savings Reversal",
                "description": (
                    f"Actor: {actor_uname} ({resolved_role}). Reversed {table_name} #{str(original_savings_id)[:8]} "
                    f"(Amount: {reversal_amount}, Payout: {payout_method}). Reason: {reason}"
                ),
                "table_name": table_name,
                "record_id": new_id,
            },
        })
        operations.append(SavingsService._build_user_audit_op(
            user_id=actor_uid,
            username=actor_uname,
            role=resolved_role,
            branch=str(orig.get("branch_id") or orig.get("branch") or ""),
            action="SAVINGS_REVERSAL",
            module="corrections",
            entity_type=table_name,
            entity_id=original_savings_id if SavingsService._is_valid_non_zero_uuid(str(original_savings_id)) else None,
            display_name=str(orig.get("reference") or str(original_savings_id)[:8]),
            previous_value={"deposit_amount": dep_amt, "withdrawal_amount": wd_amt},
            new_value={"reversal_id": new_id, "reversal_amount": reversal_amount, "event_type": event_type, "reason": reason},
        ))

        # 3. Reversal Domain Event
        event_payload = {
            "branch": orig.get("branch_id") or orig.get("branch"),
            "officer": orig.get("officer_id") or orig.get("officer"),
            "amount": reversal_amount,
            "reference": comp_record["reference"],
            "narration": f"Reversal of {table_name} {original_savings_id}. Reason: {reason}",
            "date": rev_dt_str,
            "cash_paid": cash_paid,
            "payout_method": payout_method,
            "original_cash_account": original_cash_account,
            "is_laps": table_name == "laps_savings",
        }

        agg_map = {
            "individual_savings": "IndividualSavings",
            "group_savings": "GroupSavings",
            "internal_savings": "MiscSavings",
            "laps_savings": "LapsSavings",
        }
        agg_type = agg_map.get(table_name, "IndividualSavings")
        ev = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=new_id,
            aggregate_type=agg_type,
            event_type=event_type,
            payload=event_payload,
        )

        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": ev.event_id,
                "aggregate_id": ev.aggregate_id,
                "aggregate_type": ev.aggregate_type,
                "event_type": ev.event_type,
                "version": ev.version,
                "payload": ev.payload,
                "status": "Completed",
            },
        })

        _, post_op = FinancialPostingEngine.post_event(uow, ev, defer_commit=True)
        operations.append(post_op)

        # 4. Execute atomically via RPC
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # 5. Rebuild projections for reversal date and original posting date
        try:
            branch_val = orig.get("branch_id") or orig.get("branch")
            orig_oid = orig.get("officer_id")
            rebuild_date = rev_dt.date() if hasattr(rev_dt, "date") and callable(rev_dt.date) else (date.fromisoformat(str(rev_dt)[:10]) if rev_dt else date.today())
            uow.cashbook.rebuild_projection(uow, branch_val, rebuild_date)
            if SavingsService._is_valid_non_zero_uuid(str(branch_val or "")) and SavingsService._is_valid_non_zero_uuid(str(orig_oid or "")):
                uow.cashbook.rebuild_projection(str(branch_val), rebuild_date, officer_id=str(orig_oid))

            orig_raw_date = orig.get("posting_date") or orig.get("date")
            if orig_raw_date:
                orig_date = date.fromisoformat(str(orig_raw_date)[:10])
                if orig_date != rebuild_date:
                    uow.cashbook.rebuild_projection(uow, branch_val, orig_date)
                    if SavingsService._is_valid_non_zero_uuid(str(branch_val or "")) and SavingsService._is_valid_non_zero_uuid(str(orig_oid or "")):
                        uow.cashbook.rebuild_projection(str(branch_val), orig_date, officer_id=str(orig_oid))
        except Exception as ex_rb:
            print(f"[SAVINGS REVERSAL TRACE] Projection rebuild warning: {ex_rb}")

        return {"status": "SUCCESS", "reversal_id": new_id, "event_type": event_type, "amount": reversal_amount}

    @staticmethod
    def preview_automatic_laps_sweep(
        uow: SupabaseUnitOfWork,
        branch_id: Optional[str] = None,
        threshold_days: int = 90,
        execution_date: Optional[date] = None
    ) -> List[dict]:
        """
        Scans for clients with 'Inactive (Savings Only)', 'Dormant', or 'Suspended' status
        for >= threshold_days (max 3 months) who have positive individual savings balances.
        Returns candidate accounts without executing transfers.
        """
        eval_date = execution_date if execution_date else date.today()
        target_statuses = {"Inactive (Savings Only)", "Dormant", "Suspended"}

        query = (
            uow.client.table("clients")
            .select("client_id, name, client_code, branch_id, officer_id, status, status_changed_at, created_at, branches(name), app_users(username, full_name)")
        )
        if branch_id:
            query = query.eq("branch_id", branch_id)

        res = query.execute()
        clients = res.data or []

        candidates = []
        for c in clients:
            c_status = c.get("status")
            if c_status not in target_statuses:
                continue

            # Determine duration in current status
            dt_str = c.get("status_changed_at") or c.get("created_at")
            if not dt_str:
                continue
            try:
                changed_dt = date.fromisoformat(str(dt_str)[:10])
            except Exception:
                continue

            days_inactive = (eval_date - changed_dt).days
            if days_inactive < threshold_days:
                continue

            # Check individual savings balance
            bal = uow.individual_savings.get_total_balance(client_id=c["client_id"])
            if bal > 0.01:
                b_name = c.get("branches", {}).get("name") if isinstance(c.get("branches"), dict) else ""
                u_info = c.get("app_users") if isinstance(c.get("app_users"), dict) else {}
                o_name = u_info.get("full_name") or u_info.get("username", "")

                candidates.append({
                    "client_id": c["client_id"],
                    "client_name": c.get("name", "Unknown"),
                    "client_code": c.get("client_code", ""),
                    "branch_id": c.get("branch_id"),
                    "branch_name": b_name,
                    "officer_name": o_name,
                    "status": c_status,
                    "days_in_status": days_inactive,
                    "savings_balance": round(bal, 2)
                })

        return candidates

    @staticmethod
    def process_automatic_laps_sweep(
        uow: SupabaseUnitOfWork,
        branch_id: Optional[str] = None,
        threshold_days: int = 90,
        execution_date: Optional[date] = None
    ) -> dict:
        """
        Executes automated sweep to LAPS for clients inactive >= 3 months (90 days).
        Non-cash operation: transfers savings from individual_savings to laps_savings (Account 1000 unaffected).
        """
        candidates = SavingsService.preview_automatic_laps_sweep(
            uow=uow,
            branch_id=branch_id,
            threshold_days=threshold_days,
            execution_date=execution_date
        )

        eval_date = execution_date if execution_date else date.today()
        swept = []
        total_amt = 0.0

        for cand in candidates:
            try:
                off_ident = cand.get("officer_name") or cand.get("officer_id")
                if not off_ident:
                    raise ValueError(f"Missing officer identity for automatic LAPS sweep of client {cand.get('client_id')}.")
                res = SavingsService.transfer_to_laps(
                    uow=uow,
                    client_id=cand["client_id"],
                    client_name=cand["client_name"],
                    source_savings_type="IndividualSavings",
                    branch=cand["branch_name"] or cand["branch_id"],
                    officer=off_ident,
                    amount=cand["savings_balance"],
                    reference=f"AUTO-LAPS-{cand['client_id'][:8]}",
                    remarks=f"Automatic LAPS sweep after {cand['days_in_status']} days in {cand['status']}",
                    posting_date=eval_date
                )
                swept.append({
                    "client_id": cand["client_id"],
                    "client_name": cand["client_name"],
                    "amount": cand["savings_balance"],
                    "status": "Transferred",
                    "details": res
                })
                total_amt += cand["savings_balance"]
            except Exception as ex:
                swept.append({
                    "client_id": cand["client_id"],
                    "client_name": cand["client_name"],
                    "amount": cand["savings_balance"],
                    "status": "Failed",
                    "error": str(ex)
                })

        transferred_count = len([s for s in swept if s.get("status") == "Transferred"])
        return {
            "success": True,
            "swept_count": transferred_count,
            "total_amount": round(total_amt, 2),
            "details": swept,
            "message": f"Successfully swept {transferred_count} client balances (₦{total_amt:,.2f}) into LAPS."
        }


