from typing import Dict, Any, Optional
from domain.enums import TransactionClassification

class WithdrawalClassificationEngine:
    @staticmethod
    def classify_withdrawal(classification: TransactionClassification, amount: float, is_cash_paid: Optional[bool] = None) -> Dict[str, Any]:
        """
        Classifies a savings withdrawal and determines its impact on Product Withdrawal and physical cash vault buckets.
        
        Rules:
        - Product Withdrawal = Total reduction in customer savings balance regardless of cash movement.
        - Physical Cash (cash_withdrawal) = Physical cash leaving the branch vault.
        """
        result = {
            "product_withdrawal": 0.0,
            "cash_withdrawal": 0.0,
            "bank_withdrawal": 0.0,  # Retained for backwards compatibility
            "affects_cash_vault": False
        }
        
        if amount <= 0:
            return result

        if isinstance(classification, str):
            try:
                classification = TransactionClassification(classification)
            except ValueError:
                pass

        if classification == TransactionClassification.AUTOMATIC_DEDUCTION:
            # Upfront origination charges deducted from savings (no physical cash movement)
            result["product_withdrawal"] = amount
            result["cash_withdrawal"] = 0.0
            result["bank_withdrawal"] = 0.0
            result["affects_cash_vault"] = False

        elif classification in (
            TransactionClassification.CUSTOMER_CASH_WITHDRAWAL,
            TransactionClassification.INDIVIDUAL_SAVINGS_WITHDRAWAL,
            TransactionClassification.GROUP_SAVINGS_WITHDRAWAL,
        ):
            # Option A: Direct customer withdrawals settle strictly via Bank Transfer (1050)
            result["product_withdrawal"] = amount
            result["cash_withdrawal"] = 0.0
            result["bank_withdrawal"] = amount
            result["affects_cash_vault"] = False

        elif classification == TransactionClassification.LOAN_OFFSET:
            # Savings used to offset outstanding loan (ZERO physical cash movement)
            result["product_withdrawal"] = amount
            result["cash_withdrawal"] = 0.0
            result["bank_withdrawal"] = 0.0
            result["affects_cash_vault"] = False

        elif classification == TransactionClassification.LAPS_TRANSFER:
            # Internal LAPS transfer (ZERO physical cash movement)
            result["product_withdrawal"] = amount
            result["cash_withdrawal"] = 0.0
            result["bank_withdrawal"] = 0.0
            result["affects_cash_vault"] = False

        elif classification == TransactionClassification.LAPS_PAYOUT:
            # Option A: Direct LAPS payout settles strictly via Bank Transfer (1050)
            result["product_withdrawal"] = amount
            result["cash_withdrawal"] = 0.0
            result["bank_withdrawal"] = amount
            result["affects_cash_vault"] = False

        else:
            # Default fallback routes direct payout via Bank Transfer (1050)
            result["product_withdrawal"] = amount
            result["cash_withdrawal"] = 0.0
            result["bank_withdrawal"] = amount
            result["affects_cash_vault"] = False

        return result

