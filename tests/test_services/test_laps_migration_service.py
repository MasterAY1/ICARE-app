import unittest
from unittest.mock import MagicMock
from domain.entities.savings import LapsSavings
from services.laps_migration_service import LAPSMigrationService


class TestLAPSMigrationService(unittest.TestCase):

    def setUp(self):
        self.mock_uow = MagicMock()
        
        # Setup mock repositories
        self.mock_laps_savings_repo = MagicMock()
        self.mock_uow.laps_savings = self.mock_laps_savings_repo
        self.mock_laps_savings_repo._resolve_branch_id.return_value = "branch-uuid-123"
        
        def mock_create(entity):
            entity.id = "mock-laps-id-999"
        self.mock_laps_savings_repo.create.side_effect = mock_create

        self.mock_audit = MagicMock()
        self.mock_uow.audit = self.mock_audit

        self.mock_event_store = MagicMock()
        self.mock_uow.event_store = self.mock_event_store

        self.mock_ledger_repo = MagicMock()
        self.mock_uow.ledger = self.mock_ledger_repo

        self.mock_rules_repo = MagicMock()
        self.mock_uow.posting_rules = self.mock_rules_repo
        
        rule_mock = MagicMock()
        rule_mock.debit_account = "3000"
        rule_mock.credit_account = "2030"
        self.mock_rules_repo.get_by_event_type.return_value = rule_mock

    def test_bulk_migration_known_owners(self):
        records = [
            {
                "client_id": "cli-101",
                "client_name": "Adeola Adeleke",
                "branch": "Ogijo",
                "officer": "AM_Area_1",
                "amount": 25000.0,
                "owner_known": True,
                "remarks": "Historical LAPS balance"
            },
            {
                "client_id": "cli-102",
                "client_name": "Bisi Akande",
                "branch": "Ogijo",
                "officer": "AM_Area_1",
                "amount": 15000.0,
                "owner_known": "Yes",
                "remarks": "Historical LAPS balance"
            }
        ]

        res = LAPSMigrationService.migrate_legacy_laps(
            self.mock_uow,
            records,
            user_id="SuperAdmin",
            batch_id="LAPS-MIG-TEST-001"
        )

        self.assertEqual(res["batch_id"], "LAPS-MIG-TEST-001")
        if res["errors"]:
            print("\nDEBUG ERRORS:", res["errors"])
        self.assertEqual(res["success_count"], 2)
        self.assertEqual(res["failed_count"], 0)
        self.assertEqual(res["total_amount_migrated"], 40000.0)
        self.assertFalse(res["affects_cash_vault"])

        # Check repository calls
        self.assertEqual(self.mock_laps_savings_repo.create.call_count, 2)
        
        # Check first created entity fields
        created_entity_1 = self.mock_laps_savings_repo.create.call_args_list[0][0][0]
        self.assertEqual(created_entity_1.client_id, "cli-101")
        self.assertEqual(created_entity_1.deposit_amount, 25000.0)
        self.assertEqual(created_entity_1.migration_batch_id, "LAPS-MIG-TEST-001")
        self.assertEqual(created_entity_1.migration_source, "EXCEL_MIGRATION")
        self.assertTrue(created_entity_1.owner_known)

    def test_bulk_migration_unknown_owner(self):
        records = [
            {
                "client_id": "",
                "client_name": "Unassigned Legacy Deposit",
                "branch": "Lagos",
                "officer": "Admin",
                "amount": 50000.0,
                "owner_known": False,
                "remarks": "Unknown owner legacy LAPS"
            }
        ]

        res = LAPSMigrationService.migrate_legacy_laps(
            self.mock_uow,
            records,
            user_id="SuperAdmin",
            batch_id="LAPS-MIG-UNKNOWN-001"
        )

        self.assertEqual(res["success_count"], 1)
        self.assertEqual(res["total_amount_migrated"], 50000.0)

        created_entity = self.mock_laps_savings_repo.create.call_args_list[0][0][0]
        self.assertEqual(created_entity.client_id, "")
        self.assertFalse(created_entity.owner_known)
        self.assertEqual(created_entity.migration_batch_id, "LAPS-MIG-UNKNOWN-001")


if __name__ == "__main__":
    unittest.main()
