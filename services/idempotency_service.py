"""
Idempotency Service.

Manages distributed, database-backed idempotency locks, payload hashing,
in-flight concurrency control, and deterministic response replay for
mission-critical financial endpoints across the ICARE Core Banking Platform.
"""

import json
import hashlib
import logging
from typing import Dict, Any, Optional
from datetime import datetime, date

from fastapi import HTTPException, status
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.rbac_scope_service import RBACScopeService, UnknownRoleError

logger = logging.getLogger(__name__)


class IdempotencyService:
    @staticmethod
    def compute_payload_hash(payload: Any) -> str:
        """
        Calculates a deterministic SHA-256 hash of the normalized request payload.
        Handles Pydantic models, dicts, dates, and nested structures.
        """
        def _json_serial(obj):
            if isinstance(obj, (datetime, date)):
                return obj.isoformat()
            if hasattr(obj, "dict"):
                return obj.dict()
            if hasattr(obj, "model_dump"):
                return obj.model_dump()
            return str(obj)

        if hasattr(payload, "model_dump"):
            raw_dict = payload.model_dump()
        elif hasattr(payload, "dict"):
            raw_dict = payload.dict()
        elif isinstance(payload, dict):
            raw_dict = payload
        else:
            raw_dict = {"data": payload}

        # Normalize and sort keys
        normalized_str = json.dumps(raw_dict, sort_keys=True, default=_json_serial)
        return hashlib.sha256(normalized_str.encode("utf-8")).hexdigest()

    @classmethod
    def acquire_lock(
        cls,
        uow: SupabaseUnitOfWork,
        key: str,
        scope: str,
        payload: Any,
        timeout_seconds: int = 60,
        user_id: Optional[str] = None,
        branch_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Acquires an atomic database-backed lock for the given idempotency key.

        Returns:
            Dict containing 'action' ('PROCEED', 'REPLAY', 'CONFLICT') and status metadata.

        Raises:
            HTTPException 422 if idempotency_key is missing/blank or re-used with different payload parameters.
            HTTPException 403 if idempotency_key belongs to another user.
            HTTPException 409 if transaction is currently in-flight.
        """
        if not key or not str(key).strip():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="A valid idempotency_key is required for financial transactions."
            )

        clean_key = str(key).strip()
        clean_user_id = str(user_id).strip() if user_id else None
        clean_branch_id = str(branch_id).strip() if branch_id else None
        req_hash = cls.compute_payload_hash(payload)

        try:
            res = uow.client.rpc("acquire_idempotency_lock", {
                "p_key": clean_key,
                "p_scope": scope,
                "p_request_hash": req_hash,
                "p_timeout_seconds": timeout_seconds,
                "p_user_id": clean_user_id,
                "p_branch_id": clean_branch_id,
            }).execute()

            lock_data = res.data if isinstance(res.data, dict) else {}
            action = lock_data.get("action", "PROCEED")

            if action == "CONFLICT":
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=lock_data.get("message") or "This transaction is currently in progress. Please wait a moment before checking status."
                )

            if action == "REPLAY":
                rec_owner = str(lock_data.get("user_id") or "").strip()
                if clean_user_id and rec_owner and rec_owner != clean_user_id:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="Forbidden: This transaction key belongs to another staff member."
                    )

            return lock_data

        except HTTPException:
            raise
        except Exception as ex:
            err_msg = str(ex)
            if "ERR_IDEMPOTENCY_OWNERSHIP_VIOLATION" in err_msg:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Forbidden: This transaction key belongs to another staff member."
                )
            if "ERR_IDEMPOTENCY_PAYLOAD_MISMATCH" in err_msg:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail="Idempotency key was previously submitted with different payload parameters. Cannot reuse keys across different transactions."
                )
            logger.error(f"[IDEMPOTENCY] Error acquiring lock for key {clean_key}: {ex}")
            # If database RPC fails, fail closed to protect financial ledger integrity
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Unable to verify transaction idempotency safety: {err_msg}"
            )

    @classmethod
    def assert_transaction_access(cls, current_user: Any, record: Dict[str, Any]) -> None:
        """
        Enforces strict ownership and branch-scope authorization before returning
        cached transaction receipts or status records. Fails closed on missing ownership metadata.
        """
        try:
            norm_role = RBACScopeService.normalize_role(getattr(current_user, "role", None))
        except UnknownRoleError as exc:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Forbidden: {exc}"
            )
        if norm_role in ("Admin", "Director"):
            return

        rec_user_id = str(record.get("user_id") or "").strip()
        rec_branch_id = str(record.get("branch_id") or "").strip()
        caller_user_id = str(getattr(current_user, "id", None) or "").strip()
        caller_branch_id = str(getattr(current_user, "branch_id", None) or "").strip()

        if not rec_user_id and not rec_branch_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: Transaction ownership metadata is unavailable; administrative access required."
            )

        if norm_role == "CO":
            if not rec_user_id or rec_user_id != caller_user_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Forbidden: You can only view status for your own transactions."
                )
            if rec_branch_id and caller_branch_id and rec_branch_id != caller_branch_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Forbidden: You can only view status for your own transactions."
                )
            return

        if norm_role == "Branch Manager":
            same_user = bool(rec_user_id and caller_user_id and rec_user_id == caller_user_id)
            same_branch = bool(rec_branch_id and caller_branch_id and rec_branch_id == caller_branch_id)
            if same_user or same_branch:
                return
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: You cannot access transactions belonging to another branch."
            )

        if norm_role == "Area Manager":
            allowed_branches = set(
                str(b).strip()
                for b in (getattr(current_user, "assigned_branch_ids", None) or [])
                if b
            )
            if caller_branch_id:
                allowed_branches.add(caller_branch_id)
            same_user = bool(rec_user_id and caller_user_id and rec_user_id == caller_user_id)
            in_area = bool(rec_branch_id and rec_branch_id in allowed_branches)
            if same_user or in_area:
                return
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: You cannot access transactions outside your supervisory area."
            )

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: Insufficient privileges to inspect transaction status."
        )

    @classmethod
    def commit_result(
        cls,
        uow: SupabaseUnitOfWork,
        key: str,
        response_code: int,
        response_body: Any
    ) -> None:
        """
        Permanently registers a successfully committed transaction result in the idempotency registry.
        """
        if not key or not str(key).strip():
            return

        clean_key = str(key).strip()
        try:
            body_dict = response_body
            if hasattr(response_body, "model_dump"):
                body_dict = response_body.model_dump()
            elif hasattr(response_body, "dict"):
                body_dict = response_body.dict()

            uow.client.table("idempotency_keys").update({
                "status": "COMMITTED",
                "response_code": response_code,
                "response_body": body_dict
            }).eq("key", clean_key).execute()

        except Exception as ex:
            logger.error(f"[IDEMPOTENCY] Failed to commit idempotency result for key {clean_key}: {ex}")

    @classmethod
    def record_failure(
        cls,
        uow: SupabaseUnitOfWork,
        key: str,
        error_message: str,
        status_code: int = 500
    ) -> None:
        """
        Marks an idempotency record as failed, allowing retry or auditing.
        """
        if not key or not str(key).strip():
            return

        clean_key = str(key).strip()
        try:
            uow.client.table("idempotency_keys").update({
                "status": "FAILED",
                "response_code": status_code,
                "response_body": {"error": error_message}
            }).eq("key", clean_key).execute()
        except Exception as ex:
            logger.error(f"[IDEMPOTENCY] Failed to record failure status for key {clean_key}: {ex}")

    @classmethod
    def get_transaction_status(
        cls,
        uow: SupabaseUnitOfWork,
        key: str
    ) -> Optional[Dict[str, Any]]:
        """
        Fetches the execution status and cached receipt for a client transaction key.
        Used by mobile clients to recover after intermittent network drops.
        """
        if not key or not str(key).strip():
            return None

        clean_key = str(key).strip()
        res = uow.client.table("idempotency_keys").select("*").eq("key", clean_key).execute()
        if res.data:
            return res.data[0]
        return None
