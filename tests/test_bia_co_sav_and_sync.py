"""
Regression & verification tests for:
- BIA-CO-SAV-001: Elimination of N+1 get_total_balance calls & unscoped client_memberships scan
- BIA-CO-SYNC-001: ICARE error response detail parity, HTTP 503 on DB_NETWORK_TIMEOUT,
  and branch-scoped GROUP- group_id lookup in collection batch service.
"""
import asyncio
import os
import sys
import uuid
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from fastapi import Request
from fastapi.testclient import TestClient

from api.core.errors import translate_error_to_icare_response
from api.dependencies import get_current_user, get_uow
from api.main import app, global_exception_handler
from models.user import CurrentUser
from services.collection_batch_service import save_repayment


class _FakeQuery:
    def __init__(self, data=None, on_in=None, on_eq=None):
        self._data = list(data) if data is not None else []
        self._on_in = on_in
        self._on_eq = on_eq
        self._eq_filters = {}

    def select(self, *args, **kwargs):
        return self

    def eq(self, col, val, *args, **kwargs):
        self._eq_filters[col] = val
        if self._on_eq:
            self._on_eq(col, val)
        if "." not in str(col) and any(isinstance(r, dict) and col in r for r in self._data):
            self._data = [r for r in self._data if isinstance(r, dict) and r.get(col) == val]
        return self

    def neq(self, col, val, *args, **kwargs):
        if "." not in str(col) and any(isinstance(r, dict) and col in r for r in self._data):
            self._data = [r for r in self._data if isinstance(r, dict) and r.get(col) != val]
        return self

    def lt(self, *args, **kwargs):
        return self

    def gt(self, *args, **kwargs):
        return self

    def gte(self, *args, **kwargs):
        return self

    def lte(self, *args, **kwargs):
        return self

    def or_(self, *args, **kwargs):
        return self

    def ilike(self, col, val, *args, **kwargs):
        if "." not in str(col) and any(isinstance(r, dict) and col in r for r in self._data):
            target = str(val or "").strip().lower()
            self._data = [r for r in self._data if isinstance(r, dict) and str(r.get(col) or "").strip().lower() == target]
        return self

    def in_(self, col, vals, *args, **kwargs):
        if self._on_in:
            self._on_in(col, list(vals or []))
        if "." not in str(col) and any(isinstance(r, dict) and col in r for r in self._data):
            val_set = set(vals or [])
            self._data = [r for r in self._data if isinstance(r, dict) and r.get(col) in val_set]
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def execute(self):
        return MagicMock(data=list(self._data))


