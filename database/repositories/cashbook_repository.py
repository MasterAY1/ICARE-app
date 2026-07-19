from typing import List, Optional
from datetime import date, datetime
from domain.entities.cashbook_entry import CashbookEntry
from domain.queries import CashbookFilter
from mappers.base_mappers import CashbookMapper
from interfaces.cashbook_repository import CashbookRepository
from database.repositories.base_repository import BaseRepository
from core.exceptions import RepositoryError

class SupabaseCashbookRepository(BaseRepository[CashbookEntry], CashbookRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "master_cashbook"
        self.columns = "*, branches(name)"

    def _resolve_branch_id(self, branch_name: str) -> str:
        if not branch_name:
            return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"
        try:
            res = self.client.table("branches").select("branch_id").eq("name", branch_name).execute()
            if res.data:
                return res.data[0]["branch_id"]
        except Exception:
            pass
        return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d" # Lagos fallback

    def _resolve_branch_id_by_filter(self, branch: Optional[str]) -> Optional[str]:
        if not branch:
            return None
        return self._resolve_branch_id(branch)

    def find_by_id(self, id: str) -> Optional[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns).eq("id", id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_all(self) -> List[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns)
        res = self._execute(query)
        return [CashbookMapper.to_domain(d) for d in res.data]

    def find_by_date_and_branch(self, date_str: str, branch: str) -> Optional[CashbookEntry]:
        branch_id = self._resolve_branch_id(branch)
        query = self.client.table(self.table_name).select(self.columns).eq("date", date_str).eq("branch_id", branch_id)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_previous(self, date_str: str, branch: str) -> Optional[CashbookEntry]:
        branch_id = self._resolve_branch_id(branch)
        query = self.client.table(self.table_name).select(self.columns).eq("branch_id", branch_id).lt("date", date_str).order("date", desc=True).limit(1)
        res = self._execute(query)
        data = self._single_or_none(res.data)
        return CashbookMapper.to_domain(data) if data else None

    def find_range(self, filters: CashbookFilter) -> List[CashbookEntry]:
        query = self.client.table(self.table_name).select(self.columns)
        if filters.branch:
            branch_id = self._resolve_branch_id(filters.branch)
            query = query.eq("branch_id", branch_id)
        if filters.start_date:
            query = query.gte("date", filters.start_date)
        if filters.end_date:
            query = query.lte("date", filters.end_date)
        
        query = query.order("date")
        res = self._execute(query)
        return [CashbookMapper.to_domain(d) for d in res.data]

    def rebuild_projection(self, branch_id: str, posting_date) -> None:
        if isinstance(posting_date, str):
            posting_date = date.fromisoformat(posting_date)
            
        # 1. Resolve branch name
        branch_name = "Lagos"
        try:
            res_b = self.client.table("branches").select("name").eq("branch_id", branch_id).execute()
            if res_b.data:
                branch_name = res_b.data[0]["name"]
        except Exception:
            pass

        # 2. Get previous day's closing balance as opening balance
        from datetime import timedelta
        prev_date = posting_date - timedelta(days=1)
        prev_date_str = prev_date.isoformat()
        
        opening_bal = 0.0
        try:
            res_prev = self.client.table("master_cashbook").select("closing_balance").eq("branch_id", branch_id).eq("date", prev_date_str).execute()
            if res_prev.data:
                opening_bal = float(res_prev.data[0]["closing_balance"] or 0.0)
        except Exception:
            pass

        # 3. Query all ledger entries for this branch on this date
        try:
            res_entries = self.client.table("financial_ledger_entries") \
                .select("*, financial_transactions!inner(event_id, posting_date, narration, reference, event_store(event_type))") \
                .eq("branch_id", branch_id) \
                .eq("financial_transactions.posting_date", posting_date.isoformat()) \
                .execute()
            entries_list = res_entries.data or []
        except Exception:
            entries_list = []

        rep_daily = 0.0
        rep_12_weeks = 0.0
        rep_24_weeks = 0.0
        rep_monthly = 0.0
        savings_deposit = 0.0
        laps_reserve = 0.0
        funds_received_ho = 0.0
        funds_received_other_branch = 0.0
        loan_received_asset = 0.0
        loan_received_finance = 0.0
        daily_11_pct = 0.0
        weekly_11_pct = 0.0
        savings_adj_no = 0
        savings_adj_amount = 0.0
        risk_premium_returns = 0.0
        passbook = 0.0
        app_fee = 0.0
        asset_credit_sales = 0.0
        cash_and_carry = 0.0
        contingency = 0.0
        credit_form = 0.0
        credit_form_damage = 0.0
        bonus = 0.0
        misc_fees = 0.0
        
        fund_transferred_other_branch = 0.0
        fund_transferred_ho = 0.0
        fund_to_other_area = 0.0
        fund_to_asset_program = 0.0
        fund_to_product_finance = 0.0
        savings_withdrawal = 0.0
        staff_salaries = 0.0
        office_expenses = 0.0
        laps_returns = 0.0
        bank_deposit = 0.0
        bank_withdrawal = 0.0
        product_withdrawal = 0.0

        for entry in entries_list:
            acc = entry.get("account_code")
            if acc != "1000":
                continue
            
            amount = float(entry.get("amount") or 0.0)
            side = entry.get("side")
            tx = entry.get("financial_transactions") or {}
            ev_store = tx.get("event_store") or {}
            event_type = ev_store.get("event_type")
            narr = str(tx.get("narration") or "").lower()

            if side == "Debit":
                # Inflow
                if event_type == "RepaymentReceived":
                    cycle = "Daily"
                    try:
                        res_l = self.client.table("loans").select("loan_products(repayment_cycle)").eq("loan_id", entry.get("aggregate_id")).execute()
                        if res_l.data:
                            cycle = res_l.data[0].get("loan_products", {}).get("repayment_cycle", "Daily")
                    except Exception:
                        pass
                    if cycle == "Daily":
                        rep_daily += amount
                    elif cycle == "Weekly":
                        duration = 12
                        try:
                            res_l2 = self.client.table("loans").select("loan_products(name)").eq("loan_id", entry.get("aggregate_id")).execute()
                            if res_l2.data:
                                name = str(res_l2.data[0].get("loan_products", {}).get("name", "")).lower()
                                if "24" in name:
                                    duration = 24
                        except Exception:
                            pass
                        if duration == 12:
                            rep_12_weeks += amount
                        else:
                            rep_24_weeks += amount
                    elif cycle == "Monthly":
                        rep_monthly += amount
                    else:
                        rep_daily += amount
                elif event_type == "SavingsDeposited":
                    if entry.get("aggregate_type") == "LapsSavings":
                        laps_reserve += amount
                    else:
                        savings_deposit += amount
                elif event_type == "FeeCharged":
                    if "passbook" in narr or "pass book" in narr:
                        passbook += amount
                    elif "processing" in narr or "application" in narr:
                        app_fee += amount
                    elif "contingency" in narr:
                        contingency += amount
                    elif "daily" in narr:
                        daily_11_pct += amount
                    elif "weekly" in narr:
                        weekly_11_pct += amount
                    elif "monthly" in narr or "risk premium" in narr or "markup" in narr:
                        risk_premium_returns += amount
                    else:
                        misc_fees += amount
                elif event_type == "CashTransferred_HO_In":
                    funds_received_ho += amount
                elif event_type == "BankWithdrawn":
                    bank_withdrawal += amount
                elif event_type == "AssetSoldCash":
                    cash_and_carry += amount
                elif event_type == "PenaltyCharged":
                    misc_fees += amount
            elif side == "Credit":
                # Outflow
                if event_type == "LoanDisbursed":
                    category = "Finance"
                    try:
                        res_l3 = self.client.table("loans").select("product_category").eq("loan_id", entry.get("aggregate_id")).execute()
                        if res_l3.data:
                            category = res_l3.data[0].get("product_category", "Finance")
                    except Exception:
                        pass
                    if category == "Asset":
                        fund_to_asset_program += amount
                    else:
                        fund_to_product_finance += amount
                elif event_type == "SavingsWithdrawn":
                    savings_withdrawal += amount
                elif event_type == "ExpenseRecorded":
                    office_expenses += amount
                elif event_type == "SalaryPaid":
                    staff_salaries += amount
                elif event_type == "BankDeposited":
                    bank_deposit += amount
                elif event_type == "CashTransferred_HO_Out":
                    fund_transferred_ho += amount

        total_inflows = rep_daily + rep_12_weeks + rep_24_weeks + rep_monthly + savings_deposit + laps_reserve + funds_received_ho + funds_received_other_branch + loan_received_asset + loan_received_finance + daily_11_pct + weekly_11_pct + savings_adj_amount + risk_premium_returns + passbook + app_fee + asset_credit_sales + cash_and_carry + contingency + credit_form + credit_form_damage + bonus + misc_fees
        total_outflows = fund_transferred_other_branch + fund_transferred_ho + fund_to_other_area + fund_to_asset_program + fund_to_product_finance + savings_withdrawal + staff_salaries + office_expenses + laps_returns + bank_deposit + bank_withdrawal + product_withdrawal
        closing_balance = opening_bal + total_inflows - total_outflows

        cb_data = {
            "date": posting_date.isoformat(),
            "branch_id": branch_id,
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
            "closing_balance": closing_balance
        }
        print(f"[SAVINGS TRACE] Rebuilding cashbook projection for branch {branch_id} on {posting_date.isoformat()}... Inflows={total_inflows}, Outflows={total_outflows}, Closing={closing_balance}")
        res = self.client.table(self.table_name).upsert(cb_data, on_conflict="date,branch_id").execute()
        print(f"[SAVINGS TRACE] Cashbook projection rebuilt successfully! Result data: {res.data}")

    def _prepare_db_data(self, entity: CashbookEntry) -> dict:
        data = CashbookMapper.to_database(entity)
        branch_name = data.pop("branch", None)
        data["branch_id"] = self._resolve_branch_id(branch_name or entity.branch)
        return data

    def create(self, entity: CashbookEntry) -> CashbookEntry:
        data = self._prepare_db_data(entity)
        if "id" in data and not data["id"]:
            del data["id"]
        query = self.client.table(self.table_name).insert(data)
        res = self._execute(query)
        inserted = self._single_or_none(res.data)
        if inserted:
            entity.id = inserted.get("id")
        return entity

    def update(self, entity: CashbookEntry) -> CashbookEntry:
        data = self._prepare_db_data(entity)
        cb_id = data.pop("id", None)
        if cb_id:
            query = self.client.table(self.table_name).update(data).eq("id", cb_id)
        else:
            query = self.client.table(self.table_name).update(data).eq("date", entity.date.isoformat()).eq("branch_id", data["branch_id"])
        res = self._execute(query)
        updated = self._single_or_none(res.data)
        if updated:
            entity.id = updated.get("id")
        return entity

    def delete(self, id: str) -> bool:
        query = self.client.table(self.table_name).delete().eq("id", id)
        res = self._execute(query)
        return len(res.data) > 0
