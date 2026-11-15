import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock, patch


class _ChainTableMock:
    def __init__(self, rows):
        self._rows = rows

    def select(self, *args, **kwargs):
        return self

    def eq(self, *args, **kwargs):
        return self

    def in_(self, *args, **kwargs):
        return self

    def gte(self, *args, **kwargs):
        return self

    def lte(self, *args, **kwargs):
        return self

    def lt(self, *args, **kwargs):
        return self

    def or_(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def execute(self):
        return SimpleNamespace(data=self._rows)


class TestWaveB1CoDashboard023(unittest.TestCase):
    def test_route_defaults_to_business_date_and_serializes_schema(self):
        from api.routes.co.dashboard import get_co_dashboard
        from api.schemas.dashboard import CoDashboardResponse

        user = SimpleNamespace(
            id="off-1",
            username="co_one",
            role="CO",
            branch="Ibadan",
            branch_id="br-1",
        )
        uow = MagicMock()
        mock_payload = {
            "welcome": {
                "officer_name": "co_one",
                "branch_name": "Ibadan",
                "date_str": "15 October 2026",
                "date_iso": "2026-10-15",
                "meeting_day": "Thursday",
                "time_str": "09:00 AM",
            },
            "branch_closure": {"is_closed": False, "reason": ""},
            "repayment_summary": {
                "rep_12_weeks_amt": 5000.0,
                "rep_12_weeks_clients": 1,
                "rep_24_weeks_amt": 0.0,
                "rep_24_weeks_clients": 0,
                "rep_120_days_amt": 4000.0,
                "rep_120_days_clients": 1,
                "rep_daily_amt": 2000.0,
                "rep_daily_clients": 1,
                "rep_monthly_amt": 10000.0,
                "rep_monthly_clients": 1,
                "total_collected_today": 21000.0,
            },
            "meeting_portfolio": [],
            "savings": {
                "deposited_amt": 3000.0,
                "deposited_clients": 1,
                "withdrawn_amt": 0.0,
                "withdrawn_clients": 0,
                "net_savings": 3000.0,
            },
            "repayment_status": {
                "full_payment": {"count": 1, "amount": 150000.0},
                "normal_payment": {"count": 2, "amount": 7000.0},
                "part_payment": {"count": 0, "amount": 0.0},
                "excess_payment": {"count": 1, "amount": 47500.0},
                "not_paid": {"count": 0, "amount": 0.0},
                "overdue_arrears": {"count": 0, "amount": 0.0},
            },
            "cash_position": {
                "opening_balance": 0.0,
                "cash_in": 24000.0,
                "cash_out": 0.0,
                "closing_balance": 24000.0,
                "status": "Balanced",
                "difference": 0.0,
            },
            "attention_list": [],
            "overdue_portfolio": {"total_overdue_amt": 0.0, "overdue_clients_count": 0, "overdue_groups_count": 0},
        }

        with patch("api.routes.co.dashboard.BusinessDateService.get_business_date", return_value=date(2026, 10, 15)) as mock_bd, \
             patch("api.routes.co.dashboard.DashboardService.get_co_dashboard_data", return_value=mock_payload) as mock_svc:
            res = get_co_dashboard(date_str=None, current_user=user, uow=uow)

        mock_bd.assert_called_once_with(uow, "br-1")
        self.assertEqual(mock_svc.call_args.kwargs["target_date"], date(2026, 10, 15))
        parsed = CoDashboardResponse.model_validate(res)
        self.assertEqual(parsed.welcome.date_iso, "2026-10-15")
        self.assertEqual(parsed.repayment_summary.rep_120_days_amt, 4000.0)
        self.assertEqual(parsed.repayment_status.normal_payment.count, 2)

    def test_payment_breakdown_prevents_premature_payoff_and_tracks_normal_and_multi_loan(self):
        from services.dashboard_service import DashboardService

        # Thursday 2026-10-15 (open weekday)
        loans_rows = [
            # L1: active_credit 100k, total_due 120k, paid lifetime 105k -> remaining_bal 15k (> 0): must NOT trigger premature payoff!
            {
                "loan_id": "L1",
                "client_id": "C1",
                "status": "Active",
                "active_credit": 100000.0,
                "total_due": 120000.0,
                "loan_repay": 5000.0,
                "duration": 24,
                "meeting_day": "Thursday",
                "loan_products": {"name": "24 Weeks", "repayment_cycle": "Weekly", "installments": 24},
            },
            # L2 & L3 for same client C2: L2 settled in full (150k), L3 still active (should use L2 active_credit = 150k!)
            {
                "loan_id": "L2",
                "client_id": "C2",
                "status": "Completed",
                "active_credit": 150000.0,
                "total_due": 150000.0,
                "loan_repay": 2500.0,
                "duration": 60,
                "meeting_day": "Daily",
                "loan_products": {"name": "60 Days Daily", "repayment_cycle": "Daily", "installments": 60},
            },
            {
                "loan_id": "L3",
                "client_id": "C2",
                "status": "Active",
                "active_credit": 300000.0,
                "total_due": 300000.0,
                "loan_repay": 10000.0,
                "duration": 24,
                "meeting_day": "Thursday",
                "loan_products": {"name": "24 Weeks", "repayment_cycle": "Weekly", "installments": 24},
            },
        ]
        today_reps = [
            {"loan_id": "L1", "client_id": "C1", "amount_paid": 5000.0, "transaction_type": "REPAYMENT", "note": ""},
            {"loan_id": "L2", "client_id": "C2", "amount_paid": 50000.0, "transaction_type": "REPAYMENT", "note": ""},
            # Must be excluded because ONBOARDING_LEGACY
            {"loan_id": "L3", "client_id": "C2", "amount_paid": 10000.0, "transaction_type": "ONBOARDING_LEGACY", "note": "Legacy Repayments Onboarded"},
        ]
        payoff_rows = [
            {
                "loan_id": "L2",
                "client_id": "C2",
                "record_type": "FULL_PAYOFF_AND_EXCESS",
                "active_credit_settled": 150000.0,
                "excess_amount": 47500.0,
            }
        ]

        class _MultiTableMock:
            def __init__(self, name):
                self._name = name
                self._cols = "*"

            def select(self, cols="*", *args, **kwargs):
                self._cols = cols
                return self

            def eq(self, *args, **kwargs):
                return self

            def in_(self, *args, **kwargs):
                return self

            def gte(self, *args, **kwargs):
                return self

            def lte(self, *args, **kwargs):
                return self

            def or_(self, *args, **kwargs):
                return self

            def order(self, *args, **kwargs):
                return self

            def limit(self, *args, **kwargs):
                return self

            def execute(self):
                if self._name == "loans":
                    return SimpleNamespace(data=loans_rows)
                if self._name == "repayments":
                    if "transaction_type" in self._cols:
                        return SimpleNamespace(data=today_reps)
                    return SimpleNamespace(
                        data=[
                            {"loan_id": "L1", "amount_paid": 105000.0},
                            {"loan_id": "L2", "amount_paid": 150000.0},
                            {"loan_id": "L3", "amount_paid": 10000.0},
                        ]
                    )
                if self._name == "loan_payoff_excess_records":
                    return SimpleNamespace(data=payoff_rows)
                return SimpleNamespace(data=[])

        uow = MagicMock()
        uow.client.table.side_effect = lambda name: _MultiTableMock(name)

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Working Day")), \
             patch(
                 "services.schedule_service.ScheduleService.get_loan_due_breakdown",
                 side_effect=[
                     {"has_overdue": False, "overdue_arrears": 0.0, "total_due_today": 5000.0},
                     {"has_overdue": False, "overdue_arrears": 0.0, "total_due_today": 10000.0},
                 ],
             ):
            bd = DashboardService._calculate_payment_breakdown(
                uow, date(2026, 10, 15), branch_id="br-1", officer_id="off-1", schedules_by_loan={}
            )

        self.assertEqual(bd["full_payments"], {"count": 1, "amount": 150000.0})
        self.assertEqual(bd["excess_payments"], {"count": 1, "amount": 47500.0})
        self.assertEqual(bd["normal_payments"], {"count": 1, "amount": 5000.0})
        self.assertEqual(bd["not_paid"], {"count": 1, "amount": 10000.0})

    def test_co_dashboard_excludes_offsets_buckets_all_products_and_scopes_branch(self):
        from services.dashboard_service import DashboardService

        table_queries = []

        class _RecordingTableMock(_ChainTableMock):
            def __init__(self, name, rows):
                super().__init__(rows)
                self._name = name

            def eq(self, col, val):
                table_queries.append((self._name, col, val))
                return self

        reps = [
            {
                "loan_id": "L1", "client_id": "C1", "amount_paid": 3000.0,
                "transaction_type": "REPAYMENT", "payment_mode": "Cash", "note": "",
                "loans": {"duration": 120, "repayment_cycle": "Daily", "loan_products": {"name": "120 Days Daily", "repayment_cycle": "Daily", "installments": 120}},
            },
            {
                "loan_id": "L2", "client_id": "C2", "amount_paid": 2000.0,
                "transaction_type": "REPAYMENT", "payment_mode": "Cash", "note": "",
                "loans": {"duration": 60, "repayment_cycle": "Daily", "loan_products": {"name": "60 Days Daily", "repayment_cycle": "Daily", "installments": 60}},
            },
            {
                "loan_id": "L3", "client_id": "C3", "amount_paid": 5000.0,
                "transaction_type": "REPAYMENT", "payment_mode": "Cash", "note": "",
                "loans": {"duration": 12, "repayment_cycle": "Weekly", "loan_products": {"name": "12 Weeks Weekly", "repayment_cycle": "Weekly", "installments": 12}},
            },
            {
                "loan_id": "L4", "client_id": "C4", "amount_paid": 15000.0,
                "transaction_type": "REPAYMENT", "payment_mode": "Cash", "note": "",
                "loans": {"duration": 3, "repayment_cycle": "Monthly", "loan_products": {"name": "Monthly 3M", "repayment_cycle": "Monthly", "installments": 3}},
            },
            {
                "loan_id": "L5", "client_id": "C5", "amount_paid": 8000.0,
                "transaction_type": "LOAN_OFFSET", "payment_mode": "SAVINGS_OFFSET", "note": "[LOAN_OFFSET:L5]",
                "loans": {"duration": 24, "repayment_cycle": "Weekly", "loan_products": {"name": "24 Weeks", "repayment_cycle": "Weekly", "installments": 24}},
            },
        ]
        ind_sav = [
            {"client_id": "C1", "deposit_amount": 1000.0, "withdrawal_amount": 0.0, "reference": "SAV-1", "remarks": "Cash deposit"},
            {"client_id": "C5", "deposit_amount": 0.0, "withdrawal_amount": 8000.0, "reference": "WD-OFF", "remarks": "LoanOffsetFromSavings [LOAN_OFFSET:L5]"},
            {"client_id": "C6", "deposit_amount": 0.0, "withdrawal_amount": 1500.0, "reference": "WD-CASH", "remarks": "Cash withdrawal"},
        ]
        internal_sav = [
            {"id": 99, "deposit_amount": 500.0, "withdrawal_amount": 0.0, "reference": "MISC-1", "remarks": "Misc Passbook"},
        ]

        def route(name):
            if name == "repayments":
                return _RecordingTableMock(name, reps)
            if name == "individual_savings":
                return _RecordingTableMock(name, ind_sav)
            if name == "group_savings":
                return _RecordingTableMock(name, [])
            if name == "internal_savings":
                return _RecordingTableMock(name, internal_sav)
            return _RecordingTableMock(name, [])

        uow = MagicMock()
        uow.client.table.side_effect = route

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(False, "Public Holiday")), \
             patch("services.savings_service.SavingsService.get_branch_misc_savings_officer", return_value=("off-1", "co_one")), \
             patch.object(DashboardService, "_calculate_payment_breakdown", return_value={
                 "full_payments": {"count": 0, "amount": 0.0},
                 "normal_payments": {"count": 0, "amount": 0.0},
                 "excess_payments": {"count": 0, "amount": 0.0},
                 "part_payments": {"count": 0, "amount": 0.0},
                 "not_paid": {"count": 0, "amount": 0.0},
                 "overdue_arrears": {"count": 0, "amount": 0.0},
             }):
            res = DashboardService.get_co_dashboard_data(
                uow=uow,
                branch_name="Ibadan",
                officer_name="co_one",
                officer_id="off-1",
                branch_id="br-1",
                target_date=date(2026, 10, 15),
            )

        self.assertTrue(res["branch_closure"]["is_closed"])
        self.assertEqual(res["branch_closure"]["reason"], "Public Holiday")
        self.assertEqual(res["welcome"]["date_iso"], "2026-10-15")
        self.assertEqual(res["repayment_summary"]["rep_120_days_amt"], 3000.0)
        self.assertEqual(res["repayment_summary"]["rep_daily_amt"], 2000.0)
        self.assertEqual(res["repayment_summary"]["rep_12_weeks_amt"], 5000.0)
        self.assertEqual(res["repayment_summary"]["rep_monthly_amt"], 15000.0)
        self.assertEqual(res["repayment_summary"]["rep_24_weeks_amt"], 0.0)
        self.assertEqual(res["repayment_summary"]["total_collected_today"], 25000.0)
        # 1000 individual + 500 misc deposit; only 1500 cash withdrawal (LoanOffsetFromSavings excluded!)
        self.assertEqual(res["savings"]["deposited_amt"], 1500.0)
        self.assertEqual(res["savings"]["deposited_clients"], 2)
        self.assertEqual(res["savings"]["withdrawn_amt"], 1500.0)
        self.assertEqual(res["savings"]["withdrawn_clients"], 1)
        self.assertIn(("repayments", "branch_id", "br-1"), table_queries)
        self.assertIn(("individual_savings", "branch_id", "br-1"), table_queries)
        self.assertIn(("group_savings", "branch_id", "br-1"), table_queries)
        self.assertIn(("internal_savings", "branch_id", "br-1"), table_queries)

    def test_calculate_par_pct_uses_business_date(self):
        from services.dashboard_service import DashboardService

        uow = MagicMock()
        loans_tbl = _ChainTableMock([{"loan_id": "L1", "active_credit": 100000.0}])
        sched_tbl = _ChainTableMock([{"total_due": 12000.0, "paid_amount": 2000.0}])
        captured_lt = []

        class _SchedMock(_ChainTableMock):
            def lt(self, col, val):
                captured_lt.append((col, val))
                return self

        uow.client.table.side_effect = lambda name: loans_tbl if name == "loans" else _SchedMock([{"total_due": 12000.0, "paid_amount": 2000.0}])

        with patch("services.dashboard_service.BusinessDateService.get_business_date", return_value=date(2026, 10, 15)) as mock_bd:
            par = DashboardService.calculate_par_pct(uow, branch_id="br-1")

        mock_bd.assert_called_once_with(uow, "br-1")
        self.assertEqual(par, "10.0%")
        self.assertEqual(captured_lt, [("due_date", "2026-10-15")])


if __name__ == "__main__":
    unittest.main()
