"""
tests/test_enterprise_feature_enhancements.py
Comprehensive Verification Suite for Enterprise Enhancements:
1. BM Approval for Client Profile Updates
2. Automated 3-Month LAPS Sweep (Duration Limit & Non-Cash Invariant)
3. Loan Defaulter Status & 3-Default Rule Automation
4. Multi-Level Client Transfers (Intra-Branch, Inter-Branch, Inter-Area)
5. Centralized Error Framework & Actionable Messages
"""
import pytest
import uuid
from datetime import date, datetime, timedelta
from unittest.mock import MagicMock, patch

from domain.enums import LoanStatus, ClientStatus, ClientTransferType, ClientProfileUpdateStatus
from api.core.errors import ICAREException, translate_error_to_icare_response, ERROR_REGISTRY
from services.client_service import ClientService
from services.savings_service import SavingsService
from services.schedule_service import ScheduleService
from services.renewal_service import RenewalService


# =========================================================================
# FEATURE 1: BM APPROVAL FOR CLIENT PROFILE EDITS
# =========================================================================

def test_submit_client_update_request_and_bm_approval():
    """Verifies four-eyes review: CO submits request, BM approves and applies changes."""
    mock_uow = MagicMock()

    client_id = str(uuid.uuid4())
    branch_id = str(uuid.uuid4())
    co_id = "CO1_UUID"
    bm_id = "BM_UUID"

    # Mock client find
    mock_client = MagicMock()
    mock_client.client_id = client_id
    mock_client.branch_id = branch_id
    mock_client.name = "Original Client Name"
    mock_client.phone = "08011112222"
    mock_client.address = "123 Old St"
    mock_client.marital_status = "Single"
    mock_client.business_type = "Retail"
    mock_uow.clients.find_by_id.return_value = mock_client

    # Mock pending check (no pending requests currently)
    mock_pend_res = MagicMock(data=[])
    mock_uow.client.table().select().eq().eq().execute.return_value = mock_pend_res

    # 1. CO submits profile update request
    proposed_changes = {
        "name": "Updated Client Name",
        "phone": "08099998888",
        "address": "456 New Road",
        "marital_status": "Married",
        "business_type": "Wholesale"
    }

    sub_res = ClientService.submit_profile_update_request(
        uow=mock_uow,
        client_id=client_id,
        requested_by=co_id,
        branch_id=branch_id,
        proposed_changes=proposed_changes
    )

    assert sub_res["status"] == "PENDING_APPROVAL"
    assert "request_id" in sub_res

    # Verify insert into client_profile_update_requests
    mock_uow.client.table.assert_any_call("client_profile_update_requests")

    # 2. Duplicate submission prevention
    mock_uow.client.table().select().eq().eq().execute.return_value = MagicMock(data=[{"request_id": sub_res["request_id"]}])
    with pytest.raises(ICAREException) as exc_info:
        ClientService.submit_profile_update_request(
            uow=mock_uow,
            client_id=client_id,
            requested_by=co_id,
            branch_id=branch_id,
            proposed_changes=proposed_changes
        )
    assert exc_info.value.error_code == "CLIENT_EDIT_PENDING_APPROVAL"

    # 3. BM approves the request
    req_id = sub_res["request_id"]
    mock_req_data = [{
        "request_id": req_id,
        "client_id": client_id,
        "branch_id": branch_id,
        "status": ClientProfileUpdateStatus.PENDING.value,
        "proposed_changes": proposed_changes
    }]
    mock_uow.client.table().select().eq().execute.return_value = MagicMock(data=mock_req_data)

    app_res = ClientService.approve_profile_update_request(
        uow=mock_uow,
        request_id=req_id,
        approved_by=bm_id
    )

    assert app_res["status"] == "APPROVED"
    mock_uow.client.table.assert_any_call("clients")


def test_reject_client_update_request():
    """Verifies BM can reject request with a mandatory reason."""
    mock_uow = MagicMock()
    req_id = str(uuid.uuid4())

    # Rejection without reason must fail
    with pytest.raises(ICAREException) as exc_info:
        ClientService.reject_profile_update_request(
            uow=mock_uow,
            request_id=req_id,
            rejected_by="BM_UUID",
            reason=""
        )
    assert exc_info.value.error_code == "REJECTION_REASON_REQUIRED"

    # Valid rejection
    mock_req_data = [{
        "request_id": req_id,
        "client_id": "CLIENT_1",
        "branch_id": "BRANCH_1",
        "status": ClientProfileUpdateStatus.PENDING.value
    }]
    mock_uow.client.table().select().eq().execute.return_value = MagicMock(data=mock_req_data)

    rej_res = ClientService.reject_profile_update_request(
        uow=mock_uow,
        request_id=req_id,
        rejected_by="BM_UUID",
        reason="Information could not be verified by physical inspection."
    )
    assert rej_res["status"] == "REJECTED"


