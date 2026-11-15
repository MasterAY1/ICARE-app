import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from fastapi import HTTPException


class _FilterChainTableMock:
    """In-memory filterable PostgREST table mock supporting range pagination."""

    def __init__(self, rows):
        self._all_rows = list(rows or [])
        self._filters = []
        self._range = None
        self._order_col = None
        self._order_desc = False
        self._limit = None

    def select(self, *args, **kwargs):
        return self

    def eq(self, col, val):
        self._filters.append(("eq", col, val))
        return self

    def in_(self, col, vals):
        val_set = {str(v) for v in (vals or [])}
        self._filters.append(("in", col, val_set))
        return self

    def gte(self, col, val):
        self._filters.append(("gte", col, str(val)))
        return self

    def lte(self, col, val):
        self._filters.append(("lte", col, str(val)))
        return self

    def lt(self, col, val):
        self._filters.append(("lt", col, str(val)))
        return self

    def ilike(self, col, val):
        self._filters.append(("ilike", col, str(val)))
        return self

    def or_(self, *args, **kwargs):
        return self

    def order(self, col, desc=False):
        self._order_col = col
        self._order_desc = desc
        return self

    def limit(self, n):
        self._limit = n
        return self

    def range(self, start, end):
        self._range = (start, end)
        return self

    def execute(self):
        out = []
        for row in self._all_rows:
            ok = True
            for op, col, val in self._filters:
                rv = row.get(col)
                rv_s = "" if rv is None else str(rv)
                if op == "eq":
                    if rv_s != str(val):
                        ok = False
                        break
                elif op == "in":
                    if rv_s not in val:
                        ok = False
                        break
                elif op == "gte":
                    if rv_s[:len(val)] < val:
                        ok = False
                        break
                elif op == "lte":
                    if rv_s[:10] > val[:10]:
                        ok = False
                        break
                elif op == "lt":
                    if rv_s[:10] >= val[:10]:
                        ok = False
                        break
                elif op == "ilike":
                    needle = val.replace("%", "").lower()
                    if needle not in rv_s.lower():
                        ok = False
                        break
            if ok:
                out.append(dict(row))

        if self._order_col:
            out.sort(key=lambda r: str(r.get(self._order_col) or ""), reverse=self._order_desc)

        if self._range is not None:
            s, e = self._range
            out = out[s : e + 1]
        elif self._limit is not None:
            out = out[: self._limit]
        return SimpleNamespace(data=out)


