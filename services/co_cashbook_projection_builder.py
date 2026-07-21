from datetime import date, timedelta
from typing import Optional
from interfaces.unit_of_work import UnitOfWork

class CoCashbookProjectionBuilder:
    @staticmethod
    def rebuild_co_projection(uow: UnitOfWork, branch_id: str, officer_id: str, posting_date: date) -> Optional[dict]:
        """
        Rebuilds the officer-level daily cashbook projection row in co_cashbooks.
        """
        if isinstance(posting_date, str):
            posting_date = date.fromisoformat(posting_date)
            
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

        # 2. Fetch ledger entries for this branch & officer on posting_date
        try:
            res_entries = uow.client.table("financial_ledger_entries") \
                .select("*, financial_transactions!inner(event_id, posting_date, narration, reference, officer_id, event_store(event_type))") \
                .eq("branch_id", branch_id) \
                .eq("financial_transactions.officer_id", officer_id) \
                .eq("financial_transactions.posting_date", p_date_str) \
                .execute()
            entries_list = res_entries.data or []
        except Exception:
            entries_list = []

        rep_daily = rep_12_weeks = rep_24_weeks = rep_monthly = 0.0
        savings_deposit = laps_reserve = 0.0
        funds_received_ho = funds_received_other_branch = 0.0
        loan_received_asset = loan_received_finance = 0.0
        daily_11_pct = weekly_11_pct = 0.0
        savings_adj_no = 0
        savings_adj_amount = risk_premium_returns = passbook = app_fee = 0.0
        asset_credit_sales = cash_and_carry = contingency = credit_form = credit_form_damage = 0.0
        bonus = misc_fees = 0.0

        fund_transferred_other_branch = fund_transferred_ho = fund_to_other_area = 0.0
        fund_to_asset_program = fund_to_product_finance = savings_withdrawal = 0.0
        staff_salaries = office_expenses = laps_returns = bank_deposit = bank_withdrawal = product_withdrawal = 0.0

        for entry in entries_list:
            acc = entry.get("account_code")
            if acc != "1000": # Only track cash account flow
                continue

            amount = float(entry.get("amount") or 0.0)
            side = entry.get("side")
            tx = entry.get("financial_transactions") or {}
            ev_store = tx.get("event_store") or {}
            event_type = ev_store.get("event_type")
            narr = str(tx.get("narration") or "").lower()

            if side == "Debit":
                # Inflows
                if event_type == "RepaymentReceived":
                    cycle = "Daily"
                    try:
                        res_l = uow.client.table("loans").select("loan_products(repayment_cycle)").eq("loan_id", entry.get("aggregate_id")).execute()
                        if res_l.data:
                            cycle = res_l.data[0].get("loan_products", {}).get("repayment_cycle", "Daily")
                    except Exception:
                        pass

                    if cycle == "Daily": rep_daily += amount
                    elif cycle == "Weekly":
                        duration = 12
                        try:
                            res_l2 = uow.client.table("loans").select("loan_products(name)").eq("loan_id", entry.get("aggregate_id")).execute()
                            if res_l2.data:
                                name = str(res_l2.data[0].get("loan_products", {}).get("name", "")).lower()
                                if "24" in name: duration = 24
                        except Exception:
                            pass
                        if duration == 12: rep_12_weeks += amount
                        else: rep_24_weeks += amount
                    elif cycle == "Monthly": rep_monthly += amount
                    else: rep_daily += amount

                elif event_type in ["SavingsDeposited", "INDIVIDUAL_SAVINGS_DEPOSIT", "GROUP_SAVINGS_DEPOSIT"]:
                    if entry.get("aggregate_type") == "LapsSavings": laps_reserve += amount
                    else: savings_deposit += amount
                elif event_type in ["FeeCharged", "MARKUP", "CONTINGENCY", "PROCESSING_FEE", "PASSBOOK"]:
                    if "passbook" in narr or "pass book" in narr: passbook += amount
                    elif "processing" in narr or "application" in narr: app_fee += amount
                    elif "contingency" in narr: contingency += amount
                    elif "daily" in narr: daily_11_pct += amount
                    elif "weekly" in narr: weekly_11_pct += amount
                    elif "monthly" in narr or "risk premium" in narr or "markup" in narr: risk_premium_returns += amount
                    else: misc_fees += amount
                elif event_type == "CashTransferred_HO_In": funds_received_ho += amount
                elif event_type == "BankWithdrawn": bank_withdrawal += amount
                elif event_type == "AssetSoldCash": cash_and_carry += amount
                elif event_type == "PenaltyCharged": misc_fees += amount

            elif side == "Credit":
                # Outflows
                if event_type == "LoanDisbursed":
                    category = "Finance"
                    try:
                        res_l3 = uow.client.table("loans").select("product_category").eq("loan_id", entry.get("aggregate_id")).execute()
                        if res_l3.data: category = res_l3.data[0].get("product_category", "Finance")
                    except Exception:
                        pass
                    if category == "Asset": fund_to_asset_program += amount
                    else: fund_to_product_finance += amount

                elif event_type in ["SavingsWithdrawn", "INDIVIDUAL_SAVINGS_WITHDRAWAL", "AUTOMATIC_DEDUCTION"]:
                    savings_withdrawal += amount
                    product_withdrawal += amount
                elif event_type == "ExpenseRecorded": office_expenses += amount
                elif event_type == "SalaryPaid": staff_salaries += amount
                elif event_type == "BankDeposited": bank_deposit += amount
                elif event_type == "CashTransferred_HO_Out": fund_transferred_ho += amount

        total_inflows = rep_daily + rep_12_weeks + rep_24_weeks + rep_monthly + savings_deposit + laps_reserve + funds_received_ho + funds_received_other_branch + loan_received_asset + loan_received_finance + daily_11_pct + weekly_11_pct + savings_adj_amount + risk_premium_returns + passbook + app_fee + asset_credit_sales + cash_and_carry + contingency + credit_form + credit_form_damage + bonus + misc_fees
        total_outflows = fund_transferred_other_branch + fund_transferred_ho + fund_to_other_area + fund_to_asset_program + fund_to_product_finance + savings_withdrawal + staff_salaries + office_expenses + laps_returns + bank_deposit + bank_withdrawal + product_withdrawal
        closing_balance = opening_bal + total_inflows - total_outflows

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
            "funds_received_ho": funds_received_ho,
            "funds_received_other_branch": funds_received_other_branch,
            "loan_received_asset": loan_received_asset,
            "loan_received_finance": loan_received_finance,
            "daily_11_pct": daily_11_pct,
            "weekly_11_pct": weekly_11_pct,
            "savings_adj_no": savings_adj_no,
            "savings_adj_amount": savings_adj_amount,
            "risk_premium_returns": risk_premium_returns,
            "passbook": passbook,
            "app_fee": app_fee,
            "asset_credit_sales": asset_credit_sales,
            "cash_and_carry": cash_and_carry,
            "contingency": contingency,
            "credit_form": credit_form,
            "credit_form_damage": credit_form_damage,
            "bonus": bonus,
            "misc_fees": misc_fees,
            "fund_transferred_other_branch": fund_transferred_other_branch,
            "fund_transferred_ho": fund_transferred_ho,
            "fund_to_other_area": fund_to_other_area,
            "fund_to_asset_program": fund_to_asset_program,
            "fund_to_product_finance": fund_to_product_finance,
            "savings_withdrawal": savings_withdrawal,
            "staff_salaries": staff_salaries,
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
