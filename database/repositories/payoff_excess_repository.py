"""
LoanPayoffExcessRepository — Phase 8.5
Authoritative data access for loan full payoffs and excess payments.
Governance: BR-DASH-005, BR-DASH-007, GEMINI Invariant 9
"""
from typing import List, Optional, Dict, Any
from datetime import date
from domain.entities.payoff_excess_record import LoanPayoffExcessRecord
from database.repositories.base_repository import BaseRepository


class SupabaseLoanPayoffExcessRepository(BaseRepository[LoanPayoffExcessRecord]):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "loan_payoff_excess_records"

    def _prepare_db_data(self, record: LoanPayoffExcessRecord) -> Dict[str, Any]:
        dt_str = record.date.isoformat() if hasattr(record.date, 'isoformat') else str(record.date)
        return {
            "id": record.id,
            "repayment_id": record.repayment_id,
            "loan_id": record.loan_id,
            "client_id": record.client_id,
            "officer_id": record.officer_id,
            "branch_id": record.branch_id,
            "date": dt_str[:10],
            "record_type": record.record_type,
            "amount_paid": float(record.amount_paid or 0.0),
            "expected_installment": float(record.expected_installment or 0.0),
            "active_credit_settled": float(record.active_credit_settled or 0.0),
            "excess_amount": float(record.excess_amount or 0.0),
            "remaining_balance_before": float(record.remaining_balance_before or 0.0),
            "remaining_balance_after": float(record.remaining_balance_after or 0.0),
            "notes": record.notes
        }

    def record_event(self, record: LoanPayoffExcessRecord) -> Dict[str, Any]:
        data = self._prepare_db_data(record)
        res = self.client.table(self.table_name).insert(data).execute()
        return res.data[0] if res.data else data

    def find_by_repayment_id(self, repayment_id: str) -> List[Dict[str, Any]]:
        res = self.client.table(self.table_name).select("*").eq("repayment_id", repayment_id).execute()
        return res.data or []

    def find_by_period(
        self,
        start_date: date,
        end_date: date,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        record_type: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        s_str = start_date.isoformat()[:10]
        e_str = end_date.isoformat()[:10]
        q = self.client.table(self.table_name).select("*").gte("date", s_str).lte("date", e_str)
        if branch_id:
            q = q.eq("branch_id", branch_id)
        if officer_id:
            q = q.eq("officer_id", officer_id)
        if record_type:
            q = q.eq("record_type", record_type)
        res = q.execute()
        return res.data or []

    def delete_by_repayment_id(self, repayment_id: str) -> None:
        self.client.table(self.table_name).delete().eq("repayment_id", repayment_id).execute()
