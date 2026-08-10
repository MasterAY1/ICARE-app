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
        prev_date = posting_date - timedelta(days=1)
        prev_date_str = prev_date.isoformat()

        # 1. Previous day opening balance
        opening_bal = 0.0
        try:
            res_prev = uow.client.table("master_cashbook").select("closing_balance") \
                .eq("branch_id", branch_id).eq("date", prev_date_str).execute()
            if res_prev.data:
                opening_bal = float(res_prev.data[0]["closing_balance"] or 0.0)
        except Exception:
            pass

        # 2. Fetch all co_cashbooks for this branch on date
        co_rows = []
        try:
            res_co = uow.client.table("co_cashbooks").select("*") \
                .eq("branch_id", branch_id).eq("date", p_date_str).execute()
            co_rows = res_co.data or []
        except Exception:
            pass

        # 3. Aggregate operational fields across COs
        numeric_fields = [
            "rep_daily", "rep_12_weeks", "rep_24_weeks", "rep_monthly",
            "savings_deposit", "laps_reserve", "loan_received_asset", "loan_received_finance",
            "daily_11_pct", "weekly_11_pct", "savings_adj_amount", "risk_premium_returns",
            "passbook", "app_fee", "asset_credit_sales", "cash_and_carry", "contingency",
            "credit_form", "credit_form_damage", "bonus", "misc_fees",
            "funds_received_ho", "funds_received_other_branch",
            "fund_transferred_other_branch", "fund_transferred_ho", "fund_to_other_area",
            "fund_to_asset_program", "fund_to_product_finance", "savings_withdrawal",
            "staff_salaries", "office_expenses", "laps_returns", "bank_deposit",
            "bank_withdrawal", "product_withdrawal"
        ]

        totals = {field: 0.0 for field in numeric_fields}

        for row in co_rows:
            for field in numeric_fields:
                totals[field] += float(row.get(field) or 0.0)

        # 4. Fetch Branch Treasury Activities and Loan Disbursements from Ledger
        try:
            # We fetch all ledger entries for the branch on this date that hit Account 1000 (Vault Cash)
            # but ONLY for branch-level event types (treasury transfers, expenses, disbursements)
            # CO-level events (repayments, fees) are already aggregated from the CO cashbooks.
            res_ledger = uow.client.table("financial_ledger_entries") \
                .select("*, financial_transactions!inner(event_store(event_type, payload))") \
                .eq("branch_id", branch_id) \
                .eq("account_code", "1000") \
                .eq("financial_transactions.posting_date", p_date_str) \
                .execute()
            
            for entry in (res_ledger.data or []):
                amt = float(entry.get("amount") or 0.0)
                side = entry.get("side")
                tx = entry.get("financial_transactions") or {}
                ev_store = tx.get("event_store") or {}
                event_type = ev_store.get("event_type")
                payload = ev_store.get("payload") or {}
                
                # Branch Inflows (Debit 1000)
                if side == "Debit":
                    if event_type == "CashTransferred_HO_In":
                        # Could be inter-branch or HO, check payload classification/transaction_type
                        tx_type = payload.get("transaction_type")
                        if tx_type == "INTER_BRANCH_IN":
                            totals["funds_received_other_branch"] += amt
                        else:
                            totals["funds_received_ho"] += amt
                            
                # Branch Outflows (Credit 1000)
                elif side == "Credit":
                    if event_type == "CashTransferred_HO_Out":
                        tx_type = payload.get("transaction_type")
                        if tx_type == "INTER_BRANCH_OUT":
                            totals["fund_transferred_other_branch"] += amt
                        else:
                            totals["fund_transferred_ho"] += amt
                    elif event_type == "ExpenseRecorded":
                        totals["office_expenses"] += amt
                    elif event_type == "SalaryPaid":
                        totals["staff_salaries"] += amt
                    elif event_type == "LoanDisbursed":
                        # Deduce pool from payload (default to Finance if unspecified)
                        prod_cat = "Finance"
                        if "Asset" in str(payload.get("narration", "")):
                            prod_cat = "Asset"
                        if prod_cat == "Asset":
                            totals["fund_to_asset_program"] += amt
                        else:
                            totals["fund_to_product_finance"] += amt
        except Exception as e:
            print(f"[SAVINGS TRACE] Master Cashbook failed to fetch branch ledger entries: {e}")

        # Corrected Master Cashbook Formulas (ICARE Business Rules)
        # Bank Withdrawal = Inflow (cash brought into operational position)
        # Total Outflows = Physical cash outflows (savings_withdrawal + laps_returns + bank_deposit + loan disbursements + treasury outflows)
        # product_withdrawal = Informational value reduction column (NOT included in cash outflows to avoid double-counting)
        total_inflows = (
            totals["rep_daily"] + totals["rep_12_weeks"] + totals["rep_24_weeks"] + totals["rep_monthly"] +
            totals["savings_deposit"] + totals["laps_reserve"] + totals["bank_withdrawal"] +
            totals["funds_received_ho"] + totals["funds_received_other_branch"] +
            totals["loan_received_asset"] + totals["loan_received_finance"] +
            totals["daily_11_pct"] + totals["weekly_11_pct"] + totals["savings_adj_amount"] +
            totals["risk_premium_returns"] + totals["passbook"] + totals["app_fee"] +
            totals["asset_credit_sales"] + totals["cash_and_carry"] + totals["contingency"] +
            totals["credit_form"] + totals["credit_form_damage"] + totals["bonus"] + totals["misc_fees"]
        )

        total_outflows = (
            totals["bank_deposit"] + totals["savings_withdrawal"] + totals["laps_returns"] +
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
        closing_balance = opening_bal + total_inflows - total_outflows

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

        try:
            res = uow.client.table("master_cashbook").upsert(mb_data, on_conflict="date,branch_id").execute()
            return mb_data
        except Exception as ex:
            print("Error upserting master_cashbook:", ex)
            return None
