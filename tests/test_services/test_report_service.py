import unittest
from datetime import date
from unittest.mock import MagicMock
import pandas as pd
from services.report_service import ReportService
from utils.reports import export_dataframe_to_excel_bytes, export_consolidated_report_to_excel


class TestReportService(unittest.TestCase):
    def setUp(self):
        self.mock_uow = MagicMock()

    def test_trial_balance_balanced(self):
        mock_accounts = [
            {"account_code": "1000", "account_name": "Physical Vault Cash", "account_type": "Asset", "normal_balance": "Debit"},
            {"account_code": "1100", "account_name": "Commercial Bank Account", "account_type": "Asset", "normal_balance": "Debit"},
            {"account_code": "2000", "account_name": "Client Savings Deposits", "account_type": "Liability", "normal_balance": "Credit"},
            {"account_code": "4000", "account_name": "Interest Income", "account_type": "Income", "normal_balance": "Credit"},
        ]
        mock_entries = [
            {"account_code": "1000", "side": "Debit", "amount": 100000.0, "branch_id": "b1"},
            {"account_code": "1000", "side": "Credit", "amount": 20000.0, "branch_id": "b1"},
            {"account_code": "1100", "side": "Debit", "amount": 50000.0, "branch_id": "b1"},
            {"account_code": "2000", "side": "Credit", "amount": 120000.0, "branch_id": "b1"},
            {"account_code": "4000", "side": "Credit", "amount": 10000.0, "branch_id": "b1"},
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "chart_of_accounts":
                query.execute.return_value = MagicMock(data=mock_accounts)
            elif table_name == "financial_ledger_entries":
                query.execute.return_value = MagicMock(data=mock_entries)
            else:
                query.execute.return_value = MagicMock(data=[])
            query.select.return_value = query
            query.order.return_value = query
            query.eq.return_value = query
            query.in_.return_value = query
            query.gte.return_value = query
            query.lte.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table

        # Execute
        tb = ReportService.get_trial_balance(self.mock_uow)

        # Total Debits: 100,000 + 50,000 = 150,000
        # Total Credits: 20,000 + 120,000 + 10,000 = 150,000
        self.assertEqual(tb["total_debits"], 150000.0)
        self.assertEqual(tb["total_credits"], 150000.0)
        self.assertEqual(tb["variance"], 0.0)
        self.assertEqual(tb["status"], "BALANCED")
        self.assertEqual(len(tb["rows"]), 4)

        # Verify Account 1000 Asset Net Balance (Debit balance: 80,000)
        row_1000 = next(r for r in tb["rows"] if r["Account Code"] == "1000")
        self.assertEqual(row_1000["Debit Balance"], 80000.0)
        self.assertEqual(row_1000["Credit Balance"], 0.0)

        # Verify Account 2000 Liability Net Balance (Credit balance: 120,000)
        row_2000 = next(r for r in tb["rows"] if r["Account Code"] == "2000")
        self.assertEqual(row_2000["Credit Balance"], 120000.0)
        self.assertEqual(row_2000["Debit Balance"], 0.0)

    def test_trial_balance_unbalanced_flag(self):
        mock_accounts = [
            {"account_code": "1000", "account_name": "Physical Vault Cash", "account_type": "Asset", "normal_balance": "Debit"},
            {"account_code": "2000", "account_name": "Client Savings Deposits", "account_type": "Liability", "normal_balance": "Credit"},
        ]
        # Debits = 100,000, Credits = 90,000 (10,000 imbalance)
        mock_entries = [
            {"account_code": "1000", "side": "Debit", "amount": 100000.0, "branch_id": "b1"},
            {"account_code": "2000", "side": "Credit", "amount": 90000.0, "branch_id": "b1"},
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "chart_of_accounts":
                query.execute.return_value = MagicMock(data=mock_accounts)
            elif table_name == "financial_ledger_entries":
                query.execute.return_value = MagicMock(data=mock_entries)
            else:
                query.execute.return_value = MagicMock(data=[])
            query.select.return_value = query
            query.order.return_value = query
            query.eq.return_value = query
            query.in_.return_value = query
            query.gte.return_value = query
            query.lte.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table

        tb = ReportService.get_trial_balance(self.mock_uow)
        self.assertEqual(tb["total_debits"], 100000.0)
        self.assertEqual(tb["total_credits"], 90000.0)
        self.assertEqual(tb["variance"], 10000.0)
        self.assertEqual(tb["status"], "OUT OF BALANCE")

    def test_trial_balance_multi_branch_scoping(self):
        mock_accounts = [
            {"account_code": "1000", "account_name": "Physical Vault Cash", "account_type": "Asset", "normal_balance": "Debit"},
            {"account_code": "2000", "account_name": "Client Savings Deposits", "account_type": "Liability", "normal_balance": "Credit"},
        ]
        mock_entries = [
            {"account_code": "1000", "side": "Debit", "amount": 50000.0, "branch_id": "b1"},
            {"account_code": "2000", "side": "Credit", "amount": 50000.0, "branch_id": "b2"},
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "chart_of_accounts":
                query.execute.return_value = MagicMock(data=mock_accounts)
            elif table_name == "financial_ledger_entries":
                query.execute.return_value = MagicMock(data=mock_entries)
            query.select.return_value = query
            query.order.return_value = query
            query.in_.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table
        tb = ReportService.get_trial_balance(self.mock_uow, branch_id=["b1", "b2"])
        self.assertEqual(tb["total_debits"], 50000.0)
        self.assertEqual(tb["total_credits"], 50000.0)
        self.assertEqual(tb["status"], "BALANCED")

    def test_savings_summary(self):
        mock_clients = [
            {"client_id": "c1", "client_code": "CLI-001", "name": "Alice", "branch_id": "b1", "app_users": {"full_name": "Officer One"}},
            {"client_id": "c2", "client_code": "CLI-002", "name": "Bob", "branch_id": "b1", "app_users": {"full_name": "Officer Two"}}
        ]
        mock_ind_savings = [
            {"client_id": "c1", "deposit_amount": 5000.0, "withdrawal_amount": 0.0, "posting_date": "2026-09-01"},
            {"client_id": "c1", "deposit_amount": 2000.0, "withdrawal_amount": 1000.0, "posting_date": "2026-09-02"},
            {"client_id": "c2", "deposit_amount": 10000.0, "withdrawal_amount": 0.0, "posting_date": "2026-09-01"},
        ]
        mock_grp_savings = [
            {"group_id": "g1", "deposit_amount": 20000.0, "withdrawal_amount": 0.0, "posting_date": "2026-09-01", "groups": {"name": "Group Alpha"}},
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "clients":
                query.execute.return_value = MagicMock(data=mock_clients)
            elif table_name == "individual_savings":
                query.execute.return_value = MagicMock(data=mock_ind_savings)
            elif table_name == "group_savings":
                query.execute.return_value = MagicMock(data=mock_grp_savings)
            else:
                query.execute.return_value = MagicMock(data=[])
            query.select.return_value = query
            query.eq.return_value = query
            query.in_.return_value = query
            query.gte.return_value = query
            query.lte.return_value = query
            query.order.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table

        sav = ReportService.get_savings_summary(self.mock_uow)

        self.assertEqual(sav["total_individual_deposits"], 17000.0)
        self.assertEqual(sav["total_individual_withdrawals"], 1000.0)
        self.assertEqual(sav["net_individual_savings"], 16000.0)
        self.assertEqual(sav["total_group_deposits"], 20000.0)
        self.assertEqual(sav["active_savers_count"], 2)
        self.assertEqual(sav["total_consolidated_savings"], 36000.0)

    def test_savings_summary_officer_filtering(self):
        mock_clients = [
            {"client_id": "c1", "client_code": "CLI-001", "name": "Alice", "branch_id": "b1", "app_users": {"full_name": "Officer One"}},
            {"client_id": "c2", "client_code": "CLI-002", "name": "Bob", "branch_id": "b1", "app_users": {"full_name": "Officer Two"}}
        ]
        mock_ind_savings = [
            {"client_id": "c1", "deposit_amount": 5000.0, "withdrawal_amount": 0.0, "posting_date": "2026-09-01"},
            {"client_id": "c2", "deposit_amount": 10000.0, "withdrawal_amount": 0.0, "posting_date": "2026-09-01"},
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "clients":
                query.execute.return_value = MagicMock(data=mock_clients)
            elif table_name == "individual_savings":
                query.execute.return_value = MagicMock(data=mock_ind_savings)
            else:
                query.execute.return_value = MagicMock(data=[])
            query.select.return_value = query
            query.eq.return_value = query
            query.in_.return_value = query
            query.gte.return_value = query
            query.lte.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table

        # Filter strictly for Officer One
        sav = ReportService.get_savings_summary(self.mock_uow, officer_name="Officer One")
        self.assertEqual(sav["total_individual_deposits"], 5000.0)
        self.assertEqual(sav["net_individual_savings"], 5000.0)
        self.assertEqual(sav["active_savers_count"], 1)

    def test_repayment_summary(self):
        mock_repayments = [
            {
                "id": "r1", "loan_id": "l1", "client_id": "c1", "amount_paid": 5000.0, "expected_amount": 5000.0,
                "overdue_amount": 0.0, "payment_status": "PAID", "date": "2026-09-01",
                "loans": {"loan_products": {"name": "Daily 60 Days"}, "active_credit": 60000.0},
                "branches": {"name": "Ikorodu"},
                "app_users": {"full_name": "Officer One"}
            },
            {
                "id": "r2", "loan_id": "l2", "client_id": "c2", "amount_paid": 6000.0, "expected_amount": 5000.0,
                "overdue_amount": 0.0, "payment_status": "PAID", "date": "2026-09-01",
                "loans": {"loan_products": {"name": "Weekly 12 Weeks"}, "active_credit": 50000.0},
                "branches": {"name": "Ikorodu"},
                "app_users": {"full_name": "Officer Two"}
            }
        ]
        mock_payoffs = [
            {"record_type": "FULL_PAYOFF_WITH_EXCESS", "active_credit_settled": 50000.0, "excess_amount": 1000.0, "branch_id": "b1"}
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "repayments":
                query.execute.return_value = MagicMock(data=mock_repayments)
            elif table_name == "loan_payoff_excess_records":
                query.execute.return_value = MagicMock(data=mock_payoffs)
            elif table_name == "clients":
                query.execute.return_value = MagicMock(data=[
                    {"client_id": "c1", "client_code": "CLI-001", "name": "Alice"},
                    {"client_id": "c2", "client_code": "CLI-002", "name": "Bob"}
                ])
            else:
                query.execute.return_value = MagicMock(data=[])
            query.select.return_value = query
            query.eq.return_value = query
            query.in_.return_value = query
            query.gte.return_value = query
            query.lte.return_value = query
            query.order.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table

        rep = ReportService.get_repayment_summary(self.mock_uow)

        self.assertEqual(rep["total_collected"], 11000.0)
        self.assertEqual(rep["total_expected"], 10000.0)
        # Base collections = 11,000 - 1,000 excess = 10,000 -> 100.0% efficiency
        self.assertEqual(rep["collection_efficiency"], 100.0)
        self.assertEqual(rep["excess_payment_amount"], 1000.0)
        self.assertEqual(rep["full_payoff_count"], 1)
        self.assertEqual(rep["full_payoff_amount"], 50000.0)
        self.assertEqual(len(rep["repayments_dataframe"]), 2)

    def test_repayment_summary_product_and_officer_filtering(self):
        mock_repayments = [
            {
                "id": "r1", "loan_id": "l1", "client_id": "c1", "amount_paid": 5000.0, "expected_amount": 5000.0,
                "overdue_amount": 0.0, "payment_status": "PAID", "date": "2026-09-01",
                "loans": {"loan_products": {"name": "Daily 60 Days"}, "active_credit": 60000.0},
                "branches": {"name": "Ikorodu"},
                "app_users": {"full_name": "Officer One"}
            },
            {
                "id": "r2", "loan_id": "l2", "client_id": "c2", "amount_paid": 6000.0, "expected_amount": 5000.0,
                "overdue_amount": 0.0, "payment_status": "PAID", "date": "2026-09-01",
                "loans": {"loan_products": {"name": "Weekly 12 Weeks"}, "active_credit": 50000.0},
                "branches": {"name": "Ikorodu"},
                "app_users": {"full_name": "Officer Two"}
            }
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "repayments":
                query.execute.return_value = MagicMock(data=mock_repayments)
            elif table_name == "loan_payoff_excess_records":
                query.execute.return_value = MagicMock(data=[])
            elif table_name == "clients":
                query.execute.return_value = MagicMock(data=[])
            query.select.return_value = query
            query.order.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table

        # 1. Filter by product
        rep_p = ReportService.get_repayment_summary(self.mock_uow, product_name="Daily 60 Days")
        self.assertEqual(rep_p["total_collected"], 5000.0)
        self.assertEqual(rep_p["total_expected"], 5000.0)
        self.assertEqual(rep_p["total_transactions"], 1)

        # 2. Filter by officer
        rep_o = ReportService.get_repayment_summary(self.mock_uow, officer_name="Officer Two")
        self.assertEqual(rep_o["total_collected"], 6000.0)
        self.assertEqual(rep_o["total_expected"], 5000.0)
        self.assertEqual(rep_o["total_transactions"], 1)

    def test_area_branch_comparison(self):
        mock_branches = [
            {"branch_id": "b1", "name": "Ogijo"},
            {"branch_id": "b2", "name": "Ikorodu"}
        ]
        mock_loans = [
            {"loan_id": "l1", "client_id": "c1", "branch_id": "b1", "status": "Active", "active_credit": 100000.0, "total_due": 50000.0, "loan_products": {"name": "Daily 60 Days"}},
            {"loan_id": "l2", "client_id": "c2", "branch_id": "b1", "status": "Active", "active_credit": 150000.0, "total_due": 80000.0, "loan_products": {"name": "Weekly 12W"}},
            {"loan_id": "l3", "client_id": "c3", "branch_id": "b2", "status": "Active", "active_credit": 200000.0, "total_due": 120000.0, "loan_products": {"name": "Weekly 12W"}},
        ]
        mock_savings = [
            {"client_id": "c1", "branch_id": "b1", "deposit_amount": 20000.0, "withdrawal_amount": 5000.0},
            {"client_id": "c2", "branch_id": "b1", "deposit_amount": 30000.0, "withdrawal_amount": 0.0},
            {"client_id": "c3", "branch_id": "b2", "deposit_amount": 40000.0, "withdrawal_amount": 10000.0},
        ]
        mock_reps = [
            {"branch_id": "b1", "amount_paid": 50000.0, "expected_amount": 50000.0, "overdue_amount": 0.0, "loans": {"loan_products": {"name": "Daily 60 Days"}}},
            {"branch_id": "b2", "amount_paid": 80000.0, "expected_amount": 100000.0, "overdue_amount": 5000.0, "loans": {"loan_products": {"name": "Weekly 12W"}}},
        ]

        def mock_table(table_name):
            query = MagicMock()
            if table_name == "branches":
                query.execute.return_value = MagicMock(data=mock_branches)
            elif table_name == "loans":
                query.execute.return_value = MagicMock(data=mock_loans)
            elif table_name == "individual_savings":
                query.execute.return_value = MagicMock(data=mock_savings)
            elif table_name == "repayments":
                query.execute.return_value = MagicMock(data=mock_reps)
            query.select.return_value = query
            query.in_.return_value = query
            query.gte.return_value = query
            query.lte.return_value = query
            return query

        self.mock_uow.client.table.side_effect = mock_table

        area_data = ReportService.get_area_branch_comparison(self.mock_uow, assigned_branch_ids=["b1", "b2"])

        # Check Area Totals
        self.assertEqual(area_data["total_branches"], 2)
        # People on Loan: c1, c2 in b1; c3 in b2 -> 3 unique clients
        self.assertEqual(area_data["total_people_on_loan"], 3)
        self.assertEqual(area_data["total_active_loans"], 3)
        # Active Savers: c1 (15k), c2 (30k), c3 (30k) -> 3 savers
        self.assertEqual(area_data["total_active_savers"], 3)
        self.assertEqual(area_data["total_area_savings"], 75000.0)
        self.assertEqual(area_data["total_area_collections"], 130000.0)
        self.assertEqual(area_data["total_area_expected"], 150000.0)
        self.assertEqual(area_data["total_area_portfolio"], 250000.0)

        # Check Branch Rows
        df_comp = area_data["dataframe"]
        self.assertEqual(len(df_comp), 2)
        row_b1 = df_comp[df_comp["Branch"] == "Ogijo"].iloc[0]
        self.assertEqual(row_b1["No. of People on Loan"], 2)
        self.assertEqual(row_b1["Active Loans"], 2)
        self.assertEqual(row_b1["No. of Active Savers"], 2)
        self.assertEqual(row_b1["Total Savings"], 45000.0)
        self.assertEqual(row_b1["Collections Received"], 50000.0)
        self.assertEqual(row_b1["Expected Collections"], 50000.0)
        self.assertEqual(row_b1["Status"], "[EXCELLENT]")

        row_b2 = df_comp[df_comp["Branch"] == "Ikorodu"].iloc[0]
        self.assertEqual(row_b2["No. of People on Loan"], 1)
        self.assertEqual(row_b2["No. of Active Savers"], 1)

    def test_excel_export_bytes(self):
        df = pd.DataFrame({
            "Account Code": ["1000", "2000"],
            "Account Name": ["Vault Cash", "Savings Deposits"],
            "Amount": [100000.0, 50000.0]
        })
        excel_bytes = export_dataframe_to_excel_bytes(df, "Test Sheet")
        self.assertIsInstance(excel_bytes, bytes)
        self.assertGreater(len(excel_bytes), 0)

        multi_bytes = export_consolidated_report_to_excel(
            trial_balance_df=df,
            savings_df=df,
            repayments_df=df,
            loans_df=df,
            portfolio_summary={"total_loans": 5, "total_principal": 500000.0},
            area_comparison_df=df
        )
        self.assertIsInstance(multi_bytes, bytes)
        self.assertGreater(len(multi_bytes), 0)


if __name__ == "__main__":
    unittest.main()
