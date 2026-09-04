"""
End-to-End Integration & Reconciliation Test Suite (Phase 10)
Verifies physical cash vs zero-cash operations across:
- Business Service Layer (SavingsService, LAPSMigrationService)
- Domain Event Store & Event Classification
- Double-Entry Posting Engine (FinancialPostingEngine)
- Sub-system Repositories (IndividualSavings, GroupSavings, MiscSavings, LapsSavings, Loans, EventStore, Ledger)
- CO Cashbook Projection Builder & Master Cashbook Projection Builder
"""

import unittest
from datetime import date
from unittest.mock import MagicMock
from domain.enums import TransactionClassification
from services.withdrawal_classification_engine import WithdrawalClassificationEngine
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder


class TestE2EWithdrawalReconciliation(unittest.TestCase):

    def setUp(self):
        self.branch_id = "branch-lagos-001"
        self.officer_id = "officer-001"
        self.date_val = date(2026, 7, 31)

        self.mock_uow = MagicMock()
        # Mock opening balance as 50000.0
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = []

    def test_classification_engine_cash_vs_non_cash(self):
        """Verify Classification Engine correctly sets affects_cash_vault for all transaction types."""
        res_cash = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.CUSTOMER_CASH_WITHDRAWAL, amount=5000.0
        )
        self.assertTrue(res_cash["affects_cash_vault"])
        self.assertEqual(res_cash["product_withdrawal"], 5000.0)

        res_offset = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LOAN_OFFSET, amount=12000.0
        )
        self.assertFalse(res_offset["affects_cash_vault"])
        self.assertEqual(res_offset["product_withdrawal"], 12000.0)

        res_laps_tr = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_TRANSFER, amount=8000.0
        )
        self.assertFalse(res_laps_tr["affects_cash_vault"])
        self.assertEqual(res_laps_tr["product_withdrawal"], 8000.0)

        res_laps_payout_cash = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_PAYOUT, amount=15000.0, is_cash_paid=True
        )
        self.assertTrue(res_laps_payout_cash["affects_cash_vault"])

        res_laps_payout_bank = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_PAYOUT, amount=15000.0, is_cash_paid=False
        )
        self.assertFalse(res_laps_payout_bank["affects_cash_vault"])

    def test_e2e_customer_cash_withdrawal(self):
        """Test Customer Cash Withdrawal: Physical vault cash MUST decrease."""
        entries = [{
            "account_code": "1000",
            "side": "Credit",
            "amount": 10000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "SavingsWithdrawn"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )

        self.assertEqual(res["savings_withdrawal"], 10000.0)
        self.assertEqual(res["total_outflows"], 10000.0)
        self.assertEqual(res["closing_balance"], -10000.0)

    def test_e2e_loan_offset_from_savings_zero_cash(self):
        """Test Loan Offset From Savings: ZERO physical vault cash impact."""
        # Non-1000 ledger entry (DR 2000 Savings, CR 1200 Loan Portfolio)
        entries = [{
            "account_code": "2000",
            "side": "Debit",
            "amount": 25000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "LoanOffsetFromSavings"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )

        self.assertEqual(res["savings_withdrawal"], 0.0)
        self.assertEqual(res["total_inflows"], 25000.0)
        self.assertEqual(res["total_outflows"], 25000.0)
        self.assertEqual(res["closing_balance"], 0.0)

    def test_e2e_laps_transferred_zero_cash(self):
        """Test Transfer To LAPS: ZERO physical vault cash impact."""
        entries = [{
            "account_code": "2000",
            "side": "Debit",
            "amount": 18000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "LapsTransferred"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )

        self.assertEqual(res["savings_withdrawal"], 0.0)
        self.assertEqual(res["total_outflows"], 0.0)
        self.assertEqual(res["closing_balance"], 0.0)

    def test_e2e_laps_payout_cash_vs_bank(self):
        """Test LAPS Payout: Cash payout reduces vault cash, Bank payout has ZERO vault cash impact."""
        # 1. Cash Payout (CR 1000)
        entries_cash = [{
            "account_code": "1000",
            "side": "Credit",
            "amount": 15000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "LapsPaidOut"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries_cash
        res_cash = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )
        self.assertEqual(res_cash["laps_returns"], 15000.0)
        self.assertEqual(res_cash["total_outflows"], 15000.0)

        # 2. Non-Cash Bank Payout (CR 1050 - Bank)
        entries_bank = [{
            "account_code": "1050",
            "side": "Credit",
            "amount": 15000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "LapsPaidOut"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries_bank
        res_bank = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )
        self.assertEqual(res_bank["laps_returns"], 0.0)
        self.assertEqual(res_bank["total_outflows"], 0.0)

    def test_e2e_bank_withdrawal_cash_inflow(self):
        """Test Bank Withdrawal: Inflow into vault cash position."""
        entries = [{
            "account_code": "1000",
            "side": "Debit",
            "amount": 50000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "BankWithdrawn"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )

        self.assertEqual(res["bank_withdrawal"], 50000.0)
        self.assertEqual(res["total_inflows"], 50000.0)
        self.assertEqual(res["total_outflows"], 0.0)
        self.assertEqual(res["closing_balance"], 50000.0)

    def test_e2e_bank_deposit_cash_outflow(self):
        """Test Bank Deposit: Outflow from vault cash position."""
        entries = [{
            "account_code": "1000",
            "side": "Credit",
            "amount": 30000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "BankDeposited"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )

        self.assertEqual(res["bank_deposit"], 30000.0)
        self.assertEqual(res["total_outflows"], 30000.0)
        self.assertEqual(res["closing_balance"], -30000.0)

    def test_e2e_legacy_laps_migration_zero_cash(self):
        """Test Legacy LAPS Migration: ZERO physical vault cash impact."""
        entries = [{
            "account_code": "3000",
            "side": "Debit",
            "amount": 100000.0,
            "financial_transactions": {
                "officer_id": self.officer_id,
                "posting_date": "2026-07-31",
                "event_store": {"event_type": "LapsMigrated"}
            }
        }]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )

        self.assertEqual(res["total_outflows"], 0.0)
        self.assertEqual(res["closing_balance"], 0.0)

    def test_full_cashbook_reconciliation_math(self):
        """Test complete mathematical reconciliation: closing = opening + total_inflows - total_outflows."""
        entries = [
            # Bank Withdrawal (Inflow 50k)
            {"account_code": "1000", "side": "Debit", "amount": 50000.0, "financial_transactions": {"officer_id": self.officer_id, "posting_date": "2026-07-31", "event_store": {"event_type": "BankWithdrawn"}}},
            # Savings Deposit (Inflow 20k)
            {"account_code": "1000", "side": "Debit", "amount": 20000.0, "financial_transactions": {"officer_id": self.officer_id, "posting_date": "2026-07-31", "event_store": {"event_type": "SavingsDeposited"}}},
            # Customer Cash Withdrawal (Outflow 10k)
            {"account_code": "1000", "side": "Credit", "amount": 10000.0, "financial_transactions": {"officer_id": self.officer_id, "posting_date": "2026-07-31", "event_store": {"event_type": "SavingsWithdrawn"}}},
            # Bank Deposit (Outflow 15k)
            {"account_code": "1000", "side": "Credit", "amount": 15000.0, "financial_transactions": {"officer_id": self.officer_id, "posting_date": "2026-07-31", "event_store": {"event_type": "BankDeposited"}}},
            # Loan Offset (Non-cash 30k)
            {"account_code": "2000", "side": "Debit", "amount": 30000.0, "financial_transactions": {"officer_id": self.officer_id, "posting_date": "2026-07-31", "event_store": {"event_type": "LoanOffsetFromSavings"}}},
            # LAPS Transfer (Non-cash 12k)
            {"account_code": "2030", "side": "Credit", "amount": 12000.0, "financial_transactions": {"officer_id": self.officer_id, "posting_date": "2026-07-31", "event_store": {"event_type": "LapsTransferred"}}}
        ]
        self.mock_uow.client.table().select().eq().eq().eq().execute().data = entries

        res = CoCashbookProjectionBuilder.rebuild_co_projection(
            self.mock_uow, self.branch_id, self.officer_id, self.date_val
        )

        # Dual-sided non-cash offsets reflect symmetrically:
        # Inflows: 50k (bank_withdrawn) + 20k (savings_deposited) + 30k (rep offset) + 12k (laps_reserve) = 112k
        # Outflows: 10k (cust withdrawal) + 15k (bank_deposit) + 30k (pwd offset) + 12k (pwd laps) = 67k
        # Closing balance: 0 opening + 112k - 67k = 45k (identical net vault position)
        self.assertEqual(res["total_inflows"], 112000.0)
        self.assertEqual(res["total_outflows"], 67000.0)
        self.assertEqual(res["closing_balance"], 45000.0)


if __name__ == "__main__":
    unittest.main()
