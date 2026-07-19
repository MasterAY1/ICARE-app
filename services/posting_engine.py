from typing import Optional, List
from datetime import date, datetime
from domain.entities.event_store import DomainEvent
from domain.entities.ledger import FinancialTransaction, LedgerEntry
from interfaces.unit_of_work import UnitOfWork
from core.exceptions import RepositoryError

class FinancialPostingEngine:
    @staticmethod
    def _resolve_branch_id(uow: UnitOfWork, branch_name: str) -> str:
        if not branch_name:
            return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"
        try:
            res = uow.client.table("branches").select("branch_id").eq("name", branch_name).execute()
            if res.data:
                return res.data[0]["branch_id"]
        except Exception:
            pass
        return "1a3b5c7d-9e0f-4a2b-8c4d-6e8f0a2b4c6d"

    @staticmethod
    def _resolve_officer_id(uow: UnitOfWork, username: str) -> Optional[str]:
        if not username:
            return None
        try:
            res = uow.client.table("app_users").select("id").eq("username", username).execute()
            if res.data:
                return res.data[0]["id"]
        except Exception:
            pass
        return None

    @classmethod
    def post_event(cls, uow: UnitOfWork, event: DomainEvent) -> str:
        # 1. Check Idempotency
        if uow.event_store.is_processed(event.event_id, "posting_engine"):
            try:
                res = uow.client.table("financial_transactions").select("transaction_id").eq("event_id", event.event_id).execute()
                if res.data:
                    return res.data[0]["transaction_id"]
            except Exception:
                pass
            return "ALREADY_POSTED"

        # 2. Mark Processing
        uow.event_store.mark_processing(event.event_id, "posting_engine")

        try:
            # 3. Resolve Posting Rule
            rule = uow.posting_rules.get_rule(event.event_type, event.version)
            if not rule:
                raise ValueError(f"No active posting rule found for event type: {event.event_type} v{event.version}")

            # 4. Extract Amount
            payload = event.payload or {}
            amount = 0.0
            for key in ["amount", "deposit_amount", "withdrawal_amount", "amount_paid", "loan_amount", "fee_amount"]:
                if key in payload and payload[key] is not None:
                    amount = float(payload[key])
                    break

            if amount <= 0:
                # We skip posting or throw error. For core banking, entries must have positive amount
                raise ValueError("Transaction amount must be greater than zero.")

            # Resolve branch and officer details
            b_name = payload.get("branch", "")
            branch_id = cls._resolve_branch_id(uow, b_name)
            
            o_name = payload.get("officer", payload.get("credit_officer", ""))
            officer_id = cls._resolve_officer_id(uow, o_name)

            p_date = date.today()
            if payload.get("date"):
                try:
                    p_date = date.fromisoformat(payload["date"].split("T")[0])
                except Exception:
                    pass

            # 5. Construct journal entries
            tx = FinancialTransaction(
                transaction_id=None,
                event_id=event.event_id,
                posting_date=p_date,
                branch_id=branch_id,
                officer_id=officer_id,
                narration=payload.get("narration") or f"Event processed: {event.event_type}",
                reference=payload.get("reference") or event.event_id,
                status="Posted"
            )

            debit = LedgerEntry(
                entry_id=None,
                transaction_id="",
                branch_id=branch_id,
                account_code=rule.debit_account,
                side="Debit",
                amount=amount,
                aggregate_type=event.aggregate_type,
                aggregate_id=event.aggregate_id
            )

            credit = LedgerEntry(
                entry_id=None,
                transaction_id="",
                branch_id=branch_id,
                account_code=rule.credit_account,
                side="Credit",
                amount=amount,
                aggregate_type=event.aggregate_type,
                aggregate_id=event.aggregate_id
            )

            # 6. Post double entry to ledger
            print(f"[SAVINGS TRACE] Posting double entry event. ID: {event.event_id}, Type: {event.event_type}, Payload: {event.payload}")
            tx_id = uow.ledger.create_transaction(tx, [debit, credit])
            print(f"[SAVINGS TRACE] Ledger transaction created successfully! TxID: {tx_id}")

            try:
                # 7. Mark Completed
                uow.event_store.mark_posted(event.event_id, "posting_engine")
                print(f"[SAVINGS TRACE] Event marked posted in event_store: {event.event_id}")

                # 8. Trigger Projection Updates
                uow.cashbook.rebuild_projection(branch_id, p_date)
                print(f"[SAVINGS TRACE] Cashbook projection rebuild completed for branch_id: {branch_id}")
            except Exception as inner_ex:
                # Rollback transaction posting from ledger
                try:
                    uow.client.table("financial_ledger_entries").delete().eq("transaction_id", tx_id).execute()
                    uow.client.table("financial_transactions").delete().eq("transaction_id", tx_id).execute()
                except Exception:
                    pass
                raise inner_ex

            return tx_id

        except Exception as e:
            uow.event_store.mark_failed(event.event_id, "posting_engine", str(e))
            raise e

    @classmethod
    def reverse_transaction(cls, uow: UnitOfWork, transaction_id: str, narration: str = None) -> str:
        # 1. Fetch original transaction
        original_tx = uow.ledger.find_transaction_by_id(transaction_id)
        if not original_tx:
            raise ValueError(f"Transaction {transaction_id} not found")

        if original_tx.status == "Reversed":
            raise ValueError(f"Transaction {transaction_id} is already reversed")

        # 2. Fetch original entries
        original_entries = uow.ledger.get_transaction_entries(transaction_id)

        # 3. Create reversing entries
        reversing_entries = []
        for e in original_entries:
            reversing_entries.append(LedgerEntry(
                entry_id=None,
                transaction_id="",
                branch_id=e.branch_id,
                account_code=e.account_code,
                side="Credit" if e.side == "Debit" else "Debit",
                amount=e.amount,
                aggregate_type=e.aggregate_type,
                aggregate_id=e.aggregate_id
            ))

        # 4. Construct reversing transaction header
        reversing_tx = FinancialTransaction(
            transaction_id=None,
            event_id=None,
            posting_date=date.today(),
            branch_id=original_tx.branch_id,
            officer_id=original_tx.officer_id,
            narration=narration or f"Offsetting Reversal of {transaction_id}",
            reference=original_tx.reference,
            status="Reversed",
            reversal_of=transaction_id,
            currency_code=original_tx.currency_code
        )

        # 5. Insert reversing journal header and entries
        reversal_id = uow.ledger.create_transaction(reversing_tx, reversing_entries)

        # 6. Update original transaction header status to 'Reversed'
        uow.client.table("financial_transactions").update({"status": "Reversed"}).eq("transaction_id", transaction_id).execute()

        # 7. Rebuild Cashbook projection
        uow.cashbook.rebuild_projection(original_tx.branch_id, original_tx.posting_date)
        if original_tx.posting_date != reversing_tx.posting_date:
            uow.cashbook.rebuild_projection(original_tx.branch_id, reversing_tx.posting_date)

        return reversal_id
