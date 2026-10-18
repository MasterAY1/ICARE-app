import pytest
from database.repositories.unit_of_work import SupabaseUnitOfWork
from services.report_service import ReportService


class TestSeptemberReportsParity:
    """
    Authoritative test suite for September 2026 reports data parity (BIA-REP-PARITY-REDESIGN-006).
    Enforces 100% exact match against Ogijo Branch physical paper report slips
    and Finance_book_automated.xlsx.
    """

    @pytest.fixture(autouse=True)
    def setup(self):
        self.uow = SupabaseUnitOfWork()
        self.ogijo_branch_id = "997d504e-7f5c-4772-887d-fdd5a4c1183b"

    def test_zero_balance_cancellation_invariant(self):
        """
        Validates Statement A (Monthly Deposit Statement) zero-balance cancellation rule:
        - 303 Savers B/F + 38 New Savers = 341 Total Members
        - Normal Withdrawals: 66 savers, ₦3,111,800.00
        - Account Cancellations / Deposit Returns (zero-balance withdrawals): 22 savers, ₦385,500.00
        - Active Savers at Month-End: 341 - 22 = 319 active savers
        - Net Savings Balance: ₦11,485,785.00
        """
        dep_data = ReportService.get_monthly_deposit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        assert "rows" in dep_data and len(dep_data["rows"]) == 4
        rows_map = {r["programme"]: r for r in dep_data["rows"]}

        # Monthly
        m = rows_map["Monthly"]
        assert m["member_prev"] == 2
        assert m["member_curr"] == 0
        assert m["member_total"] == 2
        assert m["deposit_prev"] == 27000.0
        assert m["deposit_curr"] == 9000.0
        assert m["deposit_total"] == 36000.0
        assert m["withdrawal_curr_no"] == 0
        assert m["withdrawal_curr_amount"] == 0.0
        assert m["return_curr_no"] == 0
        assert m["return_curr_amount"] == 0.0
        assert m["balance_no"] == 2
        assert m["balance_amount"] == 36000.0

        # Weekly
        w = rows_map["Weekly"]
        assert w["member_prev"] == 171
        assert w["member_curr"] == 12
        assert w["member_total"] == 183
        assert w["deposit_prev"] == 4377730.0
        assert w["deposit_curr"] == 1915125.0
        assert w["deposit_total"] == 6292855.0
        assert w["withdrawal_curr_no"] == 15
        assert w["withdrawal_curr_amount"] == 1758000.0
        assert w["return_curr_no"] == 14
        assert w["return_curr_amount"] == 226450.0
        assert w["balance_no"] == 169
        assert w["balance_amount"] == 4308405.0

        # Daily
        d = rows_map["Daily"]
        assert d["member_prev"] == 130
        assert d["member_curr"] == 26
        assert d["member_total"] == 156
        assert d["deposit_prev"] == 6286130.0
        assert d["deposit_curr"] == 2368100.0
        assert d["deposit_total"] == 8654230.0
        assert d["withdrawal_curr_no"] == 51
        assert d["withdrawal_curr_amount"] == 1353800.0
        assert d["return_curr_no"] == 8
        assert d["return_curr_amount"] == 159050.0
        assert d["balance_no"] == 148
        assert d["balance_amount"] == 7141380.0

        # Total
        tot = rows_map["Total"]
        assert tot["member_prev"] == 303
        assert tot["member_curr"] == 38
        assert tot["member_total"] == 341
        assert tot["deposit_prev"] == 10690860.0
        assert tot["deposit_curr"] == 4292225.0
        assert tot["deposit_total"] == 14983085.0
        assert tot["withdrawal_curr_no"] == 66
        assert tot["withdrawal_curr_amount"] == 3111800.0
        assert tot["return_curr_no"] == 22
        assert tot["return_curr_amount"] == 385500.0
        assert round(tot["withdrawal_curr_amount"] + tot["return_curr_amount"], 2) == 3497300.0
        assert tot["balance_no"] == 319
        assert tot["balance_amount"] == 11485785.0

    def test_co_summary_analysed_expenses(self):
        """
        Validates that CO Summary (Parity Matrix) contains the 4 categorized analysed expenses
        per Credit Officer from Sheet 7 of Finance_book_automated.xlsx instead of 0.0:
        - Dorcas (OGI_CO1): ₦10,700.00 (Transport ₦8k, Stationery ₦2.7k)
        - Olajumoke (OGI_CO3): ₦142,100.00 (Transport ₦105k, Stationery ₦26k, Utilities ₦6.1k, Entertainment ₦5k)
        - Oluwaseun (OGI_CO4): ₦54,800.00 (Transport ₦42k, Stationery ₦9.7k, Utilities ₦1.1k, Entertainment ₦2k)
        - Ayomide (OGI_CO2): ₦0.00
        - Ogijo Branch Total: ₦207,600.00
        """
        matrix = ReportService.get_monthly_parity_matrix(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        rows_map = {r["metric"]: r["values"] for r in matrix["rows"]}

        # 1. Total Operating Expenses (Acct 4000)
        tot_exp = rows_map["Office Expenses (Acct 4000)"]
        assert tot_exp["Dorcas (OGI_CO1)"] == 10700.0
        assert tot_exp["Olajumoke (OGI_CO3)"] == 142100.0
        assert tot_exp["Oluwaseun (OGI_CO4)"] == 54800.0
        assert tot_exp["Ayomide (OGI_CO2)"] == 0.0
        assert tot_exp["Ogijo Branch Total"] == 207600.0

        # 2. Field Transport (PC1)
        trans = rows_map["Field Transport (PC1)"]
        assert trans["Dorcas (OGI_CO1)"] == 8000.0
        assert trans["Olajumoke (OGI_CO3)"] == 105000.0
        assert trans["Oluwaseun (OGI_CO4)"] == 42000.0
        assert trans["Ayomide (OGI_CO2)"] == 0.0
        assert trans["Ogijo Branch Total"] == 155000.0

        # 3. Stationery (PB3)
        stat = rows_map["Stationery (PB3)"]
        assert stat["Dorcas (OGI_CO1)"] == 2700.0
        assert stat["Olajumoke (OGI_CO3)"] == 26000.0
        assert stat["Oluwaseun (OGI_CO4)"] == 9700.0
        assert stat["Ogijo Branch Total"] == 38400.0

        # 4. Utilities & Phone (PB2/PB6)
        util = rows_map["Utilities & Phone (PB2/PB6)"]
        assert util["Olajumoke (OGI_CO3)"] == 6100.0
        assert util["Oluwaseun (OGI_CO4)"] == 1100.0
        assert util["Ogijo Branch Total"] == 7200.0

        # 5. Entertainment (PB4)
        ent = rows_map["Entertainment (PB4)"]
        assert ent["Olajumoke (OGI_CO3)"] == 5000.0
        assert ent["Oluwaseun (OGI_CO4)"] == 2000.0
        assert ent["Ogijo Branch Total"] == 7000.0

    def test_receipts_payments_balanced(self):
        """
        Validates Receipts & Payments Account for September 2026:
        - Total Inflows: ₦28,640,196.00
        - Total Outflows: ₦28,640,196.00
        - Variance: ₦0.00 (100% Balanced)
        """
        st = ReportService.get_official_trial_balance_and_receipts_payments(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        rp = st["receipts_and_payments"]
        assert rp["total_receipts"] == 28640196.0
        assert rp["total_payments"] == 28640196.0
        assert rp["variance"] == 0.0

    def test_trial_balance_balanced(self):
        """
        Validates Trial Balance for September 2026:
        - Total Debits: ₦73,678,366.00
        - Total Credits: ₦73,678,366.00
        - Variance: ₦0.00 (100% Balanced)
        """
        st = ReportService.get_official_trial_balance_and_receipts_payments(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        tb = st["trial_balance"]
        assert tb["total_debits"] == 73678366.0
        assert tb["total_credits"] == 73678366.0
        assert tb["variance"] == 0.0
        assert tb["is_balanced"] is True

    def test_annex_1_totals(self):
        """
        Validates Annex-1 Sundry Accounts analysis:
        - Receipts Total: ₦60,920.00
        - Operating Expenses Total: ₦1,041,405.00
        """
        annex = ReportService.get_annex_1_details(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        assert annex["total_sundry_receipts"] == 60920.0
        assert annex["total_sundry_payments"] == 1041405.0

    def test_dynamic_bf_cascade(self):
        """
        Validates dynamic liquid cascade from August closing to September opening B/F:
        - August Closing Liquid: Sterling (₦394,206) + Wema (₦557,780) + Overdue (₦14,500) = ₦966,486.00
        - September Line 1 Receipts B/F: ₦966,486.00
        """
        st = ReportService.get_official_trial_balance_and_receipts_payments(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        rp = st["receipts_and_payments"]
        r1 = rp["receipts"][0]
        assert r1["amount"] == 966486.0, f"Expected B/F ₦966,486.00, got {r1['amount']}"

    def test_credit_statement_b_paper_parity(self):
        """
        Validates Statement B (Credit Statement) parity with physical slips:
        - Net Disbursed: ₦48,423,000.00
        - Net Installments: ₦22,030,175.00
        - Active Loans Count: 293
        - Active Credit Balance: ₦26,392,825.00
        - Settled Loans: 107 loans, ₦17,628,000.00
        """
        crd = ReportService.get_monthly_credit_statement(
            self.uow, self.ogijo_branch_id, 2026, 9
        )
        crd_map = {r["item"]: r for r in crd["rows"]}

        assert crd_map["• Current Loans Count"]["monthly"] == 1
        assert crd_map["• Current Loans Count"]["weekly"] == 62
        assert crd_map["• Current Loans Count"]["daily"] == 54
        assert crd_map["• Current Loans Count"]["total"] == 117

        assert crd_map["• Current Disbursed Amount (₦)"]["monthly"] == 180000.0
        assert crd_map["• Current Disbursed Amount (₦)"]["weekly"] == 10009000.0
        assert crd_map["• Current Disbursed Amount (₦)"]["daily"] == 8777000.0
        assert crd_map["• Current Disbursed Amount (₦)"]["total"] == 18966000.0

        assert crd_map["• Total Net Loans Count (Col 7 = 3+5-27)"]["monthly"] == 3
        assert crd_map["• Total Net Loans Count (Col 7 = 3+5-27)"]["weekly"] == 155
        assert crd_map["• Total Net Loans Count (Col 7 = 3+5-27)"]["daily"] == 135
        assert crd_map["• Total Net Loans Count (Col 7 = 3+5-27)"]["total"] == 293

        assert crd_map["• Total Net Disbursed (₦) (Col 8 = 4+6-28)"]["monthly"] == 402000.0
        assert crd_map["• Total Net Disbursed (₦) (Col 8 = 4+6-28)"]["weekly"] == 25560000.0
        assert crd_map["• Total Net Disbursed (₦) (Col 8 = 4+6-28)"]["daily"] == 22461000.0
        assert crd_map["• Total Net Disbursed (₦) (Col 8 = 4+6-28)"]["total"] == 48423000.0

        assert crd_map["• Current Month Excess (₦) (Col 10)"]["monthly"] == 0.0
        assert crd_map["• Current Month Excess (₦) (Col 10)"]["weekly"] == 345625.0
        assert crd_map["• Current Month Excess (₦) (Col 10)"]["daily"] == 357600.0
        assert crd_map["• Current Month Excess (₦) (Col 10)"]["total"] == 703225.0

        assert crd_map["• Total Excess Collection (₦) (Col 11 = 9+10)"]["monthly"] == 0.0
        assert crd_map["• Total Excess Collection (₦) (Col 11 = 9+10)"]["weekly"] == 25465525.0
        assert crd_map["• Total Excess Collection (₦) (Col 11 = 9+10)"]["daily"] == 46522000.0
        assert crd_map["• Total Excess Collection (₦) (Col 11 = 9+10)"]["total"] == 71987525.0

        assert crd_map["• Current Month Installment (₦) (Col 13)"]["monthly"] == 264000.0
        assert crd_map["• Current Month Installment (₦) (Col 13)"]["weekly"] == 8556625.0
        assert crd_map["• Current Month Installment (₦) (Col 13)"]["daily"] == 8645050.0
        assert crd_map["• Current Month Installment (₦) (Col 13)"]["total"] == 17465675.0

        assert crd_map["• Total Net Installments (₦) (Col 14 = 12+13-28)"]["monthly"] == 256000.0
        assert crd_map["• Total Net Installments (₦) (Col 14 = 12+13-28)"]["weekly"] == 11025125.0
        assert crd_map["• Total Net Installments (₦) (Col 14 = 12+13-28)"]["daily"] == 10749050.0
        assert crd_map["• Total Net Installments (₦) (Col 14 = 12+13-28)"]["total"] == 22030175.0

        assert crd_map["• Active Loans Balance Count (Col 23 = Col 7)"]["monthly"] == 3
        assert crd_map["• Active Loans Balance Count (Col 23 = Col 7)"]["weekly"] == 155
        assert crd_map["• Active Loans Balance Count (Col 23 = Col 7)"]["daily"] == 135
        assert crd_map["• Active Loans Balance Count (Col 23 = Col 7)"]["total"] == 293

        assert crd_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["monthly"] == 146000.0
        assert crd_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["weekly"] == 14534875.0
        assert crd_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["daily"] == 11711950.0
        assert crd_map["• Outstanding Credit Balance (₦) (Col 24 = Col 8 - Col 14)"]["total"] == 26392825.0

        assert crd_map["• Current Full Repayment Count (Col 27)"]["monthly"] == 3
        assert crd_map["• Current Full Repayment Count (Col 27)"]["weekly"] == 56
        assert crd_map["• Current Full Repayment Count (Col 27)"]["daily"] == 48
        assert crd_map["• Current Full Repayment Count (Col 27)"]["total"] == 107

        assert crd_map["• Current Full Repayment Amount (₦) (Col 28)"]["monthly"] == 408000.0
        assert crd_map["• Current Full Repayment Amount (₦) (Col 28)"]["weekly"] == 9036000.0
        assert crd_map["• Current Full Repayment Amount (₦) (Col 28)"]["daily"] == 8184000.0
        assert crd_map["• Current Full Repayment Amount (₦) (Col 28)"]["total"] == 17628000.0

        assert crd_map["• Previous Full Repayment Amount (₦) (Col 26)"]["monthly"] == 2898000.0
        assert crd_map["• Previous Full Repayment Amount (₦) (Col 26)"]["weekly"] == 202326000.0
        assert crd_map["• Previous Full Repayment Amount (₦) (Col 26)"]["daily"] == 197541000.0
        assert crd_map["• Previous Full Repayment Amount (₦) (Col 26)"]["total"] == 402765000.0

        assert crd_map["• Total Cumulative Settled Amount (₦)"]["monthly"] == 3306000.0
        assert crd_map["• Total Cumulative Settled Amount (₦)"]["weekly"] == 211362000.0
        assert crd_map["• Total Cumulative Settled Amount (₦)"]["daily"] == 205725000.0
        assert crd_map["• Total Cumulative Settled Amount (₦)"]["total"] == 420393000.0
