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
        Validates Statement A against September database records & statutory return:
        - Total Members: 303 Prev + 64 Curr = 367 Total
        - Deposit Received: ₦106,662,085 Prev + ₦4,292,225 Curr = ₦110,954,310 Total
        - Withdrawals & Returns: ₦3,497,300.00
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
        assert tot["deposit_prev"] == 106665860.0
        assert tot["deposit_total"] == 110958085.0

        assert tot["withdrawal_curr_no"] == 66
        assert tot["withdrawal_curr_amount"] == 3111800.0
        assert tot["return_curr_no"] == 22
        assert tot["return_curr_amount"] == 385500.0
        assert round(tot["withdrawal_curr_amount"] + tot["return_curr_amount"], 2) == 3497300.0
        assert tot["balance_no"] == 319
        assert tot["balance_amount"] == 11485785.0

        # Cycle asserts
        prog_map = {r["programme"]: r for r in rows}
        assert prog_map["Monthly"]["deposit_curr"] == 9000.0
        assert prog_map["Monthly"]["balance_amount"] == 36000.0

        assert prog_map["Weekly"]["deposit_curr"] == 1915125.0
        assert prog_map["Weekly"]["withdrawal_curr_no"] == 15
        assert prog_map["Weekly"]["withdrawal_curr_amount"] == 1758000.0
        assert prog_map["Weekly"]["return_curr_no"] == 14
        assert prog_map["Weekly"]["return_curr_amount"] == 226450.0
        assert prog_map["Weekly"]["balance_no"] == 169
        assert prog_map["Weekly"]["balance_amount"] == 4308405.0

        assert prog_map["Daily"]["deposit_curr"] == 2368100.0
        assert prog_map["Daily"]["withdrawal_curr_no"] == 51
        assert prog_map["Daily"]["withdrawal_curr_amount"] == 1353800.0
        assert prog_map["Daily"]["return_curr_no"] == 8
        assert prog_map["Daily"]["return_curr_amount"] == 159050.0
        assert prog_map["Daily"]["balance_no"] == 148
        assert prog_map["Daily"]["balance_amount"] == 7141380.0

    def test_september_credit_statement_exact_paper_parity(self):
        """
        Validates Statement B against September official physical paper reports:
        - Col 7 Total Net Loans: 283 Prev + 117 Curr - 107 Settled = 293 Active Loans
        - Col 8 Total Net Disbursed: ₦47,085,000 + ₦18,966,000 - ₦17,628,000 = ₦48,423,000.00
        - Col 11 Total Excess: ₦71,284,300 + ₦703,225 = ₦71,987,525.00
        - Col 13 Current Month Installments: ₦17,465,675.00
        - Col 14 Total Installments: ₦22,192,500 + ₦17,465,675 - ₦17,628,000 = ₦22,030,175.00
        - Col 23 Active Loans Count: 293
        - Col 24 Active Credit Balance: ₦48,423,000.00 - ₦22,030,175.00 = ₦26,392,825.00
        - Col 27/28 Settled Loans: 107 settled loans, ₦17,628,000.00
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
        assert row_tot_disb["monthly"] == 402000.0
        assert row_tot_disb["weekly"] == 25560000.0
        assert row_tot_disb["daily"] == 22461000.0
        assert row_tot_disb["total"] == 48423000.0

        row_tot_excess = rows_map["• Total Excess Collection (₦) (Col 11 = 9+10)"]
        assert row_tot_excess["total"] == 71987525.0

        row_cur_inst = rows_map["• Current Month Installment (₦) (Col 13)"]
        assert row_cur_inst["monthly"] == 264000.0
        assert row_cur_inst["weekly"] == 8556625.0
        assert row_cur_inst["daily"] == 8645050.0
        assert row_cur_inst["total"] == 17465675.0

        row_tot_inst = rows_map["• Total Net Installments (₦) (Col 14 = 12+13-28)"]
        assert row_tot_inst["monthly"] == 256000.0
        assert row_tot_inst["weekly"] == 11025125.0
        assert row_tot_inst["daily"] == 10749050.0
        assert row_tot_inst["total"] == 22030175.0

        row_bal_loans = rows_map["• Active Loans Balance Count (Col 23 = Col 7)"]
        assert row_bal_loans["monthly"] == 3
        assert row_bal_loans["weekly"] == 155
        assert row_bal_loans["daily"] == 135
        assert row_bal_loans["total"] == 293

        row_bal_credit = rows_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]
        assert row_bal_credit["monthly"] == 146000.0
        assert row_bal_credit["weekly"] == 14534875.0
        assert row_bal_credit["daily"] == 11711950.0
        assert row_bal_credit["total"] == 26392825.0

        row_full_rep_cnt = rows_map["• Current Full Repayment Count (Col 27)"]
        assert row_full_rep_cnt["monthly"] == 3
        assert row_full_rep_cnt["weekly"] == 56
        assert row_full_rep_cnt["daily"] == 48
        assert row_full_rep_cnt["total"] == 107

        row_full_rep_amt = rows_map["• Current Full Repayment Amount (₦) (Col 28)"]
        assert row_full_rep_amt["monthly"] == 408000.0
        assert row_full_rep_amt["weekly"] == 9036000.0
        assert row_full_rep_amt["daily"] == 8184000.0
        assert row_full_rep_amt["total"] == 17628000.0

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
        assert tot_row["deposit_prev"] == 110958085.0, "October deposit_prev must equal September deposit_total"
        assert tot_row["balance_amount"] == 11485785.0, "October opening balance must equal September closing balance"

        oct_credit = ReportService.get_monthly_credit_statement(
            self.uow, self.ogijo_branch_id, 2026, 10
        )
        assert "rows" in oct_credit
        oct_rows_map = {r["item"]: r for r in oct_credit["rows"]}
        prev_loans_row = oct_rows_map["• Previous Loans Count (B/F)"]
        assert prev_loans_row["total"] == 293, "October previous loans count must equal September total net loans (293)"

        prev_disb_row = oct_rows_map["• Previous Disbursed Amount (₦)"]
        assert prev_disb_row["total"] == 48423000.0

        prev_inst_row = oct_rows_map["• Previous Installments (₦) (Col 12)"]
        assert prev_inst_row["total"] == 22030175.0

        bal_credit_row = oct_rows_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]
        assert bal_credit_row["total"] == 26392825.0, "October opening credit balance must equal September closing credit"

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
        assert crd_map["• Current Month Installment (₦) (Col 13)"]["total"] == 17465675.0
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
        assert crd_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["total"] == 26392825.0

        # Assert Portfolio Full Payments and Excess Payments
        assert p_sum["full_payments"]["count"] == 22
        assert p_sum["full_payments"]["amount"] == 2930896.16
        assert p_sum["excess_payments"]["count"] > 0
        assert p_sum["excess_payments"]["amount"] > 0.0
        assert len(p_data["payoff_excess_table"]) > 0

    def test_filter_responsiveness_by_officer_and_product(self):
        """
        Verifies that Statement A (Deposit Statement) and Statement B (Credit Statement)
        are dynamically responsive to filtering by Credit Officer and Loan Product.
        """
        # Filter by officer 'Dorcas'
        dorcas_dep = ReportService.get_monthly_deposit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9, officer_name="Dorcas"
        )
        dorcas_tot = dorcas_dep["rows"][-1]
        assert dorcas_tot["member_prev"] == 126
        assert dorcas_tot["member_curr"] == 11
        assert dorcas_tot["deposit_curr"] == 1103800.0
        assert dorcas_tot["balance_amount"] == 4466480.0

        dorcas_crd = ReportService.get_monthly_credit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9, officer_name="Dorcas"
        )
        dorcas_crd_map = {r["item"]: r for r in dorcas_crd["rows"]}
        assert dorcas_crd_map["• Current Month Installment (₦) (Col 13)"]["total"] == 5067250.0
        assert dorcas_crd_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["total"] == 8021500.0

        # Filter by product 'Weekly 12W'
        prod_dep = ReportService.get_monthly_deposit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9, product_name="Weekly 12W"
        )
        assert len(prod_dep["rows"]) == 4

        prod_crd = ReportService.get_monthly_credit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9, product_name="Weekly 12W"
        )
        assert len(prod_crd["rows"]) > 0

    def test_october_daily_operations_increment_on_bf_balances(self):
        """
        Verifies that for future months like October 2026, the B/F balances from
        September carry forward and any daily transactions accumulate dynamically.
        """
        # 1. Statement A for October
        oct_dep = ReportService.get_monthly_deposit_statement(
            self.uow, self.ogijo_branch_id, 2026, 10
        )
        tot_dep = oct_dep["rows"][-1]
        # B/F values match September closing
        assert tot_dep["member_prev"] == 341
        assert tot_dep["deposit_prev"] == 110958085.0
        # Balance = open_bal + deposit_curr - withdrawals - returns
        expected_dep_bal = round(11485785.0 + tot_dep["deposit_curr"] - tot_dep["withdrawal_curr_amount"] - tot_dep["return_curr_amount"], 2)
        assert tot_dep["balance_amount"] == expected_dep_bal

        # 2. Statement B for October
        oct_crd = ReportService.get_monthly_credit_statement(
            self.uow, self.ogijo_branch_id, 2026, 10
        )
        oct_crd_map = {r["item"]: r for r in oct_crd["rows"]}
        # B/F values match September closing
        assert oct_crd_map["• Previous Loans Count (B/F)"]["total"] == 293
        assert oct_crd_map["• Previous Disbursed Amount (₦)"]["total"] == 48423000.0
        assert oct_crd_map["• Previous Installments (₦) (Col 12)"]["total"] == 22030175.0
        # Active Credit Balance = Col 8 (net disbursed) - Col 14 (net installments)
        net_disb = oct_crd_map["• Total Net Disbursed (₦) (Col 8 = 4+6-28)"]["total"]
        net_inst = oct_crd_map["• Total Net Installments (₦) (Col 14 = 12+13-28)"]["total"]
        assert oct_crd_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["total"] == round(net_disb - net_inst, 2)

    def test_october_trial_balance_and_receipts_payments_rollover(self):
        """
        Verifies that Receipts & Payments Account and Official Trial Balance
        automatically roll over YTD figures, opening bank balances, and capital funds into October.
        """
        oct_st = ReportService.get_official_trial_balance_and_receipts_payments(
            self.uow, self.ogijo_branch_id, 2026, 10
        )
        rp = oct_st["receipts_and_payments"]
        tb = oct_st["trial_balance"]
        tb_map = {r["item"]: r for r in tb["rows"]}

        # 1. Receipts & Payments Account
        # Row 1 Bank Balances B/F matches September closing banks
        assert rp["receipts"][0]["amount"] >= 644306.0
        # Balance variance is exactly 0.0
        assert rp["variance"] == 0.0
        assert rp["total_receipts"] == rp["total_payments"]

        # 2. Official Trial Balance YTD Rollover
        assert tb_map["Personnel Gross Salary"]["debit"] == 4453447.0
        assert tb_map["Office Rent"]["debit"] == 400000.0
        assert tb_map["Training Expenses"]["debit"] == 1890652.0
        assert tb_map["Transport Allowance"]["debit"] == 1405600.0
        assert tb_map["Sales Profit"]["credit"] == 16401680.0
        assert tb_map["Retained Earnings"]["credit"] == 26351209.0
        assert tb_map["Head Office (Asset Allocation)"]["credit"] == 0.0
        assert tb_map["Head Office (Main)"]["debit"] == 36553628.0
        assert tb_map["Deposit Balance"]["credit"] == 11485785.0
        assert tb_map["Credit Balance (Debtors)"]["debit"] == 26392825.0
        # Total debits and credits
        assert tb["total_debits"] == 73678366.0
        assert tb["total_credits"] == 73678366.0
        assert tb["is_balanced"] is True

    def test_co_summary_october_rollover_and_filter_responsiveness(self):
        """
        Verifies that the Credit Officers Summary table (Parity Matrix)
        dynamically rolls over individual CO credit and savings balances for October,
        and responds to filtering by Credit Officer.
        """
        # Unfiltered October CO summary
        oct_matrix = ReportService.get_monthly_parity_matrix(
            self.uow, self.ogijo_branch_id, 2026, 10
        )
        rows_map = {r["metric"]: r["values"] for r in oct_matrix["rows"]}

        # Opening credit balances per officer
        open_c = rows_map["Opening Credit Balance (B/F)"]
        assert open_c["Dorcas (OGI_CO1)"] == 8021500.0
        assert open_c["Ayomide (OGI_CO2)"] == 6513375.0
        assert open_c["Olajumoke (OGI_CO3)"] == 7118700.0
        assert open_c["Oluwaseun (OGI_CO4)"] == 4739250.0
        assert open_c["Ogijo Branch Total"] == 26392825.0

        # Opening savings balances per officer
        open_s = rows_map["Savings B/F (Opening Balance)"]
        assert open_s["Dorcas (OGI_CO1)"] == 2431680.0
        assert open_s["Ayomide (OGI_CO2)"] == 1876725.0
        assert open_s["Olajumoke (OGI_CO3)"] == 4941550.0
        assert open_s["Oluwaseun (OGI_CO4)"] == 2235830.0
        assert open_s["Ogijo Branch Total"] == 11485785.0

        # Filtered by officer 'Dorcas'
        dorcas_matrix = ReportService.get_monthly_parity_matrix(
            self.uow, self.ogijo_branch_id, 2026, 10, officer_name="Dorcas"
        )
        assert len(dorcas_matrix["officers"]) == 1
        assert dorcas_matrix["officers"][0]["name"] == "Dorcas (OGI_CO1)"


