import uuid
from datetime import date, timedelta
from typing import Optional
from interfaces.unit_of_work import UnitOfWork

class CoCashbookProjectionBuilder:
    @staticmethod
    def rebuild_co_projection(uow: UnitOfWork, branch_id: str, officer_id: str, posting_date: date) -> Optional[dict]:
        """
        Rebuilds the officer-level daily cashbook projection row in co_cashbooks.
        Strictly contains Credit Officer originated transactions in accordance with ICARE Constitutional Rules (BR-CASH-001 to BR-CASH-005).
        """
        if isinstance(posting_date, str):
            posting_date = date.fromisoformat(posting_date)
        elif hasattr(posting_date, "date"):
            posting_date = posting_date.date()
            
        if not branch_id or not officer_id:
            return None

        p_date_str = posting_date.isoformat()
        prev_date = posting_date - timedelta(days=1)
        prev_date_str = prev_date.isoformat()
        
        # 1. Opening balance from previous day's CO Cashbook closing balance
        opening_bal = 0.0
        try:
            res_prev = uow.client.table("co_cashbooks").select("closing_balance") \
                .eq("branch_id", branch_id).eq("officer_id", officer_id).eq("date", prev_date_str).execute()
            if res_prev.data:
                opening_bal = float(res_prev.data[0]["closing_balance"] or 0.0)
        except Exception:
            pass

        # 2. Determine if this officer is the designated Misc Savings officer for the branch (BR-SAV-002)
        from services.savings_service import SavingsService
        designated_misc_officer_id = None
        try:
            res_misc_off = SavingsService.get_branch_misc_savings_officer(uow, branch_id)
            designated_misc_officer_id = res_misc_off[0] if isinstance(res_misc_off, tuple) else res_misc_off
        except Exception:
            pass
        is_misc_officer = (str(officer_id) == str(designated_misc_officer_id))

        # 3. Fetch ledger entries for this branch & officer on posting_date
        try:
            res_entries = uow.client.table("financial_ledger_entries") \
                .select("*, financial_transactions!inner(event_id, posting_date, narration, reference, officer_id, event_store(event_type, payload))") \
                .eq("branch_id", branch_id) \
                .eq("financial_transactions.officer_id", officer_id) \
                .eq("financial_transactions.posting_date", p_date_str) \
                .execute()
            entries_list = res_entries.data or []
        except Exception as e:
            print(f"Error fetching ledger entries for CO Cashbook: {e}")
            raise e

        # Also fetch branch-wide internal savings if this is the designated misc officer
        branch_misc_entries = []
        if is_misc_officer:
            try:
                res_misc = uow.client.table("internal_savings").select("amount") \
                    .eq("branch_id", branch_id).eq("posting_date", p_date_str).execute()
                branch_misc_entries = res_misc.data or []
            except Exception:
                pass

        rep_daily = rep_12_weeks = rep_24_weeks = rep_monthly = 0.0
        savings_deposit = laps_reserve = 0.0
        daily_11_pct = weekly_11_pct = risk_premium_returns = 0.0
        savings_adj_no = 0
        savings_adj_amount = passbook = app_fee = 0.0
        asset_credit_sales = cash_and_carry = contingency = credit_form = credit_form_damage = 0.0
        bonus = misc_fees = 0.0

        savings_withdrawal = laps_returns = bank_deposit = bank_withdrawal = product_withdrawal = 0.0
        weekly_active = daily_active = monthly_active = 0.0
        office_expenses = 0.0

        processed_pwd_events = set()

        for entry in entries_list:
            acc = entry.get("account_code")
            amount = float(entry.get("amount") or 0.0)
            side = entry.get("side")
            tx = entry.get("financial_transactions") or {}
            ev_store = tx.get("event_store") or {}
            event_type = ev_store.get("event_type")
            ev_id = tx.get("event_id") or entry.get("entry_id") or str(uuid.uuid4())
            narr = str(tx.get("narration") or "").lower()

            # Handle internal non-cash transfers for Product Withdrawal
            if event_type == "LapsTransferred" and acc == "2030" and side == "Credit":
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    laps_reserve += amount
                    processed_pwd_events.add(ev_id)
                continue

            if event_type == "LoanOffsetFromSavings" and acc in ["2000", "2010", "2020"] and side == "Debit":
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    processed_pwd_events.add(ev_id)
                continue

            # Account 4000 Office Expenses
            if acc == "4000" and side == "Debit":
                office_expenses += amount
                continue

            if acc != "1000":
                continue

            if side == "Debit":
                # CO Inflows
                if event_type == "RepaymentReceived":
                    loan_id = ev_store.get("payload", {}).get("loan_id") or entry.get("aggregate_id")
                    prod_name = ""
                    cycle = "Weekly"
                    try:
                        # 1. Try querying loans by loan_id
                        res_l = uow.client.table("loans").select("frequency, duration, loan_products(name, repayment_cycle)").eq("loan_id", loan_id).execute()
                        if not res_l.data:
                            # 2. Try querying loans by client_id
                            res_l = uow.client.table("loans").select("frequency, duration, loan_products(name, repayment_cycle)").eq("client_id", loan_id).eq("status", "Active").execute()
                        if res_l.data:
                            row_l = res_l.data[0]
                            lp = row_l.get("loan_products") or {}
                            prod_name = str(lp.get("name") or "").lower()
                            cycle = lp.get("repayment_cycle") or row_l.get("frequency") or ("Daily" if "daily" in prod_name else "Weekly")
                    except Exception:
                        pass

                    if "12 week" in prod_name or "12w" in prod_name or "12wk" in prod_name or (cycle == "Weekly" and "24" not in prod_name):
                        rep_12_weeks += amount
                    elif "24 week" in prod_name or "24w" in prod_name or "24wk" in prod_name:
                        rep_24_weeks += amount
                    elif "120" in prod_name or "120d" in prod_name or "60" in prod_name or "60d" in prod_name or "daily" in prod_name or cycle == "Daily":
                        rep_daily += amount
                    elif "month" in prod_name or cycle == "Monthly":
                        rep_monthly += amount
                    else:
                        if cycle == "Daily":
                            rep_daily += amount
                        elif cycle == "Monthly":
                            rep_monthly += amount
                        else:
                            rep_12_weeks += amount

                elif event_type in ["SavingsDeposited", "INDIVIDUAL_SAVINGS_DEPOSIT", "GROUP_SAVINGS_DEPOSIT"]:
                    if entry.get("aggregate_type") == "LapsSavings":
                        laps_reserve += amount
                    else:
                        savings_deposit += amount
                        
                elif event_type in ["FeeCharged", "MARKUP", "MARKUP_11", "MARKUP_20", "CONTINGENCY", "PROCESSING_FEE", "PASSBOOK"]:
                    if "passbook" in narr or "pass book" in narr or "pass_book" in narr: passbook += amount
                    elif "processing" in narr or "application" in narr or "app fee" in narr or "app_fee" in narr: app_fee += amount
                    elif "contingency" in narr:
                        contingency += amount
                        if "upfront" in narr: product_withdrawal += amount
                    elif "credit form damage" in narr or "credit_form_damage" in narr: credit_form_damage += amount
                    elif "credit form" in narr or "credit_form" in narr: credit_form += amount
                    elif "bonus" in narr: bonus += amount
                    elif "11%" in narr and "weekly" in narr:
                        weekly_11_pct += amount
                        if "upfront" in narr: product_withdrawal += amount
                    elif "20%" in narr and "weekly" in narr:
                        risk_premium_returns += amount
                        if "upfront" in narr: product_withdrawal += amount
                    elif "20%" in narr or "markup_20" in narr or "120" in narr or "24" in narr or "6m" in narr or "6 month" in narr:
                        risk_premium_returns += amount
                        if "upfront" in narr: product_withdrawal += amount
                    elif "11%" in narr or "markup_11" in narr or "3m" in narr or "3 month" in narr or "60" in narr:
                        daily_11_pct += amount
                        if "upfront" in narr: product_withdrawal += amount
                    elif "weekly" in narr:
                        weekly_11_pct += amount
                        if "upfront" in narr: product_withdrawal += amount
                    elif "daily" in narr:
                        daily_11_pct += amount
                        if "upfront" in narr: product_withdrawal += amount
                    else:
                        if is_misc_officer:
                            savings_deposit += amount
                        else:
                            misc_fees += amount

                elif event_type == "BankWithdrawn":
                    bank_withdrawal += amount
                elif event_type == "AssetSoldCash":
                    if "credit" in narr or "credit sale" in narr:
                        asset_credit_sales += amount
                    else:
                        cash_and_carry += amount
                elif event_type == "PenaltyCharged":
                    if is_misc_officer:
                        savings_deposit += amount
                    else:
                        misc_fees += amount

            elif side == "Credit":
                # CO Outflows
                if event_type in ["SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION"]:
                    savings_withdrawal += amount
                    bank_withdrawal += amount  # Bank transfer payout from bank
                    if ev_id not in processed_pwd_events:
                        product_withdrawal += amount
                        processed_pwd_events.add(ev_id)
                elif event_type == "BankDeposited":
                    bank_deposit += amount
                elif event_type == "LapsPaidOut":
                    laps_returns += amount
                    bank_withdrawal += amount  # Bank transfer payout from bank
                    if ev_id not in processed_pwd_events:
                        product_withdrawal += amount
                        processed_pwd_events.add(ev_id)

        # Add pooled branch misc savings for designated officer
        if is_misc_officer and branch_misc_entries:
            misc_total = sum(float(m.get("amount") or 0.0) for m in branch_misc_entries)
            savings_deposit += misc_total

        # 4. Fetch Active Loans originated today by this CO (BR-CASH-001 & BR-CASH-003)
        try:
            res_loans = uow.client.table("loans").select("amount, active_credit, product_type, loan_products(repayment_cycle, product_category)") \
                .eq("officer_id", officer_id).eq("branch_id", branch_id) \
                .gte("created_at", f"{p_date_str}T00:00:00").lte("created_at", f"{p_date_str}T23:59:59") \
                .in_("status", ["Active", "Approved", "Completed"]).execute()
            for l in (res_loans.data or []):
                act_cr = float(l.get("active_credit") or l.get("amount") or 0.0)
                prod_data = l.get("loan_products") or {}
                cycle = prod_data.get("repayment_cycle", "Weekly")
                cat = prod_data.get("product_category", "Finance")

                if cycle == "Daily":
                    daily_active += act_cr
                elif cycle == "Weekly":
                    weekly_active += act_cr
                elif cycle == "Monthly":
                    monthly_active += act_cr
                else:
                    weekly_active += act_cr

                # Asset loans enter as Asset Credit Sales on Left, Cash loans enter as Bank Withdrawal
                if cat == "Asset" or "asset" in str(l.get("product_type", "")).lower():
                    asset_credit_sales += act_cr
                else:
                    bank_withdrawal += act_cr
        except Exception:
            pass

        # 5. Corrected Cashbook Formulas (ICARE Business Rules)
        total_inflows = (
            opening_bal +
            savings_deposit + laps_reserve +
            rep_daily + rep_12_weeks + rep_24_weeks + rep_monthly +
            daily_11_pct + weekly_11_pct + savings_adj_amount +
            risk_premium_returns + passbook + app_fee +
            asset_credit_sales + cash_and_carry + contingency +
            credit_form + credit_form_damage + bonus + bank_withdrawal
        )
        total_outflows = (
            product_withdrawal +
            weekly_active + daily_active + monthly_active +
            office_expenses + bank_deposit + laps_returns
        )
        closing_balance = total_inflows - total_outflows

        cb_data = {
            "date": p_date_str,
            "branch_id": branch_id,
            "officer_id": officer_id,
            "opening_balance": opening_bal,
            "rep_daily": rep_daily,
            "rep_12_weeks": rep_12_weeks,
            "rep_24_weeks": rep_24_weeks,
            "rep_monthly": rep_monthly,
            "savings_deposit": savings_deposit,
            "laps_reserve": laps_reserve,
            "funds_received_ho": 0.0,
            "funds_received_other_branch": 0.0,
            "loan_received_asset": 0.0,
            "loan_received_finance": 0.0,
            "daily_11_pct": daily_11_pct,
            "weekly_11_pct": weekly_11_pct,
            "risk_premium_returns": risk_premium_returns,
            "savings_adj_no": savings_adj_no,
            "savings_adj_amount": savings_adj_amount,
            "passbook": passbook,
            "app_fee": app_fee,
            "asset_credit_sales": asset_credit_sales,
            "cash_and_carry": cash_and_carry,
            "contingency": contingency,
            "credit_form": credit_form,
            "credit_form_damage": credit_form_damage,
            "bonus": bonus,
            "misc_fees": 0.0,
            "fund_transferred_other_branch": 0.0,
            "fund_transferred_ho": 0.0,
            "fund_to_asset_program": 0.0,
            "fund_to_product_finance": 0.0,
            "savings_withdrawal": savings_withdrawal,
            "staff_salaries": 0.0,
            "office_expenses": office_expenses,
            "laps_returns": laps_returns,
            "bank_deposit": bank_deposit,
            "bank_withdrawal": bank_withdrawal,
            "product_withdrawal": product_withdrawal,
            "total_inflows": total_inflows,
            "total_outflows": total_outflows,
            "closing_balance": closing_balance,
            "status": "COMPLETED",
            "version": 1
        }

        try:
            res = uow.client.table("co_cashbooks").upsert(cb_data, on_conflict="date,branch_id,officer_id").execute()
            return cb_data
        except Exception as ex:
            print("Error upserting co_cashbook:", ex)
            return None
