import unittest
from unittest.mock import MagicMock
from services.report_service import ReportService


OGIJO_AUG_RECON_DATA = {
    "deposit_statement": {
        "rows": [
            {"programme": "Monthly", "member_total": 2, "deposit_total": 27000.0, "withdrawal_total_no": 7, "withdrawal_total_amount": 227900.0, "return_total_no": 1, "return_total_amount": 5000.0, "balance_amount": 27000.0},
            {"programme": "Weekly", "member_total": 171, "deposit_total": 4377730.0, "withdrawal_total_no": 1540, "withdrawal_total_amount": 40849865.0, "return_total_no": 549, "return_total_amount": 9617175.0, "balance_amount": 4377730.0},
            {"programme": "Daily", "member_total": 130, "deposit_total": 6286130.0, "withdrawal_total_no": 1683, "withdrawal_total_amount": 44025180.0, "return_total_no": 475, "return_total_amount": 11654445.0, "balance_amount": 6286130.0},
            {"programme": "Total", "member_total": 303, "deposit_total": 10690860.0, "withdrawal_total_no": 3230, "withdrawal_total_amount": 85102945.0, "return_total_no": 1025, "return_total_amount": 21276620.0, "balance_amount": 10690860.0}
        ]
    },
    "credit_statement": {
        "rows": [
            {"section": "1. Credit Disbursed", "item": "• Previous Loans Count (B/F)", "monthly": 5, "weekly": 149, "daily": 129, "total": 283},
            {"section": "1. Credit Disbursed", "item": "• Previous Disbursed Amount (₦)", "monthly": 792000.0, "weekly": 24525000.0, "daily": 21768000.0, "total": 47085000.0},
            {"section": "1. Credit Disbursed", "item": "• Total Net Loans Count (Col 7 = 3+5-27)", "monthly": 5, "weekly": 149, "daily": 129, "total": 283},
            {"section": "1. Credit Disbursed", "item": "• Total Net Disbursed (₦) (Col 8 = 4+6-28)", "monthly": 792000.0, "weekly": 24525000.0, "daily": 21768000.0, "total": 47085000.0},
            {"section": "2. Excess Collection", "item": "• Total Excess Collection (₦) (Col 11 = 9+10)", "monthly": 0.0, "weekly": 25119900.0, "daily": 46164400.0, "total": 71284300.0},
            {"section": "3. Installment Collection", "item": "• Total Net Installments (₦) (Col 14 = 12+13-28)", "monthly": 400000.0, "weekly": 11504500.0, "daily": 10288000.0, "total": 22192500.0},
            {"section": "5. Full Repayment (Settled Loans)", "item": "• Total Cumulative Settled Count", "monthly": 19, "weekly": 1592, "daily": 1579, "total": 3190},
            {"section": "5. Full Repayment (Settled Loans)", "item": "• Total Cumulative Settled Amount (₦)", "monthly": 2898000.0, "weekly": 202326000.0, "daily": 197541000.0, "total": 402765000.0}
        ]
    }
}


