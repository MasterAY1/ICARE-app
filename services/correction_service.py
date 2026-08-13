import uuid
from datetime import datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.repayment_service import RepaymentService

class CorrectionService:
    @staticmethod
    def request_correction(uow: SupabaseUnitOfWork, record_id: str, record_type: str, reason: str, requested_by: str, branch_id: str = None) -> str:
        """
        Creates a pending correction request (BR-ERR-001).
        """
        req_id = str(uuid.uuid4())
        record = {
            "id": req_id,
            "record_id": record_id,
            "record_type": record_type,
            "requested_by": requested_by,
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
        """
        # Fetch request
        res = uow.client.table("correction_requests").select("*").eq("id", request_id).execute()
        if not res.data:
            raise ValueError(f"Correction request {request_id} not found.")
        req = res.data[0]

        if req["status"] != "Pending":
            raise ValueError(f"Request {request_id} is already {req['status']}.")

        if req["record_type"] == "Repayment":
            # Delegate to RepaymentService to execute reversal
            RepaymentService.reverse_repayment(uow, req["record_id"], req["reason"], approved_by)
        else:
            raise NotImplementedError(f"Correction for record_type '{req['record_type']}' not yet supported.")

        # Mark as approved
        update_data = {
            "status": "Approved",
            "approved_by": approved_by,
            "approval_date": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        uow.client.table("correction_requests").update(update_data).eq("id", request_id).execute()

    @staticmethod
    def reject_correction(uow: SupabaseUnitOfWork, request_id: str, approved_by: str):
        # Mark as rejected
        update_data = {
            "status": "Rejected",
            "approved_by": approved_by,
            "approval_date": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        uow.client.table("correction_requests").update(update_data).eq("id", request_id).execute()
