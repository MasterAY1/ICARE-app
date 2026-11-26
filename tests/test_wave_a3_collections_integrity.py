"""
Wave A.3 unit tests for Daily Collections backend integrity:
1. Multi-loan -L2 batch submit preserves explicit loan_id and strips synthetic client suffix.
2. CollectionBatchService.save_repayment passes include_extra_fields=False to RepaymentService.post_repayment
   and commits savings, repayment, and fees in a single atomic_execute_operations RPC call.
3. get_collections_history handles 0 repayments (only savings deposits) without UnboundLocalError on off_disp,
   and populates client_id, group_name, and officer accurately.
4. RepaymentService.reverse_repayment atomically reverts Completed loan/client statuses back to Active / On Loan.
"""
import os
import sys
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi.testclient import TestClient

from api.dependencies import get_current_user, get_uow
from api.main import app
from auth.authorization import PERMISSIONS
from auth.session import generate_session_token
from models.user import CurrentUser
from services import collection_batch_service
from services.repayment_service import RepaymentService


client = TestClient(app)
USER_UUID = "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
BRANCH_UUID = "b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22"
TOKEN = generate_session_token(USER_UUID, "co_ayomide")
HEADERS = {"Authorization": f"Bearer {TOKEN}"}


class _FluentQuery:
    """Reusable fluent Supabase query stub returning fixed data on execute()."""

    def __init__(self, data=None):
        self._data = data if data is not None else []

    def __getattr__(self, name):
        def _chain(*args, **kwargs):
            return self
        return _chain

    def execute(self):
        res = MagicMock()
        res.data = self._data
        return res


def _build_co_user() -> CurrentUser:
    return CurrentUser(
        id=USER_UUID,
        username="co_ayomide",
        full_name="Ayomide CO",
        role="Credit Officer",
        branch="Ogijo",
        branch_id=BRANCH_UUID,
        permissions=PERMISSIONS.get("Credit Officer", set()),
    )


def test_multi_loan_l2_batch_submit_preserves_loan_id():
    """-L2 synthetic client IDs must strip cleanly for client lookup while preserving explicit loan_id."""
    assert collection_batch_service._strip_client_suffix("CL-001-L2") == "CL-001"
    assert collection_batch_service._strip_client_suffix("CL-001-ASSET") == "CL-001"

    mock_uow = MagicMock()
    mock_user = _build_co_user()
    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: mock_user

    try:
        mock_uow.cashbook._resolve_branch_id.return_value = BRANCH_UUID
        mock_uow.loans._resolve_officer_id.return_value = USER_UUID
        mock_uow.__enter__.return_value = mock_uow
        mock_uow.__exit__.return_value = False

        def fake_table(name):
            if name == "clients":
                return _FluentQuery([
                    {
                        "client_id": "client-uuid-1",
                        "client_code": "CL-001",
                        "branch_id": BRANCH_UUID,
                    }
                ])
            if name == "branches":
                return _FluentQuery([{"branch_id": BRANCH_UUID, "name": "Ogijo"}])
            if name == "groups":
                return _FluentQuery([{"group_id": "grp-uuid-1", "officer_id": USER_UUID}])
            if name == "app_users":
                return _FluentQuery([{"username": "co_ayomide", "id": USER_UUID}])
            if name == "loans":
                return _FluentQuery([])
            return _FluentQuery([])

        mock_uow.client.table.side_effect = fake_table
        mock_uow.client.rpc.return_value.execute.return_value.data = {"action": "PROCEED", "status": "NEW"}

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
             patch("services.collection_batch_service.unit_of_work.SupabaseUnitOfWork", return_value=mock_uow), \
             patch("services.collection_batch_service.save_repayment") as mock_save_rep:
            payload = {
                "group_name": "Market Group",
                "idempotency_key": "IDEM-WAVE-A3-L2-001",
                "collections": [
                    {
                        "client_id": "CL-001-L2",
                        "loan_id": "loan-uuid-2",
                        "client_name": "Balogun Kudirat",
                        "loan_product": "Daily 60 Days",
                        "loan_repayment_amount": 4000.0,
                        "savings_deposit_amount": 500.0,
                        "expected_amount": 4000.0,
                    }
                ],
            }

            res = client.post("/api/v1/co/collections/batch-submit", json=payload, headers=HEADERS)
            assert res.status_code == 200
            mock_save_rep.assert_called_once()
            passed_item = mock_save_rep.call_args[0][0]
            assert passed_item["loan_id"] == "loan-uuid-2"
            assert passed_item["Client ID"] == "CL-001-L2"
    finally:
        app.dependency_overrides.clear()


