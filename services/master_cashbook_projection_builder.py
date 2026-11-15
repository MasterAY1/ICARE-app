from datetime import date, timedelta
from typing import Optional
from interfaces.unit_of_work import UnitOfWork

class MasterCashbookProjectionBuilder:
    @staticmethod
    def rebuild_master_projection(uow: UnitOfWork, branch_id: str, posting_date: date) -> Optional[dict]:
        """
        Rebuilds the Master Cashbook projection row by aggregating all co_cashbooks for the branch,
        plus fetching branch-level treasury activities (HO transfers, inter-branch transfers, staff salaries,
        office expenses, and loan disbursement pools).
        """
        if isinstance(posting_date, str):
            posting_date = date.fromisoformat(posting_date)
            
        if not branch_id:
            return None

        p_date_str = posting_date.isoformat()
        # 1. Rebuild & fetch all co_cashbooks for this branch on date first
        co_rows = []
        rebuilt_co_map = {}
        try:
            res_cos = uow.client.table("app_users").select("id, role, username") \
                .eq("branch_id", branch_id).execute()
            co_user_ids = [
                str(u["id"]) for u in (res_cos.data or [])
                if isinstance(u, dict) and u.get("id") and (
                    "co" in str(u.get("role") or "").lower()
                    or "credit" in str(u.get("role") or "").lower()
                    or str(u.get("username") or "").lower().startswith("co")
                )
            ]
            if co_user_ids:
                from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
                for oid in co_user_ids:
                    try:
                        rb = CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, oid, posting_date)
                        if isinstance(rb, dict):
                            rebuilt_co_map[oid] = rb
                    except Exception:
                        pass
        except Exception:
            pass

        try:
            res_co = uow.client.table("co_cashbooks").select("*") \
                .eq("branch_id", branch_id).eq("date", p_date_str).execute()
            db_co_rows = res_co.data or []
            if rebuilt_co_map:
                merged_map = {}
                for r in db_co_rows:
                    if isinstance(r, dict) and r.get("officer_id"):
                        merged_map[str(r["officer_id"])] = r
                merged_map.update(rebuilt_co_map)
                co_rows = list(merged_map.values())
            else:
                co_rows = db_co_rows
        except Exception:
            if rebuilt_co_map:
                co_rows = list(rebuilt_co_map.values())

        # 2. Previous day opening balance resolution
        opening_bal = 0.0
        try:
            sum_co_open = sum(float(r.get("opening_balance") or 0.0) for r in co_rows) if co_rows else 0.0
            from services.business_date_service import BusinessDateService
            prev_work_date = BusinessDateService.get_previous_working_day(posting_date)
            prev_work_str = prev_work_date.isoformat()
            
            res_prev = uow.client.table("master_cashbook").select("closing_balance") \
                .eq("branch_id", branch_id).eq("date", prev_work_str).execute()
            if res_prev.data and res_prev.data[0].get("closing_balance") is not None:
                prev_close = float(res_prev.data[0]["closing_balance"] or 0.0)
                opening_bal = prev_close if prev_close >= 0 else sum_co_open
            else:
                # Query most recent preceding working day
                res_recent = uow.client.table("master_cashbook").select("date, closing_balance") \
                    .eq("branch_id", branch_id).lt("date", p_date_str) \
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
                    opening_bal = sum_co_open
        except Exception:
            pass

        # 3. Aggregate operational fields across COs
        numeric_fields = [
            "rep_daily", "rep_120_days", "rep_12_weeks", "rep_24_weeks", "rep_monthly",
            "savings_deposit", "laps_reserve", "loan_received_asset", "loan_received_finance",
            "daily_11_pct", "daily_20_pct", "weekly_11_pct", "weekly_20_pct", "savings_adj_amount", "risk_premium_returns",
            "passbook", "app_fee", "asset_credit_sales", "cash_and_carry", "contingency",
            "credit_form", "credit_form_damage", "bonus", "misc_fees",
            "funds_received_ho", "funds_received_other_branch", "funds_received_other_area",
            "fund_transferred_other_branch", "fund_transferred_ho", "fund_to_other_area",
            "fund_to_asset_program", "fund_to_product_finance", "savings_withdrawal",
            "staff_salaries", "office_expenses", "laps_returns", "bank_deposit",
            "product_withdrawal",
            "disb_60d", "disb_120d", "disb_12w", "disb_24w", "disb_mth"
        ]

        totals = {field: 0.0 for field in numeric_fields}
        totals["bank_withdrawal"] = 0.0
        co_bank_wd = 0.0
        co_asset_credit_total = 0.0
        co_asset_loan_explicit = 0.0
        has_explicit_asset_loan = False
        co_finance_principal_total = 0.0
        has_explicit_finance_principal = False

        for row in co_rows:
            for field in numeric_fields:
                totals[field] += float(row.get(field) or 0.0)
            co_bank_wd += float(row.get("bank_withdrawal") or 0.0)
            co_asset_credit_total += float(row.get("asset_credit_sales") or 0.0)
            if "_asset_loan_principal" in row:
                has_explicit_asset_loan = True
                co_asset_loan_explicit += float(row.get("_asset_loan_principal") or 0.0)
            if "_finance_loan_principal" in row:
                has_explicit_finance_principal = True
                co_finance_principal_total += float(row.get("_finance_loan_principal") or 0.0)

        totals["bank_withdrawal"] = co_bank_wd
        if totals.get("misc_fees", 0.0) != 0.0:
            totals["savings_deposit"] = totals.get("savings_deposit", 0.0) + totals["misc_fees"]
            totals["misc_fees"] = 0.0

        # 4. Fetch Branch Treasury Activities from Ledger
        from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
        branch_treasury_finance = 0.0
        branch_treasury_asset = 0.0
        co_non_loan_asset_credit = 0.0
        try:
            res_ledger = uow.client.table("financial_ledger_entries") \
                .select("*, financial_transactions!inner(officer_id, event_store(event_type, payload))") \
                .eq("branch_id", branch_id) \
                .eq("account_code", "1000") \
                .eq("financial_transactions.posting_date", p_date_str) \
                .execute()
            
            co_officer_ids = set(str(r.get("officer_id")) for r in co_rows if r.get("officer_id"))

            def _apply_fee_to_totals(narr_text: str, delta: float) -> None:
                n = (narr_text or "").lower()
                if "passbook" in n or "pass book" in n or "pass_book" in n:
                    totals["passbook"] += delta
                elif "damage" in n and ("credit" in n or "form" in n):
                    totals["credit_form_damage"] += delta
                elif "processing" in n or "application" in n or "app fee" in n or "app_fee" in n or "credit form" in n or "credit_form" in n:
                    totals["app_fee"] += delta
                elif "contingency" in n:
                    totals["contingency"] += delta
                elif "bonus" in n:
                    totals["bonus"] += delta
                elif "11%" in n and ("weekly" in n or "12w" in n):
                    totals["weekly_11_pct"] += delta
                elif "20%" in n and ("weekly" in n or "24w" in n or "24" in n):
                    totals["weekly_20_pct"] += delta
                elif "11%" in n and ("daily" in n or "60" in n):
                    totals["daily_11_pct"] += delta
                elif "20%" in n and ("daily" in n or "120" in n):
                    totals["daily_20_pct"] += delta
                elif "month" in n or "3m" in n or "6m" in n or "monthly" in n or "risk" in n:
                    totals["risk_premium_returns"] += delta
                elif "weekly" in n:
                    totals["weekly_11_pct"] += delta
                elif "daily" in n:
                    totals["daily_11_pct"] += delta
                else:
                    totals["savings_deposit"] += delta

            def _apply_repayment_to_totals(ev_p: dict, delta: float) -> None:
                p_name = str(ev_p.get("product_type") or ev_p.get("narration") or "").lower()
                cyc = str(ev_p.get("repayment_cycle") or "")
                dur = int(ev_p.get("duration") or 0)
                bucket = CoCashbookProjectionBuilder._classify_loan_product(p_name, cyc, dur)
                if bucket == "120d":
                    totals["rep_120_days"] += delta
                elif bucket == "60d":
                    totals["rep_daily"] += delta
                elif bucket == "24w":
                    totals["rep_24_weeks"] += delta
                elif bucket == "monthly":
                    totals["rep_monthly"] += delta
                else:
                    totals["rep_12_weeks"] += delta

            for entry in (res_ledger.data or []):
                amt = float(entry.get("amount") or 0.0)
                side = entry.get("side")
                tx = entry.get("financial_transactions") or {}
                ev_store = tx.get("event_store") or {}
                event_type = ev_store.get("event_type")
                payload = ev_store.get("payload") or {}
                tx_officer_id = str(tx.get("officer_id") or "")
                narr_l = str(payload.get("narration") or entry.get("narration") or "").lower()
                
                # Branch Inflows (Debit 1000)
                if side == "Debit":
                    if event_type == "CashTransferred_HO_In":
                        tx_type = payload.get("transaction_type")
                        if tx_type == "INTER_BRANCH_IN":
                            totals["funds_received_other_branch"] += amt
                        elif tx_type == "INTER_AREA_IN":
                            totals["funds_received_other_area"] += amt
                        else:
                            totals["funds_received_ho"] += amt
                    elif event_type == "CashTransferred_HO_Out_Reversed":
                        tx_type = payload.get("transaction_type")
                        if tx_type == "INTER_BRANCH_OUT":
                            totals["fund_transferred_other_branch"] -= amt
                        elif tx_type == "INTER_AREA_OUT":
                            totals["fund_to_other_area"] -= amt
                        elif tx_type == "ASSET_PROGRAM":
                            totals["fund_to_asset_program"] -= amt
                        else:
                            totals["fund_transferred_ho"] -= amt
                    elif event_type == "BankWithdrawn":
                        if tx_officer_id not in co_officer_ids:
                            totals["bank_withdrawal"] += amt
                    elif event_type == "BankDepositReversed":
                        if tx_officer_id not in co_officer_ids:
                            totals["bank_deposit"] -= amt
                    elif event_type == "ExpenseReversed":
                        if tx_officer_id not in co_officer_ids:
                            totals["office_expenses"] -= amt
                    elif event_type == "SalaryReversed":
                        totals["staff_salaries"] -= amt
                    elif event_type in ["SavingsDeposited", "INDIVIDUAL_SAVINGS", "GROUP_SAVINGS", "SavingsDeposit", "SAVINGS_DEPOSIT"]:
                        if tx_officer_id not in co_officer_ids:
                            agg_type = entry.get("aggregate_type") or ev_store.get("aggregate_type")
                            if agg_type == "LapsSavings":
                                totals["laps_reserve"] += amt
                            else:
                                totals["savings_deposit"] += amt
                    elif event_type in ["RepaymentReceived", "REPAYMENT"]:
                        if tx_officer_id not in co_officer_ids:
                            _apply_repayment_to_totals(payload, amt)
                    elif event_type in ["FeeCharged", "MARKUP", "MARKUP_11", "MARKUP_20", "CONTINGENCY", "PROCESSING_FEE", "PASSBOOK", "PenaltyCharged"]:
                        if tx_officer_id not in co_officer_ids:
                            _apply_fee_to_totals(narr_l, amt)
                    elif event_type == "AssetSoldCash":
                        if tx_officer_id not in co_officer_ids:
                            if "credit" in narr_l:
                                totals["asset_credit_sales"] += amt
                            else:
                                totals["cash_and_carry"] += amt
                        elif "credit" in narr_l:
                            co_non_loan_asset_credit += amt
                    elif event_type == "SavingsWithdrawalReversed":
                        if tx_officer_id not in co_officer_ids:
                            is_laps_rev = (
                                bool(payload.get("is_laps"))
                                or str(payload.get("reversed_event_type") or "") == "LapsPaidOut"
                                or "laps" in str(payload.get("source_bucket") or "").lower()
                            )
                            is_auto_rev = CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr_l, payload)
                            is_bank_rev = (payload.get("cash_paid") is False) or ("bank" in str(payload.get("payout_method") or "").lower())
                            if is_laps_rev:
                                totals["laps_returns"] -= amt
                            elif is_auto_rev:
                                totals["product_withdrawal"] -= amt
                            else:
                                totals["product_withdrawal"] -= amt
                                totals["savings_withdrawal"] -= amt
                                if is_bank_rev:
                                    totals["bank_withdrawal"] -= amt
                            
                # Branch Outflows (Credit 1000)
                elif side == "Credit":
                    if event_type == "CashTransferred_HO_Out":
                        tx_type = payload.get("transaction_type")
                        if tx_type == "INTER_BRANCH_OUT":
                            totals["fund_transferred_other_branch"] += amt
                        elif tx_type == "INTER_AREA_OUT":
                            totals["fund_to_other_area"] += amt
                        elif tx_type == "ASSET_PROGRAM":
                            totals["fund_to_asset_program"] += amt
                        else:
                            totals["fund_transferred_ho"] += amt
                    elif event_type == "CashTransferred_HO_In_Reversed":
                        tx_type = payload.get("transaction_type")
                        if tx_type == "INTER_BRANCH_IN":
                            totals["funds_received_other_branch"] -= amt
                        elif tx_type == "INTER_AREA_IN":
                            totals["funds_received_other_area"] -= amt
                        else:
                            totals["funds_received_ho"] -= amt
                    elif event_type == "ExpenseRecorded":
                        if tx_officer_id not in co_officer_ids:
                            totals["office_expenses"] += amt
                    elif event_type == "SalaryPaid":
                        totals["staff_salaries"] += amt
                    elif event_type in ["LoanDisbursed", "LOAN_DISBURSED"]:
                        if tx_officer_id not in co_officer_ids:
                            cat = str(payload.get("product_category") or "")
                            p_type = str(payload.get("product_type") or "").lower()
                            cyc = str(payload.get("repayment_cycle") or "")
                            dur = int(payload.get("duration") or 0)
                            princ = float(payload.get("amount") or amt)
                            act_cr = float(payload.get("active_credit") or princ)
                            if "asset" in cat.lower() or "asset" in p_type or "asset" in narr_l:
                                totals["loan_received_asset"] += princ
                                branch_treasury_asset += princ
                            else:
                                totals["fund_to_product_finance"] += princ
                                branch_treasury_finance += princ
                            bucket = CoCashbookProjectionBuilder._classify_loan_product(p_type or narr_l, cyc, dur)
                            if bucket == "120d":
                                totals["disb_120d"] += act_cr
                            elif bucket == "60d":
                                totals["disb_60d"] += act_cr
                            elif bucket == "24w":
                                totals["disb_24w"] += act_cr
                            elif bucket == "monthly":
                                totals["disb_mth"] += act_cr
                            else:
                                totals["disb_12w"] += act_cr
                    elif event_type == "BankDeposited":
                        if tx_officer_id not in co_officer_ids:
                            totals["bank_deposit"] += amt
                    elif event_type == "BankWithdrawalReversed":
                        if tx_officer_id not in co_officer_ids:
                            totals["bank_withdrawal"] -= amt
                    elif event_type in ["SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION"]:
                        if tx_officer_id not in co_officer_ids:
                            is_bank_p = (payload.get("cash_paid") is False) or ("bank" in str(payload.get("payout_method") or "").lower())
                            if not CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr_l, payload):
                                totals["product_withdrawal"] += amt
                                totals["savings_withdrawal"] += amt
                                if is_bank_p:
                                    totals["bank_withdrawal"] += amt
                    elif event_type in ["LapsPaidOut", "LapsRestoredToSavings"]:
                        if tx_officer_id not in co_officer_ids:
                            totals["laps_returns"] += amt
                    elif event_type == "FeeReversed":
                        if tx_officer_id not in co_officer_ids:
                            _apply_fee_to_totals(narr_l, -amt)
                    elif event_type in ["SavingsReversed", "SavingsDepositReversed"]:
                        if tx_officer_id not in co_officer_ids:
                            agg_type = entry.get("aggregate_type") or ev_store.get("aggregate_type")
                            if agg_type == "LapsSavings":
                                totals["laps_reserve"] -= amt
                            else:
                                totals["savings_deposit"] -= amt
                    elif event_type == "RepaymentReversed":
                        if tx_officer_id not in co_officer_ids:
                            _apply_repayment_to_totals(payload, -amt)

            # 4b. Non-CO Bank-paid Savings / LAPS withdrawals & reversals (Account 1050)
            res_1050 = uow.client.table("financial_ledger_entries") \
                .select("*, financial_transactions!inner(officer_id, event_store(event_type, payload))") \
                .eq("branch_id", branch_id) \
                .eq("account_code", "1050") \
                .eq("financial_transactions.posting_date", p_date_str) \
                .execute()
            for entry in (res_1050.data or []):
                if entry.get("account_code") != "1050":
                    continue
                amt = float(entry.get("amount") or 0.0)
                side = entry.get("side")
                tx = entry.get("financial_transactions") or {}
                ev_store = tx.get("event_store") or {}
                event_type = ev_store.get("event_type")
                payload = ev_store.get("payload") or {}
                tx_officer_id = str(tx.get("officer_id") or "")
                if tx_officer_id in co_officer_ids:
                    continue
                narr_l = str(payload.get("narration") or entry.get("narration") or "").lower()
                is_auto = CoCashbookProjectionBuilder._is_auto_deduction_withdrawal(event_type, narr_l, payload)
                if side == "Credit":
                    if event_type in ["SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION"] and not is_auto:
                        totals["product_withdrawal"] += amt
                        totals["bank_withdrawal"] += amt
                    elif event_type == "LapsPaidOut":
                        totals["laps_returns"] += amt
                        totals["bank_withdrawal"] += amt
                elif side == "Debit" and event_type == "SavingsWithdrawalReversed":
                    is_laps_rev = (
                        bool(payload.get("is_laps"))
                        or str(payload.get("reversed_event_type") or "") == "LapsPaidOut"
                        or "laps" in str(payload.get("source_bucket") or "").lower()
                    )
                    if is_laps_rev:
                        totals["laps_returns"] -= amt
                        totals["bank_withdrawal"] -= amt
                    elif is_auto:
                        totals["product_withdrawal"] -= amt
                    else:
                        totals["product_withdrawal"] -= amt
                        totals["bank_withdrawal"] -= amt
        except Exception as e:
            print(f"[SAVINGS TRACE] Master Cashbook failed to fetch branch ledger entries: {e}")

        # 5. Fallback: If no direct loans aggregated from CO rows AND no branch treasury loans, fetch from loans table
        if branch_treasury_finance == 0.0 and branch_treasury_asset == 0.0 and totals["fund_to_product_finance"] == 0.0 and not co_rows:
            try:
                res_loans = uow.client.table("loans") \
                    .select("loan_amount, active_credit, product_category, extra_fields, loan_products(name, repayment_cycle, installments)") \
                    .eq("branch_id", branch_id) \
                    .eq("disbursement_date", p_date_str) \
                    .in_("status", ["Active", "Approved", "Completed"]) \
                    .execute()
                
                import json
                for l in (res_loans.data or []):
                    extra = l.get("extra_fields")
                    if isinstance(extra, str):
                        try:
                            extra = json.loads(extra)
                        except Exception:
                            extra = {}
                    if isinstance(extra, dict) and extra.get("is_legacy") is True:
                        continue
                    princ = float(l.get("loan_amount") or 0.0)
                    act_cr = float(l.get("active_credit") or princ)
                    lp = l.get("loan_products") or {}
                    p_name = str(lp.get("name") or l.get("product_type") or "").lower()
                    p_cat = str(l.get("product_category") or ("Asset" if "asset" in p_name else "Finance"))
                    
                    if "Asset" in p_cat or "asset" in p_name:
                        totals["loan_received_asset"] += princ
                        branch_treasury_asset += princ
                    else:
                        totals["fund_to_product_finance"] += princ
                        branch_treasury_finance += princ
                        
                    cycle = lp.get("repayment_cycle") or l.get("repayment_cycle") or ("Daily" if "daily" in p_name else "Weekly")
                    dur = int(l.get("duration") or 0)
                    bucket = CoCashbookProjectionBuilder._classify_loan_product(p_name, cycle, dur)
                    if bucket == "120d":
                        totals["disb_120d"] = totals.get("disb_120d", 0.0) + act_cr
                    elif bucket == "60d":
                        totals["disb_60d"] = totals.get("disb_60d", 0.0) + act_cr
                    elif bucket == "24w":
                        totals["disb_24w"] = totals.get("disb_24w", 0.0) + act_cr
                    elif bucket == "monthly":
                        totals["disb_mth"] = totals.get("disb_mth", 0.0) + act_cr
                    else:
                        totals["disb_12w"] = totals.get("disb_12w", 0.0) + act_cr
                
            except Exception as e:
                print(f"Master Cashbook failed to fetch direct loan disbursements: {e}")

        # Roll CO Asset Loan principal out of asset_credit_sales into loan_received_asset (no double-counting)
        if has_explicit_asset_loan:
            co_asset_loan_amt = co_asset_loan_explicit
        else:
            co_asset_loan_amt = max(0.0, co_asset_credit_total - co_non_loan_asset_credit)
        if co_asset_loan_amt > 0:
            totals["asset_credit_sales"] = max(0.0, totals.get("asset_credit_sales", 0.0) - co_asset_loan_amt)
            totals["loan_received_asset"] = totals.get("loan_received_asset", 0.0) + co_asset_loan_amt

        # Prefer true Finance Principal when explicit _finance_loan_principal metadata is present on CO rows
        if has_explicit_finance_principal and co_finance_principal_total > 0:
            totals["fund_to_product_finance"] = co_finance_principal_total + branch_treasury_finance

        # Balance loan_received_finance with fund_to_product_finance (Finance Principal symmetry)
        if totals.get("fund_to_product_finance", 0.0) > 0:
            totals["loan_received_finance"] = totals["fund_to_product_finance"]
        elif branch_treasury_finance > 0 and totals.get("loan_received_finance", 0.0) == 0.0:
            totals["loan_received_finance"] = branch_treasury_finance

        # Ensure misc_fees is always unified into savings_deposit
        if totals.get("misc_fees", 0.0) != 0.0:
            totals["savings_deposit"] = totals.get("savings_deposit", 0.0) + totals["misc_fees"]
        totals["misc_fees"] = 0.0

        # Corrected Master Cashbook Formulas (ICARE Business Rules)
        total_inflows = (
            opening_bal +
            totals["rep_daily"] + totals.get("rep_120_days", 0.0) + totals["rep_12_weeks"] + totals["rep_24_weeks"] + totals["rep_monthly"] +
            totals["savings_deposit"] + totals["laps_reserve"] + totals["bank_withdrawal"] +
            totals["funds_received_ho"] + totals["funds_received_other_branch"] + totals["funds_received_other_area"] +
            totals["loan_received_asset"] + totals["loan_received_finance"] +
            totals["daily_11_pct"] + totals["daily_20_pct"] + totals["weekly_11_pct"] + totals["weekly_20_pct"] + totals["savings_adj_amount"] +
            totals["risk_premium_returns"] + totals["passbook"] + totals["app_fee"] +
            totals["asset_credit_sales"] + totals["cash_and_carry"] + totals["contingency"] +
            totals["credit_form"] + totals["credit_form_damage"] + totals["bonus"]
        )

        prod_wd = max(totals["product_withdrawal"], totals["savings_withdrawal"])
        totals["product_withdrawal"] = prod_wd

        total_outflows = (
            totals["product_withdrawal"] +
            totals.get("disb_60d", 0.0) + totals.get("disb_120d", 0.0) +
            totals.get("disb_12w", 0.0) + totals.get("disb_24w", 0.0) + totals.get("disb_mth", 0.0) +
            totals["bank_deposit"] + totals["laps_returns"] +
            totals["fund_to_asset_program"] + totals["fund_to_product_finance"] +
            totals["fund_transferred_other_branch"] + totals["fund_transferred_ho"] + totals["fund_to_other_area"] +
            totals["staff_salaries"] + totals["office_expenses"]
        )

        # 6. Preserve Manual Treasury Adjustments & Verification Status
        adj_in = 0.0
        adj_out = 0.0
        adj_reason = None
        verified_by = None
        verified_at = None
        existing_status = "Open"
        
        try:
            res_curr = uow.client.table("master_cashbook").select("adjustment_in, adjustment_out, adjustment_reason, verified_by, verified_at, status") \
                .eq("branch_id", branch_id).eq("date", p_date_str).execute()
            if res_curr.data:
                curr_row = res_curr.data[0]
                adj_in = float(curr_row.get("adjustment_in") or 0.0)
                adj_out = float(curr_row.get("adjustment_out") or 0.0)
                adj_reason = curr_row.get("adjustment_reason")
                verified_by = curr_row.get("verified_by")
                verified_at = curr_row.get("verified_at")
                existing_status = curr_row.get("status") or "Open"
        except Exception:
            pass

        total_inflows += adj_in
        total_outflows += adj_out
        closing_balance = total_inflows - total_outflows

        mb_data = {
            "date": p_date_str,
            "branch_id": branch_id,
            "opening_balance": opening_bal,
            "total_inflows": total_inflows,
            "total_outflows": total_outflows,
            "closing_balance": closing_balance,
            "adjustment_in": adj_in,
            "adjustment_out": adj_out,
            "adjustment_reason": adj_reason,
            "verified_by": verified_by,
            "verified_at": verified_at,
            "status": existing_status,
            "version": 1
        }
        mb_data.update(totals)

        db_payload = {k: v for k, v in mb_data.items() if not k.startswith("_")}
        for _ in range(10):
            try:
                uow.client.table("master_cashbook").upsert(db_payload, on_conflict="date,branch_id").execute()
                return mb_data
            except Exception as ex:
                msg = str(ex)
                if "PGRST204" in msg or "Could not find the '" in msg:
                    import re
                    m = re.search(r"Could not find the '([^']+)' column", msg)
                    if m and m.group(1) in db_payload:
                        del db_payload[m.group(1)]
                        continue
                print("Error upserting master_cashbook:", ex)
                return mb_data
        return mb_data
