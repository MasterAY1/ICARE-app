import math
from typing import Dict, Any, List
from datetime import date, timedelta

class LoanProductEngine:
    @staticmethod
    def calculate_loan_setup(amount: float, product_type: str, product_category: str = "Finance") -> Dict[str, Any]:
        """
        Calculates interest, markup, contingency, gap fee, duration, frequency, and installments.
        
        Pricing Rules:
        - 11% markup rate products: 60 Days, 12W, 3M  (Interest rate = 12% = 11% markup + 1% contingency)
        - 20% markup rate products: 120 Days, 24W, 6M (Interest rate = 21% = 20% markup + 1% contingency)
        """
        prod_str = str(product_type)
        prod_low = prod_str.lower()
        
        if "cash and carry" in prod_low:
            rate = 0.0
            duration = 1
            freq = "One-Time"
            round_step = 1
            force_gap = False
        elif "120" in prod_low:
            rate = 0.21
            duration = 120
            freq = "Daily"
            round_step = 50
            force_gap = False
        elif "daily" in prod_low or "60" in prod_low:
            rate = 0.12
            duration = 60
            freq = "Daily"
            round_step = 50
            force_gap = False
        elif "3 month" in prod_low or "3m" in prod_low:
            rate = 0.12
            duration = 3
            freq = "Monthly"
            round_step = 100
            force_gap = False
        elif "6 month" in prod_low or "6m" in prod_low:
            rate = 0.21
            duration = 6
            freq = "Monthly"
            round_step = 100
            force_gap = False
        elif "12 week" in prod_low or "12w" in prod_low:
            rate = 0.12
            duration = 12
            freq = "Weekly"
            round_step = 50
            force_gap = True
        else: # 24 Weeks fallback
            rate = 0.21
            duration = 24
            freq = "Weekly"
            round_step = 50
            force_gap = True
            
        interest = amount * rate
        
        # 1% Contingency split
        if rate == 0.12:
            contingency = interest * (1.0 / 12.0)
        elif rate == 0.21:
            contingency = interest * (1.0 / 21.0)
        else:
            contingency = 0.0
            
        markup = interest - contingency
        
        is_asset = "asset" in str(product_category).lower() or "asset" in prod_low
        
        if is_asset:
            gap_fee = 0.0
            loan_repayment = (amount + interest) / duration if duration > 0 else 0.0
        else:
            raw_val = amount / duration if duration > 0 else 0.0
            if raw_val.is_integer():
                loan_repayment = float(raw_val)
                gap_fee = 0.0
            else:
                loan_repayment = math.floor(raw_val / round_step) * round_step
                while True:
                    gap = amount - (loan_repayment * duration)
                    is_valid = True if gap >= 0 else False
                    if force_gap and (gap % 1000 != 0 or gap < 1000):
                        is_valid = False
                    if is_valid:
                        gap_fee = float(gap)
                        break
                    loan_repayment -= round_step
                    if loan_repayment <= 0:
                        loan_repayment = 0.0
                        gap_fee = float(amount)
                        break
                        
        total_upfront_required = interest + gap_fee
        active_credit = amount - gap_fee
        expected_installment = active_credit / duration if duration > 0 else 0.0
        
        return {
            "freq": freq,
            "duration": duration,
            "rate": rate,
            "interest": interest,
            "markup": markup,
            "contingency": contingency,
            "gap_fee": gap_fee,
            "total_upfront_required": total_upfront_required,
            "active_credit": active_credit,
            "loan_repayment": loan_repayment,
            "expected_installment": expected_installment
        }

    @staticmethod
    def generate_repayment_schedule(start_date: date, duration: int, frequency: str) -> List[date]:
        """Generate installment due dates list"""
        schedule = []
        curr = start_date
        for _ in range(duration):
            schedule.append(curr)
            if frequency == "Daily":
                curr = curr + timedelta(days=1)
            elif frequency == "Weekly":
                curr = curr + timedelta(days=7)
            elif frequency == "Monthly":
                # Approximate 30 days for monthly cycle
                curr = curr + timedelta(days=30)
            else:
                curr = curr + timedelta(days=1)
        return schedule
