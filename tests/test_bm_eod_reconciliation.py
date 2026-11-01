"""
tests/test_bm_eod_reconciliation.py
Unit and Contract Verification Suite for Branch Manager (BM) Master Cashbook
Reconciliation, EOD Day Close, and Account 1000 Vault Cash Alignment.
"""
import unittest
from unittest.mock import MagicMock, patch
from datetime import date, timedelta
from fastapi import HTTPException

from services.business_date_service import BusinessDateService
from services.area_manager_service import AreaManagerService
from services.financial_reconciliation_service import FinancialReconciliationService
from api.routes.bm.cashbook import execute_eod_day_close
from api.schemas.master_cashbook import EodCloseRequest
from models.user import CurrentUser


class TestBmEodReconciliation(unittest.TestCase):

    def setUp(self):
        self.mock_uow = MagicMock()
        self.branch_id = "00000000-0000-0000-0000-000000000001"
        self.branch_name = "Ikeja Main"
        self.test_date = date(2026, 11, 2)  # Monday

    def test_close_business_date_workflow_and_acct_1000_alignment(self):
        """Verifies complete EOD close workflow: freezes cashbooks, advances date, and derives Account 1000 vault cash."""
        table_mock = MagicMock()
        self.mock_uow.client.table.return_value = table_mock

        builders = {}
        for t in ["app_users", "master_cashbook", "co_cashbooks", "financial_ledger_entries", "area_eod_confirmations", "branch_closures"]:
            b = MagicMock()
            b.select.return_value = b
            b.eq.return_value = b
            b.lte.return_value = b
            b.gte.return_value = b
            b.or_.return_value = b
            b.update.return_value = b
            b.upsert.return_value = b
            b.execute.return_value = MagicMock(data=[])
            builders[t] = b

        builders["app_users"].execute.return_value = MagicMock(data=[{"id": "u_bm_uuid"}])
        builders["master_cashbook"].execute.return_value = MagicMock(data=[{"closing_balance": 250000.0}])
        builders["financial_ledger_entries"].execute.return_value = MagicMock(data=[
            {"amount": 400000.0, "side": "Debit"},
            {"amount": 150000.0, "side": "Credit"}
        ])

        self.mock_uow.client.table.side_effect = lambda t: builders.get(t, MagicMock())

        # Execute Day Close
        success = BusinessDateService.close_business_date(
            uow=self.mock_uow,
            branch_id=self.branch_id,
            posting_date=self.test_date,
            closed_by="bm_ikeja",
            notes="End of Day Balanced"
        )

        self.assertTrue(success)

        # 1. Verify Master Cashbook frozen with Closed status
        mc_builder = builders["master_cashbook"]
        mc_builder.update.assert_called()
        update_args = mc_builder.update.call_args[0][0]
        self.assertEqual(update_args["status"], "Closed")
        self.assertEqual(update_args["verified_by"], "u_bm_uuid")

        # 2. Verify CO Cashbooks frozen with Closed status
        co_builder = builders["co_cashbooks"]
        co_builder.update.assert_called_with({"status": "Closed"})

        # 3. Verify tomorrow's Master Cashbook initialized with carried forward opening balance (₦250,000)
        mc_upsert_args = mc_builder.upsert.call_args[0][0]
        self.assertEqual(mc_upsert_args["opening_balance"], 250000.0)
        self.assertEqual(mc_upsert_args["status"], "Open")

        # 4. Verify Account 1000 queried using created_at (not missing entry_date)
        fle_builder = builders["financial_ledger_entries"]
        fle_builder.lte.assert_called_with("created_at", "2026-11-02T23:59:59")
        fle_builder.eq.assert_any_call("account_code", "1000")

        # 5. Verify area_eod_confirmations auto-populated with zero cash variance (250k - 250k = 0)
        eod_builder = builders["area_eod_confirmations"]
        eod_upsert_args = eod_builder.upsert.call_args[0][0]
        self.assertEqual(eod_upsert_args["status"], "PENDING")
        self.assertEqual(eod_upsert_args["acct_1000_balance"], 250000.0)
        self.assertEqual(eod_upsert_args["cash_variance"], 0.0)

    def test_close_business_date_captures_variance_when_vault_differs(self):
        """When physical Account 1000 vault differs from cashbook closing balance, variance is recorded accurately."""
        self.mock_uow.client.table.side_effect = None
        table_mock = MagicMock()
        self.mock_uow.client.table.return_value = table_mock

        executed_queries = {}

        def table_router(table_name):
            builder = MagicMock()
            builder.select.return_value = builder
            builder.eq.return_value = builder
            builder.lte.return_value = builder
            builder.update.return_value = builder
            builder.upsert.return_value = builder

            if table_name == "app_users":
                builder.execute.return_value = MagicMock(data=[{"id": "u_bm_uuid"}])
            elif table_name == "master_cashbook":
                # Cashbook says closing balance is ₦300,000
                builder.execute.return_value = MagicMock(data=[{"closing_balance": 300000.0}])
            elif table_name == "financial_ledger_entries":
                # Account 1000 physical vault only has ₦280,000
                builder.execute.return_value = MagicMock(data=[
                    {"amount": 280000.0, "side": "Debit"}
                ])
            else:
                builder.execute.return_value = MagicMock(data=[])

            executed_queries[table_name] = builder
            return builder

        self.mock_uow.client.table.side_effect = table_router

        BusinessDateService.close_business_date(
            uow=self.mock_uow,
            branch_id=self.branch_id,
            posting_date=self.test_date,
            closed_by="bm_ikeja"
        )

        eod_builder = executed_queries["area_eod_confirmations"]
        eod_upsert_args = eod_builder.upsert.call_args[0][0]
        # Cashbook 300,000 - Vault 280,000 = Variance of 20,000
        self.assertEqual(eod_upsert_args["acct_1000_balance"], 280000.0)
        self.assertEqual(eod_upsert_args["cash_variance"], 20000.0)

    def test_financial_reconciliation_zero_emoji_and_badge(self):
        """Verifies FinancialReconciliationService produces status_badge and zero emoji characters."""
        table_mock = MagicMock()
        self.mock_uow.client.table.return_value = table_mock

        def table_router(table_name):
            builder = MagicMock()
            builder.select.return_value = builder
            builder.eq.return_value = builder
            builder.gte.return_value = builder
            builder.lte.return_value = builder
            builder.in_.return_value = builder
            builder.execute.return_value = MagicMock(data=[{"amount": 50000.0}])
            return builder

        self.mock_uow.client.table.side_effect = table_router

        result = FinancialReconciliationService.verify_6way_financial_integrity(
            uow=self.mock_uow,
            branch_id=self.branch_id,
            posting_date=self.test_date
        )

        self.assertIn("status_badge", result)
        self.assertIn(result["status_badge"], ["BALANCED", "VARIANCE_DETECTED"])
        self.assertNotIn("status_emoji", result)

    def test_execute_eod_day_close_authorization_guard(self):
        """BM cannot execute EOD close on an unauthorized branch."""
        bm_user = CurrentUser(
            id="bm_u1",
            username="bm_ikeja",
            role="Branch Manager",
            branch="Ikeja Main",
            branch_id=self.branch_id,
            permissions=["execute_eod"]
        )

        self.mock_uow.cashbook._resolve_branch_id.return_value = "00000000-0000-0000-0000-000000000099"  # Other branch

        payload = EodCloseRequest(
            date="2026-11-02",
            branch="Epe Outlet",
            branch_id="00000000-0000-0000-0000-000000000099"
        )

        with self.assertRaises(HTTPException) as ctx:
            execute_eod_day_close(
                payload=payload,
                current_user=bm_user,
                uow=self.mock_uow
            )
        self.assertEqual(ctx.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
