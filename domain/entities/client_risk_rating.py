from dataclasses import dataclass
from typing import Optional

@dataclass
class ClientRiskRating:
    """Computed client risk rating value object."""
    client_id: str = ""
    loan_id: Optional[str] = None
    compliance_pct: float = 0.0  # Total Paid / Total Expected * 100
    paid_meetings: int = 0
    part_payment_meetings: int = 0
    missed_meetings: int = 0
    consecutive_missed: int = 0
    total_expected: float = 0.0
    total_paid: float = 0.0
    loans_completed: int = 0
    overdue_balance: float = 0.0

    @property
    def rating_score(self) -> str:
        """Compute risk rating from compliance percentage."""
        if self.compliance_pct >= 95:
            return "EXCELLENT"
        elif self.compliance_pct >= 85:
            return "GOOD"
        elif self.compliance_pct >= 70:
            return "FAIR"
        elif self.compliance_pct >= 50:
            return "RISKY"
        else:
            return "HIGH_RISK"

    @property
    def rating_emoji(self) -> str:
        mapping = {
            "EXCELLENT": "⭐",
            "GOOD": "🟢",
            "FAIR": "🟡",
            "RISKY": "🟠",
            "HIGH_RISK": "🔴"
        }
        return mapping.get(self.rating_score, "⚪")

    @property
    def rating_label(self) -> str:
        mapping = {
            "EXCELLENT": "Excellent — Eligible for upgrade",
            "GOOD": "Good — Maintain current loan",
            "FAIR": "Fair — Monitor closely",
            "RISKY": "Risky — No loan increase",
            "HIGH_RISK": "High Risk — Downgrade or decline"
        }
        return mapping.get(self.rating_score, "Unknown")

    @property
    def eligible_for_upgrade(self) -> bool:
        return self.rating_score == "EXCELLENT" and self.consecutive_missed == 0
