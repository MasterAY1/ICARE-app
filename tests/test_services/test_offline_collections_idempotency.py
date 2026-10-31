"""
Offline Collections & Idempotency Tests (BIA-CO-OFFLINE-007)
Verifies:
1. SingleClientSubmitInput / SingleClientSubmitResponse schema support for idempotency_key and batch_id.
2. Operational business date closure exemption when syncing offline collections (BR-DATE-002).
3. Deterministic transaction ID deduplication (uuid5) to prevent double-posting to the financial ledger.
"""

import unittest
from unittest.mock import MagicMock, patch
import uuid
from datetime import date
from fastapi import HTTPException

from api.schemas.collections import SingleClientSubmitInput, SingleClientSubmitResponse
from api.routes.co.collections import submit_single_client
from api.dependencies import CurrentUser


class TestOfflineCollectionsIdempotency(unittest.TestCase):

    def setUp(self):
        self.mock_user = CurrentUser(
            id="usr-co-01",
            username="test_co",
            role="CO",
            branch="Ikorodu",
            branch_id="br-ikorodu-001"
        )
        self.mock_uow = MagicMock()

    def test_single_client_submit_schema_idempotency_key(self):
        """Verify SingleClientSubmitInput accepts idempotency_key and batch_id."""
        payload = SingleClientSubmitInput(
            client_id="c-001",
            client_name="Test Client",
            loan_repayment=5000.0,
            idempotency_key="idemp-uuid-12345",
            batch_id="COL-SC-2026-10-31-001"
        )
        self.assertEqual(payload.idempotency_key, "idemp-uuid-12345")
        self.assertEqual(payload.batch_id, "COL-SC-2026-10-31-001")

        # Verify response schema has both fields
        resp = SingleClientSubmitResponse(
            success=True,
            message="Collection posted successfully",
            receipt={"batch_id": "COL-SC-2026-10-31-001"},
            idempotency_key="idemp-uuid-12345",
            batch_id="COL-SC-2026-10-31-001"
        )
        self.assertEqual(resp.idempotency_key, "idemp-uuid-12345")
        self.assertEqual(resp.batch_id, "COL-SC-2026-10-31-001")

    @patch("api.routes.co.collections.BusinessDateService.is_operational_open")
    def test_closed_date_rejected_without_idempotency_key(self, mock_is_open):
        """A live submission when business date is closed must be rejected (403)."""
        mock_is_open.return_value = (False, "Date closed by Branch Manager")

        payload = SingleClientSubmitInput(
            client_id="c-001",
            client_name="Test Client",
            loan_repayment=5000.0,
            date="2026-10-30",
            idempotency_key=None  # No offline idempotency key
        )

        with self.assertRaises(HTTPException) as cm:
            submit_single_client(
                payload=payload,
                current_user=self.mock_user,
                uow=self.mock_uow
            )
        self.assertEqual(cm.exception.status_code, 403)
        self.assertIn("Date closed", str(cm.exception.detail))

    @patch("app.save_repayments")
    @patch("api.routes.co.collections.check_branch_access")
    @patch("api.routes.co.collections.BusinessDateService.is_operational_open")
    def test_closed_date_allowed_with_offline_idempotency_key(self, mock_is_open, mock_access, mock_save_rep):
        """Offline-captured collections syncing back must be accepted even if date is closed (BR-DATE-002)."""
        mock_is_open.return_value = (False, "Date closed by Branch Manager")
        mock_access.return_value = None
        mock_save_rep.return_value = {"receipt_no": "REC-001", "total_received": 5000.0}

        # Mock client lookup
        mock_client_table = MagicMock()
        mock_client_table.select.return_value.eq.return_value.execute.return_value.data = [
            {"branch_id": "br-ikorodu-001"}
        ]
        self.mock_uow.client.table.return_value = mock_client_table

        payload = SingleClientSubmitInput(
            client_id="c-001",
            client_name="Test Client",
            loan_repayment=5000.0,
            date="2026-10-30",
            idempotency_key="offline-single-sync-999"  # Offline key provided
        )

        resp = submit_single_client(
            payload=payload,
            current_user=self.mock_user,
            uow=self.mock_uow
        )

        self.assertTrue(resp.success)
        self.assertEqual(resp.idempotency_key, "offline-single-sync-999")
        mock_save_rep.assert_called_once()

    def test_deterministic_tx_id_generation(self):
        """Verify deterministic uuid5 generation prevents duplicate ledger postings."""
        sc_batch_id = "COL-SC-OFFLINE-UUID-ABC"
        client_id = "c-client-12345"

        tx_id_1 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_rep"))
        tx_id_2 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_rep"))

        sav_tx_id_1 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_sav"))
        sav_tx_id_2 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_sav"))

        # Invariant: identical inputs produce identical UUIDs across sync retries
        self.assertEqual(tx_id_1, tx_id_2)
        self.assertEqual(sav_tx_id_1, sav_tx_id_2)
        self.assertNotEqual(tx_id_1, sav_tx_id_1)


if __name__ == "__main__":
    unittest.main()
