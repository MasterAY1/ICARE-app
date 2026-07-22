from datetime import date
from typing import Dict, Any, Optional
from interfaces.unit_of_work import UnitOfWork

class DailyReconciliationService:
    @staticmethod
    def reconcile_branch_day(uow: UnitOfWork, branch_id: str, posting_date: date) -> Dict[str, Any]:
        """
        Performs automated daily 3-way financial reconciliation across:
        1. General Ledger (Account 1000 Cash Net Movement)
        2. CO Cashbooks Aggregated Net Movement
        3. Master Cashbook Net Movement
        
        Returns status 'BALANCED' or 'OUT_OF_BALANCE' with exact delta breakdown.
        """
        if isinstance(posting_date, str):
            posting_date = date.fromisoformat(posting_date)
            
        p_date_str = posting_date.isoformat()

        # 1. General Ledger Net Cash Movement (Account 1000)
        gl_debit = 0.0
        gl_credit = 0.0
        try:
            res_gl = uow.client.table("financial_ledger_entries") \
                .select("side, amount, financial_transactions!inner(posting_date, branch_id)") \
                .eq("branch_id", branch_id) \
                .eq("account_code", "1000") \
                .eq("financial_transactions.posting_date", p_date_str) \
                .execute()
            for entry in (res_gl.data or []):
                amt = float(entry.get("amount") or 0.0)
                if entry.get("side") == "Debit":
                    gl_debit += amt
                elif entry.get("side") == "Credit":
                    gl_credit += amt
        except Exception as ex:
            print("Error fetching GL entries for reconciliation:", ex)

        gl_net_flow = gl_debit - gl_credit

        # 2. Aggregated CO Cashbooks Net Operational Flow
        co_inflows = 0.0
        co_outflows = 0.0
        co_count = 0
        try:
            res_co = uow.client.table("co_cashbooks").select("total_inflows, total_outflows") \
                .eq("branch_id", branch_id).eq("date", p_date_str).execute()
            co_rows = res_co.data or []
            co_count = len(co_rows)
            for r in co_rows:
                co_inflows += float(r.get("total_inflows") or 0.0)
                co_outflows += float(r.get("total_outflows") or 0.0)
        except Exception as ex:
            print("Error fetching CO cashbooks for reconciliation:", ex)

        co_net_flow = co_inflows - co_outflows

        # 3. Master Cashbook Net Vault Movement
        mb_inflows = 0.0
        mb_outflows = 0.0
        mb_opening = 0.0
        mb_closing = 0.0
        mb_status = "Not Found"
        try:
            res_mb = uow.client.table("master_cashbook").select("*") \
                .eq("branch_id", branch_id).eq("date", p_date_str).execute()
            if res_mb.data:
                mb_row = res_mb.data[0]
                mb_inflows = float(mb_row.get("total_inflows") or 0.0)
                mb_outflows = float(mb_row.get("total_outflows") or 0.0)
                mb_opening = float(mb_row.get("opening_balance") or 0.0)
                mb_closing = float(mb_row.get("closing_balance") or 0.0)
                mb_status = mb_row.get("status") or "Open"
        except Exception as ex:
            print("Error fetching Master cashbook for reconciliation:", ex)

        mb_net_flow = mb_inflows - mb_outflows

        # 4. Reconciliation Math
        gl_vs_co_diff = abs(gl_net_flow - co_net_flow)
        gl_vs_mb_diff = abs(gl_net_flow - mb_net_flow)
        co_vs_mb_diff = abs(co_net_flow - mb_net_flow)

        is_balanced = (gl_vs_co_diff < 0.01) and (gl_vs_mb_diff < 0.01) and (co_vs_mb_diff < 0.01)
        reconciliation_status = "BALANCED" if is_balanced else "OUT_OF_BALANCE"

        return {
            "date": p_date_str,
            "branch_id": branch_id,
            "reconciliation_status": reconciliation_status,
            "is_balanced": is_balanced,
            "gl_cash_debit": gl_debit,
            "gl_cash_credit": gl_credit,
            "gl_net_flow": gl_net_flow,
            "co_cashbooks_count": co_count,
            "co_net_flow": co_net_flow,
            "master_cashbook_opening": mb_opening,
            "master_cashbook_net_flow": mb_net_flow,
            "master_cashbook_closing": mb_closing,
            "master_cashbook_status": mb_status,
            "deltas": {
                "gl_vs_co": gl_vs_co_diff,
                "gl_vs_master": gl_vs_mb_diff,
                "co_vs_master": co_vs_mb_diff
            }
        }