def test_save_repayment_passes_include_extra_fields_false_for_single_rpc():
    """save_repayment must pass include_extra_fields=False & defer_operations so savings/fees/repayment share 1 RPC."""
    mock_uow = MagicMock()
    mock_uow.loans._resolve_branch_id.return_value = BRANCH_UUID
    mock_uow.loans._resolve_officer_id.return_value = USER_UUID
    mock_uow.cashbook.rebuild_projection.return_value = None

    def fake_table(name):
        if name == "clients":
            return _FluentQuery([{"client_id": "client-uuid-1"}])
        if name == "branches":
            return _FluentQuery([{"branch_id": BRANCH_UUID, "name": "Ogijo"}])
        if name == "loans":
            return _FluentQuery([
                {
                    "loan_id": "loan-uuid-1",
                    "product_category": "Daily 60 Days",
                    "active_credit": 20000.0,
                    "extra_fields": None,
                }
            ])
        if name == "groups":
            return _FluentQuery([{"group_id": "grp-uuid-1"}])
        if name == "app_users":
            return _FluentQuery([{"id": USER_UUID, "username": "co_ayomide"}])
        return _FluentQuery([])

    mock_uow.client.table.side_effect = fake_table

    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
         patch("services.repayment_service.RepaymentService.post_repayment") as mock_post_rep, \
         patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_event, \
         patch("services.collection_performance_service.CollectionPerformanceService.record_meeting_collection"):
        mock_post_event.side_effect = lambda *args, **kwargs: (
            "tx-deferred-id",
            {"type": "insert", "table": "financial_transactions", "record": {"id": "tx-deferred-id"}},
        )

        data = {
            "Client ID": "CL-001-L2",
            "loan_id": "loan-uuid-2",
            "Client Name": "Kudirat",
            "Group": "Market Group",
            "Loan Product": "Daily 60 Days",
            "Loan Repayment Amount": 5000.0,
            "Savings Amount": 1000.0,
            "App Fee": 500.0,
            "Expected Amount": 5000.0,
            "Date": "2026-11-15",
            "Officer": "co_ayomide",
            "Branch": "Ogijo",
        }

        collection_batch_service.save_repayment(data, override_uow=mock_uow)

        mock_post_rep.assert_called_once()
        repayment_arg = mock_post_rep.call_args[0][1]
        assert repayment_arg.loan_id == "loan-uuid-2"
        kwargs = mock_post_rep.call_args.kwargs
        assert kwargs["include_extra_fields"] is False
        assert isinstance(kwargs["defer_operations"], list)
        mock_uow.client.rpc.assert_called_once()
        rpc_name, rpc_args = mock_uow.client.rpc.call_args[0]
        assert rpc_name == "atomic_execute_operations"
        tables = [op.get("table") for op in rpc_args["p_operations"]]
        assert "individual_savings" in tables
        assert "fees" in tables


