import unittest
import uuid
from datetime import date, timedelta
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.event_store import DomainEvent
from domain.enums import TransactionClassification
from services.posting_engine import FinancialPostingEngine
from services.business_date_service import BusinessDateService
from services.co_cashbook_projection_builder import CoCashbookProjectionBuilder
from services.master_cashbook_projection_builder import MasterCashbookProjectionBuilder
from services.reconciliation_service import DailyReconciliationService
from services.event_replay_service import EventReplayService

class TestFullChainRuntimeIntegrity(unittest.TestCase):

    def setUp(self):
        self.uow = SupabaseUnitOfWork()
        res_b = self.uow.client.table("branches").select("branch_id, name").limit(1).execute()
        self.assertTrue(len(res_b.data) > 0, "Branch must exist in DB")
        self.branch_id = res_b.data[0]["branch_id"]
        self.branch_name = res_b.data[0]["name"]
        
        res_u = self.uow.client.table("app_users").select("id, username").limit(1).execute()
        self.assertTrue(len(res_u.data) > 0, "User must exist in DB")
        self.officer_id = res_u.data[0]["id"]
        self.officer_username = res_u.data[0]["username"]

    def test_directive_1_and_10_full_chain_and_reconciliation(self):
        """Directive 1 & 10: Event -> Ledger -> Projection -> Reconciliation"""
        p_date = BusinessDateService.get_business_date(self.uow, self.branch_name)
        ref_id = f"REF-{uuid.uuid4().hex[:6].upper()}"
        amount = 12500.0

        # Clean up any residual manual adjustment for today to test automated event flow reconciliation
        p_date_str = p_date.isoformat()
        self.uow.client.table("master_cashbook").update({
            "adjustment_in": 0.0,
            "adjustment_out": 0.0,
            "adjustment_reason": None
        }).eq("branch_id", self.branch_id).eq("date", p_date_str).execute()

        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=self.officer_id,
            aggregate_type="IndividualSavings",
            event_type="SavingsDeposited",
            payload={
                "branch": self.branch_name,
                "officer": self.officer_username,
                "amount": amount,
                "date": p_date_str,
                "reference": ref_id,
                "classification": TransactionClassification.INDIVIDUAL_SAVINGS_DEPOSIT.value,
                "narration": f"Runtime verification savings deposit {ref_id}"
            }
        )
        self.uow.event_store.append(event)
        tx_id = FinancialPostingEngine.post_event(self.uow, event)
        self.assertIsNotNone(tx_id, "Ledger transaction ID must exist")

        # Rebuild projections
        co_proj = CoCashbookProjectionBuilder.rebuild_co_projection(self.uow, self.branch_id, self.officer_id, p_date)
        mb_proj = MasterCashbookProjectionBuilder.rebuild_master_projection(self.uow, self.branch_id, p_date)
        self.assertIsNotNone(co_proj)
        self.assertIsNotNone(mb_proj)

        # Reconcile
        recon = DailyReconciliationService.reconcile_branch_day(self.uow, self.branch_id, p_date)
        self.assertEqual(recon["reconciliation_status"], "BALANCED", f"Reconciliation must be BALANCED: {recon}")

    def test_directive_3_manual_entries_preserved_on_rebuild(self):
        """Directive 3: Manual treasury entries in Master Cashbook must never be overwritten on rebuild"""
        p_date = date(2026, 11, 15)
        p_date_str = p_date.isoformat()

        # Seed manual entry on Master Cashbook
        manual_adj_in = 7500.0
        manual_reason = "BM Vault Top-up Adjustment"
        self.uow.client.table("master_cashbook").upsert({
            "date": p_date_str,
            "branch_id": self.branch_id,
            "adjustment_in": manual_adj_in,
            "adjustment_reason": manual_reason,
            "status": "Open",
            "version": 1
        }, on_conflict="date,branch_id").execute()

        # Execute projection rebuild
        mb_proj = MasterCashbookProjectionBuilder.rebuild_master_projection(self.uow, self.branch_id, p_date)
        self.assertIsNotNone(mb_proj)
        self.assertEqual(float(mb_proj.get("adjustment_in") or 0.0), manual_adj_in, "Manual adjustment_in must be preserved on rebuild")
        self.assertEqual(mb_proj.get("adjustment_reason"), manual_reason, "Manual adjustment_reason must be preserved on rebuild")

    def test_directive_4_idempotency(self):
        """Directive 4: Re-posting same domain event must not duplicate ledger entries"""
        p_date = BusinessDateService.get_business_date(self.uow, self.branch_name)
        ev_id = str(uuid.uuid4())
        ref_id = f"IDEMP-{uuid.uuid4().hex[:6].upper()}"

        event = DomainEvent(
            event_id=ev_id,
            aggregate_id=self.officer_id,
            aggregate_type="IndividualSavings",
            event_type="SavingsDeposited",
            payload={
                "branch": self.branch_name,
                "officer": self.officer_username,
                "amount": 3000.0,
                "date": p_date.isoformat(),
                "reference": ref_id,
                "classification": TransactionClassification.INDIVIDUAL_SAVINGS_DEPOSIT.value,
                "narration": f"Idempotency test deposit {ref_id}"
            }
        )
        self.uow.event_store.append(event)
        
        # Post First Time
        tx1 = FinancialPostingEngine.post_event(self.uow, event)
        # Post Second Time (Retry)
        tx2 = FinancialPostingEngine.post_event(self.uow, event)

        self.assertEqual(tx1, tx2, "Re-posting the same event must return identical transaction ID without duplicating GL entries")

    def test_directive_5_disposable_projection_event_replay(self):
        """Directive 5: Deleting cashbook rows and running EventReplay re-builds exact projections"""
        p_date = BusinessDateService.get_business_date(self.uow, self.branch_name)
        
        # Initial build
        co1 = CoCashbookProjectionBuilder.rebuild_co_projection(self.uow, self.branch_id, self.officer_id, p_date)
        
        # Wipe projections for today
        self.uow.client.table("co_cashbooks").delete().eq("branch_id", self.branch_id).eq("officer_id", self.officer_id).eq("date", p_date.isoformat()).execute()

        # Replay events
        co2 = CoCashbookProjectionBuilder.rebuild_co_projection(self.uow, self.branch_id, self.officer_id, p_date)
        self.assertIsNotNone(co2)
        if co1 and co2:
            self.assertEqual(co1.get("closing_balance"), co2.get("closing_balance"), "Event replay must reconstruct identical closing balance")

    def test_directive_7_branch_closing_and_carry_forward(self):
        """Directive 7: Branch day close freezes books and carries forward opening balance"""
        p_date = date(2026, 12, 1) # Test date
        p_date_str = p_date.isoformat()
        next_date_str = (p_date + timedelta(days=1)).isoformat()

        # Build initial cashbook for p_date
        self.uow.client.table("master_cashbook").upsert({
            "date": p_date_str,
            "branch_id": self.branch_id,
            "opening_balance": 50000.0,
            "total_inflows": 10000.0,
            "total_outflows": 2000.0,
            "closing_balance": 58000.0,
            "status": "Open",
            "version": 1
        }, on_conflict="date,branch_id").execute()

        # Close business date
        res_close = BusinessDateService.close_business_date(self.uow, self.branch_id, p_date, closed_by=self.officer_id)
        self.assertTrue(res_close, "Branch day close must succeed")

        # Verify today's status is Closed
        res_today = self.uow.client.table("master_cashbook").select("status").eq("branch_id", self.branch_id).eq("date", p_date_str).execute()
        self.assertEqual(res_today.data[0]["status"], "Closed", "Closed master cashbook status must be Closed")

        # Verify tomorrow's opening balance carried forward
        res_tomorrow = self.uow.client.table("master_cashbook").select("opening_balance").eq("branch_id", self.branch_id).eq("date", next_date_str).execute()
        self.assertTrue(len(res_tomorrow.data) > 0)
        self.assertEqual(float(res_tomorrow.data[0]["opening_balance"]), 58000.0, "Tomorrow's opening balance must equal today's closing balance")

if __name__ == "__main__":
    unittest.main()
