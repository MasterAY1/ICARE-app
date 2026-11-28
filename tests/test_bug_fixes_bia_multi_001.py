from datetime import date, datetime, timezone
from unittest.mock import MagicMock, patch
import pytest
from fastapi import HTTPException

from api.routes.co.collections import (
    get_single_client_options,
    submit_single_client,
    submit_batch_collections,
)
from api.schemas.collections import SingleClientSubmitInput
from api.schemas.financial_writes import BatchCollectionInput, BatchCollectionItem
from models.user import CurrentUser
from services.business_date_service import BusinessDateService
from services.correction_service import CorrectionService
from services.onboarding_service import OnboardingService
from services.repayment_service import RepaymentService


BRANCH_UUID = "43324139-99bb-4820-b0af-a65ab3a1ed1d"
OFFICER_UUID = "2effe9b0-1e91-48bf-b698-4cc29c663796"
BM_UUID = "f346fdf5-0d4c-4592-b8ec-74ab4d103ab4"
CLIENT_UUID = "c4b14b34-3c66-46b0-ae1c-74de0a0f1234"
CO_ROLE_UUID = "bd8790ee-c0eb-485a-8b6a-93f54519965d"
BM_ROLE_UUID = "3ea1496a-0498-4a1d-872a-1c7ecdf77b06"


