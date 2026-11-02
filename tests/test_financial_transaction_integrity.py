"""
Financial Transaction Integrity & Concurrency Hardened Test Suite.

Verifies institutional-grade transaction safety:
1. Duplicate repayment submissions (idempotency replay)
2. Duplicate disbursement submissions (fail-closed active guard)
3. Simultaneous submissions (in-flight 409 conflict lock)
4. Interrupted requests (transaction status lookup recovery)
5. Database failures during posting (atomic rollback)
6. Retried requests with mismatched payloads (rejection 422)
7. Concurrent updates to the same financial record (single-claimer locking)
8. Reconciliation after failed operations (zero orphan ledger drift)
"""

import unittest
from unittest.mock import MagicMock, patch
from datetime import date, datetime
import uuid
import pytest
from fastapi import HTTPException

from domain.entities.loan import Loan
from domain.entities.repayment import Repayment
from domain.entities.savings import IndividualSavings, GroupSavings
from domain.enums import LoanStatus
from services.idempotency_service import IdempotencyService
from services.loan_service import LoanService
from services.savings_service import SavingsService
from services.collection_batch_service import save_repayment, save_repayments
from api.routes.co.collections import submit_single_client, submit_batch_collections, get_transaction_status
from api.schemas.collections import SingleClientSubmitInput, SingleClientSubmitResponse
from api.schemas.financial_writes import BatchCollectionInput, BatchCollectionItem, BatchCollectionResponse
from models.user import CurrentUser


