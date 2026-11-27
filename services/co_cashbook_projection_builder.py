import uuid
from datetime import date, timedelta
from typing import Optional
from interfaces.unit_of_work import UnitOfWork

class CoCashbookProjectionBuilder:
    @staticmethod
    def _classify_loan_product(prod_name: str, cycle: str = "", duration: int = 0) -> str:
        """
        Deterministically classify loan products into cashbook buckets.
        Always evaluates 120-day products before 12-week products so "12" in "120" never collides.
        """
        p = (prod_name or "").lower()
        c = (cycle or "").lower()
        if "120" in p or "120d" in p or c == "120d" or duration == 120:
            return "120d"
        if "60" in p or "60d" in p or "daily" in p or c == "daily" or duration == 60:
            return "60d"
        if "24" in p or "24w" in p or "24wk" in p or c == "24w" or duration == 24:
            return "24w"
        if "month" in p or "3m" in p or "6m" in p or c == "monthly":
            return "monthly"
        return "12w"

    @staticmethod
    def _resolve_loan_bucket(uow: UnitOfWork, ev_payload: dict, loan_id: Optional[str]) -> str:
        """Resolves loan product classification bucket without dropping Completed payoff loans."""
        prod_name = str(ev_payload.get("product_type") or "").lower()
        cycle = str(ev_payload.get("repayment_cycle") or "")
        duration = int(ev_payload.get("duration") or 0)
        if not prod_name and loan_id:
            try:
                cols = "loan_id, product_id, extra_fields, loan_products(name, repayment_cycle, installments)"
                res_l = uow.client.table("loans").select(cols).eq("loan_id", loan_id).execute()
                if not res_l.data and len(str(loan_id)) == 36 and "-" in str(loan_id):
                    try:
                        res_l = uow.client.table("loans").select(cols).eq("id", loan_id).execute()
                    except Exception:
                        pass
                if not res_l.data:
                    res_l = uow.client.table("loans").select(cols) \
                        .eq("client_id", loan_id).order("created_at", desc=True).limit(1).execute()
                if res_l.data:
                    row_l = res_l.data[0]
                    lp = row_l.get("loan_products") or {}
                    prod_name = str(lp.get("name") or "").lower()
                    cycle = str(lp.get("repayment_cycle") or ("Daily" if "daily" in prod_name else ("Weekly" if "weekly" in prod_name else "Monthly")))
                    duration = int(row_l.get("duration") or lp.get("installments") or duration or 0)
            except Exception:
                pass
        return CoCashbookProjectionBuilder._classify_loan_product(prod_name, cycle, duration)

    @staticmethod
    def _is_auto_deduction_withdrawal(event_type: Optional[str], narr: str, ev_payload: dict) -> bool:
        return (
            "auto-deducted" in narr or
            "upfront" in narr or
            event_type == "AUTOMATIC_DEDUCTION" or
            ev_payload.get("classification") == "AUTOMATIC_DEDUCTION"
        )

    @staticmethod
    def classify_fee_bucket(narr_or_type: str, fee_type: str = "") -> str:
        """Deterministically maps fee metadata/narration to its canonical Cashbook inflow bucket."""
        ft_low = str(fee_type or "").strip().lower()
        if ft_low == "other" or "other" in ft_low:
            return "other"
        n = f"{ft_low} {narr_or_type or ''}".lower()
        if "passbook" in n or "pass book" in n or "pass_book" in n:
            return "passbook"
        if ("damage" in n and ("credit" in n or "form" in n)) or "damage" in ft_low:
            return "credit_form_damage"
        if "processing" in n or "application" in n or "app fee" in n or "app_fee" in n or "credit form" in n or "credit_form" in n:
            return "app_fee"
        if "contingency" in n:
            return "contingency"
        if "bonus" in n:
            return "bonus"
        if ("11%" in n or "markup_11" in n) and ("weekly" in n or "12w" in n):
            return "weekly_11_pct"
        if ("20%" in n or "markup_20" in n) and ("weekly" in n or "24w" in n or "24" in n):
            return "weekly_20_pct"
        if ("11%" in n or "markup_11" in n) and ("daily" in n or "60" in n):
            return "daily_11_pct"
        if ("20%" in n or "markup_20" in n) and ("daily" in n or "120" in n):
            return "daily_20_pct"
        if "month" in n or "3m" in n or "6m" in n or "monthly" in n or "risk" in n:
            return "risk_premium_returns"
        if "markup_20" in n:
            return "weekly_20_pct"
        if "markup_11" in n or "weekly" in n:
            return "weekly_11_pct"
        if "daily" in n:
            return "daily_11_pct"
        return "savings_deposit"

    @staticmethod
    def apply_fee_bucket(buckets: dict, bucket_name: str, delta: float) -> None:
        if bucket_name and bucket_name != "other" and bucket_name in buckets:
            buckets[bucket_name] += delta

    @staticmethod
    def rebuild_co_projection(uow: UnitOfWork, branch_id: str, officer_id: str, posting_date: date, manual_opening_balance: Optional[float] = None) -> Optional[dict]:
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
        
        existing_status = None
        try:
            res_status = uow.client.table("co_cashbooks").select("status") \
                .eq("branch_id", branch_id).eq("officer_id", officer_id).eq("date", p_date_str).execute()
            s_rows = getattr(res_status, "data", None)
            if isinstance(s_rows, list) and s_rows:
                existing_status = s_rows[0].get("status")
        except Exception:
            existing_status = None

        # 1. Opening balance from previous business day's CO Cashbook closing balance (BR-CASH-002)
        opening_bal = 0.0
        if manual_opening_balance is not None:
            opening_bal = float(manual_opening_balance)
        else:
            try:
                from services.business_date_service import BusinessDateService
                prev_work_date = BusinessDateService.get_previous_working_day(posting_date)
                prev_work_str = prev_work_date.isoformat()
                
                res_prev = uow.client.table("co_cashbooks").select("closing_balance") \
                    .eq("branch_id", branch_id).eq("officer_id", officer_id).eq("date", prev_work_str).execute()
                if res_prev.data and res_prev.data[0].get("closing_balance") is not None:
                    opening_bal = float(res_prev.data[0]["closing_balance"] or 0.0)
                else:
                    # Query the most recent operational date prior to posting_date (ordered by date desc)
                    res_recent = uow.client.table("co_cashbooks").select("date, closing_balance") \
                        .eq("branch_id", branch_id).eq("officer_id", officer_id).lt("date", p_date_str) \
                        .order("date", desc=True).limit(5).execute()
                    found = False
                    if res_recent.data:
                        for row in res_recent.data:
                            r_date_str = row.get("date")
                            if r_date_str:
                                r_d = date.fromisoformat(r_date_str)
                                is_work, _ = BusinessDateService.is_working_day(r_d)
                                if is_work and row.get("closing_balance") is not None:
                                    opening_bal = float(row["closing_balance"] or 0.0)
                                    found = True
                                    break
                    if not found:
                        # Inception / Beginning of Period: Check if current row in co_cashbooks already has an explicit opening balance
                        res_cur = uow.client.table("co_cashbooks").select("opening_balance") \
                            .eq("branch_id", branch_id).eq("officer_id", officer_id).eq("date", p_date_str).execute()
                        if res_cur.data and res_cur.data[0].get("opening_balance") is not None and float(res_cur.data[0]["opening_balance"]) != 0:
                            opening_bal = float(res_cur.data[0]["opening_balance"])
                        else:
                            opening_bal = 0.0
            except Exception:
                opening_bal = 0.0

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

        rep_daily = rep_120_days = rep_12_weeks = rep_24_weeks = rep_monthly = 0.0
        savings_deposit = laps_reserve = 0.0
        daily_11_pct = daily_20_pct = weekly_11_pct = weekly_20_pct = risk_premium_returns = 0.0
        savings_adj_no = 0
        savings_adj_amount = passbook = app_fee = 0.0
        asset_credit_sales = cash_and_carry = contingency = credit_form_damage = 0.0
        bonus = misc_fees = 0.0

        savings_withdrawal = laps_returns = bank_deposit = bank_withdrawal = product_withdrawal = 0.0
        weekly_active = weekly_24_active = daily_active_60d = daily_active_120d = monthly_active = 0.0
        finance_loan_principal = asset_loan_principal = 0.0
        office_expenses = 0.0

        processed_pwd_events = set()
        processed_bwd_events = set()
        processed_swd_events = set()
        processed_laps_ret_events = set()
        processed_disb_events = set()
        processed_exp_events = set()

        fee_buckets = {
            "passbook": 0.0,
            "credit_form_damage": 0.0,
            "app_fee": 0.0,
            "contingency": 0.0,
            "bonus": 0.0,
            "weekly_11_pct": 0.0,
            "weekly_20_pct": 0.0,
            "daily_11_pct": 0.0,
            "daily_20_pct": 0.0,
            "risk_premium_returns": 0.0,
            "savings_deposit": 0.0,
        }

        for entry in entries_list:
            acc = entry.get("account_code")
            amount = float(entry.get("amount") or 0.0)
            side = entry.get("side")
            tx = entry.get("financial_transactions") or {}
            ev_store = tx.get("event_store") or {}
            event_type = ev_store.get("event_type")
            ev_id = tx.get("event_id") or tx.get("transaction_id") or entry.get("entry_id") or str(uuid.uuid4())
            ev_payload = ev_store.get("payload") or {}
            narr = str(tx.get("narration") or ev_payload.get("narration") or "").lower()

            # Handle internal non-cash transfers for Product Withdrawal
            if event_type == "LapsTransferred" and acc == "2030" and side == "Credit":
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    laps_reserve += amount
                    processed_pwd_events.add(ev_id)
                continue

            if event_type == "LapsRestoredToSavings" and acc == "2030" and side == "Debit":
                if ev_id not in processed_laps_ret_events:
                    laps_returns += amount
                    savings_deposit += amount
                    processed_laps_ret_events.add(ev_id)
                continue

            if event_type == "LoanOffsetFromSavings" and acc in ["2000", "2010", "2020"] and side == "Debit":
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    payload = ev_store.get("payload") or {}
                    is_asset = bool(payload.get("is_asset"))
                    cycle = str(payload.get("cycle") or "Weekly")
                    prod_name = str(payload.get("loan_product") or "").lower()
                    duration = int(payload.get("duration") or 0)

                    if is_asset or "asset" in prod_name:
                        asset_credit_sales += amount
                    else:
                        bucket = CoCashbookProjectionBuilder._classify_loan_product(prod_name, cycle, duration)
                        if bucket == "24w":
                            rep_24_weeks += amount
                        elif bucket == "120d":
                            rep_120_days += amount
                        elif bucket == "60d":
                            rep_daily += amount
                        elif bucket == "monthly":
                            rep_monthly += amount
                        else:
                            rep_12_weeks += amount
                    processed_pwd_events.add(ev_id)
                continue

            if event_type == "FeeOffsetFromSavings" and ((acc in ["2000", "2010", "2020"] and side == "Debit") or (acc == "3000" and side == "Credit")):
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    fee_type_val = str(ev_payload.get("fee_type") or ev_payload.get("classification") or "")
                    prod_hint = f"{ev_payload.get('product_type') or ''} {narr}".strip()
                    b_key = CoCashbookProjectionBuilder.classify_fee_bucket(prod_hint, fee_type_val)
                    CoCashbookProjectionBuilder.apply_fee_bucket(fee_buckets, b_key, amount)
                    processed_pwd_events.add(ev_id)
                continue

            if event_type == "GapFeeOffsetFromSavings" and ((acc in ["2000", "2010", "2020"] and side == "Debit") or (acc == "1200" and side == "Credit")):
                # Upfront gap fee settles CR 1200 from savings: adds ONLY to Right product_withdrawal (never rep_*)
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    processed_pwd_events.add(ev_id)
                continue

            if event_type == "SavingsTransferred" and acc in ["2000", "2010", "2020"] and side == "Debit":
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    savings_deposit += amount
                    processed_pwd_events.add(ev_id)
                continue

            if event_type in ["LoanDisbursed", "LOAN_DISBURSED"] and side == "Credit" and acc in ("1000", "1050", "1300"):
                if ev_id not in processed_disb_events:
                    processed_disb_events.add(ev_id)
                    raw_cat = str(ev_payload.get("product_category") or "")
                    p_type = str(ev_payload.get("product_type") or "").lower()
                    p_narr = str(ev_payload.get("narration") or narr).lower()
                    is_asset = (acc == "1300") or ("asset" in raw_cat.lower() or "asset" in p_type or "asset" in p_narr)
                    act_cr = float(ev_payload.get("active_credit") or ev_payload.get("amount") or amount)
                    orig_amt = float(ev_payload.get("amount") or act_cr)
                    cycle = str(ev_payload.get("repayment_cycle") or "")
                    duration = int(ev_payload.get("duration") or 0)

                    if is_asset:
                        asset_credit_sales += orig_amt
                        asset_loan_principal += orig_amt
                    else:
                        bank_withdrawal += orig_amt
                        finance_loan_principal += orig_amt

                    bucket = CoCashbookProjectionBuilder._classify_loan_product(p_type or p_narr, cycle, duration)
                    if bucket == "120d":
                        daily_active_120d += act_cr
                    elif bucket == "60d":
                        daily_active_60d += act_cr
                    elif bucket == "24w":
                        weekly_24_active += act_cr
                    elif bucket == "monthly":
                        monthly_active += act_cr
                    else:
                        weekly_active += act_cr
                continue

            if event_type in ["SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION"] and acc in ["2000", "2010", "2020"] and side == "Debit":
                is_auto_deduction = CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr, ev_payload)
                is_bank_payout = (ev_payload.get("cash_paid") is False) or ("bank" in str(ev_payload.get("payout_method") or "").lower())
                if ev_id not in processed_pwd_events:
                    product_withdrawal += amount
                    processed_pwd_events.add(ev_id)
                if is_bank_payout and not is_auto_deduction and ev_id not in processed_bwd_events:
                    bank_withdrawal += amount
                    processed_bwd_events.add(ev_id)
                continue

            # Bank-funded Savings & LAPS payouts (CR 1050) balance Right outflow with Bank Withdrawal inflow
            if acc == "1050" and side == "Credit":
                if event_type in ["SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION"]:
                    is_auto_deduction = CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr, ev_payload)
                    if ev_id not in processed_pwd_events:
                        product_withdrawal += amount
                        processed_pwd_events.add(ev_id)
                    if not is_auto_deduction and ev_id not in processed_bwd_events:
                        bank_withdrawal += amount
                        processed_bwd_events.add(ev_id)
                elif event_type == "LapsPaidOut":
                    if ev_id not in processed_laps_ret_events:
                        laps_returns += amount
                        processed_laps_ret_events.add(ev_id)
                    if ev_id not in processed_bwd_events:
                        bank_withdrawal += amount
                        processed_bwd_events.add(ev_id)
                continue

            # Reversal of Savings / LAPS withdrawals on liability & bank legs
            if event_type in ("SavingsWithdrawalReversed", "LapsPaidOutReversed"):
                is_auto_deduction = CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr, ev_payload)
                is_bank_payout = (ev_payload.get("cash_paid") is False) or ("bank" in str(ev_payload.get("payout_method") or "").lower())
                is_laps_rev = (
                    event_type == "LapsPaidOutReversed"
                    or bool(ev_payload.get("is_laps"))
                    or acc == "2030"
                    or str(ev_payload.get("reversed_event_type") or "") == "LapsPaidOut"
                    or "laps" in str(ev_payload.get("source_bucket") or "").lower()
                )
                if acc in ["2000", "2010", "2020"] and side == "Credit":
                    if ev_id not in processed_pwd_events:
                        product_withdrawal -= amount
                        processed_pwd_events.add(ev_id)
                    if is_bank_payout and not is_auto_deduction and ev_id not in processed_bwd_events:
                        bank_withdrawal -= amount
                        processed_bwd_events.add(ev_id)
                    continue
                if acc == "2030" and side == "Credit":
                    if ev_id not in processed_laps_ret_events:
                        laps_returns -= amount
                        processed_laps_ret_events.add(ev_id)
                    if is_bank_payout and ev_id not in processed_bwd_events:
                        bank_withdrawal -= amount
                        processed_bwd_events.add(ev_id)
                    continue
                if acc == "1050" and side == "Debit":
                    if is_laps_rev:
                        if ev_id not in processed_laps_ret_events:
                            laps_returns -= amount
                            processed_laps_ret_events.add(ev_id)
                        if ev_id not in processed_bwd_events:
                            bank_withdrawal -= amount
                            processed_bwd_events.add(ev_id)
                    else:
                        if ev_id not in processed_pwd_events:
                            product_withdrawal -= amount
                            processed_pwd_events.add(ev_id)
                        if not is_auto_deduction and ev_id not in processed_bwd_events:
                            bank_withdrawal -= amount
                            processed_bwd_events.add(ev_id)
                    continue

            # Account 4000 Office Expenses (deduplicated against Vault 1000 leg)
            if acc == "4000":
                if side == "Debit" and ("ExpenseRecorded", ev_id) not in processed_exp_events:
                    office_expenses += amount
                    processed_exp_events.add(("ExpenseRecorded", ev_id))
                elif side == "Credit" and event_type == "ExpenseReversed" and ("ExpenseReversed", ev_id) not in processed_exp_events:
                    office_expenses -= amount
                    processed_exp_events.add(("ExpenseReversed", ev_id))
                continue

            if acc != "1000":
                continue

            if side == "Debit":
                # CO Inflows
                if event_type == "RepaymentReceived":
                    loan_id = ev_payload.get("loan_id") or entry.get("aggregate_id")
                    bucket = CoCashbookProjectionBuilder._resolve_loan_bucket(uow, ev_payload, loan_id)
                    if bucket == "24w":
                        rep_24_weeks += amount
                    elif bucket == "120d":
                        rep_120_days += amount
                    elif bucket == "60d":
                        rep_daily += amount
                    elif bucket == "monthly":
                        rep_monthly += amount
                    else:
                        rep_12_weeks += amount

                elif event_type in ["SavingsDeposited", "INDIVIDUAL_SAVINGS_DEPOSIT", "GROUP_SAVINGS_DEPOSIT"]:
                    agg_type = entry.get("aggregate_type") or ev_store.get("aggregate_type")
                    classification = ev_store.get("payload", {}).get("classification")
                    if agg_type == "LapsSavings":
                        laps_reserve += amount
                    elif agg_type == "MiscSavings" or classification == "MISC_FEE":
                        savings_deposit += amount
                    elif classification == "AUTOMATIC_DEDUCTION" or "gap fee" in narr:
                        # Gap fee is non-cash and does not inflate field collections
                        pass
                    else:
                        savings_deposit += amount
                        
                elif event_type in ["FeeCharged", "MARKUP", "MARKUP_11", "MARKUP_20", "CONTINGENCY", "PROCESSING_FEE", "PASSBOOK"]:
                    b_key = CoCashbookProjectionBuilder.classify_fee_bucket(narr, str(ev_payload.get("fee_type") or ""))
                    CoCashbookProjectionBuilder.apply_fee_bucket(fee_buckets, b_key, amount)

                elif event_type == "BankWithdrawn":
                    bank_withdrawal += amount
                elif event_type == "BankDepositReversed":
                    bank_deposit -= amount
                elif event_type == "ExpenseReversed":
                    if ("ExpenseReversed", ev_id) not in processed_exp_events:
                        office_expenses -= amount
                        processed_exp_events.add(("ExpenseReversed", ev_id))
                elif event_type in ("SavingsWithdrawalReversed", "LapsPaidOutReversed"):
                    is_auto_deduction = CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr, ev_payload)
                    is_laps_rev = (
                        event_type == "LapsPaidOutReversed"
                        or bool(ev_payload.get("is_laps"))
                        or str(ev_payload.get("reversed_event_type") or "") == "LapsPaidOut"
                        or "laps" in str(ev_payload.get("source_bucket") or "").lower()
                    )
                    if is_laps_rev:
                        if ev_id not in processed_laps_ret_events:
                            laps_returns -= amount
                            processed_laps_ret_events.add(ev_id)
                    elif is_auto_deduction:
                        if ev_id not in processed_pwd_events:
                            product_withdrawal -= amount
                            processed_pwd_events.add(ev_id)
                    else:
                        is_bank_payout = (ev_payload.get("cash_paid") is False) or ("bank" in str(ev_payload.get("payout_method") or "").lower())
                        if ev_id not in processed_swd_events:
                            savings_withdrawal -= amount
                            processed_swd_events.add(ev_id)
                        if ev_id not in processed_pwd_events:
                            product_withdrawal -= amount
                            processed_pwd_events.add(ev_id)
                        if is_bank_payout and ev_id not in processed_bwd_events:
                            bank_withdrawal -= amount
                            processed_bwd_events.add(ev_id)
                elif event_type == "AssetSoldCash":
                    if "credit" in narr or "credit sale" in narr:
                        asset_credit_sales += amount
                    else:
                        cash_and_carry += amount
                elif event_type == "PenaltyCharged":
                    credit_form_damage += amount

            elif side == "Credit":
                # CO Outflows / Fee Reversals
                if event_type == "FeeReversed":
                    b_key = CoCashbookProjectionBuilder.classify_fee_bucket(narr, str(ev_payload.get("fee_type") or ""))
                    CoCashbookProjectionBuilder.apply_fee_bucket(fee_buckets, b_key, -amount)
                elif event_type == "ExpenseRecorded":
                    if ("ExpenseRecorded", ev_id) not in processed_exp_events:
                        office_expenses += amount
                        processed_exp_events.add(("ExpenseRecorded", ev_id))
                elif event_type in ["SavingsReversed", "SavingsDepositReversed"]:
                    agg_type = entry.get("aggregate_type") or ev_store.get("aggregate_type")
                    if agg_type == "LapsSavings":
                        laps_reserve -= amount
                    else:
                        savings_deposit -= amount
                elif event_type == "RepaymentReversed":
                    payload = ev_store.get("payload") or {}
                    loan_id = payload.get("loan_id") or entry.get("loan_id") or ev_store.get("aggregate_id")
                    bucket = CoCashbookProjectionBuilder._resolve_loan_bucket(uow, payload, loan_id)
                    if bucket == "24w":
                        rep_24_weeks -= amount
                    elif bucket == "120d":
                        rep_120_days -= amount
                    elif bucket == "60d":
                        rep_daily -= amount
                    elif bucket == "monthly":
                        rep_monthly -= amount
                    else:
                        rep_12_weeks -= amount
                elif event_type in ["SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION"]:
                    is_auto_deduction = CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr, ev_payload)
                    is_bank_payout = (ev_payload.get("cash_paid") is False) or ("bank" in str(ev_payload.get("payout_method") or "").lower())
                    if is_auto_deduction:
                        # Non-cash upfront deduction from savings
                        if ev_id not in processed_pwd_events:
                            product_withdrawal += amount
                            processed_pwd_events.add(ev_id)
                    else:
                        # Historical Vault Cash withdrawal (CR 1000) reduces physical cash in vault
                        if ev_id not in processed_swd_events:
                            savings_withdrawal += amount
                            processed_swd_events.add(ev_id)
                        if ev_id not in processed_pwd_events:
                            product_withdrawal += amount
                            processed_pwd_events.add(ev_id)
                        if is_bank_payout and ev_id not in processed_bwd_events:
                            bank_withdrawal += amount
                            processed_bwd_events.add(ev_id)
                elif event_type == "BankDeposited":
                    bank_deposit += amount
                elif event_type == "BankWithdrawalReversed":
                    bank_withdrawal -= amount
                elif event_type in ["LapsPaidOut", "LapsRestoredToSavings"]:
                    if ev_id not in processed_laps_ret_events:
                        laps_returns += amount
                        processed_laps_ret_events.add(ev_id)

        passbook += fee_buckets["passbook"]
        credit_form_damage += fee_buckets["credit_form_damage"]
        app_fee += fee_buckets["app_fee"]
        contingency += fee_buckets["contingency"]
        bonus += fee_buckets["bonus"]
        weekly_11_pct += fee_buckets["weekly_11_pct"]
        weekly_20_pct += fee_buckets["weekly_20_pct"]
        daily_11_pct += fee_buckets["daily_11_pct"]
        daily_20_pct += fee_buckets["daily_20_pct"]
        risk_premium_returns += fee_buckets["risk_premium_returns"]
        savings_deposit += fee_buckets["savings_deposit"]

        # 5. Corrected Cashbook Formulas (ICARE Business Rules)
        daily_active = daily_active_60d + daily_active_120d
        total_inflows = (
            opening_bal +
            savings_deposit + laps_reserve +
            rep_daily + rep_120_days + rep_12_weeks + rep_24_weeks + rep_monthly +
            daily_11_pct + daily_20_pct + weekly_11_pct + weekly_20_pct + savings_adj_amount +
            risk_premium_returns + passbook + app_fee + misc_fees +
            asset_credit_sales + cash_and_carry + contingency +
            credit_form_damage + bonus + bank_withdrawal
        )
        total_outflows = (
            product_withdrawal +
            weekly_active + weekly_24_active + daily_active + monthly_active +
            office_expenses + bank_deposit + laps_returns
        )
        closing_balance = total_inflows - total_outflows

        full_cb_data = {
            "date": p_date_str,
            "branch_id": branch_id,
            "officer_id": officer_id,
            "opening_balance": opening_bal,
            "rep_daily": rep_daily,
            "rep_120_days": rep_120_days,
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
            "daily_20_pct": daily_20_pct,
            "weekly_11_pct": weekly_11_pct,
            "weekly_20_pct": weekly_20_pct,
            "risk_premium_returns": risk_premium_returns,
            "savings_adj_no": savings_adj_no,
            "savings_adj_amount": savings_adj_amount,
            "passbook": passbook,
            "app_fee": app_fee,
            "asset_credit_sales": asset_credit_sales,
            "cash_and_carry": cash_and_carry,
            "contingency": contingency,
            "credit_form": 0.0,
            "credit_form_damage": credit_form_damage,
            "bonus": bonus,
            "misc_fees": misc_fees,
            "fund_transferred_other_branch": 0.0,
            "fund_transferred_ho": 0.0,
            "fund_to_asset_program": 0.0,
            "fund_to_product_finance": finance_loan_principal,
            "disb_60d": daily_active_60d,
            "disb_120d": daily_active_120d,
            "disb_12w": weekly_active,
            "disb_24w": weekly_24_active,
            "disb_mth": monthly_active,
            "active_loan_daily": daily_active_60d,
            "active_loan_120d": daily_active_120d,
            "active_loan_12w": weekly_active,
            "active_loan_24w": weekly_24_active,
            "active_loan_monthly": monthly_active,
            "_finance_loan_principal": finance_loan_principal,
            "_asset_loan_principal": asset_loan_principal,
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
            "status": (existing_status if str(existing_status or "").strip().lower() in {"closed", "verified"} else "COMPLETED"),
            "version": 1
        }

        db_payload = {
            k: v for k, v in full_cb_data.items()
            if not k.startswith("_") and not k.startswith("active_loan_")
        }

        for _ in range(8):
            try:
                uow.client.table("co_cashbooks").upsert(db_payload, on_conflict="date,branch_id,officer_id").execute()
                return full_cb_data
            except Exception as ex:
                msg = str(ex)
                if "PGRST204" in msg or "Could not find the '" in msg:
                    import re
                    m = re.search(r"Could not find the '([^']+)' column", msg)
                    if m and m.group(1) in db_payload:
                        del db_payload[m.group(1)]
                        continue
                print("Error upserting co_cashbook:", ex)
                return full_cb_data
        return full_cb_data
