import uuid
import math
from typing import Optional, Any
from datetime import date, datetime, timedelta
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.loan import Loan
from services.business_date_service import get_nigerian_holidays

class ScheduleService:
    @staticmethod
    def generate_schedule(uow: SupabaseUnitOfWork, loan: Loan, start_date: date) -> None:
        """
        Generates amortization schedule installments in the database for a loan based on product rules.
        """
        # 1. Fetch loan product parameters via LoanProductEngine
        from services.loan_product_engine import LoanProductEngine
        prod_cat = getattr(loan, 'product_category', None) or (loan.extra_fields.get("product_category") if hasattr(loan, 'extra_fields') and isinstance(loan.extra_fields, dict) else None) or ("Asset" if getattr(loan, 'is_asset', False) else "Finance")
        setup = LoanProductEngine.calculate_loan_setup(loan.amount, loan.product_type, prod_cat)
        
        is_asset = "asset" in str(prod_cat).lower() or (loan.product_type and "asset" in str(loan.product_type).lower())
        cycle = setup.get("freq", "Weekly")
        installments = setup.get("duration", loan.duration) or loan.duration

        # In ICARE, active_credit is already derived at origination and strictly divisible by duration.
        # Prefer the established loan_repay, or active_credit / installments.
        loan_repay = float(getattr(loan, 'loan_repay', 0.0) or 0.0)
        if loan_repay > 0:
            inst_total = loan_repay
        elif getattr(loan, 'active_credit', 0.0) and installments > 0:
            inst_total = float(loan.active_credit / installments)
        else:
            inst_total = float(setup.get("loan_repayment", 0.0))

        inst_principal = inst_total
        inst_interest = 0.0
        gap = 0

        # 2. Create schedule rows
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

        ng_holidays = get_nigerian_holidays(years=[base_date.year, base_date.year + 1, base_date.year + 2, base_date.year + 3])

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
    def get_loan_due_breakdown(
        uow: SupabaseUnitOfWork,
        loan_id: str,
        evaluation_date: date = None,
        client_id: str = None,
        loan_data: Optional[dict] = None,
        schedule_rows: Optional[list] = None,
        meeting_day_str: Optional[str] = None,
        total_paid_sch: Optional[float] = None
    ) -> dict:
        """
        Authoritative calculation of loan repayment obligations for an evaluation date per BR-DASH-007.
        Strictly enforces frequency/meeting-day invariants:
        - Daily loans: Evaluated on every valid working day.
        - Weekly loans: Evaluated ONLY on the client's assigned group meeting day.
        - Monthly loans: Evaluated on their monthly due date.
        Returns cumulative total due = (Past Overdue Arrears + Current Installment Due Today).
        """
        if not evaluation_date:
            evaluation_date = date.today()
        elif isinstance(evaluation_date, str):
            evaluation_date = date.fromisoformat(evaluation_date.split("T")[0])
        elif isinstance(evaluation_date, datetime):
            evaluation_date = evaluation_date.date()

        eval_weekday_str = evaluation_date.strftime("%A")

        # 1. Fetch loan and product details
        if loan_data is None:
            if loan_id:
                try:
                    res_l = uow.client.table("loans").select(
                        "loan_id, client_id, active_credit, total_due, loan_repay, status, loan_amount, extra_fields, loan_products(name, repayment_cycle, installments)"
                    ).eq("loan_id", loan_id).execute()
                    if res_l.data:
                        loan_data = res_l.data[0]
                except Exception:
                    pass

            if not loan_data and client_id:
                try:
                    res_l = uow.client.table("loans").select(
                        "loan_id, client_id, active_credit, total_due, loan_repay, status, loan_amount, extra_fields, loan_products(name, repayment_cycle, installments)"
                    ).eq("client_id", client_id).eq("status", "Active").execute()
                    if res_l.data:
                        loan_data = res_l.data[0]
                        loan_id = loan_data.get("loan_id")
                except Exception:
                    pass

        if not loan_data:
            return {
                "loan_id": loan_id,
                "client_id": client_id,
                "cycle": "Weekly",
                "meeting_day": None,
                "is_meeting_today": False,
                "current_installment": 0.0,
                "overdue_arrears": 0.0,
                "total_due_today": 0.0,
                "has_overdue": False,
                "missed_installments_count": 0,
                "remaining_balance": 0.0
            }

        resolved_client_id = loan_data.get("client_id") or client_id
        lp = loan_data.get("loan_products") or {}
        p_name = str(lp.get("name") or "").lower()
        cycle = lp.get("repayment_cycle") or ("Daily" if "daily" in p_name else ("Weekly" if "weekly" in p_name else "Monthly"))

        # 2. Fetch Group Meeting Day
        if meeting_day_str is None and resolved_client_id:
            try:
                res_mem = uow.client.table("client_memberships").select("groups(meeting_day)").eq("client_id", resolved_client_id).execute()
                if res_mem.data and res_mem.data[0].get("groups"):
                    meeting_day_str = res_mem.data[0]["groups"].get("meeting_day")
            except Exception:
                pass

        # 3. Check Meeting Day Validity
        is_meeting_today = False
        if cycle == "Daily":
            # Working day check
            if evaluation_date.weekday() < 5:
                is_meeting_today = True
        elif cycle == "Weekly":
            if meeting_day_str:
                is_meeting_today = (meeting_day_str.strip().lower() == eval_weekday_str.lower())
            else:
                # If unassigned group, default to True on evaluation date
                is_meeting_today = True
        elif cycle == "Monthly":
            # Monthly loans check if scheduled due date matches
            is_meeting_today = True

        # 4. Fetch schedule rows if not provided
        if schedule_rows is None:
            try:
                res_sch = uow.client.table("loan_schedule").select("*").eq("loan_id", loan_id).order("installment_number").execute()
                schedule_rows = res_sch.data or []
            except Exception:
                schedule_rows = []

        total_due_base = float(loan_data.get("total_due") if loan_data.get("total_due") is not None else (loan_data.get("active_credit") or loan_data.get("loan_amount") or 0.0))

        # Reconcile total paid from schedule and repayments table
        sch_paid = sum(float(row.get("paid_amount") or 0.0) for row in schedule_rows) if schedule_rows else 0.0
        rep_paid = 0.0
        if total_paid_sch is not None:
            rep_paid = float(total_paid_sch)
        elif loan_id:
            try:
                res_rep = uow.client.table("repayments").select("amount_paid").eq("loan_id", loan_id).execute()
                rep_paid = sum(float(r.get("amount_paid") or 0.0) for r in (res_rep.data or []))
            except Exception:
                pass

        authoritative_paid = max(sch_paid, rep_paid)
        rem_bal = max(0.0, total_due_base - authoritative_paid)

        if rem_bal <= 0.0:
            return {
                "loan_id": loan_id,
                "client_id": resolved_client_id,
                "cycle": cycle,
                "meeting_day": meeting_day_str,
                "is_meeting_today": is_meeting_today,
                "current_installment": 0.0,
                "overdue_arrears": 0.0,
                "total_due_today": 0.0,
                "has_overdue": False,
                "missed_installments_count": 0,
                "remaining_balance": 0.0
            }

        # Resolve duration and single expected installment
        lp_inst = (loan_data.get("loan_products") or {}).get("installments")
        dur = int(loan_data.get("duration") or lp_inst or (60 if cycle == "Daily" else 20))
        if dur <= 0:
            dur = 1

        inst_repay = float(loan_data.get("loan_repay") or loan_data.get("expected_installment") or 0.0)
        if inst_repay <= 0.0:
            inst_repay = round(total_due_base / dur, 2) if dur > 0 else total_due_base

        # Check schedule rows coverage
        max_sch_date = None
        if schedule_rows:
            try:
                sch_dates = [datetime.strptime(r["due_date"].split("T")[0], "%Y-%m-%d").date() for r in schedule_rows if r.get("due_date")]
                if sch_dates:
                    max_sch_date = max(sch_dates)
            except Exception:
                pass

        # If schedule rows cover up to or beyond evaluation date, use chronological waterflow
        use_waterflow = bool(schedule_rows and max_sch_date and max_sch_date >= evaluation_date)

        overdue_arrears = 0.0
        current_installment = 0.0
        missed_count = 0

        if use_waterflow:
            remaining_cash = authoritative_paid
            found_exact_today = False
            sorted_rows = sorted(
                schedule_rows,
                key=lambda r: (r.get("installment_number") or 0, r.get("due_date") or "")
            )

            for row in sorted_rows:
                try:
                    d_due = datetime.strptime(row["due_date"].split("T")[0], "%Y-%m-%d").date()
                except Exception:
                    continue

                t_due = float(row.get("total_due") or (float(row.get("principal", 0)) + float(row.get("interest", 0))))
                row_covered = min(remaining_cash, t_due)
                remaining_cash = max(0.0, remaining_cash - row_covered)
                shortfall = max(0.0, t_due - row_covered)

                if d_due < evaluation_date:
                    if shortfall > 0:
                        overdue_arrears += shortfall
                        missed_count += 1
                elif d_due == evaluation_date:
                    if shortfall > 0:
                        current_installment += shortfall
                        found_exact_today = True

            if is_meeting_today and not found_exact_today and current_installment == 0.0:
                for row in sorted_rows:
                    try:
                        d_due = datetime.strptime(row["due_date"].split("T")[0], "%Y-%m-%d").date()
                    except Exception:
                        continue
                    if d_due >= evaluation_date:
                        t_due = float(row.get("total_due") or (float(row.get("principal", 0)) + float(row.get("interest", 0))))
                        current_installment = min(inst_repay, t_due)
                        break
        else:
            # Truncated or missing schedule rows: derive from start_date & cycle calendar
            start_dt = None
            if loan_data.get("start_date"):
                try:
                    start_dt = datetime.strptime(str(loan_data["start_date"]).split("T")[0], "%Y-%m-%d").date()
                except Exception:
                    pass
            if not start_dt and schedule_rows:
                try:
                    first_row = min(schedule_rows, key=lambda r: (r.get("installment_number") or 1, r.get("due_date") or ""))
                    start_dt = datetime.strptime(str(first_row["due_date"]).split("T")[0], "%Y-%m-%d").date()
                except Exception:
                    pass
            if not start_dt and loan_data.get("created_at"):
                try:
                    start_dt = datetime.strptime(str(loan_data["created_at"]).split("T")[0], "%Y-%m-%d").date()
                except Exception:
                    pass
            if not start_dt:
                start_dt = evaluation_date

            past_meetings = 0
            if start_dt < evaluation_date:
                cur = start_dt
                day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                while cur < evaluation_date:
                    if cycle == "Daily":
                        if cur.weekday() < 5:
                            past_meetings += 1
                    elif cycle == "Weekly":
                        if meeting_day_str and day_names[cur.weekday()].lower() == meeting_day_str.lower():
                            past_meetings += 1
                        elif not meeting_day_str and cur.weekday() == start_dt.weekday():
                            past_meetings += 1
                    cur += timedelta(days=1)

            expected_past = min(dur, past_meetings) * inst_repay
            overdue_arrears = min(rem_bal, max(0.0, expected_past - authoritative_paid))
            missed_count = int(math.ceil(overdue_arrears / inst_repay)) if inst_repay > 0 and overdue_arrears > 0 else 0
            current_installment = min(inst_repay, max(0.0, rem_bal - overdue_arrears)) if is_meeting_today else 0.0

        current_installment = min(current_installment, rem_bal)
        overdue_arrears = min(overdue_arrears, rem_bal)

        if is_meeting_today:
            total_due_today = min(rem_bal, overdue_arrears + current_installment)
        else:
            total_due_today = 0.0

        return {
            "loan_id": loan_id,
            "client_id": resolved_client_id,
            "cycle": cycle,
            "meeting_day": meeting_day_str,
            "is_meeting_today": is_meeting_today,
            "current_installment": round(current_installment, 2),
            "overdue_arrears": round(overdue_arrears, 2),
            "total_due_today": round(total_due_today, 2),
            "has_overdue": overdue_arrears > 0,
            "missed_installments_count": missed_count,
            "remaining_balance": round(rem_bal, 2)
        }

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
    def record_repayment(uow: SupabaseUnitOfWork, loan_id: str, amount: float, paid_date: date = None, cached_schedule_rows: list = None) -> float:
        """
        Applies a manual repayment amount to the loan schedule in chronological sequence.
        Returns the excess amount (if any) that can reduce outstanding principal.
        """
        if not paid_date:
            paid_date = date.today()

        # Load schedule sorted by installment_number (from cache if provided)
        if cached_schedule_rows is not None:
            schedule_rows = sorted(cached_schedule_rows, key=lambda r: int(r.get("installment_number") or 0))
        else:
            res = uow.client.table("loan_schedule").select("*").eq("loan_id", loan_id).order("installment_number").execute()
            schedule_rows = res.data or []

        if not schedule_rows:
            return amount

        remaining_repayment = amount

        for row in schedule_rows:
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
    def reverse_repayment_schedule(
        uow: SupabaseUnitOfWork,
        loan_id: str,
        amount: float,
        reversal_date: Optional[date] = None
    ) -> float:
        """
        Reverses an amount previously applied to a loan schedule (BR-ERR-002).
        Walks schedule rows in descending order of installment_number, deducting paid_amount
        and transitioning status from Paid -> Partial -> Pending.
        Returns any remaining unreversed amount.
        """
        if not loan_id or amount <= 0:
            return amount

        res = uow.client.table("loan_schedule").select("*").eq("loan_id", loan_id).order("installment_number", desc=True).execute()
        schedule_rows = res.data or []
        if not schedule_rows:
            return amount

        remaining_to_reverse = amount

        for row in schedule_rows:
            if remaining_to_reverse <= 0:
                break

            paid_amount = float(row.get("paid_amount") or 0.0)
            if paid_amount <= 0:
                continue

            if remaining_to_reverse >= paid_amount:
                deduct = paid_amount
                new_paid_amount = 0.0
                status = "Pending"
                new_paid_date = None
                remaining_to_reverse -= deduct
            else:
                deduct = remaining_to_reverse
                new_paid_amount = paid_amount - deduct
                status = "Partial"
                new_paid_date = row.get("paid_date")
                remaining_to_reverse = 0.0

            uow.client.table("loan_schedule").update({
                "paid_amount": new_paid_amount,
                "status": status,
                "paid_date": new_paid_date
            }).eq("id", row["id"]).execute()

        return remaining_to_reverse

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

        ng_holidays = get_nigerian_holidays(years=[start_date.year, start_date.year + 1, start_date.year + 2])

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

    @staticmethod
    def evaluate_and_apply_loan_default(
        uow: SupabaseUnitOfWork,
        loan_id: str,
        evaluation_date: Optional[date] = None,
        actor_id: Optional[str] = None
    ) -> dict:
        """
        Evaluates the 3-default rule (BR-CLI-002, BR-CLI-003, BR-CLI-009):
        If a loan has >= 3 missed/overdue installments up to evaluation_date,
        automatically flags the loan status as 'Defaulter' and transitions
        the client's lifecycle status to 'Defaulter'.
        """
        from services.client_status_service import ClientStatusService
        eval_date = evaluation_date if evaluation_date else date.today()

        breakdown = ScheduleService.get_loan_due_breakdown(
            uow=uow,
            loan_id=loan_id,
            evaluation_date=eval_date
        )

        missed_count = breakdown.get("missed_installments_count", 0)
        client_id = breakdown.get("client_id")

        if missed_count >= 3:
            # Check current loan status
            res_l = uow.client.table("loans").select("loan_id, status, client_id").eq("loan_id", loan_id).execute()
            if res_l.data:
                l_row = res_l.data[0]
                if l_row.get("status") != "Defaulter":
                    uow.client.table("loans").update({
                        "status": "Defaulter",
                        "updated_at": datetime.now().isoformat()
                    }).eq("loan_id", loan_id).execute()

                # Transition client status to Defaulter if not already Defaulter
                c_id = l_row.get("client_id") or client_id
                if c_id:
                    ClientStatusService.transition_status(
                        uow=uow,
                        client_id=c_id,
                        new_status_name="Defaulter",
                        changed_by=actor_id,
                        reason=f"Client defaulted {missed_count} installments on loan {loan_id[:8]}",
                        trigger_type="SYSTEM",
                        trigger_reference=loan_id
                    )

            return {
                "defaulted": True,
                "missed_installments_count": missed_count,
                "loan_id": loan_id,
                "client_id": client_id,
                "status": "Defaulter"
            }

        return {
            "defaulted": False,
            "missed_installments_count": missed_count,
            "loan_id": loan_id,
            "client_id": client_id,
            "status": "Active"
        }

    @staticmethod
    def evaluate_branch_defaults(
        uow: SupabaseUnitOfWork,
        branch_id: Optional[str] = None,
        evaluation_date: Optional[date] = None,
        actor_id: Optional[str] = None
    ) -> dict:
        """
        Evaluates all active loans in the branch for the 3-default rule.
        Transitions eligible loans and clients to 'Defaulter'.
        """
        eval_date = evaluation_date if evaluation_date else date.today()
        query = uow.client.table("loans").select("loan_id, client_id, branch_id, status").in_("status", ["Active", "ACTIVE", "Disbursed"])
        if branch_id:
            query = query.eq("branch_id", branch_id)

        res = query.execute()
        active_loans = res.data or []

        defaulters = []
        for l in active_loans:
            r = ScheduleService.evaluate_and_apply_loan_default(
                uow=uow,
                loan_id=l["loan_id"],
                evaluation_date=eval_date,
                actor_id=actor_id
            )
            if r.get("defaulted"):
                defaulters.append(r)

        return {
            "success": True,
            "evaluated_count": len(active_loans),
            "new_defaulters_count": len(defaulters),
            "defaulters": defaulters,
            "message": f"Evaluated {len(active_loans)} active loans. {len(defaulters)} loans transitioned to Defaulter."
        }

