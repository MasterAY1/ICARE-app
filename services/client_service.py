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
from domain.enums import ClientTransferType, ClientProfileUpdateStatus, ClientTransferStatus
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
        to_branch_id: str,
        to_officer_id: Optional[str] = None,
        to_group_id: Optional[str] = None,
        reason: str = "Client portfolio reassignment",
        transferred_by: str = ""
    ) -> Dict[str, Any]:
        """
        Executes or initiates a multi-level client transfer:
        1. Intra-branch: Officer A -> Officer B within same branch (Executed immediately by BM).
        2. Inter-branch: Branch A -> Branch B (Initiated by Source BM -> AM Sign-off -> Dest BM Acceptance & Assignment).
        3. Inter-area: Area 1 -> Area 2 (Same staged workflow across zonal boundaries).
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

        # =========================================================================
        # 1. INTRA-BRANCH REASSIGNMENT (Option 1: Direct BM Reassignment)
        # =========================================================================
        if str(from_branch_id) == str(to_branch_id):
            if not to_officer_id:
                raise ICAREException(
                    error_code="DESTINATION_OFFICER_REQUIRED",
                    title="Credit Officer Required",
                    message="Please select the destination Credit Officer for this intra-branch reassignment.",
                    action="Select a Credit Officer stationed at this branch."
                )

            if str(from_officer_id) == str(to_officer_id):
                raise ICAREException(
                    error_code="CLIENT_TRANSFER_SAME_OFFICER",
                    title="Identical Officer Assignment",
                    message="The destination officer is identical to the client's current officer assignment.",
                    action="Please select a different Credit Officer within the branch."
                )

            # Verify destination officer belongs to this branch
            res_u = uow.client.table("app_users").select("id, username, full_name, branch_id").eq("id", to_officer_id).execute()
            if not res_u.data:
                raise ICAREException(
                    error_code="OFFICER_NOT_FOUND",
                    title="Credit Officer Not Found",
                    message=f"Officer ID '{to_officer_id}' does not exist.",
                    action="Please select an active Credit Officer."
                )
            dest_user = res_u.data[0]
            dest_officer_name = dest_user.get("full_name") or dest_user.get("username")

            if str(dest_user.get("branch_id")) != str(to_branch_id):
                raise ICAREException(
                    error_code="CLIENT_TRANSFER_BRANCH_MISMATCH",
                    title="Officer Branch Mismatch",
                    message=f"The selected officer '{dest_officer_name}' is not assigned to this branch.",
                    action="Please select a Credit Officer stationed at the same branch."
                )

            t_type = ClientTransferType.INTRA_BRANCH.value
            now_iso = datetime.now().isoformat()

            # Update client record
            client_update = {
                "officer_id": to_officer_id,
                "branch_id": to_branch_id,
                "group_id": to_group_id or None,
                "updated_at": now_iso
            }
            uow.client.table("clients").update(client_update).eq("client_id", client_id).execute()

            # Update active loans
            loan_update = {
                "officer_id": to_officer_id,
                "credit_officer": dest_officer_name,
                "branch_id": to_branch_id,
                "branch": dest_branch_name,
                "group_id": to_group_id or None
            }
            uow.client.table("loans").update(loan_update).eq("client_id", client_id).in_("status", ["ACTIVE", "Active", "Approved", "Defaulter"]).execute()

            # Insert record into client_transfers
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
                "approved_at": now_iso,
                "accepted_by": transferred_by,
                "accepted_at": now_iso,
                "status": ClientTransferStatus.COMPLETED.value,
                "created_at": now_iso
            }).execute()

            # Audit Log
            uow.client.table("audit_logs").insert({
                "action": f"CLIENT_TRANSFER_{t_type}",
                "entity": "clients",
                "entity_id": client_id,
                "user_id": transferred_by or to_officer_id,
                "branch_id": to_branch_id,
                "details": f"Reassigned client {client.name} ({t_type}): from officer {from_officer_id} to officer {dest_officer_name}"
            }).execute()

            return {
                "transfer_id": transfer_id,
                "transfer_type": t_type,
                "client_id": client_id,
                "client_name": client.name,
                "new_branch": dest_branch_name,
                "new_officer": dest_officer_name,
                "status": ClientTransferStatus.COMPLETED.value,
                "message": f"Client {client.name} successfully reassigned to {dest_officer_name}."
            }

        # =========================================================================
        # 2. INTER-BRANCH / INTER-AREA TRANSFER (Stage 1 Initiation by Source BM)
        # =========================================================================
        # Check if client already has an active pending transfer
        res_pending = uow.client.table("client_transfers").select("transfer_id").eq("client_id", client_id).in_("status", [
            ClientTransferStatus.PENDING_AM_APPROVAL.value,
            ClientTransferStatus.PENDING_RECEIVING_BM.value,
            "PENDING",
            "Pending"
        ]).execute()
        if res_pending.data:
            raise ICAREException(
                error_code="TRANSFER_ALREADY_PENDING",
                title="Transfer Already Pending",
                message="This client already has an active transfer request awaiting Area Manager approval or receiving branch assignment.",
                action="Please await completion or rejection of the existing transfer request."
            )

        # Check if source branch and destination branch have different zones/areas
        res_orig_b = uow.client.table("branches").select("zone_id").eq("branch_id", from_branch_id).execute()
        orig_zone = res_orig_b.data[0].get("zone_id") if res_orig_b.data else None
        dest_zone = dest_branch.get("zone_id")
        if orig_zone and dest_zone and orig_zone != dest_zone:
            t_type = ClientTransferType.INTER_AREA.value
        else:
            t_type = ClientTransferType.INTER_BRANCH.value

        transfer_id = str(uuid.uuid4())
        now_iso = datetime.now().isoformat()

        # Insert transfer request with status PENDING_AM_APPROVAL
        # Note: to_officer_id and to_group_id remain NULL until the destination BM accepts and assigns.
        uow.client.table("client_transfers").insert({
            "transfer_id": transfer_id,
            "client_id": client_id,
            "transfer_type": t_type,
            "from_branch_id": from_branch_id,
            "to_branch_id": to_branch_id,
            "from_officer_id": from_officer_id,
            "to_officer_id": None,
            "from_group_id": from_group_id,
            "to_group_id": None,
            "reason": reason.strip(),
            "transferred_by": transferred_by or from_officer_id,
            "status": ClientTransferStatus.PENDING_AM_APPROVAL.value,
            "created_at": now_iso
        }).execute()

        # Audit Log
        uow.client.table("audit_logs").insert({
            "action": f"CLIENT_TRANSFER_REQUESTED_{t_type}",
            "entity": "clients",
            "entity_id": client_id,
            "user_id": transferred_by or from_officer_id,
            "branch_id": from_branch_id,
            "details": f"Initiated transfer request for client {client.name} ({t_type}): from branch {from_branch_id} to branch {dest_branch_name} (Awaiting AM Sign-off)"
        }).execute()

        return {
            "transfer_id": transfer_id,
            "transfer_type": t_type,
            "client_id": client_id,
            "client_name": client.name,
            "new_branch": dest_branch_name,
            "new_officer": "Pending Local Assignment",
            "status": ClientTransferStatus.PENDING_AM_APPROVAL.value,
            "message": f"Transfer request for {client.name} to {dest_branch_name} submitted successfully for Area Manager sign-off."
        }

    @staticmethod
    def get_incoming_transfers(
        uow: UnitOfWork,
        branch_id: str
    ) -> List[Dict[str, Any]]:
        """
        Retrieves pending incoming client transfers for a destination branch that have been
        approved by the Area Manager and are awaiting local assignment by the receiving BM.
        """
        res = uow.client.table("client_transfers") \
            .select("transfer_id, client_id, transfer_type, from_branch_id, to_branch_id, from_officer_id, reason, status, created_at, approved_at, notes, clients(name, client_code, savings_balance), from_b:branches!client_transfers_from_branch_id_fkey(name), from_o:app_users!client_transfers_from_officer_id_fkey(full_name, username)") \
            .eq("to_branch_id", branch_id) \
            .in_("status", [ClientTransferStatus.PENDING_RECEIVING_BM.value, "APPROVED"]) \
            .order("created_at", desc=True) \
            .execute()

        incoming = []
        for row in (res.data or []):
            c_info = row.get("clients") or {}
            sb_info = row.get("from_b") or {}
            so_info = row.get("from_o") or {}
            c_id = str(row.get("client_id"))

            # Calculate outstanding loan balance for this client
            outstanding_bal = 0.0
            try:
                loans_res = uow.client.table("loans").select("total_due").eq("client_id", c_id).in_("status", ["ACTIVE", "Active", "Approved", "Defaulter"]).execute()
                for l in (loans_res.data or []):
                    outstanding_bal += float(l.get("total_due") or 0.0)
            except Exception:
                pass

            incoming.append({
                "transfer_id": str(row.get("transfer_id")),
                "client_id": c_id,
                "client_name": c_info.get("name") or "Unknown Client",
                "client_code": c_info.get("client_code") or "",
                "source_branch_id": str(row.get("from_branch_id")),
                "source_branch_name": sb_info.get("name") or "Unknown Branch",
                "source_officer_name": so_info.get("full_name") or so_info.get("username") or "Previous Officer",
                "transfer_type": row.get("transfer_type") or "INTER_BRANCH",
                "outstanding_balance": outstanding_bal,
                "savings_balance": float(c_info.get("savings_balance") or 0.0),
                "reason": row.get("reason") or "Client relocation",
                "requested_at": str(row.get("created_at")),
                "approved_at": str(row.get("approved_at") or ""),
                "status": row.get("status")
            })

        return incoming

    @staticmethod
    def accept_incoming_transfer(
        uow: UnitOfWork,
        transfer_id: str,
        to_officer_id: str,
        to_group_id: Optional[str] = None,
        accepted_by: str = ""
    ) -> Dict[str, Any]:
        """
        Receiving Branch Manager accepts an incoming inter-branch client transfer and assigns
        the client to a local Credit Officer and Solidarity Group in the destination branch.
        Atomically executes the reassignment of the client record and all active loans.
        """
        res_tr = uow.client.table("client_transfers").select("*").eq("transfer_id", transfer_id).execute()
        if not res_tr.data:
            raise ICAREException(
                error_code="TRANSFER_NOT_FOUND",
                title="Transfer Request Not Found",
                message=f"No transfer request found with ID '{transfer_id}'.",
                action="Please verify the transfer request."
            )
        transfer = res_tr.data[0]

        if transfer.get("status") not in [ClientTransferStatus.PENDING_RECEIVING_BM.value, "APPROVED"]:
            raise ICAREException(
                error_code="INVALID_TRANSFER_STATUS",
                title="Invalid Transfer Status",
                message=f"Transfer request #{transfer_id[:8]} is not awaiting receiving branch assignment (Current status: {transfer.get('status')}).",
                action="Only transfers approved by the Area Manager can be accepted and assigned."
            )

        to_branch_id = transfer.get("to_branch_id")
        client_id = transfer.get("client_id")

        # Verify destination officer exists and is stationed at destination branch
        res_u = uow.client.table("app_users").select("id, username, full_name, branch_id").eq("id", to_officer_id).execute()
        if not res_u.data:
            raise ICAREException(
                error_code="OFFICER_NOT_FOUND",
                title="Credit Officer Not Found",
                message=f"Officer ID '{to_officer_id}' does not exist.",
                action="Please select an active Credit Officer stationed at this branch."
            )
        dest_user = res_u.data[0]
        dest_officer_name = dest_user.get("full_name") or dest_user.get("username")

        if str(dest_user.get("branch_id")) != str(to_branch_id):
            raise ICAREException(
                error_code="CLIENT_TRANSFER_BRANCH_MISMATCH",
                title="Officer Branch Mismatch",
                message=f"Credit Officer '{dest_officer_name}' is not stationed at this branch.",
                action="Please select a Credit Officer stationed at your branch."
            )

        # Verify destination branch name
        res_b = uow.client.table("branches").select("name").eq("branch_id", to_branch_id).execute()
        dest_branch_name = res_b.data[0].get("name") if res_b.data else "Branch"

        # If destination group is specified, verify it belongs to this branch
        if to_group_id:
            res_g = uow.client.table("groups").select("group_id, name, branch_id").eq("group_id", to_group_id).execute()
            if not res_g.data or str(res_g.data[0].get("branch_id")) != str(to_branch_id):
                raise ICAREException(
                    error_code="GROUP_BRANCH_MISMATCH",
                    title="Solidarity Group Mismatch",
                    message="The selected solidarity group does not belong to your branch.",
                    action="Please select a group belonging to your branch or choose Ungrouped."
                )

        client = uow.clients.find_by_id(client_id)
        client_name = client.name if client else "Client"

        now_iso = datetime.now().isoformat()

        # 1. Update client record (Preserves status_id, savings_balance, client_code)
        client_update = {
            "officer_id": to_officer_id,
            "branch_id": to_branch_id,
            "group_id": to_group_id or None,
            "updated_at": now_iso
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

        # 3. Finalize client_transfers record
        uow.client.table("client_transfers").update({
            "to_officer_id": to_officer_id,
            "to_group_id": to_group_id or None,
            "status": ClientTransferStatus.COMPLETED.value,
            "accepted_by": accepted_by or to_officer_id,
            "accepted_at": now_iso
        }).eq("transfer_id", transfer_id).execute()

        # 4. Audit Log
        uow.client.table("audit_logs").insert({
            "action": "CLIENT_TRANSFER_COMPLETED",
            "entity": "clients",
            "entity_id": client_id,
            "user_id": accepted_by or to_officer_id,
            "branch_id": to_branch_id,
            "details": f"Accepted and assigned transferred client {client_name} to officer {dest_officer_name} ({dest_branch_name})"
        }).execute()

        return {
            "transfer_id": transfer_id,
            "client_id": client_id,
            "client_name": client_name,
            "new_branch": dest_branch_name,
            "new_officer": dest_officer_name,
            "status": ClientTransferStatus.COMPLETED.value,
            "message": f"Client {client_name} successfully accepted and assigned to {dest_officer_name} ({dest_branch_name})."
        }

    @staticmethod
    def reject_transfer(
        uow: UnitOfWork,
        transfer_id: str,
        rejected_by: str,
        reason: str
    ) -> Dict[str, Any]:
        """
        Rejects a client transfer request.
        """
        if not reason or not reason.strip():
            raise ICAREException(
                error_code="REJECTION_REASON_REQUIRED",
                title="Rejection Reason Required",
                message="A valid reason must be stated for rejecting this client transfer.",
                action="Please provide a business explanation for rejection."
            )

        now_iso = datetime.now().isoformat()
        uow.client.table("client_transfers").update({
            "status": ClientTransferStatus.REJECTED.value,
            "rejected_by": rejected_by,
            "rejected_at": now_iso,
            "rejection_reason": reason.strip()
        }).eq("transfer_id", transfer_id).execute()

        uow.client.table("audit_logs").insert({
            "action": "CLIENT_TRANSFER_REJECTED",
            "entity": "client_transfers",
            "entity_id": transfer_id,
            "user_id": rejected_by,
            "details": f"Rejected client transfer #{transfer_id[:8]}. Reason: {reason.strip()}"
        }).execute()

        return {
            "transfer_id": transfer_id,
            "status": ClientTransferStatus.REJECTED.value,
            "message": f"Client transfer #{transfer_id[:8]} rejected."
        }
