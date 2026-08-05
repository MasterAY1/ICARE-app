import unittest
from datetime import datetime
from domain.events import (
    EVENT_LOAN_OFFSET_FROM_SAVINGS,
    EVENT_LAPS_TRANSFERRED,
    EVENT_LAPS_PAID_OUT,
    LoanOffsetFromSavingsEvent,
    LapsTransferredEvent,
    LapsPaidOutEvent
)

class TestWithdrawalDomainEvents(unittest.TestCase):
    def test_loan_offset_from_savings_event(self):
        event = LoanOffsetFromSavingsEvent(
            event_id="evt-001",
            client_id="client-123",
            loan_id="loan-456",
            source_savings_type="IndividualSavings",
            amount=20000.0,
            branch="Lagos",
            branch_id="b-001",
            officer="co_officer1",
            officer_id="u-001",
            business_date="2026-07-31",
            reference="REF-OFFSET-001",
            narration="Loan offset using savings",
            metadata={"audit_source": "unit_test"}
        )
        self.assertEqual(EVENT_LOAN_OFFSET_FROM_SAVINGS, "LoanOffsetFromSavings")
        self.assertEqual(event.event_id, "evt-001")
        self.assertEqual(event.client_id, "client-123")
        self.assertEqual(event.loan_id, "loan-456")
        self.assertEqual(event.source_savings_type, "IndividualSavings")
        self.assertEqual(event.amount, 20000.0)
        self.assertEqual(event.branch, "Lagos")
        self.assertEqual(event.branch_id, "b-001")
        self.assertEqual(event.officer, "co_officer1")
        self.assertEqual(event.officer_id, "u-001")
        self.assertEqual(event.business_date, "2026-07-31")
        self.assertEqual(event.reference, "REF-OFFSET-001")
        self.assertEqual(event.classification, "LOAN_OFFSET")
        self.assertEqual(event.metadata.get("audit_source"), "unit_test")
        self.assertIsInstance(event.occurred_on, datetime)

    def test_laps_transferred_event(self):
        event = LapsTransferredEvent(
            event_id="evt-002",
            client_id="client-123",
            source_savings_type="IndividualSavings",
            amount=15000.0,
            branch="Lagos",
            branch_id="b-001",
            officer="co_officer1",
            officer_id="u-001",
            business_date="2026-07-31",
            reference="REF-LAPS-001",
            narration="Transfer savings to LAPS"
        )
        self.assertEqual(EVENT_LAPS_TRANSFERRED, "LapsTransferred")
        self.assertEqual(event.event_id, "evt-002")
        self.assertEqual(event.client_id, "client-123")
        self.assertEqual(event.source_savings_type, "IndividualSavings")
        self.assertEqual(event.destination, "LAPS")
        self.assertEqual(event.amount, 15000.0)
        self.assertEqual(event.branch, "Lagos")
        self.assertEqual(event.branch_id, "b-001")
        self.assertEqual(event.officer, "co_officer1")
        self.assertEqual(event.officer_id, "u-001")
        self.assertEqual(event.classification, "LAPS_TRANSFER")

    def test_laps_paid_out_event(self):
        event_cash = LapsPaidOutEvent(
            event_id="evt-003",
            client_id="client-123",
            amount=10000.0,
            branch="Lagos",
            branch_id="b-001",
            officer="co_officer1",
            officer_id="u-001",
            business_date="2026-07-31",
            reference="REF-PAYOUT-001",
            cash_paid=True,
            narration="LAPS cash payout"
        )
        self.assertEqual(EVENT_LAPS_PAID_OUT, "LapsPaidOut")
        self.assertTrue(event_cash.cash_paid)
        self.assertEqual(event_cash.amount, 10000.0)
        self.assertEqual(event_cash.branch_id, "b-001")
        self.assertEqual(event_cash.officer_id, "u-001")
        self.assertEqual(event_cash.classification, "LAPS_PAYOUT")

        event_non_cash = LapsPaidOutEvent(
            event_id="evt-004",
            client_id="client-123",
            amount=10000.0,
            branch="Lagos",
            officer="co_officer1",
            business_date="2026-07-31",
            reference="REF-PAYOUT-002",
            cash_paid=False,
            narration="LAPS bank transfer payout"
        )
        self.assertFalse(event_non_cash.cash_paid)

if __name__ == "__main__":
    unittest.main()