# =========================================================================
# FEATURE 2: AUTOMATIC 3-MONTH LAPS SWEEP
# =========================================================================

def test_automatic_laps_sweep_qualification_and_execution():
    """
    Verifies that only clients inactive for >= 90 days with positive individual savings
    are swept to LAPS, and Account 1000 is untouched.
    """
    mock_uow = MagicMock()
    today = date(2026, 10, 1)

    c1_id = str(uuid.uuid4()) # Inactive 120 days, bal 15,000 -> QUALIFIED
    c2_id = str(uuid.uuid4()) # Inactive 40 days, bal 10,000 -> NOT QUALIFIED (< 90 days)
    c3_id = str(uuid.uuid4()) # On Loan, bal 5,000 -> NOT QUALIFIED (Wrong status)
    c4_id = str(uuid.uuid4()) # Dormant 100 days, bal 0 -> NOT QUALIFIED (Zero balance)

    mock_clients = [
        {
            "client_id": c1_id,
            "name": "Dormant Client A",
            "client_code": "CL-001",
            "branch_id": "BRANCH_1",
            "status": "Inactive (Savings Only)",
            "status_changed_at": (today - timedelta(days=120)).isoformat(),
            "branches": {"name": "Ogijo"},
            "app_users": {"username": "CO1"}
        },
        {
            "client_id": c2_id,
            "name": "Recent Client B",
            "client_code": "CL-002",
            "branch_id": "BRANCH_1",
            "status": "Dormant",
            "status_changed_at": (today - timedelta(days=40)).isoformat(),
            "branches": {"name": "Ogijo"},
            "app_users": {"username": "CO1"}
        },
        {
            "client_id": c3_id,
            "name": "Active Borrower C",
            "client_code": "CL-003",
            "branch_id": "BRANCH_1",
            "status": "On Loan",
            "status_changed_at": (today - timedelta(days=120)).isoformat(),
            "branches": {"name": "Ogijo"},
            "app_users": {"username": "CO1"}
        },
        {
            "client_id": c4_id,
            "name": "Zero Balance D",
            "client_code": "CL-004",
            "branch_id": "BRANCH_1",
            "status": "Suspended",
            "status_changed_at": (today - timedelta(days=100)).isoformat(),
            "branches": {"name": "Ogijo"},
            "app_users": {"username": "CO1"}
        }
    ]

    mock_uow.client.table().select().execute.return_value = MagicMock(data=mock_clients)

    # Balance resolver
    def get_bal(client_id):
        if client_id == c1_id:
            return 15000.0
        elif client_id == c2_id:
            return 10000.0
        elif client_id == c3_id:
            return 5000.0
        return 0.0

    mock_uow.individual_savings.get_total_balance.side_effect = get_bal

    # 1. Test Preview
    candidates = SavingsService.preview_automatic_laps_sweep(
        uow=mock_uow,
        threshold_days=90,
        execution_date=today
    )

    assert len(candidates) == 1
    assert candidates[0]["client_id"] == c1_id
    assert candidates[0]["savings_balance"] == 15000.0
    assert candidates[0]["days_in_status"] == 120

    # 2. Test Execution
    with patch.object(SavingsService, "transfer_to_laps", return_value={"status": "success"}) as mock_transfer:
        res = SavingsService.process_automatic_laps_sweep(
            uow=mock_uow,
            threshold_days=90,
            execution_date=today
        )

        assert res["success"] is True
        assert res["swept_count"] == 1
        assert res["total_amount"] == 15000.0
        mock_transfer.assert_called_once()
        call_kwargs = mock_transfer.call_args[1]
        assert call_kwargs["client_id"] == c1_id
        assert call_kwargs["amount"] == 15000.0
        assert call_kwargs["source_savings_type"] == "IndividualSavings"


# =========================================================================
# FEATURE 3: LOAN DEFAULTER STATUS & 3-DEFAULT AUTOMATION
# =========================================================================

