"""
ClientRiskRatingService — Phase 8
Computes client risk ratings from collection performance data.
Ratings are computed, never manually entered.

Risk Rating Scale:
  95–100%  → ⭐ Excellent — Eligible for upgrade
  85–94%   → 🟢 Good — Maintain current loan
  70–84%   → 🟡 Fair — Monitor closely
  50–69%   → 🟠 Risky — No loan increase
  Below 50% → 🔴 High Risk — Downgrade or decline

Inputs:
  - Collection performance (compliance %, paid/part/missed meetings)
  - Consecutive NOT_PAID records
  - Part-payment frequency
  - Loan completion history
  - Existing overdue balance
"""
from typing import Dict, Any, Optional
from interfaces.unit_of_work import UnitOfWork


RATING_THRESHOLDS = [
    (95, "EXCELLENT", "⭐", "Excellent — Eligible for upgrade"),
    (85, "GOOD", "🟢", "Good — Maintain current loan"),
    (70, "FAIR", "🟡", "Fair — Monitor closely"),
    (50, "RISKY", "🟠", "Risky — No loan increase"),
    (0,  "HIGH_RISK", "🔴", "High Risk — Downgrade or decline"),
]


class ClientRiskRatingService:

    @staticmethod
    def compute_risk_rating(
        uow: UnitOfWork,
        client_id: str,
        loan_id: str
    ) -> Dict[str, Any]:
        """
        Compute a client's risk rating for a given loan using:
          1. Collection Performance compliance %
          2. Consecutive missed meetings
          3. Part-payment frequency
          4. Loan completion history
          5. Current overdue balance
        """

        # 1. Collection Performance Metrics
        compliance = uow.collection_performance.get_client_compliance_history(
            client_id=client_id,
            loan_id=loan_id
        )
        compliance_pct = compliance.get("compliance_pct", 0.0)
        paid_meetings = compliance.get("paid_count", 0)
        part_payments = compliance.get("part_payment_count", 0)
        missed_meetings = compliance.get("not_paid_count", 0)
        consecutive_missed = compliance.get("consecutive_missed", 0)
        total_expected = compliance.get("total_expected", 0.0)
        total_paid = compliance.get("total_paid", 0.0)

        # 2. Loan Completion History — count of completed loans for this client
        loans_completed = 0
        try:
            res = uow.client.table("loans").select("loan_id") \
                .eq("client_id", client_id) \
                .in_("status", ["Completed", "Closed"]) \
                .execute()
            loans_completed = len(res.data) if res.data else 0
        except Exception:
            pass

        # 3. Current Overdue Balance
        overdue_balance = 0.0
        try:
            res = uow.client.table("loans").select("total_due, loan_repay") \
                .eq("loan_id", loan_id).execute()
            if res.data:
                loan_data = res.data[0]
                total_due = float(loan_data.get("total_due") or 0.0)
                loan_repay = float(loan_data.get("loan_repay") or 0.0)
                overdue_balance = max(0.0, total_due - loan_repay)
        except Exception:
            pass

        # 4. Apply Penalty Adjustments to compliance_pct
        adjusted_score = compliance_pct

        # Penalty for consecutive misses (each consecutive miss reduces score by 5 points)
        if consecutive_missed > 0:
            adjusted_score = max(0, adjusted_score - (consecutive_missed * 5))

        # Bonus for loan completion history (each completed loan adds 1 point, max 5)
        completion_bonus = min(loans_completed, 5)
        adjusted_score = min(100, adjusted_score + completion_bonus)

        # 5. Determine Rating
        rating_score = "HIGH_RISK"
        rating_emoji = "🔴"
        rating_label = "High Risk — Downgrade or decline"
        for threshold, score, emoji, label in RATING_THRESHOLDS:
            if adjusted_score >= threshold:
                rating_score = score
                rating_emoji = emoji
                rating_label = label
                break

        # 6. Upgrade Eligibility
        eligible_for_upgrade = (rating_score == "EXCELLENT" and consecutive_missed == 0)

        # 7. Recommended Maximum Next Loan
        recommended_max_loan = ClientRiskRatingService._recommend_max_loan(
            uow, client_id, loan_id, rating_score, loans_completed
        )

        return {
            "client_id": client_id,
            "loan_id": loan_id,
            "compliance_pct": round(compliance_pct, 2),
            "adjusted_score": round(adjusted_score, 2),
            "paid_meetings": paid_meetings,
            "part_payment_meetings": part_payments,
            "missed_meetings": missed_meetings,
            "consecutive_missed": consecutive_missed,
            "total_expected": total_expected,
            "total_paid": total_paid,
            "loans_completed": loans_completed,
            "overdue_balance": overdue_balance,
            "rating_score": rating_score,
            "rating_emoji": rating_emoji,
            "rating_label": rating_label,
            "eligible_for_upgrade": eligible_for_upgrade,
            "recommended_max_loan": recommended_max_loan
        }

    @staticmethod
    def _recommend_max_loan(
        uow: UnitOfWork,
        client_id: str,
        loan_id: str,
        rating_score: str,
        loans_completed: int
    ) -> float:
        """
        Calculate recommended maximum next loan amount based on:
          - Current loan amount
          - Risk rating
          - Loan completion count
        """
        current_amount = 0.0
        try:
            res = uow.client.table("loans").select("loan_amount") \
                .eq("loan_id", loan_id).execute()
            if res.data:
                current_amount = float(res.data[0].get("loan_amount") or 0.0)
        except Exception:
            pass

        multipliers = {
            "EXCELLENT": 1.5,   # 50% increase
            "GOOD": 1.25,       # 25% increase
            "FAIR": 1.0,        # Same amount
            "RISKY": 0.75,      # 25% decrease
            "HIGH_RISK": 0.0    # No loan
        }
        multiplier = multipliers.get(rating_score, 1.0)

        # Additional boost for repeat borrowers (max 10% extra for 3+ completed loans)
        if loans_completed >= 3 and rating_score in ("EXCELLENT", "GOOD"):
            multiplier += 0.10

        return round(current_amount * multiplier, -3)  # Round to nearest 1000

    @staticmethod
    def get_branch_risk_distribution(
        uow: UnitOfWork,
        branch_id: str
    ) -> Dict[str, Any]:
        """
        Get risk rating distribution for all active loans in a branch.
        Returns count per rating category for director/BM dashboards.
        """
        distribution = {
            "EXCELLENT": 0,
            "GOOD": 0,
            "FAIR": 0,
            "RISKY": 0,
            "HIGH_RISK": 0,
            "total_clients": 0
        }

        try:
            # Get all active loans for this branch
            res = uow.client.table("loans").select("loan_id, client_id") \
                .eq("branch_id", branch_id) \
                .in_("status", ["Active", "Approved"]) \
                .execute()

            active_loans = res.data or []
            distribution["total_clients"] = len(active_loans)

            for loan in active_loans:
                try:
                    rating = ClientRiskRatingService.compute_risk_rating(
                        uow, loan["client_id"], loan["loan_id"]
                    )
                    score = rating.get("rating_score", "HIGH_RISK")
                    if score in distribution:
                        distribution[score] += 1
                except Exception:
                    distribution["HIGH_RISK"] += 1

        except Exception:
            pass

        return distribution
