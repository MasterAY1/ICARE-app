"""
CollectionPerformanceService — Phase 8
Records meeting collection performance, auto-classifies statuses,
computes compliance metrics, and determines loan upgrade/downgrade eligibility.
"""
from typing import Dict, Any, List, Optional
from datetime import date
from interfaces.unit_of_work import UnitOfWork


class CollectionPerformanceService:

    @staticmethod
    def record_meeting_collection(
        uow: UnitOfWork,
        client_id: str,
        loan_id: str,
        officer_id: str,
        meeting_date: date,
        expected_amount: float,
        amount_paid: float,
        remarks: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Record collection performance for a single client meeting.
        Status is derived automatically:
          - PAID: amount_paid >= expected_amount
          - PART_PAYMENT: 0 < amount_paid < expected_amount
          - NOT_PAID: amount_paid == 0
        """
        return uow.collection_performance.record_performance(
            client_id=client_id,
            loan_id=loan_id,
            officer_id=officer_id,
            meeting_date=meeting_date,
            expected_amount=expected_amount,
            amount_paid=amount_paid,
            remarks=remarks
        )

    @staticmethod
    def get_client_compliance(
        uow: UnitOfWork,
        client_id: str,
        loan_id: str,
        limit: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Get compliance metrics for a client's loan:
          - paid_count, part_payment_count, not_paid_count
          - total_expected, total_paid
          - compliance_pct (Total Paid / Total Expected × 100)
          - consecutive_missed
        """
        return uow.collection_performance.get_client_compliance_history(
            client_id=client_id,
            loan_id=loan_id,
            limit=limit
        )

    @staticmethod
    def check_upgrade_eligibility(
        uow: UnitOfWork,
        client_id: str,
        loan_id: str
    ) -> Dict[str, Any]:
        """
        Check loan upgrade eligibility using product-specific thresholds.
        Reads eligibility_threshold and review_meeting_count from loan_products.
        """
        # Resolve loan product configuration
        threshold = 90.0
        review_count = 12

        try:
            loan_res = uow.client.table("loans").select(
                "loan_products(eligibility_threshold, review_meeting_count, repayment_cycle, name)"
            ).eq("loan_id", loan_id).execute()
            if loan_res.data:
                product = loan_res.data[0].get("loan_products") or {}
                threshold = float(product.get("eligibility_threshold") or 90.0)
                review_count = int(product.get("review_meeting_count") or 12)
        except Exception:
            pass

        return uow.collection_performance.get_loan_eligibility(
            client_id=client_id,
            loan_id=loan_id,
            threshold=threshold,
            review_count=review_count
        )

    @staticmethod
    def get_officer_meeting_summary(
        uow: UnitOfWork,
        officer_id: str,
        meeting_date: date
    ) -> Dict[str, Any]:
        """
        Get summary of an officer's collection performance for a meeting date.
        Returns: total_clients, paid, part_payment, not_paid, total_expected, total_collected, compliance_pct
        """
        records = uow.collection_performance.find_by_officer_and_date(officer_id, meeting_date)
        
        paid = sum(1 for r in records if r.get("status") == "PAID")
        part = sum(1 for r in records if r.get("status") == "PART_PAYMENT")
        not_paid = sum(1 for r in records if r.get("status") == "NOT_PAID")
        total_expected = sum(float(r.get("expected_amount", 0)) for r in records)
        total_collected = sum(float(r.get("amount_paid", 0)) for r in records)
        compliance_pct = (total_collected / total_expected * 100) if total_expected > 0 else 100.0

        return {
            "officer_id": officer_id,
            "meeting_date": meeting_date.isoformat(),
            "total_clients": len(records),
            "paid": paid,
            "part_payment": part,
            "not_paid": not_paid,
            "total_expected": total_expected,
            "total_collected": total_collected,
            "compliance_pct": round(compliance_pct, 2)
        }

    @staticmethod
    def get_branch_meeting_summary(
        uow: UnitOfWork,
        branch_id: str,
        meeting_date: date
    ) -> Dict[str, Any]:
        """
        Get summary of branch-level collection performance for a meeting date.
        """
        records = uow.collection_performance.find_by_branch_and_date(branch_id, meeting_date)

        paid = sum(1 for r in records if r.get("status") == "PAID")
        part = sum(1 for r in records if r.get("status") == "PART_PAYMENT")
        not_paid = sum(1 for r in records if r.get("status") == "NOT_PAID")
        total_expected = sum(float(r.get("expected_amount", 0)) for r in records)
        total_collected = sum(float(r.get("amount_paid", 0)) for r in records)
        compliance_pct = (total_collected / total_expected * 100) if total_expected > 0 else 100.0

        return {
            "branch_id": branch_id,
            "meeting_date": meeting_date.isoformat(),
            "total_clients": len(records),
            "paid": paid,
            "part_payment": part,
            "not_paid": not_paid,
            "total_expected": total_expected,
            "total_collected": total_collected,
            "compliance_pct": round(compliance_pct, 2)
        }
