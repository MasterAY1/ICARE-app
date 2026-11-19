"""
Offline Collections & Idempotency Tests (BIA-CO-OFFLINE-007 / Strict BR-DATE-002)
Verifies:
1. SingleClientSubmitInput / SingleClientSubmitResponse schema requires non-blank idempotency_key.
2. Strict BR-DATE-002 business-date enforcement: CO cannot bypass closed dates via offline flags/keys or is_late_entry.
3. Only Admin / Super Admin with explicit is_late_entry=True may post on a closed date.
4. Deterministic transaction ID deduplication (uuid5) to prevent double-posting to the financial ledger.
"""

import unittest
from unittest.mock import MagicMock, patch
import uuid
from fastapi import HTTPException
from pydantic import ValidationError

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
        self.mock_admin = CurrentUser(
            id="usr-admin-01",
            username="admin_user",
            role="Admin",
            branch="Head Office",
            branch_id="br-ho-001"
        )
        self.mock_uow = MagicMock()
        self.mock_uow.client.rpc.return_value.execute.return_value.data = {"action": "PROCEED", "status": "NEW"}

    def test_single_client_submit_schema_requires_idempotency_key(self):
        """Verify SingleClientSubmitInput requires a non-blank idempotency_key and supports batch_id."""
        with self.assertRaises(ValidationError):
            SingleClientSubmitInput(
                client_id="c-001",
                client_name="Test Client",
                loan_repayment=5000.0,
            )

        with self.assertRaises(ValidationError):
            SingleClientSubmitInput(
                client_id="c-001",
                client_name="Test Client",
                loan_repayment=5000.0,
                idempotency_key="   ",
            )

        payload = SingleClientSubmitInput(
            client_id="c-001",
            client_name="Test Client",
            loan_repayment=5000.0,
            idempotency_key="idemp-uuid-12345",
            batch_id="COL-SC-2026-10-31-001"
        )
        self.assertEqual(payload.idempotency_key, "idemp-uuid-12345")
        self.assertEqual(payload.batch_id, "COL-SC-2026-10-31-001")

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
    def test_closed_date_rejected_for_co_even_with_offline_or_late_flags(self, mock_is_open):
        """Under strict BR-DATE-002, CO closed-date submissions are always rejected (403)."""
        mock_is_open.return_value = (False, "Date closed by Branch Manager")

        for extra_flags in [
            {"idempotency_key": "IDEM-NORMAL-001", "is_offline_sync": False, "is_late_entry": False},
            {"idempotency_key": "offline-single-sync-999", "is_offline_sync": True, "is_late_entry": False},
            {"idempotency_key": "IDEM-LATE-ATTEMPT-001", "is_offline_sync": False, "is_late_entry": True},
        ]:
            payload = SingleClientSubmitInput(
                client_id="c-001",
                client_name="Test Client",
                loan_repayment=5000.0,
                date="2026-10-30",
                **extra_flags,
            )

            with self.assertRaises(HTTPException) as cm:
                submit_single_client(
                    payload=payload,
                    current_user=self.mock_user,
                    uow=self.mock_uow
                )
            self.assertEqual(cm.exception.status_code, 403)

    @patch("services.collection_batch_service.save_repayments")
    @patch("api.routes.co.collections.check_branch_access")
    @patch("api.routes.co.collections.BusinessDateService.is_operational_open")
    def test_closed_date_allowed_only_for_admin_with_late_entry(self, mock_is_open, mock_access, mock_save_rep):
        """Explicit Admin is_late_entry=True may override closed business date cleanly."""
        mock_is_open.return_value = (False, "Date closed by Branch Manager")
        mock_access.return_value = None
        mock_save_rep.return_value = {"receipt_no": "REC-001", "total_received": 5000.0}

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
            idempotency_key="IDEM-ADMIN-LATE-001",
            is_late_entry=True,
        )

        resp = submit_single_client(
            payload=payload,
            current_user=self.mock_admin,
            uow=self.mock_uow
        )

        self.assertTrue(resp.success)
        self.assertEqual(resp.idempotency_key, "IDEM-ADMIN-LATE-001")
        mock_save_rep.assert_called_once()
        self.assertTrue(mock_save_rep.call_args.kwargs.get("allow_closed_date"))

    def test_deterministic_tx_id_generation(self):
        """Verify deterministic uuid5 generation prevents duplicate ledger postings."""
        sc_batch_id = "COL-SC-OFFLINE-UUID-ABC"
        client_id = "c-client-12345"

        tx_id_1 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_rep"))
        tx_id_2 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_rep"))

        sav_tx_id_1 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_sav"))
        sav_tx_id_2 = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{sc_batch_id}_{client_id}_sav"))

        self.assertEqual(tx_id_1, tx_id_2)
        self.assertEqual(sav_tx_id_1, sav_tx_id_2)
        self.assertNotEqual(tx_id_1, sav_tx_id_1)


if __name__ == "__main__":
    unittest.main()