def test_collections_history_handles_zero_repayments_without_off_disp_error():
    """History with 0 repayments and 1 savings deposit must not crash on off_disp and must preserve metadata."""
    mock_uow = MagicMock()
    mock_user = _build_co_user()
    app.dependency_overrides[get_uow] = lambda: mock_uow
    app.dependency_overrides[get_current_user] = lambda: mock_user

    try:
        mock_uow.cashbook._resolve_branch_id.return_value = BRANCH_UUID
        mock_uow.loans._resolve_officer_id.return_value = USER_UUID

        def fake_table(name):
            if name == "groups":
                return _FluentQuery([{"group_id": "grp-uuid-1", "name": "Victory Group"}])
            if name == "app_users":
                return _FluentQuery([{"id": USER_UUID, "username": "co_ayomide", "full_name": "Ayomide CO"}])
            if name == "repayments":
                return _FluentQuery([])
            if name == "individual_savings":
                class _SavQuery(_FluentQuery):
                    def lt(self, col, val):
                        # Negative reversal query must return empty
                        return _FluentQuery([])

                return _SavQuery([
                    {
                        "id": "sav-row-1",
                        "client_id": "client-uuid-9",
                        "deposit_amount": 2500.0,
                        "withdrawal_amount": 0.0,
                        "posting_date": "2026-11-15",
                        "created_at": "2026-11-15T09:15:00+00:00",
                        "reference": "SAV-REF-1",
                        "officer_id": USER_UUID,
                        "remarks": "Weekly savings deposit",
                        "clients": {
                            "name": "Amina Lawal",
                            "client_code": "OGI-009",
                            "group_id": "grp-uuid-1",
                            "groups": {"name": "Victory Group"},
                        },
                    }
                ])
            return _FluentQuery([])

        mock_uow.client.table.side_effect = fake_table

        res = client.get("/api/v1/co/collections/history?date_str=2026-11-15", headers=HEADERS)
        assert res.status_code == 200
        body = res.json()
        assert body["total_repayments"] == 0.0
        assert body["total_savings"] == 2500.0
        assert len(body["savings"]) == 1
        row = body["savings"][0]
        assert row["officer"] == "co_ayomide"
        assert row["client_id"] == "client-uuid-9"
        assert row["group_name"] == "Victory Group"
        assert row["deposit_amount"] == 2500.0
    finally:
        app.dependency_overrides.clear()


def test_reverse_repayment_atomically_reverts_completed_loan_and_client_status():
    """Reversing a payoff repayment on a Completed loan must revert loan->Active and client->On Loan atomically."""
    mock_uow = MagicMock()
    orig_rep = {
        "id": "rep-payoff-1",
        "loan_id": "loan-uuid-1",
        "client_id": "client-uuid-1",
        "amount_paid": 5000.0,
        "expected_amount": 5000.0,
        "branch_id": BRANCH_UUID,
        "officer_id": USER_UUID,
        "date": "2026-11-15T10:00:00+00:00",
        "note": "Final installment",
    }

    def fake_table(name):
        if name == "repayments":
            class _RepQuery(_FluentQuery):
                def eq(self, col, val):
                    if col == "id" and val == "rep-payoff-1":
                        return _FluentQuery([orig_rep])
                    if col == "loan_id":
                        return _FluentQuery([
                            {"id": "rep-prev-1", "amount_paid": 15000.0},
                            {"id": "rep-payoff-1", "amount_paid": 5000.0},
                        ])
                    return self

                def lt(self, *args, **kwargs):
                    return _FluentQuery([])

            return _RepQuery([orig_rep])
        if name == "loans":
            return _FluentQuery([
                {
                    "loan_id": "loan-uuid-1",
                    "client_id": "client-uuid-1",
                    "status": "Completed",
                    "active_credit": 0.0,
                    "total_due": 20000.0,
                    "loan_amount": 18000.0,
                    "product_id": "prod-1",
                    "loan_products": {"name": "Daily 60 Days"},
                }
            ])
        if name == "clients":
            return _FluentQuery([{"status": "Completed"}])
        if name == "client_statuses":
            return _FluentQuery([{"status_id": "status-on-loan-uuid", "name": "On Loan"}])
        if name == "loan_schedule":
            return _FluentQuery([
                {
                    "id": "sch-1",
                    "installment_number": 1,
                    "due_amount": 5000.0,
                    "paid_amount": 5000.0,
                    "status": "Paid",
                }
            ])
        return _FluentQuery([])

    mock_uow.client.table.side_effect = fake_table

    from services.client_status_service import ClientStatusService
    ClientStatusService._status_cache.clear()
    ClientStatusService._status_by_id_cache.clear()

    with patch("services.posting_engine.FinancialPostingEngine.post_event") as mock_post_ev:
        mock_post_ev.return_value = (
            "rev-tx-uuid",
            {"type": "insert", "table": "financial_transactions", "record": {"id": "rev-tx-uuid"}},
        )

        RepaymentService.reverse_repayment(
            mock_uow,
            original_repayment_id="rep-payoff-1",
            reason="Wrong client posted",
            reversed_by="bm-uuid-1",
            reversal_date="2026-11-15",
        )

        mock_uow.client.rpc.assert_called_once()
        rpc_name, rpc_args = mock_uow.client.rpc.call_args[0]
        assert rpc_name == "atomic_execute_operations"
        ops = rpc_args["p_operations"]

        loan_updates = [op for op in ops if op.get("type") == "update" and op.get("table") == "loans"]
        assert any(op.get("record", {}).get("status") == "Active" for op in loan_updates)

        client_updates = [op for op in ops if op.get("type") == "update" and op.get("table") == "clients"]
        assert any(op.get("record", {}).get("status") == "On Loan" for op in client_updates)

        sched_updates = [op for op in ops if op.get("type") == "update" and op.get("table") == "loan_schedule"]
        assert len(sched_updates) == 1


