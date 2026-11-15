import unittest
from datetime import date
from unittest.mock import MagicMock
import pandas as pd
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder

class TestMasterCashbookProjectionBuilder(unittest.TestCase):
    def setUp(self):
        self.mock_uow = MagicMock()
        # Default mock responses for database table queries
        self.mock_uow.client.table().select().eq().eq().execute().data = []

    def test_bank_withdrawal_is_inflow_in_master_cashbook(self):
        # Mock co_cashbooks data containing bank_withdrawal
        co_data = [{
            "rep_daily": 10000.0,
            "savings_deposit": 5000.0,
            "bank_withdrawal": 40000.0,
            "savings_withdrawal": 2000.0,
            "product_withdrawal": 2000.0,
            "bank_deposit": 0.0
        }]
        
        self.mock_uow.client.table().select().eq().eq().execute().data = co_data
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = []

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 7, 31)
        )

        self.assertEqual(result["bank_withdrawal"], 40000.0)
        # Inflows = rep_daily (10000) + savings_deposit (5000) + bank_withdrawal (40000) = 55000
        self.assertEqual(result["total_inflows"], 55000.0)
        # Outflows = product_withdrawal (2000)
        self.assertEqual(result["total_outflows"], 2000.0)
        self.assertEqual(result["closing_balance"], 53000.0)

    def test_treasury_and_loan_disbursements_aggregation_and_balancing(self):
        co_data = [{
            "officer_id": "co-1",
            "rep_daily": 20000.0,
            "bank_withdrawal": 0.0,
            "savings_withdrawal": 1000.0,
            "product_withdrawal": 1000.0
        }]

        # Mock financial_ledger_entries (Account 1000) for branch-level events
        ledger_data = [
            {
                "amount": 50000.0,
                "side": "Debit",
                "financial_transactions": {
                    "officer_id": None,
                    "event_store": {
                        "event_type": "CashTransferred_HO_In",
                        "payload": {"transaction_type": "HO_TRANSFER_IN"}
                    }
                }
            },
            {
                "amount": 3000.0,
                "side": "Credit",
                "financial_transactions": {
                    "officer_id": None,
                    "event_store": {
                        "event_type": "ExpenseRecorded",
                        "payload": {}
                    }
                }
            },
            {
                "amount": 15000.0,
                "side": "Credit",
                "financial_transactions": {
                    "officer_id": None,
                    "event_store": {
                        "event_type": "LoanDisbursed",
                        "payload": {"product_category": "Finance", "narration": "Loan"}
                    }
                }
            }
        ]

        def table_side_effect(table_name):
            mock_table = MagicMock()
            if table_name == "co_cashbooks":
                mock_table.select().eq().eq().execute().data = co_data
            elif table_name == "financial_ledger_entries":
                mock_table.select().eq().eq().eq().execute().data = ledger_data
            else:
                mock_table.select().eq().eq().execute().data = []
            return mock_table

        self.mock_uow.client.table.side_effect = table_side_effect

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 7, 31)
        )

        self.assertEqual(result["funds_received_ho"], 50000.0)
        self.assertEqual(result["office_expenses"], 3000.0)
        self.assertEqual(result["disb_12w"], 15000.0)
        self.assertEqual(result["fund_to_product_finance"], 15000.0)
        # BR-CASH-001: loan_received_finance equals fund_to_product_finance
        self.assertEqual(result["loan_received_finance"], 15000.0)

        # Inflows = 20000 (rep_daily) + 50000 (funds_received_ho) + 15000 (loan_received_finance) = 85000
        self.assertEqual(result["total_inflows"], 85000.0)
        # Outflows = 1000 (product_withdrawal) + 15000 (disb_12w) + 15000 (fund_to_product_finance) + 3000 (office_expenses) = 34000
        self.assertEqual(result["total_outflows"], 34000.0)
        # Closing balance = 85000 - 34000 = 51000
        self.assertEqual(result["closing_balance"], 51000.0)

    def test_inter_area_funding_aggregation(self):
        co_data = [{
            "officer_id": "co-1",
            "rep_daily": 10000.0,
            "savings_deposit": 5000.0,
        }]

        ledger_data = [
            {
                "amount": 25000.0,
                "side": "Debit",
                "financial_transactions": {
                    "officer_id": None,
                    "event_store": {
                        "event_type": "CashTransferred_HO_In",
                        "payload": {"transaction_type": "INTER_AREA_IN"}
                    }
                }
            },
            {
                "amount": 10000.0,
                "side": "Credit",
                "financial_transactions": {
                    "officer_id": None,
                    "event_store": {
                        "event_type": "CashTransferred_HO_Out",
                        "payload": {"transaction_type": "INTER_AREA_OUT"}
                    }
                }
            }
        ]

        def table_side_effect(table_name):
            mock_table = MagicMock()
            if table_name == "co_cashbooks":
                mock_table.select().eq().eq().execute().data = co_data
            elif table_name == "financial_ledger_entries":
                mock_table.select().eq().eq().eq().execute().data = ledger_data
            else:
                mock_table.select().eq().eq().execute().data = []
            return mock_table

        self.mock_uow.client.table.side_effect = table_side_effect

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 7, 31)
        )

        self.assertEqual(result["funds_received_other_area"], 25000.0)
        self.assertEqual(result["fund_to_other_area"], 10000.0)
        # Inflows = 10000 (rep_daily) + 5000 (savings) + 25000 (funds_received_other_area) = 40000
        self.assertEqual(result["total_inflows"], 40000.0)
        # Outflows = 10000 (fund_to_other_area)
        self.assertEqual(result["total_outflows"], 10000.0)
        self.assertEqual(result["closing_balance"], 30000.0)

    def test_monthly_kpi_calculations_satisfy_accounting_identity(self):
        """Test R4: Month Opening + Month Inflows - Month Outflows == Month-End Closing"""
        # Day 1: Open 100,000; Inflow 50,000 (Total Inflow 150,000); Outflow 30,000; Close 120,000
        # Day 2: Open 120,000; Inflow 40,000 (Total Inflow 160,000); Outflow 25,000; Close 135,000
        # Day 3: Open 135,000; Inflow 60,000 (Total Inflow 195,000); Outflow 70,000; Close 125,000
        df = pd.DataFrame([
            {"date": "2026-08-01", "opening_balance": 100000.0, "total_inflows": 150000.0, "total_outflows": 30000.0, "closing_balance": 120000.0},
            {"date": "2026-08-02", "opening_balance": 120000.0, "total_inflows": 160000.0, "total_outflows": 25000.0, "closing_balance": 135000.0},
            {"date": "2026-08-03", "opening_balance": 135000.0, "total_inflows": 195000.0, "total_outflows": 70000.0, "closing_balance": 125000.0},
        ])

        month_opening = float(df.iloc[0]["opening_balance"])
        month_inflows = float((df["total_inflows"] - df["opening_balance"]).sum())
        month_outflows = float(df["total_outflows"].sum())
        month_closing = float(df.iloc[-1]["closing_balance"])

        self.assertEqual(month_opening, 100000.0)
        self.assertEqual(month_inflows, 150000.0)  # 50k + 40k + 60k
        self.assertEqual(month_outflows, 125000.0) # 30k + 25k + 70k
        self.assertEqual(month_closing, 125000.0)
        self.assertEqual(month_opening + month_inflows - month_outflows, month_closing)

    def test_finance_loan_and_bank_withdrawal_symmetry(self):
        """Test BIA-CASHBOOK-ACTIVE-CREDIT-021: Finance Principal symmetry & full CO Bank Withdrawal aggregation"""
        co_data = [{
            "officer_id": "co-1",
            "rep_daily": 30000.0,
            "daily_11_pct": 11000.0,
            "bank_withdrawal": 100000.0,
            "disb_60d": 98000.0,            # Active Credit = Principal (100k) - Gap Fee (2k)
            "_finance_loan_principal": 100000.0,
            "fund_to_product_finance": 100000.0,
            "product_withdrawal": 13000.0,  # Markup (11k) + Gap Fee (2k)
            "bank_deposit": 30000.0,
        }]

        def table_side_effect(table_name):
            mock_table = MagicMock()
            if table_name == "co_cashbooks":
                mock_table.select().eq().eq().execute().data = co_data
            else:
                mock_table.select().eq().eq().eq().execute().data = []
                mock_table.select().eq().eq().execute().data = []
                mock_table.select().eq().execute().data = []
                mock_table.select().lt().order().limit().execute().data = []
            return mock_table

        self.mock_uow.client.table.side_effect = table_side_effect

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 7, 31)
        )

        # Finance Principal symmetry: loan_received_finance == fund_to_product_finance == 100k
        self.assertEqual(result["fund_to_product_finance"], 100000.0)
        self.assertEqual(result["loan_received_finance"], 100000.0)
        # Full CO Bank Withdrawal preserved without subtraction
        self.assertEqual(result["bank_withdrawal"], 100000.0)
        self.assertEqual(result["disb_60d"], 98000.0)
        # Inflows (Left): 30k (rep) + 100k (loan_received_finance) + 11k (markup) + 100k (bank_wd) = 241,000
        self.assertEqual(result["total_inflows"], 241000.0)
        # Outflows (Right): 98k (disb_60d) + 100k (fund_to_product_finance) + 13k (product_wd) + 30k (bank_dep) = 241,000
        self.assertEqual(result["total_outflows"], 241000.0)
        self.assertEqual(result["closing_balance"], 0.0)

    def test_asset_program_manual_treasury_and_month_end_settlement(self):
        """Test Asset Loan roll-out to loan_received_asset while fund_to_asset_program stays manual BM Treasury input"""
        co_data = [{
            "officer_id": "co-1",
            "asset_credit_sales": 508000.0,
            "cash_and_carry": 175000.0,
            "disb_12w": 400000.0,
            "bank_withdrawal": 0.0,
        }]
        # Day-level BM manual Treasury ASSET_PROGRAM differs from daily loan_received_asset (e.g., 375k)
        ledger_data = [{
            "amount": 375000.0,
            "side": "Credit",
            "financial_transactions": {
                "officer_id": None,
                "event_store": {
                    "event_type": "CashTransferred_HO_Out",
                    "payload": {"transaction_type": "ASSET_PROGRAM"},
                },
            },
        }]

        def table_side_effect(table_name):
            mock_table = MagicMock()
            if table_name == "co_cashbooks":
                mock_table.select().eq().eq().execute().data = co_data
            elif table_name == "financial_ledger_entries":
                mock_table.select().eq().eq().eq().execute().data = ledger_data
            else:
                mock_table.select().eq().eq().execute().data = []
            return mock_table

        self.mock_uow.client.table.side_effect = table_side_effect

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 2, 2)
        )

        # CO asset_credit_sales rolls cleanly into loan_received_asset without double counting
        self.assertEqual(result["loan_received_asset"], 508000.0)
        self.assertEqual(result["asset_credit_sales"], 0.0)
        self.assertEqual(result["cash_and_carry"], 175000.0)
        # Manual BM Treasury ASSET_PROGRAM stays strictly separate on outflows
        self.assertEqual(result["fund_to_asset_program"], 375000.0)
        # Inflows = 175k + 508k = 683k; Outflows = 400k (disb_12w) + 375k (fund_to_asset_program) = 775k
        self.assertEqual(result["total_inflows"], 683000.0)
        self.assertEqual(result["total_outflows"], 775000.0)

    def test_legacy_co_misc_fees_folded_into_savings_deposit(self):
        co_data = [{
            "officer_id": "co-1",
            "savings_deposit": 12000.0,
            "misc_fees": 3000.0,
        }]

        def table_side_effect(table_name):
            mock_table = MagicMock()
            if table_name == "co_cashbooks":
                mock_table.select().eq().eq().execute().data = co_data
            else:
                mock_table.select().eq().eq().eq().execute().data = []
                mock_table.select().eq().eq().execute().data = []
            return mock_table

        self.mock_uow.client.table.side_effect = table_side_effect

        result = MasterCashbookProjectionBuilder.rebuild_master_projection(
            self.mock_uow, "branch-01", date(2026, 7, 31)
        )

        self.assertEqual(result["savings_deposit"], 15000.0)
        self.assertEqual(result["misc_fees"], 0.0)
        self.assertEqual(result["total_inflows"], 15000.0)

if __name__ == "__main__":
    unittest.main()
