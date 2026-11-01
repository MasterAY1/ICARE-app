"""
LoanOverdueRecoveryRepository — Phase 9
Authoritative data access for loan overdue recovery records.
Governance: BR-DASH-004, BR-DASH-005, Invariants 8 & 9
"""
from typing import List, Optional, Dict, Any
from datetime import date
from domain.entities.overdue_recovery_record import LoanOverdueRecoveryRecord
from database.repositories.base_repository import BaseRepository


class SupabaseLoanOverdueRecoveryRepository(BaseRepository[LoanOverdueRecoveryRecord]):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "loan_overdue_recovery_records"

    def _prepare_db_data(self, record: LoanOverdueRecoveryRecord) -> Dict[str, Any]:
        d_str = record.recovery_date.isoformat() if hasattr(record.recovery_date, 'isoformat') else str(record.recovery_date)
        ts_str = record.recovery_timestamp.isoformat() if hasattr(record.recovery_timestamp, 'isoformat') else str(record.recovery_timestamp)
        return {
            "id": record.id,
            "repayment_id": record.repayment_id,
            "loan_id": record.loan_id,
            "client_id": record.client_id,
            "officer_id": record.officer_id,
            "branch_id": record.branch_id,
            "recovery_date": d_str[:10],
            "recovery_timestamp": ts_str,
            "recovered_amount": float(record.recovered_amount or 0.0),
            "overdue_before": float(record.overdue_before or 0.0),
            "overdue_after": float(record.overdue_after or 0.0),
            "total_repayment_amount": float(record.total_repayment_amount or 0.0),
            "recovery_type": record.recovery_type,
            "notes": record.notes
        }

    def record_event(self, record: LoanOverdueRecoveryRecord) -> Dict[str, Any]:
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
        recovery_type: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        s_str = start_date.isoformat()[:10]
        e_str = end_date.isoformat()[:10]
        q = self.client.table(self.table_name).select("*").gte("recovery_date", s_str).lte("recovery_date", e_str)
        if branch_id:
            q = q.eq("branch_id", branch_id)
        if officer_id:
            q = q.eq("officer_id", officer_id)
        if recovery_type:
            q = q.eq("recovery_type", recovery_type)
        res = q.execute()
        return res.data or []

    def delete_by_repayment_id(self, repayment_id: str) -> None:
        self.client.table(self.table_name).delete().eq("repayment_id", repayment_id).execute()
