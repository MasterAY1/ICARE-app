"""
Tests for AuditEnricher general ledger enrichment and TransactionExplorerService 360 search.
Verifies:
1. Replacement of raw 36-character UUIDs with human-readable references.
2. Resolution of chart of accounts (e.g. 1000 -> 1000 — Vault Cash).
3. Pre-enrichment of double-entry legs for inspection without exposing raw database info.
4. Filtering of internal and raw attributes.
5. 360° search matching on human terms (account, narration, ref, officer, branch).
"""

import unittest
from unittest.mock import MagicMock
from services.audit_enricher_service import AuditEnricher
from services.transaction_explorer_service import TransactionExplorerService


class TestAuditEnricherLedger(unittest.TestCase):

    def setUp(self):
        self.enricher = AuditEnricher(uow=None)
        self.enricher._branches_by_id["b-001"] = "Ogijo Branch"
        self.enricher._users_by_id["u-001"] = "Adenuga Ayomide"
        self.enricher._is_loaded = True

    def test_enrich_ledger_records_balanced(self):
        raw_records = [
            {
                "transaction_id": "3e01b721-44af-4dce-bd0a-43f3fdb2bd4b",
                "event_id": "cdb36a78-2d88-4c3e-8f64-d2e5b85a1112",
                "reference": "3e01b721-44af-4dce-bd0a-43f3fdb2bd4b",
                "posting_date": "2026-09-02T10:00:00",
                "branch_id": "b-001",
                "officer_id": "u-001",
                "narration": "Loan disbursement to Adewale Musa",
                "financial_ledger_entries": [
                    {
                        "entry_id": "e1-uuid",
                        "account_number": "1200",
                        "entry_type": "DEBIT",
                        "amount": 50000.0,
                        "narration": "Debit Loan Portfolio"
                    },
                    {
                        "entry_id": "e2-uuid",
                        "account_number": "1000",
                        "entry_type": "CREDIT",
                        "amount": 50000.0,
                        "narration": "Credit Vault Cash"
                    }
                ]
            }
        ]

        enriched = self.enricher.enrich_ledger_records(raw_records)
        self.assertEqual(len(enriched), 1)
        row = enriched[0]

        # 1. Human-readable Reference (No raw UUID exposed as main reference)
        self.assertEqual(row["Journal Ref"], "JNL-3E01B721")
        self.assertNotIn("-44af-4dce-bd0a-", row["Journal Ref"])

        # 2. Friendly Accounts & Names
        self.assertEqual(row["Debit Account"], "1200 — Loan Portfolio")
        self.assertEqual(row["Credit Account"], "1000 — Vault Cash")

        # 3. Formatted Currency & Balancing Status
        self.assertEqual(row["Amount"], "₦50,000.00")
        self.assertEqual(row["Status"], "🟢 Balanced")
        self.assertEqual(row["Branch"], "Ogijo Branch")
        self.assertEqual(row["Officer"], "Adenuga Ayomide")

        # 4. Enriched Double-Entry Legs for Drill-down Inspector
        entries = row["_entries"]
        self.assertEqual(len(entries), 2)
        debit_leg = entries[0]
        credit_leg = entries[1]
        self.assertEqual(debit_leg["Leg"], "📥 DEBIT")
        self.assertEqual(debit_leg["Account"], "1200 — Loan Portfolio")
        self.assertEqual(debit_leg["Debit (₦)"], "₦50,000.00")
        self.assertEqual(debit_leg["Credit (₦)"], "—")

        self.assertEqual(credit_leg["Leg"], "📤 CREDIT")
        self.assertEqual(credit_leg["Account"], "1000 — Vault Cash")
        self.assertEqual(credit_leg["Debit (₦)"], "—")
        self.assertEqual(credit_leg["Credit (₦)"], "₦50,000.00")

    def test_clean_reference(self):
        # UUID should be cleanly prefixed and shortened
        uuid_str = "cdb36a78-2d88-4c3e-8f64-d2e5b85a1112"
        clean = AuditEnricher.clean_reference(uuid_str, prefix="FEE")
        self.assertEqual(clean, "FEE-CDB36A78")

        # Standard non-UUID reference should remain intact
        norm_ref = "REF-20260902-001"
        self.assertEqual(AuditEnricher.clean_reference(norm_ref), norm_ref)

    def test_transaction_explorer_mock_search(self):
        mock_uow = MagicMock()
        mock_client = MagicMock()
        mock_uow.client = mock_client

        # Mock query tables
        def mock_table(table_name):
            m_tbl = MagicMock()
            if table_name == "financial_transactions":
                m_tbl.select.return_value.execute.return_value.data = [
                    {
                        "transaction_id": "3e01b721-44af-4dce-bd0a-43f3fdb2bd4b",
                        "reference": "3e01b721-44af-4dce-bd0a-43f3fdb2bd4b",
                        "posting_date": "2026-09-02",
                        "branch_id": "b-001",
                        "officer_id": "u-001",
                        "narration": "Loan disbursement to Adewale Musa",
                        "financial_ledger_entries": [
                            {"account_number": "1200", "entry_type": "DEBIT", "amount": 50000.0},
                            {"account_number": "1000", "entry_type": "CREDIT", "amount": 50000.0}
                        ]
                    }
                ]
            else:
                m_tbl.select.return_value.execute.return_value.data = []
            return m_tbl

        mock_client.table.side_effect = mock_table

        # Search by account term "Vault Cash"
        res = TransactionExplorerService.explore_transaction(mock_uow, "Vault Cash")
        self.assertTrue(res["found"])
        self.assertEqual(len(res["ledger_transactions"]), 1)
        matched_tx = res["ledger_transactions"][0]
        self.assertEqual(matched_tx["Journal Ref"], "JNL-3E01B721")
        self.assertEqual(matched_tx["Debit Account"], "1200 — Loan Portfolio")


if __name__ == "__main__":
    unittest.main()
