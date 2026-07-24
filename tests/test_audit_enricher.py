"""
TestAuditEnricher — Phase 8.2 Unit Test Suite
Verifies resolution of raw foreign keys into human-readable codes/names,
currency formatting, date formatting, executive status badges, and batch enrichment.
"""

import unittest
from services.audit_enricher_service import AuditEnricher


class TestAuditEnricher(unittest.TestCase):

    def setUp(self):
        self.enricher = AuditEnricher(uow=None)

    def test_currency_formatting(self):
        self.assertEqual(AuditEnricher.format_currency(3000), "₦3,000.00")
        self.assertEqual(AuditEnricher.format_currency(1234567.89), "₦1,234,567.89")
        self.assertEqual(AuditEnricher.format_currency(0), "₦0.00")
        self.assertEqual(AuditEnricher.format_currency(None), "₦0.00")

    def test_date_formatting(self):
        self.assertEqual(AuditEnricher.format_date("2026-07-24"), "24 Jul 2026")
        self.assertEqual(AuditEnricher.format_date(None), "N/A")

    def test_status_badges(self):
        self.assertIn("🟢", AuditEnricher.format_status_badge("PAID"))
        self.assertIn("🟢", AuditEnricher.format_status_badge("ACTIVE"))
        self.assertIn("🟡", AuditEnricher.format_status_badge("PART_PAYMENT"))
        self.assertIn("🔴", AuditEnricher.format_status_badge("NOT_PAID"))
        self.assertIn("🔴", AuditEnricher.format_status_badge("OVERDUE"))

    def test_fallback_resolutions(self):
        client = self.enricher.resolve_client("c324c4d7-6181-47eb-b230-0b5b2f06a3dd")
        self.assertEqual(client["code"], "c324c4d7...")

        branch = self.enricher.resolve_branch("997d504e-7f5c-4772-887d-fdd5a4c1183b")
        self.assertTrue(branch.startswith("Branch (997d504e"))

        officer = self.enricher.resolve_officer("00000000-0000-0000-0000-000000000000")
        self.assertEqual(officer, "Unassigned")

        product = self.enricher.resolve_product(None)
        self.assertEqual(product, "General Loan")

    def test_batch_fee_enrichment(self):
        raw_fees = [{
            "id": "fee-1",
            "posting_date": "2026-07-24",
            "fee_type": "PROCESSING_FEE",
            "amount": 5000,
            "client_id": "OGI-12-005",
            "officer_id": "Ayomide",
            "branch_id": "Ijebu Ode Branch",
            "reference": "REF-001"
        }]
        enriched = self.enricher.enrich_fee_records(raw_fees)
        self.assertEqual(len(enriched), 1)
        row = enriched[0]
        self.assertEqual(row["Date"], "24 Jul 2026")
        self.assertEqual(row["Fee Type"], "PROCESSING_FEE")
        self.assertEqual(row["Amount"], "₦5,000.00")
        self.assertEqual(row["Client Code"], "OGI-12-005")

    def test_batch_savings_enrichment(self):
        raw_savings = [{
            "posting_date": "2026-07-24",
            "client_id": "OGI-12-005",
            "officer_id": "Ayomide",
            "branch_id": "Ijebu Ode Branch",
            "deposit_amount": 3000,
            "withdrawal_amount": 0,
            "balance": 3000
        }]
        enriched = self.enricher.enrich_savings_records(raw_savings)
        self.assertEqual(len(enriched), 1)
        row = enriched[0]
        self.assertEqual(row["Deposit"], "₦3,000.00")
        self.assertEqual(row["Withdrawal"], "₦0.00")
        self.assertEqual(row["Balance"], "₦3,000.00")


if __name__ == "__main__":
    unittest.main()
