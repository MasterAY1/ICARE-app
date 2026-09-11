import uuid
from datetime import datetime
from typing import Optional
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.repayment_service import RepaymentService
from services.savings_service import SavingsService
from services.treasury_service import TreasuryService

class CorrectionService:
    @staticmethod
    def _resolve_user_id(uow: SupabaseUnitOfWork, user_identifier: str) -> Optional[str]:
        if not user_identifier:
            return None
        try:
            uuid.UUID(str(user_identifier))
            return str(user_identifier)
        except ValueError:
            pass
        res = uow.client.table("app_users").select("id").eq("username", str(user_identifier)).execute()
        if res.data:
            return res.data[0]["id"]
        return None

    @staticmethod
    def request_correction(uow: SupabaseUnitOfWork, record_id: str, record_type: str, reason: str, requested_by: str, branch_id: str = None) -> str:
        """
        Creates a pending correction request (BR-ERR-001).
        Enforces idempotency: blocks duplicate requests if a pending or approved request exists.
        """
        # 1. Guard against duplicate requests in correction_requests
        existing = uow.client.table("correction_requests").select("id, status").eq("record_id", str(record_id)).in_("status", ["Pending", "Approved"]).execute()
        if existing.data:
            st = existing.data[0]["status"]
            raise ValueError(f"This transaction already has an active correction request (Status: {st}). It cannot be flagged again.")

        # 2. Guard against requesting reversal for already-reversed transactions in operational tables
        if record_type in ["Savings", "SavingsDeposit", "individual_savings"]:
            negs = uow.client.table("individual_savings").select("id, remarks").lt("deposit_amount", 0).execute().data or []
            rev_match = [r for r in negs if str(record_id) in str(r.get("remarks") or "")]
            if rev_match:
                raise ValueError(f"This savings transaction has already been reversed in the ledger (Reversal Ref: {rev_match[0]['id'][:8]}).")
        elif record_type in ["group_savings", "GroupSavings"]:
            negs = uow.client.table("group_savings").select("id, remarks").lt("deposit_amount", 0).execute().data or []
            rev_match = [r for r in negs if str(record_id) in str(r.get("remarks") or "")]
            if rev_match:
                raise ValueError(f"This group savings transaction has already been reversed in the ledger (Reversal Ref: {rev_match[0]['id'][:8]}).")
        elif record_type in ["Repayment", "Loan"]:
            negs = uow.client.table("repayments").select("id, note").lt("amount_paid", 0).execute().data or []
            rev_match = [r for r in negs if str(record_id) in str(r.get("note") or "")]
            if rev_match:
                raise ValueError(f"This repayment has already been reversed in the ledger (Reversal Ref: {rev_match[0]['id'][:8]}).")

        req_id = str(uuid.uuid4())
        user_uuid = CorrectionService._resolve_user_id(uow, requested_by)
        record = {
            "id": req_id,
            "record_id": record_id,
            "record_type": record_type,
            "requested_by": user_uuid,
            "branch_id": branch_id,
            "reason": reason,
            "status": "Pending",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        uow.client.table("correction_requests").insert(record).execute()
        return req_id

    @staticmethod
    def approve_correction(uow: SupabaseUnitOfWork, request_id: str, approved_by: str):
        """
        Approves a correction request and triggers the atomic reversal (BR-ERR-002, BR-ERR-003).
        Enforces idempotency: rejects duplicate approvals if underlying record was already reversed.
        """
        # Fetch request
        res = uow.client.table("correction_requests").select("*").eq("id", request_id).execute()
        if not res.data:
            raise ValueError(f"Correction request {request_id} not found.")
        req = res.data[0]

        if req["status"] != "Pending":
            raise ValueError(f"Request {request_id} is already {req['status']}.")

        # Guard: Check if another request for the same record_id was already approved
        other_approved = uow.client.table("correction_requests").select("id").eq("record_id", req["record_id"]).eq("status", "Approved").neq("id", request_id).execute()
        if other_approved.data:
            approver_uuid = CorrectionService._resolve_user_id(uow, approved_by)
            uow.client.table("correction_requests").update({
                "status": "Rejected",
                "approved_by": approver_uuid,
                "approval_date": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat()
            }).eq("id", request_id).execute()
            raise ValueError(f"Transaction {req['record_id'][:8]} was already reversed by approved request #{other_approved.data[0]['id'][:8]}. This duplicate request has been auto-rejected.")

        rec_type = req.get("record_type")
        if rec_type in ["Repayment", "Loan"]:
            # Delegate to RepaymentService to execute reversal
            RepaymentService.reverse_repayment(uow, req["record_id"], req["reason"], approved_by)
        elif rec_type in ["Savings", "SavingsDeposit", "individual_savings", "group_savings"]:
            # Delegate to SavingsService to execute reversal
            SavingsService.reverse_savings(uow, req["record_id"], req["reason"], approved_by)
        elif rec_type in ["Treasury", "TreasuryTransaction", "treasury_transactions", "Expense", "Salary", "Fee", "FeeCharged"]:
            # Delegate to TreasuryService to execute reversal
            TreasuryService.reverse_treasury_transaction(uow, req["record_id"], req["reason"], approved_by)
        else:
            raise NotImplementedError(f"Correction for record_type '{rec_type}' not yet supported.")

        # Mark as approved
        approver_uuid = CorrectionService._resolve_user_id(uow, approved_by)
        update_data = {
            "status": "Approved",
            "approved_by": approver_uuid,
            "approval_date": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        uow.client.table("correction_requests").update(update_data).eq("id", request_id).execute()

    @staticmethod
    def reject_correction(uow: SupabaseUnitOfWork, request_id: str, approved_by: str):
        approver_uuid = CorrectionService._resolve_user_id(uow, approved_by)
        update_data = {
            "status": "Rejected",
            "approved_by": approver_uuid,
            "approval_date": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        uow.client.table("correction_requests").update(update_data).eq("id", request_id).execute()
