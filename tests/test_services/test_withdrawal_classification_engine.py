import unittest
from domain.enums import TransactionClassification
from services.withdrawal_classification_engine import WithdrawalClassificationEngine

class TestWithdrawalClassificationEngine(unittest.TestCase):
    def test_normal_customer_cash_withdrawal(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.CUSTOMER_CASH_WITHDRAWAL, 5000.0
        )
        self.assertEqual(res["product_withdrawal"], 5000.0)
        self.assertEqual(res["cash_withdrawal"], 5000.0)
        self.assertTrue(res["affects_cash_vault"])

    def test_individual_savings_cash_withdrawal(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.INDIVIDUAL_SAVINGS_WITHDRAWAL, 2500.0
        )
        self.assertEqual(res["product_withdrawal"], 2500.0)
        self.assertEqual(res["cash_withdrawal"], 2500.0)
        self.assertTrue(res["affects_cash_vault"])

    def test_loan_offset_classification(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LOAN_OFFSET, 10000.0
        )
        self.assertEqual(res["product_withdrawal"], 10000.0)
        self.assertEqual(res["cash_withdrawal"], 0.0)
        self.assertFalse(res["affects_cash_vault"])

    def test_laps_transfer_classification(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_TRANSFER, 12000.0, is_cash_paid=True
        )
        # Even if is_cash_paid parameter passed, LAPS_TRANSFER MUST have ZERO cash movement
        self.assertEqual(res["product_withdrawal"], 12000.0)
        self.assertEqual(res["cash_withdrawal"], 0.0)
        self.assertFalse(res["affects_cash_vault"])

    def test_laps_payout_cash_true(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_PAYOUT, 8000.0, is_cash_paid=True
        )
        self.assertEqual(res["product_withdrawal"], 8000.0)
        self.assertEqual(res["cash_withdrawal"], 8000.0)
        self.assertTrue(res["affects_cash_vault"])

    def test_laps_payout_cash_false(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.LAPS_PAYOUT, 8000.0, is_cash_paid=False
        )
        self.assertEqual(res["product_withdrawal"], 8000.0)
        self.assertEqual(res["cash_withdrawal"], 0.0)
        self.assertFalse(res["affects_cash_vault"])

    def test_automatic_deduction_classification(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.AUTOMATIC_DEDUCTION, 1500.0
        )
        self.assertEqual(res["product_withdrawal"], 1500.0)
        self.assertEqual(res["cash_withdrawal"], 0.0)
        self.assertFalse(res["affects_cash_vault"])

    def test_zero_or_negative_amount(self):
        res = WithdrawalClassificationEngine.classify_withdrawal(
            TransactionClassification.CUSTOMER_CASH_WITHDRAWAL, 0.0
        )
        self.assertEqual(res["product_withdrawal"], 0.0)
        self.assertEqual(res["cash_withdrawal"], 0.0)
        self.assertFalse(res["affects_cash_vault"])

if __name__ == "__main__":
    unittest.main()
