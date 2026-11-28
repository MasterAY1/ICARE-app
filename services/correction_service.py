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
    def _normalize_record_type(record_type: str) -> str:
        raw = str(record_type or "").strip()
        low = raw.lower().replace("_", " ").strip()
        if low in ("repayment", "loan", "loan repayment", "loan repayments"):
            return "Repayment"
        if low in ("savings", "savings deposit", "savings deposits", "savingsdeposit", "individual savings"):
            return "SavingsDeposit"
        if low in ("savings withdrawal", "savings withdrawals", "savingswithdrawal", "withdrawal"):
            return "SavingsWithdrawal"
        if low in ("group savings", "groupsavings"):
            return "GroupSavings"
        if low in ("misc savings", "miscsavings", "misc fee", "internal savings"):
            return "MiscSavings"
        if low in ("laps savings", "lapssavings"):
            return "LapsSavings"
        return raw

    @staticmethod
    def request_correction(uow: SupabaseUnitOfWork, record_id: str, record_type: str, reason: str, requested_by: str, branch_id: str = None) -> str:
        """
        Creates a pending correction request (BR-ERR-001).
        Enforces idempotency: blocks duplicate requests if a pending, processing, or approved request exists.
        """
        normalized_type = CorrectionService._normalize_record_type(record_type)

        # 1. Guard against duplicate requests in correction_requests
        existing = uow.client.table("correction_requests").select("id, status").eq("record_id", str(record_id)).in_("status", ["Pending", "Processing", "Approved"]).execute()
        if existing.data:
            st = existing.data[0]["status"]
            raise ValueError(f"This transaction already has an active correction request (Status: {st}). It cannot be flagged again.")

        # 2. Guard against requesting reversal for already-reversed transactions in operational tables
        savings_tbl_map = {
            "Savings": "individual_savings",
            "SavingsDeposit": "individual_savings",
            "SavingsWithdrawal": "individual_savings",
            "individual_savings": "individual_savings",
            "group_savings": "group_savings",
            "GroupSavings": "group_savings",
            "internal_savings": "internal_savings",
            "MiscSavings": "internal_savings",
            "laps_savings": "laps_savings",
            "LapsSavings": "laps_savings",
        }
        if normalized_type in savings_tbl_map or record_type in savings_tbl_map:
            target_key = normalized_type if normalized_type in savings_tbl_map else record_type
            cand_tables = (
                ["individual_savings", "group_savings", "internal_savings", "laps_savings"]
                if target_key in ("Savings", "SavingsWithdrawal", "SavingsDeposit")
                else [savings_tbl_map[target_key]]
            )
            for s_tbl in cand_tables:
                negs_dep = uow.client.table(s_tbl).select("id, remarks").lt("deposit_amount", 0).execute().data or []
                negs_wth = uow.client.table(s_tbl).select("id, remarks").lt("withdrawal_amount", 0).execute().data or []
                all_negs = (negs_dep if isinstance(negs_dep, list) else []) + (negs_wth if isinstance(negs_wth, list) else [])
                rev_match = [r for r in all_negs if isinstance(r, dict) and str(record_id) in str(r.get("remarks") or "")]
                if rev_match:
                    raise ValueError(f"This savings transaction has already been reversed in the ledger (Reversal Ref: {rev_match[0]['id'][:8]}).")
        elif normalized_type == "Repayment" or record_type in ["Repayment", "Loan"]:
            negs = uow.client.table("repayments").select("id, note").lt("amount_paid", 0).execute().data or []
            rev_match = [r for r in negs if str(record_id) in str(r.get("note") or "")]
            if rev_match:
                raise ValueError(f"This repayment has already been reversed in the ledger (Reversal Ref: {rev_match[0]['id'][:8]}).")

        req_id = str(uuid.uuid4())
        user_uuid = CorrectionService._resolve_user_id(uow, requested_by)
        record = {
            "id": req_id,
            "record_id": record_id,
            "record_type": normalized_type,
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

        approver_uuid = CorrectionService._resolve_user_id(uow, approved_by)

        # Four-Eyes Principle Guard (BR-ERR-001): Check before claiming Processing so self-approval never orphans lock
        if req.get("requested_by") and approver_uuid and str(req.get("requested_by")) == str(approver_uuid):
            raise ValueError("Four-Eyes Principle violation: The initiator of a correction request cannot approve their own request.")

        # Atomic status lock: transition status from Pending to Processing
        claim_res = uow.client.table("correction_requests").update({
            "status": "Processing",
            "updated_at": datetime.now().isoformat()
        }).eq("id", request_id).eq("status", "Pending").execute()

        if not claim_res.data:
            chk = uow.client.table("correction_requests").select("status").eq("id", request_id).execute()
            cur_st = chk.data[0]["status"] if chk.data else "Not Found"
            raise ValueError(f"Correction request {request_id} cannot be approved (Status: {cur_st}).")

        savings_record_types = [
            "Savings", "SavingsDeposit", "SavingsWithdrawal",
            "individual_savings", "group_savings", "GroupSavings",
            "internal_savings", "MiscSavings", "laps_savings", "LapsSavings",
        ]
        try:
            # Guard: Check if another request for the same record_id was already approved
            other_approved = uow.client.table("correction_requests").select("id").eq("record_id", req["record_id"]).eq("status", "Approved").neq("id", request_id).execute()
            if other_approved.data:
                uow.client.table("correction_requests").update({
                    "status": "Rejected",
                    "approved_by": approver_uuid,
                    "approval_date": datetime.now().isoformat(),
                    "updated_at": datetime.now().isoformat()
                }).eq("id", request_id).execute()
                raise ValueError(f"Transaction {req['record_id'][:8]} was already reversed by approved request #{other_approved.data[0]['id'][:8]}. This duplicate request has been auto-rejected.")

            rec_type = CorrectionService._normalize_record_type(req.get("record_type"))
            if rec_type in ["Repayment", "Loan"]:
                # Delegate to RepaymentService to execute reversal
                RepaymentService.reverse_repayment(uow, req["record_id"], req["reason"], approved_by)
            elif rec_type in savings_record_types:
                # Delegate to SavingsService to execute reversal across all 4 savings tables
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
        except Exception:
            # Release claim back to Pending if reversal execution failed
            try:
                uow.client.table("correction_requests").update({
                    "status": "Pending",
                    "updated_at": datetime.now().isoformat()
                }).eq("id", request_id).eq("status", "Processing").execute()
            except Exception:
                pass
            raise

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