def test_loan_defaulter_3_missed_installments_automation():
    """Verifies that 3 or more missed installments trigger loan & client Defaulter transition."""
    mock_uow = MagicMock()
    loan_id = str(uuid.uuid4())
    client_id = str(uuid.uuid4())

    # Mock loan due breakdown returning 3 missed installments
    mock_breakdown = {
        "loan_id": loan_id,
        "client_id": client_id,
        "missed_installments_count": 3,
        "overdue_arrears": 7500.0,
        "remaining_balance": 25000.0
    }

    with patch.object(ScheduleService, "get_loan_due_breakdown", return_value=mock_breakdown):
        # Mock active loan
        mock_uow.client.table().select().eq().execute.return_value = MagicMock(data=[{
            "loan_id": loan_id,
            "status": "Active",
            "client_id": client_id
        }])

        from services.client_status_service import ClientStatusService
        with patch.object(ClientStatusService, "transition_status") as mock_trans:
            res = ScheduleService.evaluate_and_apply_loan_default(
                uow=mock_uow,
                loan_id=loan_id,
                evaluation_date=date(2026, 10, 1)
            )

            assert res["defaulted"] is True
            assert res["status"] == "Defaulter"
            assert res["missed_installments_count"] == 3

            # Verify loan updated to Defaulter
            mock_uow.client.table("loans").update.assert_called()

            # Verify client status transition triggered with trigger_type="SYSTEM"
            mock_trans.assert_called_once()
            trans_kwargs = mock_trans.call_args[1]
            assert trans_kwargs["client_id"] == client_id
            assert trans_kwargs["new_status_name"] == "Defaulter"
            assert trans_kwargs["trigger_type"] == "SYSTEM"


def test_renewal_warning_for_defaulter():
    """Verifies Defaulter status produces a non-blocking warning per BR-CLI-009."""
    mock_uow = MagicMock()
    client_id = str(uuid.uuid4())

    # Client has completed their past loan, but their lifecycle status is 'Defaulter'
    mock_uow.client.table().select().eq().execute.side_effect = [
        MagicMock(data=[]), # no active loans
        MagicMock(data=[{"status_id": "defaulter_uuid", "client_statuses": {"name": "Defaulter"}}]),
        MagicMock(data=[{"deposit_amount": 50000.0}]), # healthy savings deposits
        MagicMock(data=[{"withdrawal_amount": 0.0}]), # withdrawals
        MagicMock(data=[{"savings_requirement": 0.10}]) # product savings requirement
    ]

    is_eligible, reasons, warnings = RenewalService.check_eligibility(
        uow=mock_uow,
        client_id=client_id,
        requested_amount=100000.0,
        product_type="Weekly 12W",
        product_category="Finance"
    )

    # Must NOT block loan application (warning only per BR-CLI-009)
    assert is_eligible is True
    assert any("DEFAULTER WARNING" in w for w in warnings)


# =========================================================================
# FEATURE 4: MULTI-LEVEL CLIENT TRANSFERS
# =========================================================================