class TestBiaCoSavAndSync(unittest.TestCase):
    def tearDown(self):
        app.dependency_overrides.clear()

    def test_individual_options_eliminates_n_plus_one_for_zero_balance_clients(self):
        branch_id = str(uuid.uuid4())
        officer_id = str(uuid.uuid4())
        group_id = str(uuid.uuid4())
        clients = []
        for idx in range(50):
            clients.append({
                "client_id": str(uuid.uuid4()),
                "client_code": f"CL-{idx:03d}",
                "name": f"Client {idx}",
                "status": "Active",
                "client_statuses": {"name": "Active"},
                "client_memberships": [{"group_id": group_id, "groups": {"group_id": group_id, "name": "Favour", "group_number": 1, "meeting_day": "Monday"}}],
            })
        sav_rows = [
            {"client_id": clients[0]["client_id"], "deposit_amount": 5000.0, "withdrawal_amount": 1000.0},
            {"client_id": clients[1]["client_id"], "deposit_amount": 2500.0, "withdrawal_amount": 0.0},
        ]

        mock_uow = MagicMock()
        mock_uow.loans._resolve_officer_id.return_value = officer_id
        mock_uow.individual_savings.get_total_balance = MagicMock(return_value=9999.0)
        mock_uow.client.rpc.return_value.execute.return_value = MagicMock(data=None)

        def _table(name):
            if name == "clients":
                return _FakeQuery(clients)
            if name == "individual_savings":
                return _FakeQuery(sav_rows)
            if name == "loans":
                return _FakeQuery([])
            if name == "withdrawal_requests":
                return _FakeQuery([])
            return _FakeQuery([])

        mock_uow.client.table.side_effect = _table

        app.dependency_overrides[get_uow] = lambda: mock_uow
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(
            id=officer_id,
            username="co_test",
            role="Credit Officer",
            branch="Test Branch",
            branch_id=branch_id,
            full_name="Test CO",
        )

        client = TestClient(app)
        resp = client.get("/api/v1/co/withdrawals/individual-options")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()

        # Zero per-client N+1 RPC calls despite 48 legitimate zero-balance clients
        self.assertEqual(mock_uow.individual_savings.get_total_balance.call_count, 0)
        self.assertEqual(len(data["clients"]), 50)
        self.assertEqual(len(data["all_groups"]), 1)
        by_id = {c["client_id"]: c for c in data["clients"]}
        self.assertEqual(by_id[clients[0]["client_id"]]["savings_balance"], 4000.0)
        self.assertEqual(by_id[clients[2]["client_id"]]["savings_balance"], 0.0)

    def test_daily_withdrawals_scopes_client_memberships_by_client_ids(self):
        branch_id = str(uuid.uuid4())
        officer_id = str(uuid.uuid4())
        cid = str(uuid.uuid4())
        gid = str(uuid.uuid4())
        cm_in_calls = []

        mock_uow = MagicMock()
        mock_uow.loans._resolve_officer_id.return_value = officer_id

        def _table(name):
            if name == "clients":
                return _FakeQuery([{"client_id": cid, "client_code": "C01", "name": "Ada Obi", "officer_id": officer_id, "branch_id": branch_id}])
            if name == "client_memberships":
                return _FakeQuery(
                    [{"client_id": cid, "groups": {"group_id": gid, "name": "Favour"}}],
                    on_in=lambda col, vals: cm_in_calls.append((col, vals)),
                )
            if name == "individual_savings":
                return _FakeQuery([
                    {"id": str(uuid.uuid4()), "client_id": cid, "officer_id": officer_id, "branch_id": branch_id, "withdrawal_amount": 1500.0, "deposit_amount": 0.0, "posting_date": "2026-11-21", "reference": "REF-1", "remarks": "Cash payout"}
                ])
            return _FakeQuery([])

        mock_uow.client.table.side_effect = _table
        app.dependency_overrides[get_uow] = lambda: mock_uow
        app.dependency_overrides[get_current_user] = lambda: CurrentUser(
            id=officer_id,
            username="co_test",
            role="Credit Officer",
            branch="Test Branch",
            branch_id=branch_id,
            full_name="Test CO",
        )

        client = TestClient(app)
        resp = client.get("/api/v1/co/withdrawals/daily-withdrawals?date=2026-11-21")
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(cm_in_calls, "client_memberships query must be scoped with client_id IN filter")
        self.assertEqual(cm_in_calls[0][0], "client_id")
        self.assertIn(cid, cm_in_calls[0][1])

    def test_error_translation_includes_detail_and_returns_503_for_db_timeout(self):
        req = Request({"type": "http", "method": "POST", "path": "/api/v1/co/collections/batch-submit", "headers": []})

        val_res = asyncio.run(global_exception_handler(req, ValueError("Invalid collection allocation.")))
        self.assertEqual(val_res.status_code, 400)
        import json
        val_body = json.loads(val_res.body.decode())
        self.assertEqual(val_body["message"], "Invalid collection allocation.")
        self.assertEqual(val_body["detail"], "Invalid collection allocation.")

        net_res = asyncio.run(global_exception_handler(req, ConnectionError("Cloudflare worker threw exception")))
        self.assertEqual(net_res.status_code, 503)
        net_body = json.loads(net_res.body.decode())
        self.assertEqual(net_body["error_code"], "DB_NETWORK_TIMEOUT")
        self.assertEqual(net_body["detail"], net_body["message"])

        dup_dict = translate_error_to_icare_response(Exception("duplicate key value violates unique constraint 23505"))
        self.assertEqual(dup_dict["error_code"], "DB_DUPLICATE_ENTRY")
        self.assertEqual(dup_dict["detail"], dup_dict["message"])

    def test_save_repayment_group_lookup_scopes_by_branch(self):
        branch_b_id = str(uuid.uuid4())
        branch_a_id = str(uuid.uuid4())
        group_a_id = str(uuid.uuid4())
        group_b_id = str(uuid.uuid4())
        captured_calls = []

        mock_uow = MagicMock()
        mock_uow.branches._resolve_branch_id.return_value = branch_b_id
        groups_rows = [
            {"group_id": group_a_id, "name": "Favour", "branch_id": branch_a_id},
            {"group_id": group_b_id, "name": "Favour", "branch_id": branch_b_id},
        ]

        def _table(name):
            if name == "branches":
                return _FakeQuery([{"branch_id": branch_b_id, "name": "Branch B"}])
            if name == "groups":
                return _FakeQuery(groups_rows)
            return _FakeQuery([])

        mock_uow.client.table.side_effect = _table

        with patch("services.savings_service.SavingsService.post_group_savings") as mock_post_grp, \
             patch("services.posting_engine.FinancialPostingEngine._resolve_branch_id", return_value=branch_b_id):
            mock_post_grp.side_effect = lambda *args, **kwargs: captured_calls.append(kwargs)
            save_repayment(
                {
                    "Date": "2026-11-23",
                    "Client ID": "GROUP-Favour",
                    "Client Name": "Favour Meeting",
                    "Branch": "Branch B",
                    "Officer": "co_branch_b",
                    "Group Savings Deposit": 5000.0,
                },
                override_uow=mock_uow,
                allow_closed_date=True,
            )

        self.assertEqual(len(captured_calls), 1)
        self.assertEqual(captured_calls[0]["group_id"], group_b_id)


if __name__ == "__main__":
    unittest.main()
