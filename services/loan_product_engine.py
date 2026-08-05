import math
from typing import Dict, Any, List, Optional
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
    def generate_repayment_schedule(
        start_date: date,
        duration: int,
        frequency: str,
        meeting_day: Optional[str] = None,
        closed_dates: Optional[List[date]] = None
    ) -> List[date]:
        """
        Generate installment due dates list according to business rules:
        - Daily (60d/120d): Monday to Friday installments only (skipping weekends Saturday/Sunday, Nigerian public holidays, and custom closures).
        - Weekly (12w/24w): Weekly installments on Group Meeting Day (shifting to next working day if holiday).
        - Monthly (3m/6m): Monthly installments starting exactly 1 month after disbursement (shifting to next working day if weekend/holiday).
        """
        import holidays
        from dateutil.relativedelta import relativedelta

        ng_holidays = holidays.Nigeria()
        if closed_dates is None:
            closed_dates = []

        def is_valid_working_day(d: date) -> bool:
            if d.weekday() >= 5:  # Saturday or Sunday
                return False
            if d in ng_holidays:
                return False
            if d in closed_dates:
                return False
            return True

        def get_next_valid_day(d: date) -> date:
            curr_d = d
            while not is_valid_working_day(curr_d):
                curr_d += timedelta(days=1)
            return curr_d

        days_map = {
            "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3,
            "friday": 4, "saturday": 5, "sunday": 6
        }

        schedule = []

        if frequency == "Daily":
            curr = start_date + timedelta(days=1)
            while len(schedule) < duration:
                if is_valid_working_day(curr):
                    schedule.append(curr)
                curr += timedelta(days=1)

        elif frequency == "Weekly":
            curr = start_date
            if meeting_day and str(meeting_day).lower() in days_map:
                target_weekday = days_map[str(meeting_day).lower()]
                days_ahead = target_weekday - curr.weekday()
                if days_ahead <= 0:
                    days_ahead += 7
                curr = curr + timedelta(days=days_ahead)
            else:
                curr = curr + timedelta(days=7)

            for _ in range(duration):
                schedule.append(get_next_valid_day(curr))
                curr += timedelta(days=7)

        elif frequency == "Monthly":
            curr = start_date
            for i in range(1, duration + 1):
                target_m_date = start_date + relativedelta(months=i)
                schedule.append(get_next_valid_day(target_m_date))

        else:  # Default / Fallback
            curr = start_date + timedelta(days=1)
            while len(schedule) < duration:
                if is_valid_working_day(curr):
                    schedule.append(curr)
                curr += timedelta(days=1)

        return schedule
