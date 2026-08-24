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
        import holidays

        schedule_rows = []
        base_date = start_date if start_date else date.today()

        # Fetch branch closures (system-wide and branch-specific)
        branch_closures = []
        try:
            closure_res = uow.client.table("branch_closures").select("*").or_(f"branch_id.is.null,branch_id.eq.{loan.branch_id}").execute()
            if closure_res.data:
                for c in closure_res.data:
                    c_start = date.fromisoformat(c["start_date"])
                    c_end = date.fromisoformat(c["end_date"])
                    branch_closures.append((c_start, c_end))
        except Exception:
            pass

        # Fetch client's group meeting day
        meeting_day_str = None
        try:
            mem_res = uow.client.table("client_memberships").select("groups(meeting_day)").eq("client_id", loan.client_id).execute()
            if mem_res.data and mem_res.data[0].get("groups"):
                meeting_day_str = mem_res.data[0]["groups"].get("meeting_day")
        except Exception:
            pass

        day_map = {"Monday": 0, "Tuesday": 1, "Wednesday": 2, "Thursday": 3, "Friday": 4, "Saturday": 5, "Sunday": 6}
        target_weekday = day_map.get(meeting_day_str) if meeting_day_str else None

        ng_holidays = holidays.NG(years=[base_date.year, base_date.year + 1, base_date.year + 2, base_date.year + 3])

        def is_working_day(d: date) -> bool:
            if d.weekday() >= 5:  # Weekend
                return False
            if d in ng_holidays:  # Public Holiday
                return False
            for c_start, c_end in branch_closures:  # Branch Closure
                if c_start <= d <= c_end:
                    return False
            return True

        def get_next_working_day(d: date) -> date:
            while not is_working_day(d):
                d += timedelta(days=1)
            return d

        def add_months(d: date, num_months: int) -> date:
            import calendar
            m = d.month - 1 + num_months
            y = d.year + m // 12
            m = m % 12 + 1
            day = min(d.day, calendar.monthrange(y, m)[1])
            return date(y, m, day)

        current_anchor = base_date
        if cycle == "Weekly" and target_weekday is not None:
            # Snap the starting anchor to the exact group meeting day
            days_ahead = target_weekday - base_date.weekday()
            if days_ahead <= 0:
                days_ahead += 7
            first_meeting_date = base_date + timedelta(days=days_ahead)
            current_anchor = first_meeting_date - timedelta(weeks=1)

        # If gap exists, the first installment might include the initial gap fee
        for i in range(1, installments + 1):
            # Calculate due date based on cycle
            if cycle == "Daily":
                current_anchor += timedelta(days=1)
                while not is_working_day(current_anchor):
                    current_anchor += timedelta(days=1)
                current_due_date = current_anchor
            elif cycle == "Weekly":
                current_anchor += timedelta(weeks=1)
                while not is_working_day(current_anchor):
                    # For weekly group meetings, skip to the next week entirely if holiday
                    current_anchor += timedelta(weeks=1)
                current_due_date = current_anchor
            elif cycle == "Monthly":
                current_anchor = add_months(base_date, i)
                # For monthly, push forward to nearest valid working day
                current_due_date = get_next_working_day(current_anchor)
            else:
                current_due_date = base_date

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

        # Save to database (Clean existing pending schedule rows first to avoid duplicates)
        if schedule_rows:
            try:
                uow.client.table("loan_schedule").delete().eq("loan_id", loan.id).eq("status", "Pending").execute()
            except Exception:
                pass
            uow.client.table("loan_schedule").insert(schedule_rows).execute()

    @staticmethod
    def get_expected_repayment(uow: SupabaseUnitOfWork, loan_id: str, evaluation_date: date = None) -> float:
        """
        Calculates the expected periodic repayment installment for a loan up to the evaluation date (default today).
        Returns the single installment amount due for the period, or 0.0 if not found.
        """
        if not evaluation_date:
            evaluation_date = date.today()

        res = uow.client.table("loan_schedule").select("*").eq("loan_id", loan_id).order("installment_number").execute()
        if not res.data:
            return 0.0

        # Find the installment due on or immediately relevant to the evaluation date
        for row in res.data:
            due_date = datetime.strptime(row["due_date"].split("T")[0], "%Y-%m-%d").date()
            if due_date >= evaluation_date:
                return float(row.get("total_due") or (float(row.get("principal", 0)) + float(row.get("interest", 0))))

        # Fallback to the last installment amount
        last_row = res.data[-1]
        return float(last_row.get("total_due") or (float(last_row.get("principal", 0)) + float(last_row.get("interest", 0))))

    @staticmethod
    def get_total_paid(uow: SupabaseUnitOfWork, loan_id: str) -> tuple[float, bool]:
        """
        Calculates the total paid amount for a specific loan from its schedule.
        Returns a tuple (total_paid, has_schedule).
        """
        res = uow.client.table("loan_schedule").select("paid_amount").eq("loan_id", loan_id).execute()
        if not res.data:
            return (0.0, False)
        return (sum(float(row["paid_amount"] or 0) for row in res.data), True)

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

    @staticmethod
    def reschedule_branch_loans_on_closure(
        uow: SupabaseUnitOfWork,
        branch_id: str,
        start_date: date,
        end_date: date
    ) -> int:
        """
        Reschedules active loan schedules when a branch closure / public holiday is logged.
        - Daily loans: installments falling on closure shift to the next working day (tomorrow), subsequent installments shift forward.
        - Weekly loans: installments falling on closure shift to the next weekly meeting day (+1 week), subsequent installments shift forward.
        - Monthly loans: installments falling on closure shift to the next working day (tomorrow).
        Returns the number of loans rescheduled.
        """
        import holidays
        from datetime import timedelta

        # Fetch all active closures for the branch
        closure_res = uow.client.table("branch_closures").select("*").or_(f"branch_id.is.null,branch_id.eq.{branch_id}").execute()
        branch_closures = []
        for c in (closure_res.data or []):
            try:
                c_start = date.fromisoformat(str(c["start_date"])[:10])
                c_end = date.fromisoformat(str(c["end_date"])[:10])
                branch_closures.append((c_start, c_end))
            except Exception:
                pass

        ng_holidays = holidays.NG(years=[start_date.year, start_date.year + 1, start_date.year + 2])

        def is_working_day(d: date) -> bool:
            if d.weekday() >= 5:
                return False
            if d in ng_holidays:
                return False
            for c_start, c_end in branch_closures:
                if c_start <= d <= c_end:
                    return False
            return True

        def get_next_working_day(d: date) -> date:
            while not is_working_day(d):
                d += timedelta(days=1)
            return d

        # Query all active loans in the branch
        q = uow.client.table("loans").select("loan_id, client_id, loan_products(name, repayment_cycle)").in_("status", ["ACTIVE", "Active", "Approved"])
        if branch_id:
            q = q.eq("branch_id", branch_id)
        loans_res = q.execute()
        active_loans = loans_res.data or []

        rescheduled_count = 0
        for l in active_loans:
            lid = l.get("loan_id")
            if not lid:
                continue

            sched_res = uow.client.table("loan_schedule").select("*").eq("loan_id", lid).order("installment_number").execute()
            rows = sched_res.data or []
            if not rows:
                continue

            prod_info = l.get("loan_products") or {}
            p_name = str(prod_info.get("name") or "").lower()
            p_cycle = str(prod_info.get("repayment_cycle") or "").lower()

            if "daily" in p_name or "daily" in p_cycle or "60" in p_name or "120" in p_name:
                cycle_type = "Daily"
            elif "monthly" in p_name or "monthly" in p_cycle or "3m" in p_name or "6m" in p_name:
                cycle_type = "Monthly"
            else:
                cycle_type = "Weekly"

            # Check if any pending installment falls in the closure window
            needs_reschedule = False
            for r in rows:
                if r.get("status") != "Paid":
                    try:
                        d_due = date.fromisoformat(str(r["due_date"])[:10])
                        if start_date <= d_due <= end_date:
                            needs_reschedule = True
                            break
                    except Exception:
                        pass

            if not needs_reschedule:
                continue

            # Reschedule pending installments
            last_due_date = None
            for r in rows:
                if r.get("status") == "Paid":
                    try:
                        last_due_date = date.fromisoformat(str(r["due_date"])[:10])
                    except Exception:
                        pass
                    continue

                old_due = date.fromisoformat(str(r["due_date"])[:10])
                new_due = old_due

                if cycle_type == "Daily":
                    if last_due_date:
                        cand = last_due_date + timedelta(days=1)
                    else:
                        cand = old_due
                    new_due = get_next_working_day(cand)
                    last_due_date = new_due
                elif cycle_type == "Weekly":
                    if last_due_date:
                        cand = last_due_date + timedelta(weeks=1)
                    else:
                        cand = old_due
                    while not is_working_day(cand):
                        cand += timedelta(weeks=1)
                    new_due = cand
                    last_due_date = new_due
                elif cycle_type == "Monthly":
                    if not is_working_day(old_due):
                        new_due = get_next_working_day(old_due)
                    last_due_date = new_due

                if new_due.isoformat() != old_due.isoformat():
                    uow.client.table("loan_schedule").update({
                        "due_date": new_due.isoformat()
                    }).eq("id", r["id"]).execute()

            rescheduled_count += 1

        return rescheduled_count