def test_save_repayment_rejects_repayment_and_not_paid_when_client_has_no_active_loan():
    """Loanless clients must fail closed cleanly rather than hitting SQL ERR_REPAYMENT_INSERT_PAYLOAD."""
    import pytest

    def _build_loanless_uow():
        mock_uow = MagicMock()
        mock_uow.loans._resolve_branch_id.return_value = BRANCH_UUID
        mock_uow.loans._resolve_officer_id.return_value = USER_UUID

        def fake_table(name):
            if name == "clients":
                return _FluentQuery([{"client_id": "client-uuid-loanless"}])
            if name == "branches":
                return _FluentQuery([{"branch_id": BRANCH_UUID, "name": "Ogijo"}])
            if name == "groups":
                return _FluentQuery([{"group_id": "grp-uuid-1"}])
            if name == "app_users":
                return _FluentQuery([{"id": USER_UUID, "username": "co_ayomide"}])
            if name == "loans":
                return _FluentQuery([])
            return _FluentQuery([])

        mock_uow.client.table.side_effect = fake_table
        return mock_uow

    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        # Case A: Cash loan repayment entered for loanless client
        uow_a = _build_loanless_uow()
        with pytest.raises(ValueError, match="does not have an active loan"):
            collection_batch_service.save_repayment(
                {
                    "Client ID": "client-uuid-loanless",
                    "Client Name": "Favour Member",
                    "Group": "Favour",
                    "Loan Repayment Amount": 2000.0,
                    "Savings Amount": 0.0,
                    "Date": "2026-11-24",
                    "Officer": "co_ayomide",
                    "Branch": "Ogijo",
                },
                override_uow=uow_a,
            )
        uow_a.client.rpc.assert_not_called()

        # Case B: Unpaid (NOT_PAID) mark submitted for loanless client
        uow_b = _build_loanless_uow()
        with pytest.raises(ValueError, match="does not have an active loan"):
            collection_batch_service.save_repayment(
                {
                    "Client ID": "client-uuid-loanless",
                    "Client Name": "Favour Member",
                    "Group": "Favour",
                    "Loan Repayment Amount": 0.0,
                    "mark_not_paid": True,
                    "Payment Status": "NOT_PAID",
                    "Date": "2026-11-24",
                    "Officer": "co_ayomide",
                    "Branch": "Ogijo",
                },
                override_uow=uow_b,
            )
        uow_b.client.rpc.assert_not_called()