class _ChainMock:
    def __init__(self, data=None):
        self._data = data if data is not None else []

    def select(self, *args, **kwargs):
        return self

    def eq(self, *args, **kwargs):
        return self

    def neq(self, *args, **kwargs):
        return self

    def ilike(self, *args, **kwargs):
        return self

    def in_(self, *args, **kwargs):
        return self

    def gte(self, *args, **kwargs):
        return self

    def lte(self, *args, **kwargs):
        return self

    def lt(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def insert(self, *args, **kwargs):
        return self

    def update(self, *args, **kwargs):
        return self

    def upsert(self, *args, **kwargs):
        return self

    def delete(self, *args, **kwargs):
        return self

    def execute(self):
        res = MagicMock()
        res.data = self._data
        return res


def _user(role="Credit Officer", username="SAG_CO1", uid=OFFICER_UUID):
    return CurrentUser(
        id=uid,
        username=username,
        role=role,
        branch="Sagamu 1",
        branch_id=BRANCH_UUID,
        full_name="Test User",
    )


def test_nigeria_timezone_and_weekend_date_freeze():
    BusinessDateService.invalidate_operational_cache()
    mock_uow = MagicMock()

    def table_side_effect(name):
        if name == "branches":
            return _ChainMock([{"branch_id": BRANCH_UUID, "cashbook_defaults": {}}])
        return _ChainMock([])

    mock_uow.client.table.side_effect = table_side_effect

    with patch("services.business_date_service.datetime") as mock_dt:
        # 23:30 UTC on Friday 2026-11-27 == 00:30 WAT on Saturday 2026-11-28
        # Returning a naive datetime representing WAT wall clock simulates UTC+1 output
        mock_dt.now.return_value = datetime(2026, 11, 28, 0, 30, 0)
        resolved = BusinessDateService.get_business_date(mock_uow, BRANCH_UUID)
        assert resolved == date(2026, 11, 28)

        BusinessDateService.invalidate_operational_cache()
        open_sat, reason_sat = BusinessDateService.is_operational_open(mock_uow, BRANCH_UUID, date(2026, 11, 28))
        assert open_sat is False
        assert "Saturday" in reason_sat or "weekend" in reason_sat.lower()

        BusinessDateService.invalidate_operational_cache()
        open_mon, _ = BusinessDateService.is_operational_open(mock_uow, BRANCH_UUID, date(2026, 11, 30))
        assert open_mon is False

        BusinessDateService.invalidate_operational_cache()
        open_fri_on_sat, _ = BusinessDateService.is_operational_open(mock_uow, BRANCH_UUID, date(2026, 11, 27))
        assert open_fri_on_sat is False


def test_single_client_options_weekend_flag_and_future_submit_blocked_even_for_admin():
    BusinessDateService.invalidate_operational_cache()
    mock_uow = MagicMock()
    mock_uow.loans._resolve_officer_id.return_value = OFFICER_UUID

    def table_side_effect(name):
        if name == "branches":
            return _ChainMock([{"branch_id": BRANCH_UUID, "cashbook_defaults": {}}])
        if name == "clients":
            return _ChainMock([])
        return _ChainMock([])

    mock_uow.client.table.side_effect = table_side_effect

    with patch("services.business_date_service.BusinessDateService.get_nigeria_today", return_value=date(2026, 11, 28)):
        opts = get_single_client_options(date_str=None, current_user=_user(), uow=mock_uow)
        assert opts.date == "2026-11-28"
        assert opts.is_open is False

        admin = _user(role="Admin", username="admin")
        sc_payload = SingleClientSubmitInput(
            client_id=CLIENT_UUID,
            client_name="Aderonke Ganiyat",
            loan_repayment=1650.0,
            date="2026-11-30",
            is_late_entry=True,
            idempotency_key="FUT-BLOCK-1",
        )
        with patch("services.rate_limiter.get_financial_rate_limiter") as mock_lim:
            mock_lim.return_value.check_rate_limit.return_value = (False, 0)
            with pytest.raises(HTTPException) as exc1:
                submit_single_client(payload=sc_payload, current_user=admin, uow=mock_uow)
            assert exc1.value.status_code == 403

            batch_payload = BatchCollectionInput(
                group_name="Itesiwaju",
                date="2026-11-30",
                is_late_entry=True,
                idempotency_key="FUT-BATCH-BLOCK-1",
                collections=[
                    BatchCollectionItem(
                        client_id=CLIENT_UUID,
                        client_name="Aderonke Ganiyat",
                        loan_repayment_amount=1650.0,
                    )
                ],
            )
            with pytest.raises(HTTPException) as exc2:
                submit_batch_collections(payload=batch_payload, current_user=admin, uow=mock_uow)
            assert exc2.value.status_code == 403


def test_repayment_reversal_uses_unique_idempotency_key_and_nets_future_date():
    orig_id = "acf2a909-a0bf-519d-9826-b5854d3b7f8a"
    orig_row = {
        "id": orig_id,
        "idempotency_key": orig_id,
        "client_id": CLIENT_UUID,
        "loan_id": "8b4e006e-e5ce-41db-8a65-23b8d0cfb3a8",
        "branch_id": BRANCH_UUID,
        "officer_id": OFFICER_UUID,
        "amount_paid": 1650.0,
        "payment_date": "2026-11-30",
        "date": "2026-11-30T00:00:00+00:00",
        "note": "Daily Collection - Itesiwaju",
        "clients": {"name": "Aderonke Ganiyat"},
    }

    mock_uow = MagicMock()
    captured_ops = []

    def table_side_effect(name):
        if name == "repayments":
            q = MagicMock()
            # First call fetches original by id, second checks negs, third checks loan replays
            q.select.return_value = q
            q.eq.return_value = q
            q.lt.return_value = q
            q.limit.return_value = q
            q.execute.side_effect = [
                MagicMock(data=[orig_row]),
                MagicMock(data=[]),
                MagicMock(data=[orig_row]),
            ]
            return q
        if name == "loans":
            return _ChainMock([{"loan_id": orig_row["loan_id"], "status": "Active", "loan_products": {"name": "Finance"}}])
        return _ChainMock([])

    mock_uow.client.table.side_effect = table_side_effect
    mock_uow.client.rpc.side_effect = lambda fn, params: (
        captured_ops.extend(params.get("p_operations") or []) or _ChainMock([])
    )

    with patch("services.business_date_service.BusinessDateService.get_nigeria_now", return_value=datetime(2026, 11, 28, 10, 0, 0)), \
         patch("services.business_date_service.BusinessDateService.is_date_closed", return_value=False), \
         patch("services.schedule_service.ScheduleService.reverse_repayment_schedule"), \
         patch(
             "services.posting_engine.FinancialPostingEngine.post_event",
             side_effect=lambda u, ev, defer_commit=True: ("tx-1", {"type": "insert", "table": "financial_transactions", "record": {"transaction_id": "tx-1", "date": ev.payload["date"]}}),
         ) as mock_post:
        RepaymentService.reverse_repayment(mock_uow, orig_id, "wrong inputs", BM_UUID)

    rep_inserts = [op["record"] for op in captured_ops if op.get("type") == "insert" and op.get("table") == "repayments"]
    assert len(rep_inserts) == 1
    comp = rep_inserts[0]
    assert comp["id"] != orig_id
    assert comp["idempotency_key"] == f"REV-{orig_id}"
    assert "clients" not in comp
    assert comp["amount_paid"] == -1650.0
    assert comp["payment_date"] == "2026-11-30"
    assert comp["date"] == "2026-11-30T00:00:00+00:00"
    assert mock_post.call_args.args[1].payload["date"] == "2026-11-30T00:00:00+00:00"


def test_correction_approve_checks_four_eyes_before_claiming_processing():
    req_id = "49108549-3c5d-4c2c-b151-8ab74c9df7c5"
    req_row = {
        "id": req_id,
        "status": "Pending",
        "record_id": "rec-1",
        "record_type": "Repayment",
        "requested_by": OFFICER_UUID,
        "reason": "wrong inputs",
    }
    mock_uow = MagicMock()
    updates = []

    def table_side_effect(name):
        if name == "correction_requests":
            q = MagicMock()
            q.select.return_value = q
            q.eq.return_value = q
            q.neq.return_value = q
            def _upd(data):
                updates.append(data)
                return q
            q.update.side_effect = _upd
            q.execute.return_value = MagicMock(data=[req_row])
            return q
        return _ChainMock([])

    mock_uow.client.table.side_effect = table_side_effect

    with pytest.raises(ValueError, match="Four-Eyes"):
        CorrectionService.approve_correction(mock_uow, req_id, OFFICER_UUID)

    # Four-Eyes failure happened BEFORE claiming Processing
    assert updates == []


def test_onboarding_commit_unconditionally_provisions_bm_role_and_working_date():
    session_id = "971e82bf-a5c3-4c46-9764-4a29da441b73"
    session_row = {
        "id": session_id,
        "branch_id": None,
        "branch_name": "Sagamu 1",
        "branch_code": "SAG",
        "status": "submitted",
        "contact_person": None,
        "contact_phone": "08127382706",
        "payload": {
            "officers": [{"name": "Mary", "phone": "08011112222"}],
            "groups": [
                {
                    "group_reference": "GRP-1",
                    "name": "Itesiwaju",
                    "meeting_day": "Monday",
                    "officer_name": "Mary",
                    "group_savings": 0.0,
                }
            ],
            "members": [
                {
                    "full_name": "Aderonke Ganiyat",
                    "group_reference": "GRP-1",
                    "officer_name": "Mary",
                    "savings_balance": 0.0,
                    "active_credit": 10000.0,
                    "current_credit_balance": 6000.0,
                    "loan_type": "Weekly Loan",
                }
            ],
        },
    }

    inserted = {"branches": [], "app_users": [], "user_roles": [], "loans": []}
    mock_uow = MagicMock()

    def make_table(name):
        q = MagicMock()
        q.select.return_value = q
        q.eq.return_value = q
        q.ilike.return_value = q
        q.in_.return_value = q
        q.order.return_value = q
        q.limit.return_value = q
        q.update.return_value = q
        q.upsert.return_value = q

        def _ins(payload):
            if name in inserted:
                if isinstance(payload, list):
                    inserted[name].extend(payload)
                else:
                    inserted[name].append(payload)
            return q

        q.insert.side_effect = _ins

        if name == "branch_onboarding_sessions":
            q.execute.return_value = MagicMock(data=[session_row])
        elif name == "loan_products":
            q.execute.return_value = MagicMock(
                data=[{"product_id": "prod-1", "name": "Weekly Loan", "repayment_cycle": "Weekly", "installments": 20}]
            )
        elif name == "roles":
            def _role_exec():
                return MagicMock(data=[{"role_id": CO_ROLE_UUID}, {"role_id": BM_ROLE_UUID}])
            # Filter eq("name", ...) cleanly
            role_filter = {"val": None}
            def _eq(col, val):
                if col == "name":
                    role_filter["val"] = val
                return q
            q.eq.side_effect = _eq
            def _exec():
                if role_filter["val"] == "Credit Officer":
                    return MagicMock(data=[{"role_id": CO_ROLE_UUID}])
                if role_filter["val"] == "Branch Manager":
                    return MagicMock(data=[{"role_id": BM_ROLE_UUID}])
                return MagicMock(data=[])
            q.execute.side_effect = _exec
            return q
        elif name == "client_statuses":
            q.execute.return_value = MagicMock(data=[{"status_id": "st-on-loan", "name": "On Loan"}])
        else:
            q.execute.return_value = MagicMock(data=[])
        return q

    mock_uow.client.table.side_effect = make_table

    with patch("services.business_date_service.BusinessDateService.get_nigeria_today", return_value=date(2026, 11, 28)):
        result = OnboardingService.commit_session(mock_uow, session_id)

    assert len(inserted["branches"]) == 1
    assert inserted["branches"][0]["cashbook_defaults"] == {"business_date": "2026-11-30"}
    assert len(inserted["loans"]) == 1
    assert inserted["loans"][0]["start_date"] == "2026-11-30"

    usernames = [u["username"] for u in inserted["app_users"]]
    assert "SAG_CO1" in usernames
    assert "BM_Sagamu_1" in usernames
    role_ids = [r["role_id"] for r in inserted["user_roles"]]
    assert CO_ROLE_UUID in role_ids
    assert BM_ROLE_UUID in role_ids
    assert result["bm_provisioned"] is True
    assert result["bm_username"] == "BM_Sagamu_1"
    assert result["officer_usernames"] == ["SAG_CO1"]
