"""
Priority 1 Financial Controls & Idempotency Ownership Test Suite.

Covers all Priority 1 invariants:
1. Mandatory idempotency_key on single-submit and batch-submit (HTTP 422 on missing/blank).
2. Strict BR-DATE-002 business-date control: rejects closed-date submissions by CO/BM/AM even with
   is_offline_sync=True, idempotency_key='offline-...', or is_late_entry=True.
3. Rejects non-Admin callers with is_late_entry=True even on open business dates (HTTP 403).
4. Allows Admin / Super Admin with is_late_entry=True on closed dates (HTTP 200).
5. RepaymentService.post_repayment rejects 'offline-...' key on closed dates when allow_closed_date=False.
6. Strict ownership & branch access checks on both transaction status endpoints:
   - /api/v1/transactions/status/{key}
   - /api/v1/co/collections/transaction/{key}
7. single-submit calls IdempotencyService.record_failure when save_repayments raises.
8. IdempotencyService.acquire_lock fails closed with 422 on blank key and 403 on ERR_IDEMPOTENCY_OWNERSHIP_VIOLATION.
"""

from datetime import date
import os
import sys
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from fastapi.testclient import TestClient
import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from api.dependencies import get_current_user, get_uow
from api.main import app
from domain.entities.repayment import Repayment
from models.user import CurrentUser
from services.idempotency_service import IdempotencyService
from services.rate_limiter import get_financial_rate_limiter
from services.repayment_service import RepaymentService


client = TestClient(app)


def _user(
    user_id: str,
    username: str,
    role: str,
    branch_id: str = "br-ogijo-01",
    branch: str = "Ogijo",
    assigned_branch_ids=None,
) -> CurrentUser:
    return CurrentUser(
        id=user_id,
        username=username,
        full_name=username,
        role=role,
        branch_id=branch_id,
        branch=branch,
        assigned_branch_ids=assigned_branch_ids or [],
    )


def _mock_client_branch_uow(branch_id: str = "br-ogijo-01") -> MagicMock:
    uow = MagicMock()
    uow.client.rpc.return_value.execute.return_value.data = {"action": "PROCEED", "status": "NEW"}

    def fake_table(name: str):
        tbl = MagicMock()
        if name == "clients":
            tbl.select.return_value.eq.return_value.execute.return_value.data = [
                {"client_id": "cli-001", "branch_id": branch_id}
            ]
            tbl.select.return_value.in_.return_value.execute.return_value.data = [
                {"client_id": "cli-001", "branch_id": branch_id}
            ]
        elif name == "branches":
            tbl.select.return_value.eq.return_value.execute.return_value.data = [
                {"name": "Ogijo", "branch_id": branch_id}
            ]
        elif name == "groups":
            tbl.select.return_value.eq.return_value.eq.return_value.execute.return_value.data = []
        return tbl

    uow.client.table.side_effect = fake_table
    return uow


@pytest.fixture(autouse=True)
def reset_overrides():
    app.dependency_overrides.clear()
    get_financial_rate_limiter().clear_all()
    yield
    app.dependency_overrides.clear()
    get_financial_rate_limiter().clear_all()


class TestMandatoryIdempotencyKey:
    def test_single_submit_rejects_missing_and_blank_idempotency_key(self):
        uow = _mock_client_branch_uow()
        co = _user("co-1", "co_ogijo", "CO")
        app.dependency_overrides[get_uow] = lambda: uow
        app.dependency_overrides[get_current_user] = lambda: co

        base_payload = {
            "client_id": "cli-001",
            "client_name": "Amina Bello",
            "loan_repayment": 2500.0,
        }
        res_missing = client.post("/api/v1/co/collections/single-submit", json=base_payload)
        assert res_missing.status_code == 422

        res_blank = client.post(
            "/api/v1/co/collections/single-submit",
            json={**base_payload, "idempotency_key": "   "},
        )
        assert res_blank.status_code == 422

    def test_batch_submit_rejects_missing_and_blank_idempotency_key(self):
        uow = _mock_client_branch_uow()
        co = _user("co-1", "co_ogijo", "CO")
        app.dependency_overrides[get_uow] = lambda: uow
        app.dependency_overrides[get_current_user] = lambda: co

        base_payload = {
            "group_name": "Unity Group",
            "collections": [
                {"client_id": "cli-001", "client_name": "Amina Bello", "loan_repayment_amount": 2500.0}
            ],
        }
        res_missing = client.post("/api/v1/co/collections/batch-submit", json=base_payload)
        assert res_missing.status_code == 422

        res_blank = client.post(
            "/api/v1/co/collections/batch-submit",
            json={**base_payload, "idempotency_key": "  \t  "},
        )
        assert res_blank.status_code == 422


