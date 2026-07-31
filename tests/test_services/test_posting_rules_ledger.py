import unittest
from unittest.mock import MagicMock
from domain.entities.event_store import DomainEvent
from domain.entities.posting_rule import PostingRule
from services.posting_engine import FinancialPostingEngine

class TestPostingRulesLedger(unittest.TestCase):
    def setUp(self):
        self.mock_uow = MagicMock()
        self.rules = {
            "LoanOffsetFromSavings_1": PostingRule(
                id="r1", event_type="LoanOffsetFromSavings", debit_account="2000", credit_account="1200", version=1, enabled=True
            ),
            "LapsTransferred_1": PostingRule(
                id="r2", event_type="LapsTransferred", debit_account="2000", credit_account="2030", version=1, enabled=True
            ),
            "LapsPaidOut_1": PostingRule(
                id="r3", event_type="LapsPaidOut", debit_account="2030", credit_account="1000", version=1, enabled=True
            ),
        }

        def mock_get_rule(event_type, version=1):
            key = f"{event_type}_{version}"
            return self.rules.get(key)

        self.mock_uow.posting_rules.get_rule.side_effect = mock_get_rule
        self.mock_uow.event_store.is_processed.return_value = False
        self.mock_uow.ledger.create_transaction.return_value = "tx-123"

    def test_loan_offset_posting_rule_balances_and_bypasses_vault_cash(self):
        event = DomainEvent(
            event_id="evt-offset-01",
            aggregate_id="agg-01",
            aggregate_type="LoanOffset",
            event_type="LoanOffsetFromSavings",
            payload={
                "branch": "Lagos",
                "officer": "officer1",
                "amount": 25000.0,
                "narration": "Loan offset test"
            }
        )

        tx_id = FinancialPostingEngine.post_event(self.mock_uow, event)
        self.assertEqual(tx_id, "tx-123")

        # Extract posted entries passed to ledger.create_transaction
        call_args = self.mock_uow.ledger.create_transaction.call_args
        tx_header, entries = call_args[0]

        self.assertEqual(len(entries), 2)
        debit_entry = [e for e in entries if e.side == "Debit"][0]
        credit_entry = [e for e in entries if e.side == "Credit"][0]

        # Verify Debit = Credit balance
        self.assertEqual(debit_entry.amount, credit_entry.amount)
        self.assertEqual(debit_entry.amount, 25000.0)

        # Verify accounts
        self.assertEqual(debit_entry.account_code, "2000")   # Individual Deposits
        self.assertEqual(credit_entry.account_code, "1200")  # Loan Portfolio

        # CRITICAL VERIFICATION: Must NOT touch account 1000 (Vault Cash)
        self.assertNotEqual(debit_entry.account_code, "1000")
        self.assertNotEqual(credit_entry.account_code, "1000")

    def test_laps_transferred_posting_rule_balances_and_bypasses_vault_cash(self):
        event = DomainEvent(
            event_id="evt-laps-01",
            aggregate_id="agg-02",
            aggregate_type="LapsSavings",
            event_type="LapsTransferred",
            payload={
                "branch": "Lagos",
                "officer": "officer1",
                "amount": 18000.0,
                "narration": "LAPS transfer test"
            }
        )

        tx_id = FinancialPostingEngine.post_event(self.mock_uow, event)
        self.assertEqual(tx_id, "tx-123")

        call_args = self.mock_uow.ledger.create_transaction.call_args
        tx_header, entries = call_args[0]

        debit_entry = [e for e in entries if e.side == "Debit"][0]
        credit_entry = [e for e in entries if e.side == "Credit"][0]

        self.assertEqual(debit_entry.amount, credit_entry.amount)
        self.assertEqual(debit_entry.amount, 18000.0)
        self.assertEqual(debit_entry.account_code, "2000")   # Individual Deposits
        self.assertEqual(credit_entry.account_code, "2030")  # LAPS Savings

        # CRITICAL VERIFICATION: Must NOT touch account 1000 (Vault Cash)
        self.assertNotEqual(debit_entry.account_code, "1000")
        self.assertNotEqual(credit_entry.account_code, "1000")

    def test_laps_paid_out_cash_true_touches_vault_cash(self):
        event = DomainEvent(
            event_id="evt-payout-cash",
            aggregate_id="agg-03",
            aggregate_type="LapsSavings",
            event_type="LapsPaidOut",
            payload={
                "branch": "Lagos",
                "officer": "officer1",
                "amount": 10000.0,
                "cash_paid": True,
                "narration": "LAPS cash payout"
            }
        )

        FinancialPostingEngine.post_event(self.mock_uow, event)
        call_args = self.mock_uow.ledger.create_transaction.call_args
        tx_header, entries = call_args[0]

        debit_entry = [e for e in entries if e.side == "Debit"][0]
        credit_entry = [e for e in entries if e.side == "Credit"][0]

        self.assertEqual(debit_entry.account_code, "2030")   # LAPS Savings
        self.assertEqual(credit_entry.account_code, "1000")  # Vault Cash (touches CO cash)

    def test_laps_paid_out_cash_false_bypasses_vault_cash(self):
        event = DomainEvent(
            event_id="evt-payout-bank",
            aggregate_id="agg-04",
            aggregate_type="LapsSavings",
            event_type="LapsPaidOut",
            payload={
                "branch": "Lagos",
                "officer": "officer1",
                "amount": 10000.0,
                "cash_paid": False,
                "narration": "LAPS bank transfer payout"
            }
        )

        FinancialPostingEngine.post_event(self.mock_uow, event)
        call_args = self.mock_uow.ledger.create_transaction.call_args
        tx_header, entries = call_args[0]

        debit_entry = [e for e in entries if e.side == "Debit"][0]
        credit_entry = [e for e in entries if e.side == "Credit"][0]

        self.assertEqual(debit_entry.account_code, "2030")   # LAPS Savings
        self.assertEqual(credit_entry.account_code, "1050")  # Bank account (bypasses CO cash)

if __name__ == "__main__":
    unittest.main()
