"""
Phase 8 — Automated Tests: Collection Performance & Client Risk Rating
Tests collection performance recording, compliance calculation, and risk rating computation.
"""
import unittest
from datetime import date, timedelta
from domain.entities.collection_performance import CollectionPerformance
from domain.entities.client_risk_rating import ClientRiskRating


class TestCollectionPerformanceDomainEntity(unittest.TestCase):
    """Test the CollectionPerformance domain entity status derivation."""

    def test_paid_status(self):
        """PAID when amount_paid >= expected_amount."""
        cp = CollectionPerformance(
            client_id="c1", loan_id="l1", officer_id="o1",
            expected_amount=8500.0, amount_paid=8500.0
        )
        self.assertEqual(cp.status, "PAID")
        self.assertEqual(cp.excess_amount, 0.0)
        self.assertEqual(cp.shortfall_amount, 0.0)

    def test_paid_with_excess(self):
        """PAID when amount_paid > expected_amount (excess payment)."""
        cp = CollectionPerformance(
            client_id="c1", loan_id="l1", officer_id="o1",
            expected_amount=8500.0, amount_paid=9000.0
        )
        self.assertEqual(cp.status, "PAID")
        self.assertEqual(cp.excess_amount, 500.0)
        self.assertEqual(cp.shortfall_amount, 0.0)

    def test_part_payment_status(self):
        """PART_PAYMENT when 0 < amount_paid < expected_amount."""
        cp = CollectionPerformance(
            client_id="c1", loan_id="l1", officer_id="o1",
            expected_amount=8500.0, amount_paid=4000.0
        )
        self.assertEqual(cp.status, "PART_PAYMENT")
        self.assertEqual(cp.excess_amount, 0.0)
        self.assertEqual(cp.shortfall_amount, 4500.0)

    def test_not_paid_status(self):
        """NOT_PAID when amount_paid == 0."""
        cp = CollectionPerformance(
            client_id="c1", loan_id="l1", officer_id="o1",
            expected_amount=8500.0, amount_paid=0.0
        )
        self.assertEqual(cp.status, "NOT_PAID")
        self.assertEqual(cp.excess_amount, 0.0)
        self.assertEqual(cp.shortfall_amount, 8500.0)

    def test_zero_expected_is_paid(self):
        """PAID when expected_amount is 0 (no obligation)."""
        cp = CollectionPerformance(
            client_id="c1", loan_id="l1", officer_id="o1",
            expected_amount=0.0, amount_paid=0.0
        )
        self.assertEqual(cp.status, "PAID")

    def test_derive_status_recalculates(self):
        """derive_status() always produces correct result from current values."""
        cp = CollectionPerformance(
            client_id="c1", loan_id="l1", officer_id="o1",
            expected_amount=1000.0, amount_paid=500.0
        )
        self.assertEqual(cp.status, "PART_PAYMENT")
        # Mutate and re-derive
        cp.amount_paid = 1000.0
        self.assertEqual(cp.derive_status(), "PAID")

    def test_auto_generates_uuid(self):
        """Entity auto-generates a UUID id if none provided."""
        cp = CollectionPerformance(client_id="c1", loan_id="l1", officer_id="o1")
        self.assertIsNotNone(cp.id)
        self.assertTrue(len(cp.id) == 36)  # UUID format


class TestClientRiskRatingDomainEntity(unittest.TestCase):
    """Test the ClientRiskRating value object rating computation."""

    def test_excellent_rating(self):
        """95-100% compliance → EXCELLENT."""
        r = ClientRiskRating(compliance_pct=98.0)
        self.assertEqual(r.rating_score, "EXCELLENT")
        self.assertEqual(r.rating_emoji, "⭐")
        self.assertTrue(r.eligible_for_upgrade)

    def test_good_rating(self):
        """85-94% compliance → GOOD."""
        r = ClientRiskRating(compliance_pct=90.0)
        self.assertEqual(r.rating_score, "GOOD")
        self.assertEqual(r.rating_emoji, "🟢")
        self.assertFalse(r.eligible_for_upgrade)

    def test_fair_rating(self):
        """70-84% compliance → FAIR."""
        r = ClientRiskRating(compliance_pct=75.0)
        self.assertEqual(r.rating_score, "FAIR")
        self.assertEqual(r.rating_emoji, "🟡")

    def test_risky_rating(self):
        """50-69% compliance → RISKY."""
        r = ClientRiskRating(compliance_pct=55.0)
        self.assertEqual(r.rating_score, "RISKY")
        self.assertEqual(r.rating_emoji, "🟠")

    def test_high_risk_rating(self):
        """Below 50% compliance → HIGH_RISK."""
        r = ClientRiskRating(compliance_pct=30.0)
        self.assertEqual(r.rating_score, "HIGH_RISK")
        self.assertEqual(r.rating_emoji, "🔴")

    def test_excellent_with_missed_meetings_not_eligible(self):
        """EXCELLENT but consecutive_missed > 0 → not eligible for upgrade."""
        r = ClientRiskRating(compliance_pct=96.0, consecutive_missed=1)
        self.assertEqual(r.rating_score, "EXCELLENT")
        self.assertFalse(r.eligible_for_upgrade)

    def test_boundary_95(self):
        """Exactly 95% → EXCELLENT."""
        r = ClientRiskRating(compliance_pct=95.0)
        self.assertEqual(r.rating_score, "EXCELLENT")

    def test_boundary_85(self):
        """Exactly 85% → GOOD."""
        r = ClientRiskRating(compliance_pct=85.0)
        self.assertEqual(r.rating_score, "GOOD")

    def test_boundary_70(self):
        """Exactly 70% → FAIR."""
        r = ClientRiskRating(compliance_pct=70.0)
        self.assertEqual(r.rating_score, "FAIR")

    def test_boundary_50(self):
        """Exactly 50% → RISKY."""
        r = ClientRiskRating(compliance_pct=50.0)
        self.assertEqual(r.rating_score, "RISKY")

    def test_zero_compliance(self):
        """0% compliance → HIGH_RISK."""
        r = ClientRiskRating(compliance_pct=0.0)
        self.assertEqual(r.rating_score, "HIGH_RISK")


class TestCollectionPerformanceRepository(unittest.TestCase):
    """Test the collection performance repository via UnitOfWork."""

    def setUp(self):
        from database.repositories.unit_of_work import SupabaseUnitOfWork
        self.uow = SupabaseUnitOfWork()

    def test_repository_accessible(self):
        """Collection performance repository is accessible on UoW."""
        self.assertIsNotNone(self.uow.collection_performance)

    def test_find_by_client_empty(self):
        """Query for non-existent client returns empty list."""
        results = self.uow.collection_performance.find_by_client(
            "00000000-0000-0000-0000-000000000000"
        )
        self.assertIsInstance(results, list)

    def test_compliance_history_empty_client(self):
        """Compliance history for non-existent client returns defaults."""
        result = self.uow.collection_performance.get_client_compliance_history(
            "00000000-0000-0000-0000-000000000000",
            "00000000-0000-0000-0000-000000000000"
        )
        self.assertEqual(result["paid_count"], 0)
        self.assertEqual(result["compliance_pct"], 100.0)  # No expected = 100%
        self.assertEqual(result["consecutive_missed"], 0)


if __name__ == "__main__":
    unittest.main()
