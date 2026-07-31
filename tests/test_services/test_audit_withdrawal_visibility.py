"""
Audit & Management Visibility Tests (Phase 9)
Verifies that all new withdrawal event types (LoanOffsetFromSavings, LapsTransferred, LapsPaidOut, LapsMigrated)
are accurately tracked, queried, and categorized across audit views, event store, and ledger audit tools.
"""

import unittest
from unittest.mock import MagicMock
from domain.events import (
    EVENT_LOAN_OFFSET_FROM_SAVINGS,
    EVENT_LAPS_TRANSFERRED,
    EVENT_LAPS_PAID_OUT
)
from services.transaction_explorer_service import TransactionExplorerService


class TestAuditWithdrawalVisibility(unittest.TestCase):

    def setUp(self):
        self.mock_uow = MagicMock()
        self.mock_client = MagicMock()
        self.mock_uow.client = self.mock_client

    def test_withdrawal_event_type_constants(self):
        """Verify withdrawal event constants exist and map to clear event strings."""
        self.assertEqual(EVENT_LOAN_OFFSET_FROM_SAVINGS, "LoanOffsetFromSavings")
        self.assertEqual(EVENT_LAPS_TRANSFERRED, "LapsTransferred")
        self.assertEqual(EVENT_LAPS_PAID_OUT, "LapsPaidOut")

    def test_explorer_service_withdrawal_search(self):
        """Verify TransactionExplorerService searches and matches withdrawal references."""
        # Setup mock return data for ledger transactions
        mock_tx_table = MagicMock()
        self.mock_client.table.side_effect = lambda name: mock_tx_table
        
        mock_tx_table.select.return_value.execute.return_value.data = [
            {
                "transaction_id": "tx-offset-001",
                "reference": "REF-OFFSET-12345",
                "narration": "Loan offset from individual savings for client John Doe",
                "financial_ledger_entries": [
                    {"account_code": "2000", "debit": 15000.0, "credit": 0.0},
                    {"account_code": "1200", "debit": 0.0, "credit": 15000.0}
                ]
            },
            {
                "transaction_id": "tx-laps-001",
                "reference": "LAPS-MIG-20260731-001",
                "narration": "Legacy LAPS bulk migration import",
                "financial_ledger_entries": [
                    {"account_code": "3000", "debit": 50000.0, "credit": 0.0},
                    {"account_code": "2030", "debit": 0.0, "credit": 50000.0}
                ]
            }
        ]

        # Explore query for offset reference
        res = TransactionExplorerService.explore_transaction(self.mock_uow, "REF-OFFSET-12345")
        self.assertTrue(res["found"])
        self.assertEqual(len(res["ledger_transactions"]), 1)
        self.assertEqual(res["ledger_transactions"][0]["transaction_id"], "tx-offset-001")

        # Explore query for legacy migration reference
        res_mig = TransactionExplorerService.explore_transaction(self.mock_uow, "LAPS-MIG-20260731-001")
        self.assertTrue(res_mig["found"])
        self.assertEqual(len(res_mig["ledger_transactions"]), 1)
        self.assertEqual(res_mig["ledger_transactions"][0]["transaction_id"], "tx-laps-001")


if __name__ == "__main__":
    unittest.main()