class TestReportServiceDepositStatementUnit(unittest.TestCase):

    def setUp(self):
        self.ogijo_id = "997d504e-7f5c-4772-887d-fdd5a4c1183b"
        self.omitoro_id = "d6d24dba-894c-4b30-b695-2178b6abf927"

    def _create_mock_uow(self, branch_id, branch_name, individual_savings=None, group_savings=None,
                          current_ind_savings=None, current_grp_savings=None,
                          groups=None, clients=None, loans=None, loan_products=None, reconciliations=None):
        uow = MagicMock()

        def table_side_effect(tbl_name):
            mock_table = MagicMock()
            if tbl_name == "branches":
                mock_table.select.return_value.eq.return_value.execute.return_value = MagicMock(
                    data=[{"name": branch_name}]
                )
            elif tbl_name == "loan_products":
                mock_table.select.return_value.execute.return_value = MagicMock(
                    data=loan_products or []
                )
            elif tbl_name == "groups":
                mock_table.select.return_value.eq.return_value.range.return_value.execute.return_value = MagicMock(
                    data=groups or []
                )
            elif tbl_name == "clients":
                mock_table.select.return_value.eq.return_value.range.return_value.execute.return_value = MagicMock(
                    data=clients or []
                )
            elif tbl_name == "loans":
                mock_table.select.return_value.eq.return_value.range.return_value.execute.return_value = MagicMock(
                    data=loans or []
                )
            elif tbl_name == "individual_savings":
                m_q = MagicMock()
                m_q.eq.return_value = m_q
                m_q.lte.return_value = m_q
                m_q.lt.return_value = m_q
                def gte_side_effect(*args, **kwargs):
                    m_curr = MagicMock()
                    m_curr.lte.return_value = m_curr
                    m_curr.eq.return_value = m_curr
                    m_curr.range.return_value.execute.return_value = MagicMock(
                        data=current_ind_savings if current_ind_savings is not None else (individual_savings or [])
                    )
                    return m_curr
                m_q.gte.side_effect = gte_side_effect
                m_q.range.return_value.execute.return_value = MagicMock(
                    data=individual_savings or []
                )
                mock_table.select.return_value = m_q
            elif tbl_name == "group_savings":
                m_q = MagicMock()
                m_q.eq.return_value = m_q
                m_q.lte.return_value = m_q
                m_q.lt.return_value = m_q
                def gte_side_effect_grp(*args, **kwargs):
                    m_curr = MagicMock()
                    m_curr.lte.return_value = m_curr
                    m_curr.eq.return_value = m_curr
                    m_curr.range.return_value.execute.return_value = MagicMock(
                        data=current_grp_savings if current_grp_savings is not None else (group_savings or [])
                    )
                    return m_curr
                m_q.gte.side_effect = gte_side_effect_grp
                m_q.range.return_value.execute.return_value = MagicMock(
                    data=group_savings or []
                )
                mock_table.select.return_value = m_q
            elif tbl_name in ("repayments", "loan_payoff_excess_records", "loan_overdue_recovery_records"):
                m_q = MagicMock()
                m_q.eq.return_value = m_q
                m_q.gte.return_value = m_q
                m_q.lte.return_value = m_q
                m_q.lt.return_value = m_q
                m_q.range.return_value.execute.return_value = MagicMock(data=[])
                return m_q
            elif tbl_name == "monthly_statement_reconciliations":
                m_r = MagicMock()
                m_r.select.return_value = m_r
                m_r.eq.return_value = m_r
                def recon_exec():
                    if branch_id == self.ogijo_id:
                        return MagicMock(data=[{"data": OGIJO_AUG_RECON_DATA}])
                    return MagicMock(data=reconciliations or [])
                m_r.execute.side_effect = recon_exec
                return m_r
            return mock_table

        uow.client.table.side_effect = table_side_effect
        return uow

    def test_ogijo_uses_base_aug_dep_for_pre_september(self):
        """Ogijo branch unfiltered reads official statutory baseline from monthly_statement_reconciliations."""
        uow = self._create_mock_uow(self.ogijo_id, "Ogijo")
        res = ReportService.get_monthly_deposit_statement(uow, self.ogijo_id, 2026, 8)
        tot = [r for r in res["rows"] if r["programme"] == "Total"][0]
        # Totals in reconciliation: member 303, deposit 10690860
        self.assertEqual(tot["member_prev"], 303)
        self.assertEqual(tot["deposit_prev"], 10690860.0)

    def test_non_ogijo_computes_dynamic_baseline_including_group_savings(self):
        """Non-Ogijo branches (like Omitoro) compute baseline dynamically from operational records."""
        # 2 individual savings and 1 group savings prior to Sept 2026
        ind_savings = [
            {"client_id": "c1", "deposit_amount": 50000.0, "withdrawal_amount": 0.0, "remarks": ""},
            {"client_id": "c2", "deposit_amount": 25000.0, "withdrawal_amount": 5000.0, "remarks": "Withdrawal"}
        ]
        grp_savings = [
            {"group_id": "g1", "deposit_amount": 10000.0, "withdrawal_amount": 0.0}
        ]
        groups = [{"group_id": "g1", "meeting_day": "Weekly", "officer_id": "off1"}]
        clients = [
            {"client_id": "c1", "group_id": "g1", "officer_id": "off1", "created_at": "2026-01-01"},
            {"client_id": "c2", "group_id": "g1", "officer_id": "off1", "created_at": "2026-01-01"}
        ]

        uow = self._create_mock_uow(
            self.omitoro_id, "Omitoro",
            individual_savings=ind_savings,
            group_savings=grp_savings,
            current_ind_savings=[],
            current_grp_savings=[],
            groups=groups,
            clients=clients
        )

        res = ReportService.get_monthly_deposit_statement(uow, self.omitoro_id, 2026, 8)
        tot = [r for r in res["rows"] if r["programme"] == "Total"][0]
        # Total deposit_prev should be 50,000 + 25,000 + 10,000 = 85,000.0
        self.assertEqual(tot["deposit_prev"], 85000.0)
        # Total member_prev should be 2 unique clients
        self.assertEqual(tot["member_prev"], 2)
        # Net balance = 85,000 - 5,000 = 80,000.0
        self.assertEqual(tot["balance_amount"], 80000.0)

    def test_latest_loan_determines_repayment_cycle(self):
        """Verify sorting loans by created_at ensures latest loan sets client repayment cycle."""
        loan_products = [
            {"product_id": "p_weekly", "repayment_cycle": "Weekly"},
            {"product_id": "p_monthly", "repayment_cycle": "Monthly"}
        ]
        # Client c1 had Weekly loan in Jan, but upgraded to Monthly loan in July
        loans = [
            {"client_id": "c1", "product_id": "p_weekly", "created_at": "2026-01-10T00:00:00Z"},
            {"client_id": "c1", "product_id": "p_monthly", "created_at": "2026-07-15T00:00:00Z"}
        ]
        ind_savings = [
            {"client_id": "c1", "deposit_amount": 100000.0, "withdrawal_amount": 0.0, "remarks": ""}
        ]
        clients = [{"client_id": "c1", "group_id": None, "officer_id": "off1", "created_at": "2026-01-01"}]

        uow = self._create_mock_uow(
            self.omitoro_id, "Omitoro",
            individual_savings=ind_savings,
            clients=clients,
            loans=loans,
            loan_products=loan_products
        )

        res = ReportService.get_monthly_deposit_statement(uow, self.omitoro_id, 2026, 8)
        monthly_row = [r for r in res["rows"] if r["programme"] == "Monthly"][0]
        weekly_row = [r for r in res["rows"] if r["programme"] == "Weekly"][0]

        # Since latest loan was Monthly, deposit should be under Monthly programme
        self.assertEqual(monthly_row["deposit_prev"], 100000.0)
        self.assertEqual(weekly_row["deposit_prev"], 0.0)

    def test_current_month_group_savings_aggregation(self):
        """Verify group savings in current month are aggregated into curr[cyc]['dep'] per BR-SAV-001."""
        # Baseline pre-Sept
        ind_savings = [
            {"client_id": "c1", "deposit_amount": 10000.0, "withdrawal_amount": 0.0, "remarks": ""}
        ]
        # Current month group savings
        grp_savings = [
            {"group_id": "g1", "deposit_amount": 15000.0, "withdrawal_amount": 2000.0}
        ]
        groups = [{"group_id": "g1", "meeting_day": "Weekly", "officer_id": "off1"}]
        clients = [{"client_id": "c1", "group_id": "g1", "officer_id": "off1", "created_at": "2026-01-01"}]

        uow = self._create_mock_uow(
            self.omitoro_id, "Omitoro",
            individual_savings=ind_savings,
            group_savings=[],
            current_ind_savings=[],
            current_grp_savings=grp_savings,
            groups=groups,
            clients=clients
        )

        res = ReportService.get_monthly_deposit_statement(uow, self.omitoro_id, 2026, 9)
        weekly_row = [r for r in res["rows"] if r["programme"] == "Weekly"][0]
        tot = [r for r in res["rows"] if r["programme"] == "Total"][0]

        # Group savings deposit of 15,000 should be aggregated into curr deposit
        self.assertEqual(weekly_row["deposit_curr"], 15000.0)
        self.assertEqual(weekly_row["withdrawal_curr_amount"], 2000.0)
        self.assertEqual(tot["deposit_curr"], 15000.0)
        self.assertEqual(tot["withdrawal_curr_amount"], 2000.0)

    def test_october_rollover_from_prior_month(self):
        """Verify October 2026 rolls over previous values from September 2026 statement."""
        uow = self._create_mock_uow(self.ogijo_id, "Ogijo")
        res_oct = ReportService.get_monthly_deposit_statement(uow, self.ogijo_id, 2026, 10)
        tot_oct = [r for r in res_oct["rows"] if r["programme"] == "Total"][0]
        # Previous in Oct must equal total from Sept (303 prev + 0 curr = 303 member, 10690860 deposit)
        self.assertEqual(tot_oct["member_prev"], 303)
        self.assertEqual(tot_oct["deposit_prev"], 10690860.0)


    def test_ogijo_credit_statement_reads_baseline_from_reconciliation(self):
        """Ogijo credit statement unfiltered reads statutory baseline from monthly_statement_reconciliations."""
        uow = self._create_mock_uow(self.ogijo_id, "Ogijo")
        res = ReportService.get_monthly_credit_statement(uow, self.ogijo_id, 2026, 8)
        c_rows = {r["item"]: r for r in res["rows"]}

        # Check baseline counts and amounts from reconciliation
        disb_no = c_rows.get("Previous Loans Count (B/F)") or c_rows.get("• Previous Loans Count (B/F)")
        self.assertIsNotNone(disb_no)
        self.assertEqual(disb_no["total"], 283)
        self.assertEqual(disb_no["weekly"], 149)
        self.assertEqual(disb_no["daily"], 129)
        self.assertEqual(disb_no["monthly"], 5)

        disb_amt = c_rows.get("Previous Disbursed Principal (₦)") or c_rows.get("Previous Disbursed Amount (₦)") or c_rows.get("• Previous Disbursed Amount (₦)")
        self.assertIsNotNone(disb_amt)
        self.assertEqual(disb_amt["total"], 47085000.0)

    def test_trial_balance_and_receipts_payments_rule_12_clean_names(self):
        """Official Trial Balance and Receipts & Payments use professional banking names without developer codes."""
        uow = self._create_mock_uow(self.ogijo_id, "Ogijo")
        res = ReportService.get_official_trial_balance_and_receipts_payments(uow, self.ogijo_id, 2026, 9)
        rp = res["receipts_and_payments"]
        tb = res["trial_balance"]

        # Receipts line 1 and Payments line 8
        self.assertEqual(rp["receipts"][0]["item"], "Bank Balances B/F")
        self.assertEqual(rp["payments"][7]["item"], "Closing Liquid Position")

        # Trial balance assets
        tb_items = {r["item"]: r for r in tb["rows"]}
        self.assertIn("Vault Cash", tb_items)
        self.assertEqual(tb_items["Vault Cash"]["section"], "E. ASSETS")
        self.assertNotIn("Cash in hand (Account 1000)", tb_items)

    def test_parity_matrix_rule_12_clean_metric_names(self):
        """Parity matrix uses professional banking metric titles without paper book or GL codes."""
        uow = self._create_mock_uow(self.ogijo_id, "Ogijo")
        res = ReportService.get_monthly_parity_matrix(uow, self.ogijo_id, 2026, 9)
        metrics = [r["metric"] for r in res["rows"]]

        # Clean corporate titles
        self.assertIn("Transit Bank Deposits Remitted", metrics)
        self.assertIn("Field Transport & Travel", metrics)
        self.assertIn("Printing & Stationery", metrics)
        self.assertIn("Entertainment & Refreshment", metrics)
        self.assertIn("Utilities & Communication", metrics)
        self.assertIn("Total Operating Expenses (OpEx)", metrics)

        # Ensure legacy paper codes are completely removed
        self.assertNotIn("Bank Deposits Remitted (Acct 1050)", metrics)
        self.assertNotIn("Field Transport (PC1)", metrics)
        self.assertNotIn("Stationery (PB3)", metrics)
        self.assertNotIn("Entertainment (PB4)", metrics)
        self.assertNotIn("Utilities & Phone (PB2/PB6)", metrics)
        self.assertNotIn("Office Expenses (Acct 4000)", metrics)


if __name__ == "__main__":
    unittest.main()
