import unittest
from unittest.mock import MagicMock
from domain.enums import TransactionClassification
from services.savings_service import SavingsService

class TestWithdrawalServices(unittest.TestCase):
    def setUp(self):
        self.mock_uow = MagicMock()
        
        # Configure repository create side effects to set entity.id
        def mock_create(entity):
            entity.id = "mock-id-123"
            return entity

        self.mock_uow.individual_savings.create.side_effect = mock_create
        self.mock_uow.group_savings.create.side_effect = mock_create
        self.mock_uow.misc_savings.create.side_effect = mock_create
        self.mock_uow.laps_savings.create.side_effect = mock_create
        self.mock_uow.repayments.create.side_effect = mock_create
        self.mock_uow.event_store.append.return_value = "mock-event-id"

    def test_post_loan_offset_from_savings(self):
        result = SavingsService.post_loan_offset_from_savings(
            uow=self.mock_uow,
            client_id="client-001",
            client_name="John Doe",
            loan_id="loan-001",
            source_savings_type="IndividualSavings",
            branch="Lagos",
            officer="officer1",
            amount=20000.0,
            reference="REF-OFFSET-001",
            remarks="Loan offset using savings"
        )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 20000.0)
        self.assertFalse(result["affects_cash_vault"]) # ZERO physical cash movement

        # Verify operational storage
        self.mock_uow.individual_savings.create.assert_called_once()
        self.mock_uow.repayments.create.assert_called_once()
        self.mock_uow.audit.log_action.assert_called_once()
        self.mock_uow.event_store.append.assert_called_once()

    def test_transfer_to_laps(self):
        result = SavingsService.transfer_to_laps(
            uow=self.mock_uow,
            client_id="client-001",
            client_name="John Doe",
            source_savings_type="IndividualSavings",
            branch="Lagos",
            officer="officer1",
            amount=15000.0,
            reference="REF-TRANSFER-001",
            remarks="Transfer savings to LAPS"
        )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 15000.0)
        self.assertFalse(result["affects_cash_vault"]) # ZERO physical cash movement

        # Verify both source withdrawal and LAPS deposit created
        self.mock_uow.individual_savings.create.assert_called_once()
        self.mock_uow.laps_savings.create.assert_called_once()
        self.mock_uow.audit.log_action.assert_called_once()
        self.mock_uow.event_store.append.assert_called_once()

    def test_pay_laps_cash_true(self):
        result = SavingsService.pay_laps(
            uow=self.mock_uow,
            client_id="client-001",
            client_name="John Doe",
            branch="Lagos",
            officer="officer1",
            amount=10000.0,
            cash_paid=True,
            reference="REF-PAYOUT-001",
            remarks="LAPS cash payout"
        )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 10000.0)
        self.assertTrue(result["cash_paid"])
        self.assertTrue(result["affects_cash_vault"]) # Cash paid out from vault

        self.mock_uow.laps_savings.create.assert_called_once()
        self.mock_uow.audit.log_action.assert_called_once()
        self.mock_uow.event_store.append.assert_called_once()

    def test_pay_laps_cash_false(self):
        result = SavingsService.pay_laps(
            uow=self.mock_uow,
            client_id="client-001",
            client_name="John Doe",
            branch="Lagos",
            officer="officer1",
            amount=10000.0,
            cash_paid=False,
            reference="REF-PAYOUT-002",
            remarks="LAPS bank transfer payout"
        )
        self.assertEqual(result["status"], "SUCCESS")
        self.assertEqual(result["amount"], 10000.0)
        self.assertFalse(result["cash_paid"])
        self.assertFalse(result["affects_cash_vault"]) # Non-cash payout

    def test_invalid_amount_validation(self):
        with self.assertRaises(ValueError):
            SavingsService.post_loan_offset_from_savings(
                uow=self.mock_uow,
                client_id="c1", client_name="N", loan_id="l1",
                source_savings_type="IndividualSavings", branch="B", officer="O", amount=0.0
            )

        with self.assertRaises(ValueError):
            SavingsService.transfer_to_laps(
                uow=self.mock_uow,
                client_id="c1", client_name="N",
                source_savings_type="IndividualSavings", branch="B", officer="O", amount=-500.0
            )

        with self.assertRaises(ValueError):
            SavingsService.pay_laps(
                uow=self.mock_uow,
                client_id="c1", client_name="N", branch="B", officer="O", amount=0.0
            )

if __name__ == "__main__":
    unittest.main()
