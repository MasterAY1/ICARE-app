import unittest
import uuid
from datetime import date
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.event_store import DomainEvent
from domain.enums import TransactionClassification
from services.posting_engine import FinancialPostingEngine
from services.business_date_service import BusinessDateService

class TestProjectionValidation(unittest.TestCase):
    def test_full_chain_projection_consistency(self):
        with SupabaseUnitOfWork() as uow:
            # 1. Resolve branch and officer
            res_b = uow.client.table("branches").select("branch_id, name").limit(1).execute()
            self.assertTrue(len(res_b.data) > 0, "At least one branch must exist in DB")
            branch_id = res_b.data[0]["branch_id"]
            branch_name = res_b.data[0]["name"]
            
            res_u = uow.client.table("app_users").select("id, username").limit(1).execute()
            self.assertTrue(len(res_u.data) > 0, "At least one user must exist in DB")
            officer_id = res_u.data[0]["id"]
            officer_username = res_u.data[0]["username"]

            p_date = BusinessDateService.get_business_date(uow, branch_name)
            p_date_str = p_date.isoformat()
            ref_id = f"TEST-TXN-{uuid.uuid4().hex[:6].upper()}"
            test_amount = 5000.0

            # 2. Emit SavingsDeposited event
            event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=officer_id,
                aggregate_type="IndividualSavings",
                event_type="SavingsDeposited",
                payload={
                    "branch": branch_name,
                    "officer": officer_username,
                    "amount": test_amount,
                    "date": p_date_str,
                    "reference": ref_id,
                    "classification": TransactionClassification.INDIVIDUAL_SAVINGS_DEPOSIT.value,
                    "narration": f"Test validation savings deposit {ref_id}"
                }
            )
            uow.event_store.append(event)
            tx_id = FinancialPostingEngine.post_event(uow, event)
            self.assertIsNotNone(tx_id, "Ledger transaction ID must not be None")

            # 3. Verify Ledger double-entry balance
            entries = uow.ledger.get_transaction_entries(tx_id)
            self.assertTrue(len(entries) >= 2, "Transaction must have at least 2 entries (debit & credit)")
            debit_sum = sum(e.amount for e in entries if e.side == "Debit")
            credit_sum = sum(e.amount for e in entries if e.side == "Credit")
            self.assertEqual(debit_sum, credit_sum, f"Ledger must balance: Debit {debit_sum} != Credit {credit_sum}")

            # 4. Verify CO Cashbook projection
            res_co = uow.client.table("co_cashbooks").select("*").eq("date", p_date_str).eq("branch_id", branch_id).eq("officer_id", officer_id).execute()
            self.assertTrue(len(res_co.data) > 0, "CO Cashbook row must exist for officer")
            co_row = res_co.data[0]
            self.assertGreaterEqual(float(co_row.get("savings_deposit") or 0), test_amount, "CO Cashbook savings deposit must reflect test amount")

            # 5. Verify Master Cashbook projection consistency
            res_mb = uow.client.table("master_cashbook").select("*").eq("date", p_date_str).eq("branch_id", branch_id).execute()
            self.assertTrue(len(res_mb.data) > 0, "Master Cashbook row must exist for branch")
            mb_row = res_mb.data[0]
            self.assertGreaterEqual(float(mb_row.get("savings_deposit") or 0), float(co_row.get("savings_deposit") or 0), "Master Cashbook savings deposit must equal or exceed CO Cashbook")

if __name__ == "__main__":
    unittest.main()
