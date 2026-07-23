from typing import List, Optional, Dict, Any
from datetime import date, datetime
from database.repositories.base_repository import BaseRepository

class SupabaseCollectionPerformanceRepository(BaseRepository):
    """Repository for collection performance tracking — backed by public.collection_performance"""
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "collection_performance"

    def record_performance(
        self,
        client_id: str,
        loan_id: str,
        officer_id: str,
        meeting_date: date,
        expected_amount: float,
        amount_paid: float,
        remarks: Optional[str] = None
    ) -> Dict[str, Any]:
        """Record collection performance for a meeting date. Status is derived from amounts."""
        if amount_paid >= expected_amount:
            status = "PAID"
        elif amount_paid > 0:
            status = "PART_PAYMENT"
        else:
            status = "NOT_PAID"

        payload = {
            "client_id": client_id,
            "loan_id": loan_id,
            "officer_id": officer_id,
            "meeting_date": meeting_date.isoformat() if isinstance(meeting_date, date) else meeting_date,
            "expected_amount": float(expected_amount),
            "amount_paid": float(amount_paid),
            "status": status,
            "remarks": remarks
        }
        res = self.client.table(self.table_name).upsert(
            payload,
            on_conflict="client_id,loan_id,meeting_date"
        ).execute()
        return res.data[0] if res.data else payload

    def find_by_client(self, client_id: str, loan_id: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get all collection performance records for a client, optionally filtered by loan."""
        query = self.client.table(self.table_name).select("*").eq("client_id", client_id)
        if loan_id:
            query = query.eq("loan_id", loan_id)
        query = query.order("meeting_date", desc=True)
        res = query.execute()
        return res.data or []

    def find_by_officer_and_date(
        self,
        officer_id: str,
        meeting_date: date
    ) -> List[Dict[str, Any]]:
        """Get all collection performances for an officer on a specific meeting date."""
        query = self.client.table(self.table_name).select("*") \
            .eq("officer_id", officer_id) \
            .eq("meeting_date", meeting_date.isoformat())
        res = query.execute()
        return res.data or []

    def find_by_branch_and_date(
        self,
        branch_id: str,
        meeting_date: date
    ) -> List[Dict[str, Any]]:
        """Get collection performances for a branch on a date (joins via officer → branch)."""
        # Since collection_performance doesn't have branch_id directly,
        # we filter by officers belonging to the branch
        try:
            officers_res = self.client.table("app_users").select("id").eq("branch_id", branch_id).execute()
            officer_ids = [o["id"] for o in (officers_res.data or [])]
            if not officer_ids:
                return []
            query = self.client.table(self.table_name).select("*") \
                .in_("officer_id", officer_ids) \
                .eq("meeting_date", meeting_date.isoformat())
            res = query.execute()
            return res.data or []
        except Exception:
            return []

    def get_client_compliance_history(
        self,
        client_id: str,
        loan_id: str,
        limit: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Get compliance metrics for a client's loan.
        Returns: paid_count, part_payment_count, not_paid_count, total_expected,
                 total_paid, compliance_pct, consecutive_missed
        """
        query = self.client.table(self.table_name).select("*") \
            .eq("client_id", client_id) \
            .eq("loan_id", loan_id) \
            .order("meeting_date", desc=True)
        if limit:
            query = query.limit(limit)
        res = query.execute()
        records = res.data or []

        paid_count = sum(1 for r in records if r.get("status") == "PAID")
        part_payment_count = sum(1 for r in records if r.get("status") == "PART_PAYMENT")
        not_paid_count = sum(1 for r in records if r.get("status") == "NOT_PAID")
        total_expected = sum(float(r.get("expected_amount", 0)) for r in records)
        total_paid = sum(float(r.get("amount_paid", 0)) for r in records)

        compliance_pct = (total_paid / total_expected * 100) if total_expected > 0 else 100.0

        # Calculate consecutive missed (most recent first)
        consecutive_missed = 0
        for r in records:
            if r.get("status") == "NOT_PAID":
                consecutive_missed += 1
            else:
                break

        return {
            "paid_count": paid_count,
            "part_payment_count": part_payment_count,
            "not_paid_count": not_paid_count,
            "total_expected": total_expected,
            "total_paid": total_paid,
            "compliance_pct": round(compliance_pct, 2),
            "consecutive_missed": consecutive_missed,
            "total_meetings": len(records)
        }

    def get_loan_eligibility(
        self,
        client_id: str,
        loan_id: str,
        threshold: float = 90.0,
        review_count: int = 12
    ) -> Dict[str, Any]:
        """
        Check loan upgrade eligibility based on configurable thresholds.
        threshold: minimum compliance % required (from loan_products.eligibility_threshold)
        review_count: number of recent meetings to evaluate (from loan_products.review_meeting_count)
        """
        compliance = self.get_client_compliance_history(client_id, loan_id, limit=review_count)
        eligible = (
            compliance["compliance_pct"] >= threshold and
            compliance["consecutive_missed"] == 0
        )
        return {
            **compliance,
            "eligible_for_upgrade": eligible,
            "threshold": threshold,
            "review_count": review_count
        }