class TestStrictBusinessDateControl:
    @pytest.mark.parametrize("role", ["CO", "Branch Manager", "Area Manager"])
    @pytest.mark.parametrize(
        "bypass_fields",
        [
            {"idempotency_key": "offline-sync-001", "is_offline_sync": True, "is_late_entry": False},
            {"idempotency_key": "IDEM-REG-001", "is_offline_sync": False, "is_late_entry": True},
            {"idempotency_key": "offline-reg-002", "is_offline_sync": False, "is_late_entry": False},
        ],
    )
    def test_single_and_batch_reject_closed_date_for_non_admin(self, role, bypass_fields):
        uow = _mock_client_branch_uow("br-ogijo-01")
        caller = _user("usr-1", "staff_user", role, branch_id="br-ogijo-01", assigned_branch_ids=["br-ogijo-01"])
        app.dependency_overrides[get_uow] = lambda: uow
        app.dependency_overrides[get_current_user] = lambda: caller

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(False, "Closed for Day Close")):
            res_sc = client.post(
                "/api/v1/co/collections/single-submit",
                json={
                    "client_id": "cli-001",
                    "client_name": "Amina Bello",
                    "loan_repayment": 2500.0,
                    "date": "2026-11-18",
                    **bypass_fields,
                },
            )
            assert res_sc.status_code == 403

            res_batch = client.post(
                "/api/v1/co/collections/batch-submit",
                json={
                    "group_name": "Unity Group",
                    "date": "2026-11-18",
                    "collections": [
                        {"client_id": "cli-001", "client_name": "Amina Bello", "loan_repayment_amount": 2500.0}
                    ],
                    **bypass_fields,
                },
            )
            assert res_batch.status_code == 403

    @pytest.mark.parametrize("role", ["CO", "Branch Manager", "Area Manager"])
    def test_non_admin_is_late_entry_rejected_even_on_open_date(self, role):
        uow = _mock_client_branch_uow("br-ogijo-01")
        caller = _user("usr-1", "staff_user", role, branch_id="br-ogijo-01", assigned_branch_ids=["br-ogijo-01"])
        app.dependency_overrides[get_uow] = lambda: uow
        app.dependency_overrides[get_current_user] = lambda: caller

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")):
            res_sc = client.post(
                "/api/v1/co/collections/single-submit",
                json={
                    "client_id": "cli-001",
                    "client_name": "Amina Bello",
                    "loan_repayment": 2500.0,
                    "date": "2026-11-18",
                    "idempotency_key": "IDEM-OPEN-LATE-SC-1",
                    "is_late_entry": True,
                },
            )
            assert res_sc.status_code == 403

            res_batch = client.post(
                "/api/v1/co/collections/batch-submit",
                json={
                    "group_name": "Unity Group",
                    "date": "2026-11-18",
                    "idempotency_key": "IDEM-OPEN-LATE-BATCH-1",
                    "is_late_entry": True,
                    "collections": [
                        {"client_id": "cli-001", "client_name": "Amina Bello", "loan_repayment_amount": 2500.0}
                    ],
                },
            )
            assert res_batch.status_code == 403

    @pytest.mark.parametrize("admin_role", ["Admin", "Super Admin"])
    def test_admin_late_entry_allowed_on_closed_date(self, admin_role):
        uow = _mock_client_branch_uow("br-ogijo-01")
        admin = _user("adm-1", "sys_admin", admin_role, branch_id="br-ho-01", branch="Head Office")
        app.dependency_overrides[get_uow] = lambda: uow
        app.dependency_overrides[get_current_user] = lambda: admin

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(False, "Closed for Day Close")), \
             patch("services.collection_batch_service.save_repayments", return_value={"batch_id": "B-1", "total_repayment": 2500.0, "total_savings": 0.0, "total_cash": 2500.0}) as mock_save:
            res_sc = client.post(
                "/api/v1/co/collections/single-submit",
                json={
                    "client_id": "cli-001",
                    "client_name": "Amina Bello",
                    "loan_repayment": 2500.0,
                    "date": "2026-11-18",
                    "idempotency_key": f"IDEM-ADMIN-SC-{admin_role}",
                    "is_late_entry": True,
                },
            )
            assert res_sc.status_code == 200
            assert mock_save.call_args.kwargs.get("allow_closed_date") is True

            res_batch = client.post(
                "/api/v1/co/collections/batch-submit",
                json={
                    "group_name": "Unity Group",
                    "date": "2026-11-18",
                    "idempotency_key": f"IDEM-ADMIN-BATCH-{admin_role}",
                    "is_late_entry": True,
                    "collections": [
                        {"client_id": "cli-001", "client_name": "Amina Bello", "loan_repayment_amount": 2500.0}
                    ],
                },
            )
            assert res_batch.status_code == 200
            assert mock_save.call_args.kwargs.get("allow_closed_date") is True

    def test_repayment_service_rejects_offline_prefix_on_closed_date(self):
        uow = MagicMock()
        rep = Repayment(
            id="rep-test-1",
            loan_id="loan-1",
            client_id="cli-001",
            amount_paid=2500.0,
            savings_amount=0.0,
            loan_repayment_amount=2500.0,
            withdrawal_amount=0.0,
            others_amount=0.0,
            recovery_amount=0.0,
            initial_payment=0.0,
            payment_date=date(2026, 11, 18),
            transaction_type="Loan",
            branch="Ogijo",
            credit_officer="co_ogijo",
            idempotency_key="offline-fake-bypass-001",
        )
        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(False, "Closed Date")):
            with pytest.raises(ValueError, match="Operational Restriction"):
                RepaymentService.post_repayment(uow, rep, allow_closed_date=False)


