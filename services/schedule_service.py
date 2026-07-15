import uuid
from datetime import date, datetime, timedelta
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.loan import Loan

class ScheduleService:
    @staticmethod
    def generate_schedule(uow: SupabaseUnitOfWork, loan: Loan, start_date: date) -> None:
        """
        Generates amortization schedule installments in the database for a loan based on product rules.
        """
        # 1. Fetch loan product parameters
        res = uow.client.table("loan_products").select("*").eq("name", loan.product_type).execute()
        if not res.data:
            # Fallback values if product not in database
            cycle = "Weekly"
            installments = loan.duration
            rate = 0.21 if loan.duration == 24 or loan.duration == 6 else 0.12
            rounding_rule = 50
        else:
            prod = res.data[0]
            cycle = prod.get("repayment_cycle", "Weekly")
            installments = prod.get("installments", loan.duration) or loan.duration
            rate = float(prod.get("interest_rate", 0) or 0)
            rate = rate / 100.0 if rate > 1.0 else rate
            rounding_rule = int(prod.get("rounding_rule", 50) or 50)

        # 2. Compute financial breakdown
        principal_amount = loan.amount
        interest_amount = principal_amount * rate
        total_payable = principal_amount + interest_amount

        # Calculate installment amounts using rounding rules
        if cycle == "One-Time":
            inst_principal = principal_amount
            inst_interest = interest_amount
            inst_total = total_payable
            gap = 0
            installments = 1
        else:
            raw_inst = principal_amount / installments
            if raw_inst.is_integer():
                inst_principal = int(raw_inst)
                gap = 0
            else:
                import math
                inst_principal = math.floor(raw_inst / rounding_rule) * rounding_rule
                gap = principal_amount - (inst_principal * installments)
            
            inst_interest = interest_amount / installments
            inst_total = inst_principal + inst_interest

        # 3. Create schedule rows
        schedule_rows = []
        current_due_date = start_date if start_date else date.today()

        # If gap exists, the first installment might include the initial gap fee
        for i in range(1, installments + 1):
            # Calculate due date based on cycle
            if i > 1:
                if cycle == "Daily":
                    current_due_date = current_due_date + timedelta(days=1)
                    # Skip Sundays
                    if current_due_date.weekday() == 6:
                        current_due_date = current_due_date + timedelta(days=1)
                elif cycle == "Weekly":
                    current_due_date = current_due_date + timedelta(weeks=1)
                elif cycle == "Monthly":
                    # Add roughly a month
                    import calendar
                    month = current_due_date.month
                    year = current_due_date.year
                    day = current_due_date.day
                    month += 1
                    if month > 12:
                        month = 1
                        year += 1
                    last_day_of_month = calendar.monthrange(year, month)[1]
                    target_day = min(day, last_day_of_month)
                    current_due_date = date(year, month, target_day)

            row_id = str(uuid.uuid4())
            row_principal = inst_principal
            # Add gap/initial fee to the first installment principal
            if i == 1 and gap > 0:
                row_principal += gap

            row_total = row_principal + inst_interest

            schedule_rows.append({
                "id": row_id,
                "loan_id": loan.id,
                "installment_number": i,
                "due_date": current_due_date.isoformat(),
                "principal": row_principal,
                "interest": inst_interest,
                "fees": 0.0,
                "total_due": row_total,
                "status": "Pending",
                "paid_amount": 0.0,
                "paid_date": None
            })

        # Save to database
        if schedule_rows:
            uow.client.table("loan_schedule").insert(schedule_rows).execute()

    @staticmethod
    def get_expected_repayment(uow: SupabaseUnitOfWork, loan_id: str, evaluation_date: date = None) -> float:
        """
        Calculates the expected repayment amount for a loan up to the evaluation date (default today).
        Expected payment = sum(total_due) of all installments due up to today - sum(paid_amount) of all installments.
        """
        if not evaluation_date:
            evaluation_date = date.today()

        res = uow.client.table("loan_schedule").select("*").eq("loan_id", loan_id).execute()
        if not res.data:
            return 0.0

        total_due_so_far = 0.0
        total_paid_so_far = 0.0

        for row in res.data:
            due_date = datetime.strptime(row["due_date"], "%Y-%m-%d").date()
            if due_date <= evaluation_date:
                total_due_so_far += float(row["total_due"] or 0)
            total_paid_so_far += float(row["paid_amount"] or 0)

        expected = total_due_so_far - total_paid_so_far
        return max(0.0, expected)

    @staticmethod
    def record_repayment(uow: SupabaseUnitOfWork, loan_id: str, amount: float, paid_date: date = None) -> float:
        """
        Applies a manual repayment amount to the loan schedule in chronological sequence.
        Returns the excess amount (if any) that can reduce outstanding principal.
        """
        if not paid_date:
            paid_date = date.today()

        # Load schedule sorted by installment_number
        res = uow.client.table("loan_schedule").select("*").eq("loan_id", loan_id).order("installment_number").execute()
        if not res.data:
            return amount

        remaining_repayment = amount

        for row in res.data:
            if remaining_repayment <= 0:
                break

            total_due = float(row["total_due"] or 0)
            paid_amount = float(row["paid_amount"] or 0)
            needed = total_due - paid_amount

            if needed <= 0:
                continue

            if remaining_repayment >= needed:
                new_paid_amount = total_due
                status = "Paid"
                remaining_repayment -= needed
            else:
                new_paid_amount = paid_amount + remaining_repayment
                status = "Partial"
                remaining_repayment = 0.0

            uow.client.table("loan_schedule").update({
                "paid_amount": new_paid_amount,
                "status": status,
                "paid_date": paid_date.isoformat()
            }).eq("id", row["id"]).execute()

        # If there is remaining_repayment (excess payment), it is applied directly to reduce principal
        # The user requested: excess goes to reduce principal/outstanding balance, do NOT skip meetings,
        # but next Expected Repayments are reduced.
        return remaining_repayment