class TestWaveB2Portfolio023(unittest.TestCase):
    def test_risk_rating_zero_emoji_and_clean_tiers(self):
        from services.client_risk_rating_service import ClientRiskRatingService, RATING_THRESHOLDS

        forbidden_emojis = ("⭐", "🟢", "🟡", "🟠", "🔴")
        for _, score, token, label in RATING_THRESHOLDS:
            self.assertNotIn(token, forbidden_emojis)
            self.assertTrue(token in ("A+", "A", "B", "C", "D"))
            for em in forbidden_emojis:
                self.assertNotIn(em, label)

        uow = MagicMock()
        uow.collection_performance.get_client_compliance_history.return_value = {
            "compliance_pct": 98.0,
            "paid_count": 12,
            "part_payment_count": 0,
            "not_paid_count": 0,
            "consecutive_missed": 0,
            "total_expected": 60000.0,
            "total_paid": 60000.0,
        }
        uow.client.table.side_effect = lambda t: (
            _FilterChainTableMock([{"loan_id": "l-1", "active_credit": 60000.0, "loan_amount": 50000.0}])
            if t == "loans"
            else _FilterChainTableMock([])
        )
        with patch("services.schedule_service.ScheduleService.get_total_paid", return_value=(60000.0, True)):
            rating = ClientRiskRatingService.compute_risk_rating(uow, "c-1", "l-1")

        self.assertEqual(rating["rating_score"], "EXCELLENT")
        self.assertEqual(rating["rating_tier"], "A+")
        self.assertEqual(rating["rating_emoji"], "A+")
        for em in forbidden_emojis:
            self.assertNotIn(em, str(rating))

    def test_client_status_br_cli_004_and_atomic_rpc(self):
        from services.client_status_service import ClientStatusService

        ClientStatusService._status_cache = {
            "Registered": {"status_id": "st-reg", "name": "Registered"},
            "Dormant": {"status_id": "st-dorm", "name": "Dormant"},
            "On Loan": {"status_id": "st-loan", "name": "On Loan"},
            "Completed": {"status_id": "st-comp", "name": "Completed"},
            "Suspended": {"status_id": "st-susp", "name": "Suspended"},
            "Inactive (Savings Only)": {"status_id": "st-inact", "name": "Inactive (Savings Only)"},
            "Closed": {"status_id": "st-cls", "name": "Closed"},
        }
        ClientStatusService._status_by_id_cache = {
            v["status_id"]: v for v in ClientStatusService._status_cache.values()
        }
        try:
            uow = MagicMock()
            uow.client.table.side_effect = lambda t: (
                _FilterChainTableMock([{"client_id": "c-1", "status_id": "st-loan", "status": "On Loan"}])
                if t == "clients"
                else _FilterChainTableMock([{"id": "u-1", "username": "co_one"}]) if t == "app_users"
                else _FilterChainTableMock([])
            )

            # System-only states blocked from manual transition
            for forbidden in ("On Loan", "Completed", "Pending Loan", "Defaulter", "Dormant"):
                with self.assertRaises(ValueError):
                    ClientStatusService.transition_status(
                        uow, "c-1", forbidden, changed_by="co_one", reason="Attempt manual", trigger_type="MANUAL"
                    )

            # Non-Dormant -> Registered blocked
            with self.assertRaises(ValueError):
                ClientStatusService.transition_status(
                    uow, "c-1", "Registered", changed_by="co_one", reason="Reactivate", trigger_type="MANUAL"
                )

            # Empty reason blocked
            with self.assertRaises(ValueError):
                ClientStatusService.transition_status(
                    uow, "c-1", "Suspended", changed_by="co_one", reason="   ", trigger_type="MANUAL"
                )

            # Valid Dormant -> Registered runs atomically via atomic_execute_operations RPC
            uow.client.table.side_effect = lambda t: (
                _FilterChainTableMock([{"client_id": "c-1", "status_id": "st-dorm", "status": "Dormant"}])
                if t == "clients"
                else _FilterChainTableMock([{"id": "u-1", "username": "co_one"}]) if t == "app_users"
                else _FilterChainTableMock([])
            )
            ok = ClientStatusService.transition_status(
                uow, "c-1", "Registered", changed_by="u-1", reason="Client returning for loan", trigger_type="MANUAL"
            )
            self.assertTrue(ok)
            uow.client.rpc.assert_called_once()
            rpc_name, rpc_args = uow.client.rpc.call_args[0]
            self.assertEqual(rpc_name, "atomic_execute_operations")
            ops = rpc_args["p_operations"]
            self.assertEqual(len(ops), 2)
            self.assertEqual(ops[0]["table"], "clients")
            self.assertEqual(ops[1]["table"], "client_status_history")
            self.assertEqual(ops[1]["record"]["trigger_type"], "MANUAL")
        finally:
            ClientStatusService._status_cache = {}
            ClientStatusService._status_by_id_cache = {}

    def test_portfolio_service_fixes_overdue_par_misc_filters_and_collections(self):
        from services.portfolio_service import PortfolioService
        from services.rbac_scope_service import RBACScope

        biz_date = date(2026, 10, 15)  # Thursday
        week_early = "2026-10-12"      # Monday of same week
        month_early = "2026-10-05"     # Earlier in same month

        # Notice username "co3_fake" MUST NOT grant misc savings when designated officer is "off-misc"
        scope_co = RBACScope(
            scope_level="OFFICER",
            user_id="off-1",
            username="co3_fake",
            role="Credit Officer",
            branch_id="br-1",
            branch_name="Ikorodu",
        )

        # Create 205 loans + repayments across officers (testing transferred client lifetime rep + no [:200] truncation)
        loans_rows = [
            {
                "loan_id": "l-overdue-partial",
                "client_id": "c-1",
                "branch_id": "br-1",
                "officer_id": "off-1",
                "loan_amount": 100000.0,
                "active_credit": 120000.0,
                "total_due": 120000.0,
                "loan_repay": 10000.0,
                "start_date": "2026-09-01",
                "expected_end_date": "2026-12-01",
                "status": "Active",
                "loan_products": {"name": "12 Week Standard"},
            },
            {
                "loan_id": "l-completed-today",
                "client_id": "c-2",
                "branch_id": "br-1",
                "officer_id": "off-1",
                "loan_amount": 50000.0,
                "active_credit": 60000.0,
                "total_due": 60000.0,
                "loan_repay": 5000.0,
                "start_date": "2026-08-01",
                "disbursement_date": "2026-08-01",
                "expected_end_date": "2026-11-01",
                "status": "Completed",
                "loan_products": {"name": "24 Week Standard"},
            },
        ]
        # Pad additional completed loans beyond 200 to prove chunking handles > 200 loan IDs cleanly
        for i in range(205):
            loans_rows.append({
                "loan_id": f"l-pad-{i}",
                "client_id": "c-1",
                "branch_id": "br-1",
                "officer_id": "off-1",
                "loan_amount": 0.0,
                "active_credit": 0.0,
                "total_due": 0.0,
                "loan_repay": 0.0,
                "start_date": "2026-01-01",
                "status": "Completed",
                "loan_products": {"name": "12 Week Standard"},
            })

        clients_rows = [
            {
                "client_id": "c-1",
                "client_code": "IKR-01-001",
                "name": "Ada Obi",
                "branch_id": "br-1",
                "officer_id": "off-1",
                "group_id": "g-1",
                "client_statuses": {"name": "On Loan"},
            },
            {
                "client_id": "c-2",
                "client_code": "IKR-01-002",
                "name": "Tunde Ade",
                "branch_id": "br-1",
                "officer_id": "off-1",
                "group_id": "g-1",
                "client_statuses": {"name": "Completed"},
            },
        ]
        repayments_rows = [
            # Prior officer collected 20k BEFORE client transfer! Must be included in lifetime repayments!
            {"id": "r-prev", "loan_id": "l-overdue-partial", "client_id": "c-1", "branch_id": "br-1", "officer_id": "off-old", "date": "2026-09-10", "amount_paid": 20000.0},
            # Partial 2k payment TODAY on overdue loan l-overdue-partial (MUST NOT hide overdue status/PAR!)
            {"id": "r-today", "loan_id": "l-overdue-partial", "client_id": "c-1", "branch_id": "br-1", "officer_id": "off-1", "date": "2026-10-15", "amount_paid": 2000.0},
            # Early completed payoff 30k earlier this week (WTD = 30k + 2k = 32k), earlier month 5k (MTD = 37k)
            {"id": "r-wtd", "loan_id": "l-completed-today", "client_id": "c-2", "branch_id": "br-1", "officer_id": "off-1", "date": week_early, "amount_paid": 30000.0},
            {"id": "r-mtd", "loan_id": "l-completed-today", "client_id": "c-2", "branch_id": "br-1", "officer_id": "off-1", "date": month_early, "amount_paid": 5000.0},
        ]
        schedule_rows = [
            # Past-due installment (2026-10-08 < 2026-10-15) with 10,000 due, 2,000 paid => 8,000 overdue arrears!
            {"loan_id": "l-overdue-partial", "due_date": "2026-10-08", "total_due": 10000.0, "expected_amount": 10000.0, "paid_amount": 2000.0, "status": "PART_PAID"},
        ]
        internal_savings_rows = [
            {"id": "ms-1", "branch_id": "br-1", "officer_id": "off-misc", "branch": "Ikorodu", "deposit_amount": 5000.0, "withdrawal_amount": 0.0, "posting_date": "2026-10-15"},
            {"id": "ms-other", "branch_id": "br-2", "officer_id": "off-misc-2", "branch": "Ikorodu 2", "deposit_amount": 9000.0, "withdrawal_amount": 0.0, "posting_date": "2026-10-15"},
        ]
        payoff_rows = [
            {
                "id": "po-1", "loan_id": "l-completed-today", "client_id": "c-2", "branch_id": "br-1", "officer_id": "off-1",
                "date": "2026-10-15", "record_type": "FULL_PAYOFF", "amount_paid": 30000.0, "expected_installment": 5000.0,
                "active_credit_settled": 60000.0, "excess_amount": 0.0, "remaining_balance_after": 0.0,
                "loans": {"loan_products": {"name": "24 Week Standard"}},
                "clients": {"name": "Tunde Ade", "client_code": "IKR-01-002"},
                "app_users": {"username": "co3_fake", "full_name": "CO Test"},
            }
        ]
        recovery_rows = [
            {
                "id": "rec-1", "loan_id": "l-overdue-partial", "client_id": "c-1", "branch_id": "br-1", "officer_id": "off-1",
                "recovery_date": "2026-10-15", "recovery_timestamp": "2026-10-15T10:00:00", "recovery_type": "PARTIAL_RECOVERY",
                "overdue_before": 10000.0, "recovered_amount": 2000.0, "overdue_after": 8000.0, "total_repayment_amount": 2000.0,
                "loans": {"loan_products": {"name": "12 Week Standard"}},
                "clients": {"name": "Ada Obi", "client_code": "IKR-01-001"},
                "app_users": {"username": "co3_fake", "full_name": "CO Test"},
            },
            {
                "id": "rec-other-prod", "loan_id": "l-completed-today", "client_id": "c-2", "branch_id": "br-1", "officer_id": "off-1",
                "recovery_date": "2026-10-15", "recovery_timestamp": "2026-10-15T11:00:00", "recovery_type": "FULL_RECOVERY",
                "overdue_before": 5000.0, "recovered_amount": 5000.0, "overdue_after": 0.0, "total_repayment_amount": 5000.0,
                "loans": {"loan_products": {"name": "24 Week Standard"}},
                "clients": {"name": "Tunde Ade", "client_code": "IKR-01-002"},
                "app_users": {"username": "co3_fake", "full_name": "CO Test"},
            },
        ]

        def _table(name):
            return _FilterChainTableMock({
                "loans": loans_rows,
                "clients": clients_rows,
                "groups": [{"group_id": "g-1", "name": "Market Group", "group_number": "1", "meeting_day": "Thursday"}],
                "repayments": repayments_rows,
                "loan_schedule": schedule_rows,
                "internal_savings": internal_savings_rows,
                "loan_payoff_excess_records": payoff_rows,
                "loan_overdue_recovery_records": recovery_rows,
            }.get(name, []))

        uow = MagicMock()
        uow.client.table.side_effect = _table

        with patch("services.portfolio_service.BusinessDateService.get_business_date", return_value=biz_date), \
             patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value=("off-misc", "designated_misc")):
            data = PortfolioService.get_portfolio_data_for_scope(uow, scope_co)

        s = data["summary"]
        # Username "co3_fake" MUST NOT match misc savings ("off-misc")
        self.assertEqual(s["total_savings_deposit"], 0.0)
        # WTD & MTD come from actual repayments (today 2k, WTD 2k+30k=32k, MTD 37k) NOT 5x / 22x multipliers
        self.assertEqual(s["today_collection"], 2000.0)
        self.assertEqual(s["this_week_collection"], 32000.0)
        self.assertEqual(s["this_month_collection"], 37000.0)
        # Overdue count & arrears amount detected despite 2,000 partial payment today!
        self.assertEqual(s["overdue"]["count"], 1)
        self.assertEqual(s["overdue"]["amount"], 8000.0)
        self.assertEqual(s["par"], "6.67%")
        # Payoff & excess DF exposes Payment Date matching Flutter UI
        pe_rows = data["payoff_excess_table"].to_dict(orient="records")
        self.assertEqual(pe_rows[0]["Payment Date"], "2026-10-15")
        self.assertEqual(pe_rows[0]["Date"], "2026-10-15")

        # Now verify selected_product filters clients_raw, expected repayment, AND recovery_records!
        with patch("services.portfolio_service.BusinessDateService.get_business_date", return_value=biz_date), \
             patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value=("off-misc", "designated_misc")):
            prod_data = PortfolioService.get_portfolio_data_for_scope(
                uow, RBACScope(scope_level="BRANCH", user_id="bm-1", role="BM", branch_id="br-1", branch_name="Ikorodu"),
                selected_product="24 Week Standard",
            )
        self.assertEqual(prod_data["summary"]["total_clients"], 1)
        self.assertEqual(len(prod_data["overdue_recovery_table"]), 1)
        self.assertEqual(prod_data["overdue_recovery_table"].iloc[0]["Client Code"], "IKR-01-002")

        # Verify BM without group/product filter gets ONLY br-1 internal_savings (5k), NOT Ikorodu 2 (9k)
        with patch("services.portfolio_service.BusinessDateService.get_business_date", return_value=biz_date), \
             patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value=("off-misc", "designated_misc")):
            bm_data = PortfolioService.get_portfolio_data_for_scope(
                uow, RBACScope(scope_level="BRANCH", user_id="bm-1", role="BM", branch_id="br-1", branch_name="Ikorodu"),
            )
        self.assertEqual(bm_data["summary"]["total_savings_deposit"], 5000.0)

    def test_client_360_drilldown_and_dossier_endpoint_fixes(self):
        from api.routes.co.portfolio import (
            get_client_dossier,
            submit_dossier_reversal_request,
            update_client_lifecycle_status,
        )
        from api.schemas.portfolio import ChangeClientStatusRequest, DossierReversalRequest
        from services.rbac_scope_service import RBACScope

        client_rec = {
            "client_id": "c-1",
            "client_code": "OGI-01-001",
            "name": "Adebayo Omotola",
            "branch_id": "br-1",
            "officer_id": "off-1",
            "status": "On Loan",
            "status_id": "st-loan",
            "status_note": "Active cycle",
            "client_statuses": {"name": "On Loan", "color_code": "#059669"},
            "groups": {"name": "Unity Group"},
        }
        loans_data = [
            {
                "loan_id": "l-active", "client_id": "c-1", "loan_amount": 100000.0, "active_credit": 120000.0,
                "total_due": 120000.0, "loan_repay": 10000.0, "status": "Active",
                "disbursement_date": "2026-10-01", "loan_products": {"name": "12 Week Standard"},
            },
            # Active status with 0 remaining balance must NOT inflate executive_banner active credit (BR-CLI-005)
            {
                "loan_id": "l-stale-zero", "client_id": "c-1", "loan_amount": 50000.0, "active_credit": 60000.0,
                "total_due": 60000.0, "loan_repay": 5000.0, "status": "Active",
                "disbursement_date": "2026-06-01", "loan_products": {"name": "Asset Loan"},
            },
        ]
        repayments_data = [
            {"id": "rep-1", "client_id": "c-1", "loan_id": "l-stale-zero", "branch_id": "br-1", "officer_id": "off-1", "date": "2026-07-01", "amount_paid": 60000.0, "expected_amount": 60000.0, "payment_status": "PAID"},
            {"id": "rep-2", "client_id": "c-1", "loan_id": "l-active", "branch_id": "br-1", "officer_id": "off-1", "date": "2026-10-15", "amount_paid": 20000.0, "expected_amount": 10000.0, "payment_status": "PAID"},
        ]
        savings_data = [
            # Sorted newest-first initially; pre-cutoff legacy row must be excluded due to OPENING-SAVINGS-BF
            {"id": "sav-3", "client_id": "c-1", "deposit_amount": 0.0, "withdrawal_amount": 1000.0, "posting_date": "2026-10-15", "created_at": "2026-10-15T10:00:00", "remarks": "Withdrawal"},
            {"id": "sav-2", "client_id": "c-1", "deposit_amount": 2000.0, "withdrawal_amount": 0.0, "posting_date": "2026-10-10", "created_at": "2026-10-10T10:00:00", "remarks": "Meeting deposit"},
            {"id": "sav-1-bf", "client_id": "c-1", "deposit_amount": 5000.0, "withdrawal_amount": 0.0, "posting_date": "2026-08-31", "created_at": "2026-08-31T08:00:00", "reference": "OPENING-SAVINGS-BF", "remarks": "Brought forward"},
            {"id": "sav-old-dup", "client_id": "c-1", "deposit_amount": 9999.0, "withdrawal_amount": 0.0, "posting_date": "1970-01-01", "reference": "ONBOARDING-1", "remarks": "Legacy onboarding"},
        ]
        audit_data = [
            {"id": "aud-1", "record_id": "l-active", "table_name": "loans", "user_id": "bm-1", "action": "LOAN_DISBURSED", "description": "Disbursed loan", "created_at": "2026-10-01T09:00:00"},
        ]
        sched_data = [
            {"id": "sch-1", "loan_id": "l-active", "installment_number": 1, "due_date": "2026-10-08", "principal_due": 8000.0, "interest_due": 2000.0, "total_due": 10000.0, "paid_amount": 10000.0, "status": "PAID"},
            {"id": "sch-2", "loan_id": "l-active", "installment_number": 2, "due_date": "2026-10-15", "principal_due": 8000.0, "interest_due": 2000.0, "total_due": 10000.0, "paid_amount": 10000.0, "status": "PAID"},
        ]

        def _table(name):
            return _FilterChainTableMock({
                "clients": [client_rec],
                "loans": loans_data,
                "repayments": repayments_data,
                "individual_savings": savings_data,
                "audit_logs": audit_data,
                "loan_schedule": sched_data,
                "branches": [{"branch_id": "br-1", "name": "Ogijo"}],
                "app_users": [{"id": "bm-1", "username": "bm_ogijo", "full_name": "BM Ogijo"}, {"id": "off-1", "username": "co_one", "full_name": "CO One"}],
            }.get(name, []))

        uow = MagicMock()
        uow.client.table.side_effect = _table
        uow.collection_performance.find_by_client.return_value = []
        uow.collection_performance.get_client_compliance_history.return_value = {
            "compliance_pct": 96.0, "paid_count": 2, "part_payment_count": 0, "not_paid_count": 0,
            "consecutive_missed": 0, "total_expected": 20000.0, "total_paid": 20000.0,
        }

        scope_co = RBACScope(scope_level="OFFICER", user_id="off-1", username="co_one", role="Credit Officer", branch_id="br-1")

        # Virtual suffix -ASSET resolves seamlessly via base code!
        with patch("services.client_status_service.ClientStatusService.get_client_history", return_value=[]), \
             patch("services.schedule_service.ScheduleService.get_total_paid", return_value=(20000.0, True)):
            resp = get_client_dossier(client_code="OGI-01-001-ASSET", scope=scope_co, uow=uow)

        # Executive banner excludes stale zero-balance l-stale-zero
        self.assertEqual(resp.executive_banner["total_active_credit"], 120000.0)
        self.assertEqual(resp.executive_banner["outstanding_balance"], 100000.0)
        # OPENING-SAVINGS-BF deduplication (5000 + 2000 - 1000 = 6000, excludes 9999 dup)
        self.assertEqual(resp.executive_banner["savings_balance"], 6000.0)
        # Savings running net_balance is chronologically sound (newest first -> [6000, 7000, 5000])
        self.assertEqual([r["net_balance"] for r in resp.savings_ledger], [6000.0, 7000.0, 5000.0])
        # Key alignments verified
        self.assertEqual(resp.customer_info["status"], "On Loan")
        self.assertEqual(resp.lifecycle_status["note"], "Active cycle")
        self.assertEqual(resp.loan_history[0]["product_name"], "12 Week Standard")
        self.assertEqual(resp.loan_history[0]["principal"], 100000.0)
        # Audit trail found via record_id & actor resolved
        self.assertEqual(len(resp.audit_trail), 1)
        self.assertEqual(resp.audit_trail[0]["performed_by"], "BM Ogijo")
        # Loan schedule & emoji-free risk rating exposed
        self.assertEqual(len(resp.loan_schedule), 2)
        self.assertEqual(resp.risk_rating["rating_tier"], "A+")

        # Verify peer CO gets 403 on status-change and reversal-request
        peer_user = SimpleNamespace(id="off-peer", username="co_peer", role="CO", branch="Ogijo", branch_id="br-1")
        peer_scope = RBACScope(scope_level="OFFICER", user_id="off-peer", username="co_peer", role="Credit Officer", branch_id="br-1")
        with self.assertRaises(HTTPException) as ctx1:
            update_client_lifecycle_status(
                ChangeClientStatusRequest(client_id="c-1", target_status="Suspended", reason="Check"),
                current_user=peer_user, scope=peer_scope, uow=uow,
            )
        self.assertEqual(ctx1.exception.status_code, 403)

        with self.assertRaises(HTTPException) as ctx2:
            submit_dossier_reversal_request(
                DossierReversalRequest(record_id="rep-2", reason="Wrong amount"),
                current_user=peer_user, scope=peer_scope, uow=uow,
            )
        self.assertEqual(ctx2.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
