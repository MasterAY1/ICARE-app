from typing import Dict, Any
from domain.enums import TransactionClassification

class WithdrawalClassificationEngine:
    @staticmethod
    def classify_withdrawal(classification: TransactionClassification, amount: float, is_cash_paid: bool = False) -> Dict[str, Any]:
        """
        Classifies a savings withdrawal and determines its impact on Product Withdrawal and Bank Withdrawal buckets.
        
        Rules:
        - Product Withdrawal = Total reduction in customer savings balance regardless of cash movement.
        - Bank Withdrawal = Physical cash leaving the branch vault.
        """
        result = {
            "product_withdrawal": 0.0,
            "bank_withdrawal": 0.0,
            "affects_cash_vault": False
        }
        
        if amount <= 0:
            return result

        if classification == TransactionClassification.AUTOMATIC_DEDUCTION:
            # Type 1 — Upfront origination charges deducted from savings
            result["product_withdrawal"] = amount
            result["bank_withdrawal"] = 0.0
            result["affects_cash_vault"] = False

        elif classification == TransactionClassification.CUSTOMER_CASH_WITHDRAWAL:
            # Type 2 — Customer cash withdrawal from officer
            result["product_withdrawal"] = amount
            result["bank_withdrawal"] = amount
            result["affects_cash_vault"] = True

        elif classification == TransactionClassification.LOAN_OFFSET:
            # Type 3 — Savings used to offset outstanding loan
            result["product_withdrawal"] = amount
            result["bank_withdrawal"] = 0.0
            result["affects_cash_vault"] = False

        elif classification == TransactionClassification.LAPS_TRANSFER:
            # Type 4 — Account closure / Laps transfer
            result["product_withdrawal"] = amount
            result["bank_withdrawal"] = amount if is_cash_paid else 0.0
            result["affects_cash_vault"] = is_cash_paid

        else:
            # Fallback
            result["product_withdrawal"] = amount
            result["bank_withdrawal"] = amount if is_cash_paid else 0.0

        return result
