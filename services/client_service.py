"""
services/client_service.py
Enterprise Service for Client Management:
1. Four-Eyes BM Approval workflow for Client Profile Modifications.
2. Multi-Level Client Transfers (Intra-branch, Inter-branch, Inter-area).
"""
from typing import Dict, Any, List, Optional
from datetime import datetime
import uuid

from interfaces.unit_of_work import UnitOfWork
from domain.enums import ClientTransferType, ClientProfileUpdateStatus
from api.core.errors import ICAREException


class ClientService:
    """Enterprise service governing client lifecycle operations."""

    @staticmethod
    def submit_profile_update_request(
        uow: UnitOfWork,
        client_id: str,
        requested_by: str,
        branch_id: str,
        proposed_changes: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Submits a client profile update request from a Credit Officer for BM review.
        """
        # 1. Verify client exists
        client = uow.clients.find_by_id(client_id)
        if not client:
            raise ICAREException(
                error_code="CLIENT_NOT_FOUND",
                title="Client Not Found",
                message=f"No client found with ID '{client_id}'.",
                action="Please select a valid client record."
            )

        # 2. Check if there is already a PENDING request
        q_pend = (
            uow.client.table("client_profile_update_requests")
            .select("request_id")
            .eq("client_id", client_id)
            .eq("status", ClientProfileUpdateStatus.PENDING.value)
            .execute()
        )
        if q_pend.data:
            raise ICAREException(
                error_code="CLIENT_EDIT_PENDING_APPROVAL",
                title="Update Already Pending",
                message="A profile modification for this client is already awaiting Branch Manager review.",
                action="Please wait for the Branch Manager to approve or reject the existing request."
            )

        # 3. Capture previous values from client profile
        prev_data = {
            "name": client.name,
            "phone": client.phone,
            "address": client.address,
            "marital_status": client.marital_status,
            "business_type": client.business_type,
            "average_monthly_income": getattr(client, "average_monthly_income", None),
            "other_obligations": getattr(client, "other_obligations", None),
            "id_means": getattr(client, "id_means", None),
            "id_number": getattr(client, "id_number", None),
        }

        # Also capture current guarantor info from latest loan if available
        res_l = (
            uow.client.table("loans")
            .select("extra_fields, guarantor_id_means, guarantor_id_number")
            .eq("client_id", client_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        if res_l.data:
            l_row = res_l.data[0]
            l_extra = l_row.get("extra_fields") or {}
            prev_data.update({
                "guarantor_name": l_extra.get("guarantor_name"),
                "guarantor_phone": l_extra.get("guarantor_phone"),
                "guarantor_address": l_extra.get("guarantor_home_address"),
                "guarantor_marital_status": l_extra.get("guarantor_marital_status"),
                "guarantor_occupation": l_extra.get("guarantor_occupation"),
                "guarantor_relationship": l_extra.get("guarantor_relationship"),
                "guarantor_office_address": l_extra.get("guarantor_office_address"),
                "guarantor_id_means": l_row.get("guarantor_id_means"),
                "guarantor_id_number": l_row.get("guarantor_id_number"),
            })

        req_id = str(uuid.uuid4())
        insert_payload = {
            "request_id": req_id,
            "client_id": client_id,
            "branch_id": branch_id or client.branch_id,
            "requested_by": requested_by,
            "proposed_changes": proposed_changes,
            "previous_values": prev_data,
            "status": ClientProfileUpdateStatus.PENDING.value,
            "created_at": datetime.now().isoformat()
        }

        uow.client.table("client_profile_update_requests").insert(insert_payload).execute()

        # Audit event
        uow.client.table("audit_logs").insert({
            "action": "SUBMIT_CLIENT_UPDATE_REQUEST",
            "entity": "clients",
            "entity_id": client_id,
            "user_id": requested_by,
            "branch_id": branch_id or client.branch_id,
            "details": f"Submitted client edit request {req_id} for {client.name}"
        }).execute()

        return {
            "request_id": req_id,
            "status": "PENDING_APPROVAL",
            "message": "Client update request submitted successfully. Awaiting Branch Manager review."
        }

    @staticmethod
    def get_pending_profile_update_requests(
        uow: UnitOfWork,
        branch_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """Lists all pending client update requests for a branch."""
        query = (
            uow.client.table("client_profile_update_requests")
            .select("*, clients(name, client_code), app_users(full_name, username), branches(name)")
            .eq("status", ClientProfileUpdateStatus.PENDING.value)
            .order("created_at", desc=True)
        )
        if branch_id:
            query = query.eq("branch_id", branch_id)

        res = query.execute()
        results = []
        for r in (res.data or []):
            c_info = r.get("clients") or {}
            u_info = r.get("app_users") or {}
            b_info = r.get("branches") or {}
            results.append({
                "request_id": r["request_id"],
                "client_id": r["client_id"],
                "client_name": c_info.get("name", "Unknown"),
                "client_code": c_info.get("client_code", ""),
                "branch_id": r["branch_id"],
                "branch_name": b_info.get("name", ""),
                "requested_by_name": u_info.get("full_name") or u_info.get("username", ""),
                "proposed_changes": r.get("proposed_changes", {}),
                "previous_values": r.get("previous_values", {}),
                "created_at": r.get("created_at")
            })
        return results

    @staticmethod
    def approve_profile_update_request(
        uow: UnitOfWork,
        request_id: str,
        approved_by: str
    ) -> Dict[str, Any]:
        """Approves a pending client profile update and commits changes atomically."""
        res_req = (
            uow.client.table("client_profile_update_requests")
            .select("*")
            .eq("request_id", request_id)
            .execute()
        )
        if not res_req.data:
            raise ICAREException(
                error_code="REQUEST_NOT_FOUND",
                title="Request Not Found",
                message="The specified update request does not exist.",
                action="Please refresh the pending requests list."
            )

        req_row = res_req.data[0]
        if req_row["status"] != ClientProfileUpdateStatus.PENDING.value:
            raise ICAREException(
                error_code="REQUEST_ALREADY_PROCESSED",
                title="Request Already Processed",
                message=f"This request has already been {req_row['status']}.",
                action="No further action can be taken on this request."
            )

        client_id = req_row["client_id"]
        changes = req_row.get("proposed_changes") or {}

        # 1. Update clients table
        client_fields = {}
        for k in ["name", "phone", "address", "marital_status", "business_type", "average_monthly_income", "other_obligations", "id_means", "id_number"]:
            if k in changes and changes[k] is not None:
                client_fields[k] = changes[k]

        if client_fields:
            client_fields["updated_at"] = datetime.now().isoformat()
            uow.client.table("clients").update(client_fields).eq("client_id", client_id).execute()

        # 2. Update loan guarantor extra_fields if present
        res_l = (
            uow.client.table("loans")
            .select("loan_id, extra_fields")
            .eq("client_id", client_id)
            .order("created_at", desc=True)
            .limit(1)
            .execute()
        )
        if res_l.data:
            latest_loan = res_l.data[0]
            loan_extra = latest_loan.get("extra_fields") or {}
            if "guarantor_name" in changes:
                loan_extra["guarantor_name"] = changes.get("guarantor_name")
            if "guarantor_phone" in changes:
                loan_extra["guarantor_phone"] = changes.get("guarantor_phone")
            if "guarantor_address" in changes:
                loan_extra["guarantor_home_address"] = changes.get("guarantor_address")
            if "guarantor_marital_status" in changes:
                loan_extra["guarantor_marital_status"] = changes.get("guarantor_marital_status")
            if "guarantor_occupation" in changes:
                loan_extra["guarantor_occupation"] = changes.get("guarantor_occupation")
            if "guarantor_relationship" in changes:
                loan_extra["guarantor_relationship"] = changes.get("guarantor_relationship")
            if "guarantor_office_address" in changes:
                loan_extra["guarantor_office_address"] = changes.get("guarantor_office_address")

            loan_update = {"extra_fields": loan_extra}
            if "guarantor_id_means" in changes:
                loan_update["guarantor_id_means"] = changes.get("guarantor_id_means")
            if "guarantor_id_number" in changes:
                loan_update["guarantor_id_number"] = changes.get("guarantor_id_number")

            uow.client.table("loans").update(loan_update).eq("loan_id", latest_loan["loan_id"]).execute()

        # 3. Update public.guarantors table
        g_name = changes.get("guarantor_name")
        g_phone = changes.get("guarantor_phone")
        if g_name and g_phone:
            res_g = uow.guarantors.find_by_phone(g_phone)
            if res_g:
                uow.client.table("guarantors").update({
                    "name": g_name,
                    "address": changes.get("guarantor_address"),
                    "occupation": changes.get("guarantor_occupation"),
                    "business_address": changes.get("guarantor_office_address"),
                    "id_means": changes.get("guarantor_id_means"),
                    "id_number": changes.get("guarantor_id_number")
                }).eq("guarantor_id", res_g.guarantor_id).execute()

        # 4. Mark request APPROVED
        uow.client.table("client_profile_update_requests").update({
            "status": ClientProfileUpdateStatus.APPROVED.value,
            "reviewed_by": approved_by,
            "reviewed_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }).eq("request_id", request_id).execute()

        # 5. Audit
        uow.client.table("audit_logs").insert({
            "action": "APPROVE_CLIENT_UPDATE",
            "entity": "clients",
            "entity_id": client_id,
            "user_id": approved_by,
            "branch_id": req_row.get("branch_id"),
            "details": f"Approved client update request {request_id}"
        }).execute()

        return {
            "request_id": request_id,
            "status": "APPROVED",
            "message": "Client profile update successfully approved and applied."
        }

    @staticmethod
    def reject_profile_update_request(
        uow: UnitOfWork,
        request_id: str,
        rejected_by: str,
        reason: str
    ) -> Dict[str, Any]:
        """Rejects a pending client profile update with reason."""
        if not reason or not reason.strip():
            raise ICAREException(
                error_code="REJECTION_REASON_REQUIRED",
                title="Reason Required",
                message="A rejection reason must be provided to inform the Credit Officer.",
                action="Please provide a clear justification for rejecting this update."
            )

        res_req = (
            uow.client.table("client_profile_update_requests")
            .select("*")
            .eq("request_id", request_id)
            .execute()
        )
        if not res_req.data:
            raise ICAREException(
                error_code="REQUEST_NOT_FOUND",
                title="Request Not Found",
                message="The specified update request does not exist.",
                action="Please refresh the pending requests list."
            )

        req_row = res_req.data[0]
        if req_row["status"] != ClientProfileUpdateStatus.PENDING.value:
            raise ICAREException(
                error_code="REQUEST_ALREADY_PROCESSED",
                title="Request Already Processed",
                message=f"This request has already been {req_row['status']}.",
                action="No further action can be taken on this request."
            )

        uow.client.table("client_profile_update_requests").update({
            "status": ClientProfileUpdateStatus.REJECTED.value,
            "rejection_reason": reason.strip(),
            "reviewed_by": rejected_by,
            "reviewed_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }).eq("request_id", request_id).execute()

        # Audit
        uow.client.table("audit_logs").insert({
            "action": "REJECT_CLIENT_UPDATE",
            "entity": "clients",
            "entity_id": req_row["client_id"],
            "user_id": rejected_by,
            "branch_id": req_row.get("branch_id"),
            "details": f"Rejected update request {request_id}: {reason.strip()}"
        }).execute()

        return {
            "request_id": request_id,
            "status": "REJECTED",
            "message": "Client profile update request has been rejected."
        }

    @staticmethod
    def transfer_client(
        uow: UnitOfWork,
        client_id: str,
        to_officer_id: str,
        to_branch_id: str,
        to_group_id: Optional[str] = None,
        reason: str = "Client portfolio reassignment",
        transferred_by: str = ""
    ) -> Dict[str, Any]:
        """
        Executes a multi-level client transfer:
        1. Intra-branch: Officer A -> Officer B within same branch.
        2. Inter-branch: Branch A -> Branch B.
        3. Inter-area: Area 1 -> Area 2.
        Preserves 100% of client lifecycle status, savings balance, and historical ledger records.
        """
        if not reason or not reason.strip():
            raise ICAREException(
                error_code="TRANSFER_REASON_REQUIRED",
                title="Transfer Reason Required",
                message="A valid reason must be stated for transferring a client portfolio.",
                action="Please state the business reason for this transfer."
            )

        client = uow.clients.find_by_id(client_id)
        if not client:
            raise ICAREException(
                error_code="CLIENT_NOT_FOUND",
                title="Client Not Found",
                message=f"No client found with ID '{client_id}'.",
                action="Please verify the selected client."
            )

        from_officer_id = client.officer_id
        from_branch_id = client.branch_id
        from_group_id = client.group_id

        if str(from_officer_id) == str(to_officer_id) and str(from_branch_id) == str(to_branch_id):
            raise ICAREException(
                error_code="CLIENT_TRANSFER_SAME_OFFICER",
                title="Identical Officer & Branch",
                message="The destination officer and branch are identical to the current assignment.",
                action="Please choose a different officer or branch to transfer this client."
            )

        # Verify destination branch exists
        res_b = uow.client.table("branches").select("branch_id, name, zone_id").eq("branch_id", to_branch_id).execute()
        if not res_b.data:
            raise ICAREException(
                error_code="BRANCH_NOT_FOUND",
                title="Destination Branch Not Found",
                message=f"Branch ID '{to_branch_id}' does not exist.",
                action="Please select an active destination branch."
            )
        dest_branch = res_b.data[0]
        dest_branch_name = dest_branch["name"]

        # Verify destination officer exists and belongs to destination branch
        res_u = uow.client.table("app_users").select("id, username, full_name, branch_id").eq("id", to_officer_id).execute()
        if not res_u.data:
            raise ICAREException(
                error_code="OFFICER_NOT_FOUND",
                title="Destination Officer Not Found",
                message=f"Officer ID '{to_officer_id}' does not exist.",
                action="Please select an active Credit Officer."
            )
        dest_user = res_u.data[0]
        dest_officer_name = dest_user.get("full_name") or dest_user.get("username")

        if str(dest_user.get("branch_id")) != str(to_branch_id):
            raise ICAREException(
                error_code="CLIENT_TRANSFER_BRANCH_MISMATCH",
                title="Officer Branch Mismatch",
                message=f"The selected officer '{dest_officer_name}' is assigned to another branch.",
                action="Please select a Credit Officer stationed at the destination branch."
            )

        # Determine transfer type
        if str(from_branch_id) == str(to_branch_id):
            t_type = ClientTransferType.INTRA_BRANCH.value
        else:
            # Check if source branch and destination branch have different zones/areas
            res_orig_b = uow.client.table("branches").select("zone_id").eq("branch_id", from_branch_id).execute()
            orig_zone = res_orig_b.data[0].get("zone_id") if res_orig_b.data else None
            dest_zone = dest_branch.get("zone_id")
            if orig_zone and dest_zone and orig_zone != dest_zone:
                t_type = ClientTransferType.INTER_AREA.value
            else:
                t_type = ClientTransferType.INTER_BRANCH.value

        # 1. Update client record (Preserves status_id, savings_balance, client_code)
        client_update = {
            "officer_id": to_officer_id,
            "branch_id": to_branch_id,
            "group_id": to_group_id or None,
            "updated_at": datetime.now().isoformat()
        }
        uow.client.table("clients").update(client_update).eq("client_id", client_id).execute()

        # 2. Update active loans for this client
        loan_update = {
            "officer_id": to_officer_id,
            "credit_officer": dest_officer_name,
            "branch_id": to_branch_id,
            "branch": dest_branch_name,
            "group_id": to_group_id or None
        }
        uow.client.table("loans").update(loan_update).eq("client_id", client_id).in_("status", ["ACTIVE", "Active", "Approved", "Defaulter"]).execute()

        # 3. Insert record into client_transfers
        transfer_id = str(uuid.uuid4())
        uow.client.table("client_transfers").insert({
            "transfer_id": transfer_id,
            "client_id": client_id,
            "transfer_type": t_type,
            "from_branch_id": from_branch_id,
            "to_branch_id": to_branch_id,
            "from_officer_id": from_officer_id,
            "to_officer_id": to_officer_id,
            "from_group_id": from_group_id,
            "to_group_id": to_group_id,
            "reason": reason.strip(),
            "transferred_by": transferred_by or to_officer_id,
            "approved_by": transferred_by,
            "created_at": datetime.now().isoformat()
        }).execute()

        # 4. Audit Log
        uow.client.table("audit_logs").insert({
            "action": f"CLIENT_TRANSFER_{t_type}",
            "entity": "clients",
            "entity_id": client_id,
            "user_id": transferred_by or to_officer_id,
            "branch_id": to_branch_id,
            "details": f"Transferred client {client.name} ({t_type}): from officer {from_officer_id} (branch {from_branch_id}) to officer {dest_officer_name} (branch {dest_branch_name})"
        }).execute()

        return {
            "transfer_id": transfer_id,
            "transfer_type": t_type,
            "client_id": client_id,
            "client_name": client.name,
            "new_branch": dest_branch_name,
            "new_officer": dest_officer_name,
            "status": "COMPLETED",
            "message": f"Client {client.name} successfully transferred to {dest_officer_name} ({dest_branch_name})."
        }
