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

        # 4. Fetch Branch Treasury Activities for the date
        try:
            res_t = uow.client.table("treasury_transactions").select("*").eq("branch_id", branch_id).execute()
            start_ts = f"{p_date_str}T00:00:00"
            end_ts = f"{p_date_str}T23:59:59"
            t_rows = [r for r in (res_t.data or []) if start_ts <= str(r.get("created_at", "")) <= end_ts]
            for t in t_rows:
                ttype = t.get("transaction_type", "")
                amt = float(t.get("amount") or 0.0)
                if ttype == "HO_TRANSFER_IN": totals["funds_received_ho"] += amt
                elif ttype == "HO_TRANSFER_OUT": totals["fund_transferred_ho"] += amt
                elif ttype == "BRANCH_TRANSFER_IN": totals["funds_received_other_branch"] += amt
                elif ttype == "BRANCH_TRANSFER_OUT": totals["fund_transferred_other_branch"] += amt
                elif ttype == "OFFICE_EXPENSE": totals["office_expenses"] += amt
                elif ttype == "STAFF_SALARY": totals["staff_salaries"] += amt
        except Exception:
            pass

        # 5. Fetch Loan Disbursements for Asset & Finance pools on this date for the branch
        try:
            res_disb = uow.client.table("loans").select("amount, product_category, disbursement_date") \
                .eq("branch_id", branch_id).eq("status", "Active").execute()
            for d in (res_disb.data or []):
                if str(d.get("disbursement_date") or "") == p_date_str:
                    cat = d.get("product_category", "Finance")
                    amt = float(d.get("amount") or 0.0)
                    if cat == "Asset": totals["fund_to_asset_program"] += amt
                    else: totals["fund_to_product_finance"] += amt
        except Exception:
            pass

        total_inflows = (
            totals["rep_daily"] + totals["rep_12_weeks"] + totals["rep_24_weeks"] + totals["rep_monthly"] +
            totals["savings_deposit"] + totals["laps_reserve"] + totals["funds_received_ho"] +
            totals["funds_received_other_branch"] + totals["loan_received_asset"] + totals["loan_received_finance"] +
            totals["daily_11_pct"] + totals["weekly_11_pct"] + totals["savings_adj_amount"] +
            totals["risk_premium_returns"] + totals["passbook"] + totals["app_fee"] + totals["asset_credit_sales"] +
            totals["cash_and_carry"] + totals["contingency"] + totals["credit_form"] + totals["credit_form_damage"] +
            totals["bonus"] + totals["misc_fees"]
        )

        total_outflows = (
            totals["fund_transferred_other_branch"] + totals["fund_transferred_ho"] + totals["fund_to_other_area"] +
            totals["fund_to_asset_program"] + totals["fund_to_product_finance"] + totals["savings_withdrawal"] +
            totals["staff_salaries"] + totals["office_expenses"] + totals["laps_returns"] + totals["bank_deposit"] +
            totals["bank_withdrawal"] + totals["product_withdrawal"]
        )

        closing_balance = opening_bal + total_inflows - total_outflows

        mb_data = {
            "date": p_date_str,
            "branch_id": branch_id,
            "opening_balance": opening_bal,
            "total_inflows": total_inflows,
            "total_outflows": total_outflows,
            "closing_balance": closing_balance,
            "status": "Open",
            "version": 1
        }
        mb_data.update(totals)

        try:
            res = uow.client.table("master_cashbook").upsert(mb_data, on_conflict="date,branch_id").execute()
            return mb_data
        except Exception as ex:
            print("Error upserting master_cashbook:", ex)
            return None
