from datetime import date
from typing import Dict, Any
from interfaces.unit_of_work import UnitOfWork
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder

class EventReplayService:
    @staticmethod
    def replay_branch_events(uow: UnitOfWork, branch_id: str, posting_date: date) -> Dict[str, Any]:
        """
        Replays event_store domain events to rebuild ledger projections for a branch and date.
        1. Deletes existing co_cashbooks and master_cashbook rows for that date & branch.
        2. Re-runs CoCashbookProjectionBuilder for all officers in the branch.
        3. Re-runs MasterCashbookProjectionBuilder for the branch.
        """
        if isinstance(posting_date, str):
            posting_date = date.fromisoformat(posting_date)
            
        p_date_str = posting_date.isoformat()

        # 1. Clear projections for branch on date
        try:
            uow.client.table("co_cashbooks").delete().eq("branch_id", branch_id).eq("date", p_date_str).execute()
            uow.client.table("master_cashbook").delete().eq("branch_id", branch_id).eq("date", p_date_str).execute()
        except Exception:
            pass

        # 2. Get list of officers in branch
        officers = []
        try:
            res_u = uow.client.table("app_users").select("id").eq("branch_id", branch_id).execute()
            if res_u.data:
                officers = [u["id"] for u in res_u.data if u.get("id")]
        except Exception:
            pass

        # 3. Rebuild officer projections
        for o_id in officers:
            CoCashbookProjectionBuilder.rebuild_co_projection(uow, branch_id, o_id, posting_date)

        # 4. Rebuild master projection
        master_result = MasterCashbookProjectionBuilder.rebuild_master_projection(uow, branch_id, posting_date)

        return {
            "status": "SUCCESS",
            "branch_id": branch_id,
            "date": p_date_str,
            "officers_rebuilt": len(officers),
            "master_cashbook": master_result
        }
