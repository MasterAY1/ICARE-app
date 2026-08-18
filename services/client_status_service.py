"""
ClientStatusService — BR-CLI-001 through BR-CLI-009
Authoritative engine for client lifecycle status management, automatic system transitions,
manual CO status control, and immutable audit history.
"""
from typing import Dict, Any, List, Optional
from datetime import datetime
import uuid

from interfaces.unit_of_work import UnitOfWork


class ClientStatusService:
    _status_cache: Dict[str, Dict[str, Any]] = {}
    _status_by_id_cache: Dict[str, Dict[str, Any]] = {}

    @classmethod
    def get_all_statuses(cls, uow: UnitOfWork, force_refresh: bool = False) -> List[Dict[str, Any]]:
        """
        Fetches all predefined client statuses from client_statuses reference table.
        """
        if not cls._status_cache or force_refresh:
            try:
                res = uow.client.table("client_statuses").select("*").order("sort_order").execute()
                statuses = res.data or []
                cls._status_cache = {s["name"]: s for s in statuses}
                cls._status_by_id_cache = {str(s["status_id"]): s for s in statuses}
            except Exception as ex:
                print(f"[ClientStatusService] Failed to load statuses: {ex}")
                return list(cls._status_cache.values())
        return list(cls._status_cache.values())

    @classmethod
    def resolve_status_id(cls, uow: UnitOfWork, status_name: str) -> Optional[str]:
        """
        Resolves a status name to its UUID status_id.
        """
        cls.get_all_statuses(uow)
        s = cls._status_cache.get(status_name)
        return s["status_id"] if s else None

    @classmethod
    def resolve_status_name(cls, uow: UnitOfWork, status_id: str) -> str:
        """
        Resolves a status_id to its human-readable name.
        """
        cls.get_all_statuses(uow)
        s = cls._status_by_id_cache.get(str(status_id))
        return s["name"] if s else "Registered"

    @classmethod
    def transition_status(
        cls,
        uow: UnitOfWork,
        client_id: str,
        new_status_name: str,
        changed_by: Optional[str] = None,
        reason: Optional[str] = None,
        trigger_type: str = "MANUAL",
        trigger_reference: Optional[str] = None,
        defer_operations: Optional[List[Dict[str, Any]]] = None
    ) -> bool:
        """
        Authoritative method to transition a client's lifecycle status (BR-CLI-001 & BR-CLI-007).
        Updates clients.status_id and appends an immutable record to client_status_history.
        """
        cls.get_all_statuses(uow)
        target_status = cls._status_cache.get(new_status_name)
        if not target_status:
            print(f"[ClientStatusService] Unknown status: {new_status_name}")
            return False

        target_status_id = target_status["status_id"]

        # 1. Fetch current client status
        try:
            c_res = uow.client.table("clients").select("status_id").eq("client_id", client_id).execute()
            old_status_id = c_res.data[0].get("status_id") if c_res.data else None
        except Exception:
            old_status_id = None

        if old_status_id == target_status_id:
            # Already in target status
            return True

        now_str = datetime.now().isoformat()
        history_id = str(uuid.uuid4())

        history_record = {
            "id": history_id,
            "client_id": client_id,
            "old_status_id": old_status_id,
            "new_status_id": target_status_id,
            "changed_by": changed_by,
            "changed_at": now_str,
            "reason": reason or f"Transition to {new_status_name}",
            "trigger_type": trigger_type,
            "trigger_reference": trigger_reference
        }

        client_update_record = {
            "status_id": target_status_id,
            "status_changed_at": now_str,
            "status_changed_by": changed_by,
            "status_note": reason or f"Transition to {new_status_name}"
        }

        if defer_operations is not None:
            # Add to atomic batch
            defer_operations.append({
                "type": "update",
                "table": "clients",
                "record": client_update_record,
                "match": {"client_id": client_id}
            })
            defer_operations.append({
                "type": "insert",
                "table": "client_status_history",
                "record": history_record
            })
            return True
        else:
            try:
                uow.client.table("clients").update(client_update_record).eq("client_id", client_id).execute()
                uow.client.table("client_status_history").insert(history_record).execute()
                return True
            except Exception as ex:
                print(f"[ClientStatusService] Transition failed: {ex}")
                return False

    @classmethod
    def on_loan_submitted(cls, uow: UnitOfWork, client_id: str, loan_id: str, officer_id: Optional[str] = None):
        """
        Auto transition: Registered / Completed -> Pending Loan (BR-CLI-003.1).
        """
        cls.transition_status(
            uow=uow,
            client_id=client_id,
            new_status_name="Pending Loan",
            changed_by=officer_id,
            reason="Loan application submitted",
            trigger_type="SYSTEM",
            trigger_reference=loan_id
        )

    @classmethod
    def on_loan_disbursed(cls, uow: UnitOfWork, client_id: str, loan_id: str, officer_id: Optional[str] = None, defer_operations: Optional[List[Dict[str, Any]]] = None):
        """
        Auto transition: Pending Loan / Completed -> On Loan upon disbursement (BR-CLI-003.2).
        """
        cls.transition_status(
            uow=uow,
            client_id=client_id,
            new_status_name="On Loan",
            changed_by=officer_id,
            reason="Loan approved by BM and disbursed",
            trigger_type="SYSTEM",
            trigger_reference=loan_id,
            defer_operations=defer_operations
        )

    @classmethod
    def on_loan_repayment_check(cls, uow: UnitOfWork, client_id: str, loan_id: str, defer_operations: Optional[List[Dict[str, Any]]] = None):
        """
        Checks if loan is fully paid (outstanding <= 0).
        If fully paid, auto transitions:
          1. loans.status -> 'Completed'
          2. clients.status_id -> 'Completed' (if no other active loans exist)
        (BR-CLI-003.3 & BR-CLI-005)
        """
        try:
            # 1. Fetch the loan details
            l_res = uow.client.table("loans").select("active_credit, total_due, loan_amount").eq("loan_id", loan_id).execute()
            if not l_res.data:
                return

            l = l_res.data[0]
            act_cred = float(l.get("active_credit") or l.get("loan_amount") or 0.0)
            tot_due_base = float(l.get("total_due") if l.get("total_due") is not None else act_cred)

            # 2. Fetch all repayments for this loan
            rep_res = uow.client.table("repayments").select("amount_paid").eq("loan_id", loan_id).execute()
            tot_paid = sum(float(r.get("amount_paid") or 0.0) for r in (rep_res.data or []))
            outstanding = max(0.0, tot_due_base - tot_paid)

            if outstanding <= 0.0 and act_cred > 0:
                # Update loan status to Completed
                if defer_operations is not None:
                    defer_operations.append({
                        "type": "update",
                        "table": "loans",
                        "record": {"status": "Completed"},
                        "match": {"loan_id": loan_id}
                    })
                else:
                    uow.client.table("loans").update({"status": "Completed"}).eq("loan_id", loan_id).execute()

                # Check if client has any other active loans
                other_loans_res = uow.client.table("loans").select("loan_id").eq("client_id", client_id).in_("status", ["Active", "ACTIVE", "Approved"]).neq("loan_id", loan_id).execute()
                has_other_active = len(other_loans_res.data or []) > 0

                if not has_other_active:
                    cls.transition_status(
                        uow=uow,
                        client_id=client_id,
                        new_status_name="Completed",
                        reason=f"Loan {loan_id[:8]}... fully paid (Outstanding = ₦0)",
                        trigger_type="SYSTEM",
                        trigger_reference=loan_id,
                        defer_operations=defer_operations
                    )
        except Exception as ex:
            print(f"[ClientStatusService] Repayment completion check failed: {ex}")

    @classmethod
    def get_client_history(cls, uow: UnitOfWork, client_id: str) -> List[Dict[str, Any]]:
        """
        Fetches full audit trail history for a client.
        """
        try:
            res = uow.client.table("client_status_history") \
                .select("*, old_status:client_statuses!client_status_history_old_status_id_fkey(name, color_code), new_status:client_statuses!client_status_history_new_status_id_fkey(name, color_code), changer:app_users(full_name)") \
                .eq("client_id", client_id) \
                .order("changed_at", desc=True) \
                .execute()
            return res.data or []
        except Exception:
            # Fallback without complex joins if needed
            try:
                res = uow.client.table("client_status_history").select("*").eq("client_id", client_id).order("changed_at", desc=True).execute()
                cls.get_all_statuses(uow)
                records = res.data or []
                for r in records:
                    r["old_status_name"] = cls.resolve_status_name(uow, r.get("old_status_id")) if r.get("old_status_id") else "None"
                    r["new_status_name"] = cls.resolve_status_name(uow, r.get("new_status_id"))
                return records
            except Exception:
                return []