def test_repayment_service_resolves_loan_before_prepare_and_fails_closed_when_missing():
    """RepaymentService must resolve loan_id before building the DB insert payload and fail closed if None."""
    from datetime import date
    import pytest
    from domain.entities.repayment import Repayment

    # 1. Resolved before _prepare_db_data
    mock_uow = MagicMock()
    mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    mock_uow.repayments._resolve_loan_id.return_value = "resolved-loan-uuid"
    mock_uow.repayments._prepare_db_data.side_effect = lambda rep_obj: {
        "id": rep_obj.id,
        "client_id": rep_obj.client_id,
        "loan_id": rep_obj.loan_id,
        "branch_id": BRANCH_UUID,
        "amount_paid": rep_obj.amount_paid,
    }

    rep_ok = Repayment(
        id="rep-resolve-1",
        loan_id="",
        client_id="client-uuid-1",
        amount_paid=0.0,
        savings_amount=0.0,
        loan_repayment_amount=0.0,
        withdrawal_amount=0.0,
        others_amount=0.0,
        recovery_amount=0.0,
        initial_payment=0.0,
        payment_date=date(2026, 11, 24),
        transaction_type="Loan",
        branch="Ogijo",
        credit_officer="co_ayomide",
        payment_status="NOT_PAID",
        expected_amount=2000.0,
        overdue_amount=2000.0,
    )
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
         patch("services.client_status_service.ClientStatusService.on_loan_repayment_check"):
        RepaymentService.post_repayment(mock_uow, rep_ok)

    rpc_ops = mock_uow.client.rpc.call_args[0][1]["p_operations"]
    rep_inserts = [op for op in rpc_ops if op.get("table") == "repayments"]
    assert len(rep_inserts) == 1
    assert rep_inserts[0]["record"]["loan_id"] == "resolved-loan-uuid"

    # 2. Missing loan fails closed without invoking atomic RPC
    mock_uow_missing = MagicMock()
    mock_uow_missing.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = []
    mock_uow_missing.repayments._resolve_loan_id.return_value = None
    mock_uow_missing.repayments._prepare_db_data.side_effect = lambda rep_obj: {
        "id": rep_obj.id,
        "client_id": rep_obj.client_id,
        "loan_id": None,
        "branch_id": BRANCH_UUID,
        "amount_paid": rep_obj.amount_paid,
    }
    rep_bad = Repayment(
        id="rep-missing-1",
        loan_id=None,
        client_id="client-uuid-loanless",
        amount_paid=2000.0,
        savings_amount=0.0,
        loan_repayment_amount=2000.0,
        withdrawal_amount=0.0,
        others_amount=0.0,
        recovery_amount=0.0,
        initial_payment=0.0,
        payment_date=date(2026, 11, 24),
        transaction_type="Loan",
        branch="Ogijo",
        credit_officer="co_ayomide",
    )
    with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")):
        with pytest.raises(ValueError, match="does not have an active loan"):
            RepaymentService.post_repayment(mock_uow_missing, rep_bad)
    mock_uow_missing.client.rpc.assert_not_called()


def test_translate_error_scrubs_err_repayment_insert_payload():
    """Error translator must never leak internal ERR_REPAYMENT_INSERT_PAYLOAD or SQL columns."""
    from api.core.errors import translate_error_to_icare_response

    exc = Exception(
        "{'message': 'ERR_REPAYMENT_INSERT_PAYLOAD: amount_paid, loan_id, client_id, and branch_id are required', 'code': 'P0001'}"
    )
    res = translate_error_to_icare_response(exc)
    assert res["error_code"] == "REPAYMENT_MISSING_LOAN_CONTEXT"
    assert "ERR_REPAYMENT_INSERT_PAYLOAD" not in res["message"]
    assert "amount_paid" not in res["message"]
    assert "loan_id" not in res["message"]