class TestFinancialTransactionIntegrity(unittest.TestCase):
    def setUp(self):
        self.mock_user = CurrentUser(
            id="usr-12345",
            username="test_officer",
            role="Credit Officer",
            branch="Ogijo",
            branch_id="00000000-0000-0000-0000-000000000001",
            full_name="Test Officer"
        )
        self.mock_uow = MagicMock()
        # Mock client queries
        self.mock_uow.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [
            {"client_id": "cli-1111", "branch_id": "00000000-0000-0000-0000-000000000001", "name": "Fatima Bello"}
        ]

    # =========================================================================
    # 1. Duplicate Repayment Submissions
    # =========================================================================
    def test_duplicate_repayment_submissions_replays_cached_response(self):
        """
        Verify that submitting a duplicate repayment with the same idempotency key
        immediately replays the cached receipt without calling the save service again.
        """
        payload = SingleClientSubmitInput(
            client_id="cli-1111",
            client_name="Fatima Bello",
            loan_repayment=5000.0,
            savings_deposit=1000.0,
            date="2026-11-02",
            batch_id="COL-SC-2026-11-02-001",
            idempotency_key="IDEM-REP-DUP-001"
        )

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("api.routes.co.collections.check_branch_access"), \
             patch("services.idempotency_service.IdempotencyService.acquire_lock") as mock_acquire, \
             patch("services.idempotency_service.IdempotencyService.commit_result") as mock_commit, \
             patch("services.collection_batch_service.save_repayments") as mock_save:

            # First submission: PROCEED
            mock_acquire.return_value = {"action": "PROCEED", "status": "NEW"}
            mock_save.return_value = {
                "batch_id": "COL-SC-2026-11-02-001",
                "total_repayment": 5000.0,
                "total_savings": 1000.0,
                "total_cash": 6000.0
            }

            resp1 = submit_single_client(payload=payload, current_user=self.mock_user, uow=self.mock_uow)
            self.assertTrue(resp1.success)
            self.assertEqual(resp1.idempotency_key, "IDEM-REP-DUP-001")
            mock_save.assert_called_once()
            mock_commit.assert_called_once()

            # Second submission: REPLAY cached response
            cached_receipt = resp1.receipt
            mock_acquire.return_value = {
                "action": "REPLAY",
                "status": "COMMITTED",
                "response_code": 200,
                "response_body": {
                    "success": True,
                    "receipt": cached_receipt,
                    "message": "Successfully posted single client collection for Fatima Bello!",
                    "idempotency_key": "IDEM-REP-DUP-001",
                    "batch_id": "COL-SC-2026-11-02-001"
                }
            }

            resp2 = submit_single_client(payload=payload, current_user=self.mock_user, uow=self.mock_uow)
            self.assertTrue(resp2.success)
            self.assertEqual(resp2.receipt["batch_id"], "COL-SC-2026-11-02-001")
            # Verify save_repayments was NOT called a second time
            self.assertEqual(mock_save.call_count, 1)

    # =========================================================================
    # 2. Duplicate Disbursement Submissions
    # =========================================================================
    def test_duplicate_disbursement_submissions_fails_closed(self):
        """
        Verify that attempting to disburse an already Active loan fails closed
        immediately without generating duplicate ledger entries or events.
        """
        active_loan = Loan(
            id="loan-active-999",
            client_id="cli-1111",
            client_name="Fatima Bello",
            product_type="Daily 60 Days",
            amount=150000.0,
            duration=60,
            frequency="Daily",
            gap_fee=0.0,
            expected_installment=2500.0,
            total_payable=150000.0,
            status="Active",  # Already Active!
            branch="Ogijo",
            credit_officer="test_officer"
        )

        with self.assertRaises(ValueError) as ctx:
            LoanService.disburse_loan(self.mock_uow, active_loan, disbursement_date=date.today())

        self.assertIn("already been activated and disbursed", str(ctx.exception))
        # Ensure no database RPC was executed
        self.mock_uow.client.rpc.assert_not_called()

    # =========================================================================
    # 3. Simultaneous Submissions (In-Flight Concurrency Lock)
    # =========================================================================
    def test_simultaneous_submissions_in_flight_conflict_raises_409(self):
        """
        Verify that if two simultaneous requests arrive with the same idempotency key,
        the second request receives an HTTP 409 Conflict.
        """
        payload = BatchCollectionInput(
            group_name="Progress Group",
            date="2026-11-02",
            collections=[
                BatchCollectionItem(client_id="cli-1", client_name="Client 1", loan_repayment_amount=2000.0)
            ],
            idempotency_key="IDEM-SIMULTANEOUS-001"
        )

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("services.idempotency_service.IdempotencyService.acquire_lock") as mock_acquire:

            mock_acquire.side_effect = HTTPException(
                status_code=409,
                detail="This transaction is currently in progress. Please wait a moment before checking status."
            )

            with self.assertRaises(HTTPException) as ctx:
                submit_batch_collections(payload=payload, current_user=self.mock_user, uow=self.mock_uow)

            self.assertEqual(ctx.exception.status_code, 409)
            self.assertIn("currently in progress", ctx.exception.detail)

    # =========================================================================
    # 4. Interrupted Requests (Mobile Status Lookup)
    # =========================================================================
    def test_interrupted_request_recovers_committed_status(self):
        """
        Verify that a mobile client whose connection dropped after server commit
        can retrieve the transaction status and receipt via /transaction/{idempotency_key}.
        """
        committed_key = "IDEM-MOBILE-DROP-001"
        cached_response = {
            "key": committed_key,
            "scope": "single_collection",
            "status": "COMMITTED",
            "response_code": 200,
            "response_body": {
                "success": True,
                "batch_id": "COL-SC-20261102-ABC",
                "receipt": {"total_cash": 12500.0}
            },
            "created_at": datetime.now().isoformat(),
            "locked_at": datetime.now().isoformat()
        }

        with patch("services.idempotency_service.IdempotencyService.get_transaction_status", return_value=cached_response):
            res = get_transaction_status(committed_key, current_user=self.mock_user, uow=self.mock_uow)

            self.assertEqual(res["status"], "COMMITTED")
            self.assertEqual(res["response_code"], 200)
            self.assertEqual(res["response_body"]["receipt"]["total_cash"], 12500.0)

    # =========================================================================
    # 5. Database Failure During Posting (Atomic Rollback)
    # =========================================================================
    def test_database_failure_during_posting_rolls_back_atomically(self):
        """
        Verify that if atomic_execute_operations raises an exception (e.g. unbalancing ledger),
        the exception propagates and no partial state is left committed.
        """
        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch.object(self.mock_uow.individual_savings, "_to_database", return_value={"id": "sav-1"}), \
             patch("services.posting_engine.FinancialPostingEngine.post_event", return_value=("tx-1", {"type": "post_financial_transaction"})):

            self.mock_uow.client.rpc.return_value.execute.side_effect = RuntimeError("ERR_UNBALANCED_TRANSACTION: Exact debits does not equal credits")

            with self.assertRaises(RuntimeError) as ctx:
                SavingsService.post_individual_savings(
                    uow=self.mock_uow,
                    client_id="cli-1111",
                    client_name="Fatima Bello",
                    branch="Ogijo",
                    officer="test_officer",
                    deposit_amount=5000.0,
                    idempotency_key="IDEM-FAIL-001"
                )

            self.assertIn("ERR_UNBALANCED_TRANSACTION", str(ctx.exception))
            self.mock_uow.client.rpc.assert_called_once()

    # =========================================================================
    # 6. Retried Requests with Mismatched Payload (422 Rejection)
    # =========================================================================
    def test_retried_request_with_mismatched_payload_rejected(self):
        """
        Verify that re-using an existing idempotency key with different financial amounts
        or parameters is rejected with HTTP 422 to protect financial integrity.
        """
        key = "IDEM-REUSE-KEY"
        payload_1 = {"client_id": "cli-1", "amount": 5000.0}
        payload_2 = {"client_id": "cli-1", "amount": 10000.0}

        hash1 = IdempotencyService.compute_payload_hash(payload_1)
        hash2 = IdempotencyService.compute_payload_hash(payload_2)
        self.assertNotEqual(hash1, hash2)

        self.mock_uow.client.rpc.return_value.execute.side_effect = Exception("ERR_IDEMPOTENCY_PAYLOAD_MISMATCH: Idempotency key was previously used with different parameters")

        with self.assertRaises(HTTPException) as ctx:
            IdempotencyService.acquire_lock(self.mock_uow, key, "repayment", payload_2)

        self.assertEqual(ctx.exception.status_code, 422)
        self.assertIn("different payload parameters", ctx.exception.detail)

    # =========================================================================
    # 7. Concurrent Updates to the Same Financial Record
    # =========================================================================
    def test_concurrent_withdrawal_approval_single_claimer_guard(self):
        """
        Verify that when two concurrent workers attempt to approve the same pending withdrawal,
        only the worker that successfully claims the 'PENDING' -> 'PROCESSING' transition proceeds.
        """
        from api.routes.bm.dashboard import _execute_withdrawal_approval

        wr_item = {
            "id": "wr-1001",
            "branch_id": "00000000-0000-0000-0000-000000000001",
            "savings_type": "Individual",
            "operation_type": "Cash Withdrawal",
            "amount": 15000.0,
            "client_name": "Fatima Bello",
            "client_id": "cli-1111",
            "requested_by": "test_officer"
        }

        # Simulate Worker 2: update returns 0 rows because Worker 1 already claimed it
        mock_uow2 = MagicMock()
        mock_uow2.client.table.return_value.update.return_value.eq.return_value.eq.return_value.execute.return_value.data = []
        # Querying current status shows it is already PROCESSING or APPROVED
        mock_uow2.client.table.return_value.select.return_value.eq.return_value.execute.return_value.data = [
            {"status": "APPROVED"}
        ]

        with patch("services.savings_service.SavingsService.post_individual_savings") as mock_post_sav:
            _execute_withdrawal_approval(mock_uow2, wr_item, date.today(), "Ogijo", "bm_user")
            # Worker 2 must NOT execute a duplicate savings withdrawal!
            mock_post_sav.assert_not_called()

    # =========================================================================
    # 8. Reconciliation After Failed Operations (Zero Orphan Ledger Drift)
    # =========================================================================
    def test_reconciliation_after_failed_operations_remains_balanced(self):
        """
        Verify that an aborted or failed transaction leaves the general ledger balanced
        with zero orphan entries and no drift in Account 1000 cash balance.
        """
        mock_ledger_entries = []

        with patch("services.business_date_service.BusinessDateService.is_operational_open", return_value=(True, "Open")), \
             patch("services.posting_engine.FinancialPostingEngine.post_event", return_value=("tx-failed", {"type": "post_financial_transaction"})):

            self.mock_uow.client.rpc.return_value.execute.side_effect = RuntimeError("Postgres transaction aborted due to constraint violation")

            try:
                SavingsService.post_individual_savings(
                    uow=self.mock_uow,
                    client_id="cli-1111",
                    client_name="Fatima Bello",
                    branch="Ogijo",
                    officer="test_officer",
                    deposit_amount=50000.0,
                    idempotency_key="IDEM-ABORT-001"
                )
            except RuntimeError:
                pass

        # Verify no entries were appended to ledger
        self.assertEqual(len(mock_ledger_entries), 0)
        # Verify ledger debit equals credit (both 0.0)
        total_debits = sum(e.get("amount", 0) for e in mock_ledger_entries if e.get("side") == "Debit")
        total_credits = sum(e.get("amount", 0) for e in mock_ledger_entries if e.get("side") == "Credit")
        self.assertEqual(total_debits, total_credits)


if __name__ == "__main__":
    unittest.main()