def test_client_transfers_multi_level():
    """Verifies intra-branch, inter-branch, and inter-area portfolio transfers."""
    mock_uow = MagicMock()

    client_id = str(uuid.uuid4())
    branch_1_id = str(uuid.uuid4())
    branch_2_id = str(uuid.uuid4())
    officer_1_id = str(uuid.uuid4())
    officer_2_id = str(uuid.uuid4())

    # Mock client find
    mock_client = MagicMock()
    mock_client.client_id = client_id
    mock_client.name = "Transferable Client"
    mock_client.branch_id = branch_1_id
    mock_client.officer_id = officer_1_id
    mock_client.group_id = "GROUP_1"
    mock_uow.clients.find_by_id.return_value = mock_client

    # 1. Intra-Branch Transfer (same branch, officer 1 -> officer 2)
    mock_uow.client.table().select().eq().execute.side_effect = [
        MagicMock(data=[{"branch_id": branch_1_id, "name": "Ogijo", "zone_id": "ZONE_A"}]), # dest branch
        MagicMock(data=[{"id": officer_2_id, "username": "CO2", "full_name": "Credit Officer 2", "branch_id": branch_1_id}]), # dest user
    ]

    res_intra = ClientService.transfer_client(
        uow=mock_uow,
        client_id=client_id,
        to_officer_id=officer_2_id,
        to_branch_id=branch_1_id,
        reason="Officer workload balancing",
        transferred_by="BM_USER"
    )

    assert res_intra["status"] == "COMPLETED"
    assert res_intra["transfer_type"] == ClientTransferType.INTRA_BRANCH.value
    assert res_intra["new_officer"] == "Credit Officer 2"

    # 2. Inter-Branch Transfer (branch 1 -> branch 2, different branch, same zone)
    mock_uow.client.table().select().eq().execute.side_effect = [
        MagicMock(data=[{"branch_id": branch_2_id, "name": "Ikorodu", "zone_id": "ZONE_A"}]), # dest branch
        MagicMock(data=[{"id": officer_2_id, "username": "IKO_CO1", "full_name": "Ikorodu Officer 1", "branch_id": branch_2_id}]), # dest user
        MagicMock(data=[{"zone_id": "ZONE_A"}]), # orig branch zone
    ]

    res_inter_b = ClientService.transfer_client(
        uow=mock_uow,
        client_id=client_id,
        to_officer_id=officer_2_id,
        to_branch_id=branch_2_id,
        reason="Client relocated residence to Ikorodu",
        transferred_by="AM_USER"
    )

    assert res_inter_b["status"] == "COMPLETED"
    assert res_inter_b["transfer_type"] == ClientTransferType.INTER_BRANCH.value

    # 3. Inter-Area Transfer (branch 1 Zone A -> branch 2 Zone B)
    mock_uow.client.table().select().eq().execute.side_effect = [
        MagicMock(data=[{"branch_id": branch_2_id, "name": "Abeokuta", "zone_id": "ZONE_B"}]), # dest branch
        MagicMock(data=[{"id": officer_2_id, "username": "ABK_CO1", "full_name": "Abeokuta Officer 1", "branch_id": branch_2_id}]), # dest user
        MagicMock(data=[{"zone_id": "ZONE_A"}]), # orig branch zone
    ]

    res_inter_a = ClientService.transfer_client(
        uow=mock_uow,
        client_id=client_id,
        to_officer_id=officer_2_id,
        to_branch_id=branch_2_id,
        reason="Client relocated to another area",
        transferred_by="ADMIN_USER"
    )

    assert res_inter_a["status"] == "COMPLETED"
    assert res_inter_a["transfer_type"] == ClientTransferType.INTER_AREA.value


# =========================================================================
# FEATURE 5: CENTRALIZED ERROR FRAMEWORK & MESSAGING
# =========================================================================

def test_centralized_error_translation():
    """Verifies that all technical and database exceptions produce human-friendly messages."""
    # 1. Custom ICAREException
    custom_exc = ICAREException(
        error_code="CUSTOM_TEST_ERROR",
        title="Custom Verification Error",
        message="This is a test explanation.",
        action="Take corrective action A."
    )
    res_1 = translate_error_to_icare_response(custom_exc)
    assert res_1["error_code"] == "CUSTOM_TEST_ERROR"
    assert res_1["title"] == "Custom Verification Error"
    assert res_1["action"] == "Take corrective action A."

    # 2. Postgres 23505 (Unique Constraint Violation)
    pg_23505 = Exception("duplicate key value violates unique constraint 'clients_client_code_key' (23505)")
    res_2 = translate_error_to_icare_response(pg_23505)
    assert res_2["error_code"] == "DB_DUPLICATE_ENTRY"
    assert "Duplicate Record Found" in res_2["title"]
    assert "unique code" in res_2["action"]

    # 3. Postgres 23503 (Foreign Key Violation)
    pg_23503 = Exception("insert or update on table 'clients' violates foreign key constraint 'clients_branch_id_fkey' (23503)")
    res_3 = translate_error_to_icare_response(pg_23503)
    assert res_3["error_code"] == "DB_FOREIGN_KEY_VIOLATION"
    assert "Reference Not Found" in res_3["title"]

    # 4. Cloudflare Worker / Connection Timeout
    cf_timeout = Exception("Cloudflare 500: worker threw exception during socket handshake")
    res_4 = translate_error_to_icare_response(cf_timeout)
    assert res_4["error_code"] == "DB_NETWORK_TIMEOUT"
    assert "Database Connection Timeout" in res_4["title"]
    assert "wait a moment and retry" in res_4["action"]

    # 5. Clean ValueError
    val_err = ValueError("Transfer amount must be greater than zero.")
    res_5 = translate_error_to_icare_response(val_err)
    assert res_5["error_code"] == "VALIDATION_ERROR"
    assert res_5["message"] == "Transfer amount must be greater than zero."
