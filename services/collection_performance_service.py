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
        cp = getattr(uow, 'collection_performance', None)
        if cp and hasattr(cp, 'record_performance'):
            return cp.record_performance(
                client_id=client_id,
                loan_id=loan_id,
                officer_id=officer_id,
                meeting_date=meeting_date,
                expected_amount=expected_amount,
                amount_paid=amount_paid,
                remarks=remarks
            )
        return {}

    @staticmethod
    def get_client_compliance(
        uow: UnitOfWork,
        client_id: str,
        loan_id: str,
        limit: Optional[int] = None
    ) -> Dict[str, Any]:
        cp = getattr(uow, 'collection_performance', None)
        if cp and hasattr(cp, 'get_client_compliance_history'):
            return cp.get_client_compliance_history(
                client_id=client_id,
                loan_id=loan_id,
                limit=limit
            )
        return {
            "paid_count": 0,
            "part_payment_count": 0,
            "not_paid_count": 0,
            "total_expected": 0.0,
            "total_paid": 0.0,
            "compliance_pct": 100.0,
            "consecutive_missed": 0,
            "total_meetings": 0
        }

    @staticmethod
    def check_upgrade_eligibility(
        uow: UnitOfWork,
        client_id: str,
        loan_id: str
    ) -> Dict[str, Any]:
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

        cp = getattr(uow, 'collection_performance', None)
        if cp and hasattr(cp, 'get_loan_eligibility'):
            return cp.get_loan_eligibility(
                client_id=client_id,
                loan_id=loan_id,
                threshold=threshold,
                review_count=review_count
            )
        return {
            "eligible_for_upgrade": False,
            "threshold": threshold,
            "review_count": review_count
        }

    @staticmethod
    def get_officer_meeting_summary(
        uow: UnitOfWork,
        officer_id: str,
        meeting_date: date
    ) -> Dict[str, Any]:
        records = []
        cp = getattr(uow, 'collection_performance', None)
        if cp and hasattr(cp, 'find_by_officer_and_date'):
            try:
                records = cp.find_by_officer_and_date(officer_id, meeting_date)
            except Exception:
                records = []

        paid = sum(1 for r in records if r.get("status") == "PAID")
        part = sum(1 for r in records if r.get("status") == "PART_PAYMENT")
        not_paid = sum(1 for r in records if r.get("status") == "NOT_PAID")
        total_expected = sum(float(r.get("expected_amount", 0)) for r in records)
        total_collected = sum(float(r.get("amount_paid", 0)) for r in records)
        compliance_pct = (total_collected / total_expected * 100) if total_expected > 0 else 100.0

        return {
            "officer_id": officer_id,
            "meeting_date": meeting_date.isoformat() if isinstance(meeting_date, date) else meeting_date,
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
        records = []
        cp = getattr(uow, 'collection_performance', None)
        if cp and hasattr(cp, 'find_by_branch_and_date'):
            try:
                records = cp.find_by_branch_and_date(branch_id, meeting_date)
            except Exception:
                records = []

        paid = sum(1 for r in records if r.get("status") == "PAID")
        part = sum(1 for r in records if r.get("status") == "PART_PAYMENT")
        not_paid = sum(1 for r in records if r.get("status") == "NOT_PAID")
        total_expected = sum(float(r.get("expected_amount", 0)) for r in records)
        total_collected = sum(float(r.get("amount_paid", 0)) for r in records)
        compliance_pct = (total_collected / total_expected * 100) if total_expected > 0 else 100.0

        return {
            "branch_id": branch_id,
            "meeting_date": meeting_date.isoformat() if isinstance(meeting_date, date) else meeting_date,
            "total_clients": len(records),
            "paid": paid,
            "part_payment": part,
            "not_paid": not_paid,
            "total_expected": total_expected,
            "total_collected": total_collected,
            "compliance_pct": round(compliance_pct, 2)
        }
