import pytest
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.report_service import ReportService


class TestMonthlyDepositAndCreditStatements:

    @pytest.fixture(autouse=True)
    def setup(self):
        self.uow = SupabaseUnitOfWork()
        self.ogijo_branch_id = "997d504e-7f5c-4772-887d-fdd5a4c1183b"

    def test_september_deposit_statement_exact_paper_parity(self):
        """
        Validates Statement A against the September statutory paper return:
        - Total Members: 303 Prev + 38 Curr = 341 Total
        - Deposit Received: ₦106,662,085 Prev + ₦4,292,225 Curr = ₦110,954,310 Total
        - Withdrawals: 66 Savers, ₦3,111,800 Current
        - Cancellations: 22 Savers, ₦385,500 Current
        - Active Savers: 319 Savers
        - Net Savings Balance: ₦11,485,785.00
        """
        dep_data = ReportService.get_monthly_deposit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        rows = dep_data["rows"]
        assert len(rows) == 4, "Should have Monthly, Weekly, Daily, Total rows"

        tot = rows[-1]
        assert tot["programme"] == "Total"
        assert tot["member_prev"] == 303
        assert tot["member_curr"] == 38
        assert tot["member_total"] == 341

        assert tot["deposit_curr"] == 4292225.0
        assert tot["deposit_total"] == 110954310.0

        assert tot["withdrawal_curr_no"] == 66
        assert tot["withdrawal_curr_amount"] == 3111800.0

        assert tot["return_curr_no"] == 22
        assert tot["return_curr_amount"] == 385500.0

        assert tot["balance_no"] == 319
        assert tot["balance_amount"] == 11485785.0

    def test_september_credit_statement_exact_paper_parity(self):
        """
        Validates Statement B against the September statutory paper return:
        - Col 7 Total Net Loans: 283 Prev + 117 Curr - 107 Settled = 293 Active Loans
        - Col 8 Total Net Disbursed: ₦47,085,000 + ₦18,966,000 - ₦17,628,000 = ₦48,423,000
        - Col 11 Total Excess: ₦71,284,300 + ₦703,225 = ₦71,987,525
        - Col 14 Total Installments: ₦22,192,500 + ₦17,465,675 - ₦17,628,000 = ₦22,030,175
        - Col 23 Active Loans Count: 293
        - Col 24 Active Credit Balance: ₦48,423,000 - ₦22,030,175 = ₦26,392,825.00
        """
        credit_data = ReportService.get_monthly_credit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        rows_map = {r["item"]: r for r in credit_data["rows"]}

        row_tot_loans = rows_map["• Total Net Loans Count (Col 7 = 3+5-27)"]
        assert row_tot_loans["monthly"] == 3
        assert row_tot_loans["weekly"] == 155
        assert row_tot_loans["daily"] == 135
        assert row_tot_loans["total"] == 293

        row_tot_disb = rows_map["• Total Net Disbursed (₦) (Col 8 = 4+6-28)"]
        assert row_tot_disb["total"] == 48423000.0

        row_tot_excess = rows_map["• Total Excess Collection (₦) (Col 11 = 9+10)"]
        assert row_tot_excess["total"] == 71987525.0

        row_tot_inst = rows_map["• Total Installments (₦) (Col 14 = 12+13-28)"]
        assert row_tot_inst["total"] == 22030175.0

        row_bal_loans = rows_map["• Active Loans Count (Col 23 = Col 7)"]
        assert row_bal_loans["total"] == 293

        row_bal_credit = rows_map["• Active Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]
        assert row_bal_credit["monthly"] == 146000.0
        assert row_bal_credit["weekly"] == 14534875.0
        assert row_bal_credit["daily"] == 11711950.0
        assert row_bal_credit["total"] == 26392825.0

    def test_automatic_rollover_next_month_zero_manual_input(self):
        """
        Verifies that for future months (e.g. October 2026), the system automatically
        rolls over M-1 closing totals into M Previous numbers with ZERO manual input.
        """
        oct_dep = ReportService.get_monthly_deposit_statement(
            self.uow, self.ogijo_branch_id, 2026, 10
        )
        assert "rows" in oct_dep and len(oct_dep["rows"]) == 4
        tot_row = oct_dep["rows"][-1]
        assert tot_row["member_prev"] == 341, "October member_prev must equal September member_total"
        assert tot_row["deposit_prev"] == 110954310.0, "October deposit_prev must equal September deposit_total"

        oct_credit = ReportService.get_monthly_credit_statement(
            self.uow, self.ogijo_branch_id, 2026, 10
        )
        assert "rows" in oct_credit
        oct_rows_map = {r["item"]: r for r in oct_credit["rows"]}
        prev_loans_row = oct_rows_map["• Previous Loans Count (B/F)"]
        assert prev_loans_row["total"] == 293, "October previous loans count must equal September total net loans (293)"

    def test_september_cross_tab_parity_and_portfolio_payoffs(self):
        """
        Verifies 100% cross-tab parity across Database, Parity Matrix, Statements A & B,
        Receipts & Payments, Trial Balance, and Portfolio Overview for September 2026.
        Enforces zero hardcoding and authoritative data provenance (BR-DASH-002, BR-DASH-005).
        """
        from datetime import date
        from services.portfolio_service import PortfolioService
        from services.rbac_scope_service import RBACScope

        # 1. Parity Matrix
        matrix = ReportService.get_monthly_parity_matrix(self.uow, self.ogijo_branch_id, 2026, 9)
        cards = matrix["summary_cards"]

        # 2. Statement A (Deposit Statement)
        dep = ReportService.get_monthly_deposit_statement(self.uow, self.ogijo_branch_id, 2026, 9)
        tot_dep = dep["rows"][-1]

        # 3. Statement B (Credit Statement)
        crd = ReportService.get_monthly_credit_statement(self.uow, self.ogijo_branch_id, 2026, 9)
        crd_map = {r["item"]: r for r in crd["rows"]}

        # 4. Trial Balance & Receipts/Payments
        tb_rec = ReportService.get_official_trial_balance_and_receipts_payments(self.uow, self.ogijo_branch_id, 2026, 9)
        rp = tb_rec["receipts_and_payments"]
        rp_rec_map = {r["item"]: r["amount"] for r in rp["receipts"]}
        rp_pay_map = {p["item"]: p["amount"] for p in rp["payments"]}

        # 5. Portfolio Service
        scope = RBACScope(role="BRANCH_MANAGER", user_id="bm_test", branch_id=self.ogijo_branch_id, scope_level="BRANCH")
        p_data = PortfolioService.get_portfolio_data_for_scope(
            uow=self.uow,
            scope=scope,
            selected_branch="Ogijo",
            start_date=date(2026, 9, 1),
            end_date=date(2026, 9, 30)
        )
        p_sum = p_data["summary"]

        # Assert Collection Parity: ₦17,465,675.00
        assert cards["collections"] == 17465675.0
        assert crd_map["• Current Month Installments (₦) (Col 13)"]["total"] == 17465675.0
        assert rp_rec_map["Installments (Finance Repayments)"] == 17465675.0
        assert p_sum["total_actual_collection"] == 17465675.0

        # Assert Savings Deposits Parity: ₦4,292,225.00
        assert cards["savings_deposits"] == 4292225.0
        assert tot_dep["deposit_curr"] == 4292225.0
        assert rp_rec_map["Deposit Savings (Monthly Deposits)"] == 4292225.0

        # Assert Savings Withdrawals Parity: ₦3,497,300.00
        assert cards["savings_withdrawals"] == 3497300.0
        assert (tot_dep["withdrawal_curr_amount"] + tot_dep["return_curr_amount"]) == 3497300.0
        assert rp_pay_map["Deposit Withdrawals (Savings Payouts)"] == 3497300.0

        # Assert Closing Savings Parity: ₦11,485,785.00
        assert cards["closing_savings"] == 11485785.0
        assert tot_dep["balance_amount"] == 11485785.0

        # Assert Closing Credit Parity: ₦26,392,825.00
        assert cards["closing_credit"] == 26392825.0
        assert crd_map["• Active Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["total"] == 26392825.0

        # Assert Portfolio Full Payments and Excess Payments
        assert p_sum["full_payments"]["count"] == 22
        assert p_sum["full_payments"]["amount"] == 2930896.16
        assert p_sum["excess_payments"]["count"] > 0
        assert p_sum["excess_payments"]["amount"] > 0.0
        assert len(p_data["payoff_excess_table"]) > 0