class TestTransactionStatusAccessControl:
    @pytest.mark.parametrize(
        "endpoint_template",
        [
            "/api/v1/transactions/status/{key}",
            "/api/v1/co/collections/transaction/{key}",
        ],
    )
    def test_status_endpoints_enforce_ownership_and_branch_scope(self, endpoint_template):
        owned_record = {
            "key": "IDEM-OWNED-001",
            "scope": "batch_collection",
            "status": "COMMITTED",
            "user_id": "co-owner",
            "branch_id": "br-ogijo-01",
            "response_code": 200,
            "response_body": {"batch_id": "B-1", "secret_customer_data": "PII"},
            "created_at": "2026-11-18T10:00:00Z",
            "locked_at": "2026-11-18T10:00:01Z",
        }
        legacy_unowned_record = {
            "key": "IDEM-LEGACY-001",
            "scope": "batch_collection",
            "status": "COMMITTED",
            "user_id": None,
            "branch_id": None,
            "response_code": 200,
            "response_body": {"batch_id": "B-LEGACY"},
            "created_at": "2026-11-18T10:00:00Z",
            "locked_at": "2026-11-18T10:00:01Z",
        }

        cases = [
            (_user("co-owner", "co1", "CO", "br-ogijo-01"), owned_record, 200),
            (_user("co-other", "co2", "CO", "br-ogijo-01"), owned_record, 403),
            (_user("bm-other", "bm2", "Branch Manager", "br-ikorodu-01"), owned_record, 403),
            (_user("bm-same", "bm1", "Branch Manager", "br-ogijo-01"), owned_record, 200),
            (_user("am-yes", "am1", "Area Manager", "br-other", assigned_branch_ids=["br-ogijo-01"]), owned_record, 200),
            (_user("am-no", "am2", "Area Manager", "br-other", assigned_branch_ids=["br-kola-01"]), owned_record, 403),
            (_user("adm-1", "admin1", "Admin", "br-ho-01"), owned_record, 200),
            (_user("co-owner", "co1", "CO", "br-ogijo-01"), legacy_unowned_record, 403),
            (_user("adm-1", "admin1", "Admin", "br-ho-01"), legacy_unowned_record, 200),
        ]

        for caller, rec, expected_status in cases:
            mock_uow = MagicMock()
            app.dependency_overrides[get_uow] = lambda u=mock_uow: u
            app.dependency_overrides[get_current_user] = lambda usr=caller: usr

            with patch("services.idempotency_service.IdempotencyService.get_transaction_status", return_value=rec):
                url = endpoint_template.format(key=rec["key"])
                res = client.get(url)
                assert res.status_code == expected_status, f"{caller.role}/{caller.id} expected {expected_status} on {url}, got {res.status_code}"


class TestIdempotencyServiceFailuresAndLocks:
    def test_single_submit_records_failure_when_save_repayments_raises(self):
        uow = _mock_client_branch_uow("br-ogijo-01")
        co = _user("co-1", "co_ogijo", "CO", branch_id="br-ogijo-01")
        app.dependency_overrides[get_uow] = lambda: uow
        app.dependency_overrides[get_current_user] = lambda: co

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("services.idempotency_service.IdempotencyService.acquire_lock", return_value={"action": "PROCEED", "status": "NEW"}) as mock_acq, \
             patch("services.idempotency_service.IdempotencyService.record_failure") as mock_fail, \
             patch("services.collection_batch_service.save_repayments", side_effect=RuntimeError("Ledger write failed")):
            with pytest.raises(RuntimeError, match="Ledger write failed"):
                client.post(
                    "/api/v1/co/collections/single-submit",
                    json={
                        "client_id": "cli-001",
                        "client_name": "Amina Bello",
                        "loan_repayment": 2500.0,
                        "idempotency_key": "IDEM-FAIL-RECORD-001",
                    },
                )

            assert mock_acq.call_count == 1
            assert mock_acq.call_args.kwargs.get("user_id") == "co-1"
            assert mock_acq.call_args.kwargs.get("branch_id") == "br-ogijo-01"
            mock_fail.assert_called_once()
            assert mock_fail.call_args[0][1] == "IDEM-FAIL-RECORD-001"

    def test_acquire_lock_rejects_blank_key_with_422_and_ownership_violation_with_403(self):
        uow = MagicMock()

        with pytest.raises(HTTPException) as blank_exc:
            IdempotencyService.acquire_lock(uow, "   ", "batch_collection", {"x": 1})
        assert blank_exc.value.status_code == 422

        uow.client.rpc.return_value.execute.side_effect = Exception(
            "ERR_IDEMPOTENCY_OWNERSHIP_VIOLATION: Idempotency key IDEM-1 belongs to another user"
        )
        with pytest.raises(HTTPException) as own_exc:
            IdempotencyService.acquire_lock(
                uow,
                "IDEM-1",
                "batch_collection",
                {"x": 1},
                user_id="co-2",
                branch_id="br-ogijo-01",
            )
        assert own_exc.value.status_code == 403
