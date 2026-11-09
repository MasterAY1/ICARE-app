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
        timeout_seconds: int = 60
    ) -> Dict[str, Any]:
        """
        Acquires an atomic database-backed lock for the given idempotency key.
        
        Returns:
            Dict containing 'action' ('PROCEED', 'REPLAY', 'CONFLICT') and status metadata.
            
        Raises:
            HTTPException 409 if transaction is currently in-flight.
            HTTPException 422 if key is re-used with different payload parameters.
        """
        if not key or not str(key).strip():
            return {"action": "PROCEED", "status": "NO_KEY"}

        clean_key = str(key).strip()
        req_hash = cls.compute_payload_hash(payload)

        try:
            res = uow.client.rpc("acquire_idempotency_lock", {
                "p_key": clean_key,
                "p_scope": scope,
                "p_request_hash": req_hash,
                "p_timeout_seconds": timeout_seconds
            }).execute()

            lock_data = res.data or {}
            action = lock_data.get("action", "PROCEED")

            if action == "CONFLICT":
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=lock_data.get("message") or "This transaction is currently in progress. Please wait a moment before checking status."
                )

            return lock_data

        except HTTPException:
            raise
        except Exception as ex:
            err_msg = str(ex)
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
