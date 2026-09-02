import uuid
from datetime import date, datetime
from typing import Optional, Any
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine

class TreasuryService:
    @staticmethod
    def _resolve_branch_id(uow: SupabaseUnitOfWork, branch_name: str) -> str:
        if not branch_name:
            raise ValueError("Branch name is required but was not provided.")
        import uuid
        try:
            uuid.UUID(str(branch_name))
            return str(branch_name)
        except ValueError:
            pass
        try:
            res = uow.client.table("branches").select("branch_id").eq("name", branch_name).execute()
            if res.data:
                return res.data[0]["branch_id"]
        except Exception as e:
            raise ValueError(f"Failed to resolve branch '{branch_name}': {str(e)}")
        raise ValueError(f"Branch '{branch_name}' not found.")

    @staticmethod
    def _resolve_officer_id(uow: SupabaseUnitOfWork, username: str) -> str:
        if not username:
            raise ValueError("Officer username is required but was not provided.")
        try:
            res = uow.client.table("app_users").select("id").eq("username", username).execute()
            if res.data:
                return res.data[0]["id"]
        except Exception as e:
            raise ValueError(f"Failed to resolve officer '{username}': {str(e)}")
        raise ValueError(f"Officer '{username}' not found.")

    @classmethod
    def post_treasury_transaction(cls, uow: SupabaseUnitOfWork, tx_type: str, amount: float, branch: str, officer: str, reference: str = None, remarks: str = None, posting_date: Optional[Any] = None) -> str:
        if amount <= 0:
            raise ValueError("Amount must be greater than zero.")

        branch_id = cls._resolve_branch_id(uow, branch)
        officer_id = cls._resolve_officer_id(uow, officer)
        record_id = str(uuid.uuid4())
        
        target_date = posting_date if posting_date else date.today()
        if hasattr(target_date, 'date') and callable(target_date.date):
            target_date = target_date.date()
        elif isinstance(target_date, str):
            target_date = date.fromisoformat(target_date[:10])
        p_date_str = target_date.isoformat()

        # Check Business Date Freeze & Working Day (BR-DATE-002)
        from services.business_date_service import BusinessDateService
        is_open, reason = BusinessDateService.is_operational_open(uow, branch_id, target_date)
        if not is_open:
            raise ValueError(f"Operational Restriction: Cannot post treasury transaction. {reason}.")

        # Resolve event type
        mapping = {
            "HO_TRANSFER_IN": "CashTransferred_HO_In",
            "HO_TRANSFER_OUT": "CashTransferred_HO_Out",
            "BANK_DEPOSIT": "BankDeposited",
            "BANK_WITHDRAWAL": "BankWithdrawn",
            "OFFICE_EXPENSE": "ExpenseRecorded",
            "SALARY": "SalaryPaid",
            "FLOAT": "ExpenseRecorded",
            "VAULT_ADJUSTMENT": "ExpenseRecorded",
            "INTER_BRANCH_IN": "CashTransferred_HO_In",
            "INTER_BRANCH_OUT": "CashTransferred_HO_Out",
            "INTER_AREA_IN": "CashTransferred_HO_In",
            "INTER_AREA_OUT": "CashTransferred_HO_Out"
        }
        event_type = mapping.get(tx_type, "ExpenseRecorded")
        evt_id = str(uuid.uuid4())

        event = DomainEvent(
            event_id=evt_id,
            aggregate_id=record_id,
            aggregate_type="Treasury",
            event_type=event_type,
            payload={
                "branch": branch,
                "officer": officer,
                "amount": amount,
                "reference": reference or record_id,
                "narration": remarks or f"Treasury {tx_type} transaction.",
                "transaction_type": tx_type,
                "classification": event_type,
                "date": p_date_str
            }
        )

        operations = []

        # 1. Operational Write: treasury_transactions
        operations.append({
            "type": "insert",
            "table": "treasury_transactions",
            "record": {
                "id": record_id,
                "posting_date": p_date_str,
                "branch_id": branch_id,
                "officer_id": officer_id,
                "transaction_type": tx_type,
                "amount": amount,
                "reference": reference or "",
                "remarks": remarks or ""
            }
        })

        # 2. Event Store Write
        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": event.event_id,
                "aggregate_id": event.aggregate_id,
                "aggregate_type": event.aggregate_type,
                "event_type": event.event_type,
                "version": event.version,
                "payload": event.payload,
                "status": "Completed"
            }
        })

        # 3. Deferred Financial Posting
        tx_id, post_op = FinancialPostingEngine.post_event(uow, event, defer_commit=True)
        operations.append(post_op)

        # Execute all accumulated operations atomically (ATOM-001)
        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        # Audit Log
        try:
            uow.audit.log_action(
                user=officer,
                role="Credit Officer",
                action=f"Treasury Transaction: {tx_type}",
                table_name="treasury_transactions",
                record_id=record_id,
                old_value=None,
                new_value={"amount": amount}
            )
        except Exception:
            pass

        # Rebuild projection
        try:
            uow.cashbook.rebuild_projection(uow, branch_id, target_date)
        except Exception as ex:
            print(f"[SAVINGS TRACE] Deferred cashbook rebuild failed: {ex}")

        return record_id

    @classmethod
    def reverse_treasury_transaction(cls, uow: SupabaseUnitOfWork, original_tx_id: str, reason: str, reversed_by: str) -> str:
        """
        Executes a compensating reversing entry for an erroneous treasury/manual transaction (BR-ERR-002).
        """
        res = uow.client.table("treasury_transactions").select("*").eq("id", original_tx_id).execute()
        if not res.data:
            # Also check event_store for direct events if not in treasury_transactions
            res_ev = uow.client.table("event_store").select("*").eq("event_id", original_tx_id).execute()
            if not res_ev.data:
                res_ev = uow.client.table("event_store").select("*").eq("aggregate_id", original_tx_id).execute()
            if not res_ev.data:
                raise ValueError(f"Transaction {original_tx_id} not found in treasury_transactions or event_store.")
            
            orig_ev = res_ev.data[0]
            orig_payload = orig_ev.get("payload") or {}
            orig_ev_type = orig_ev.get("event_type")
            amount = float(orig_payload.get("amount") or 0.0)
            branch_val = orig_payload.get("branch") or orig_payload.get("branch_id")
            officer_val = orig_payload.get("officer") or orig_payload.get("officer_id")
            
            reversal_ev_map = {
                "FeeCharged": "FeeReversed",
                "ExpenseRecorded": "ExpenseReversed",
                "SalaryPaid": "SalaryReversed",
                "BankDeposited": "BankWithdrawn",
                "BankWithdrawn": "BankDeposited",
                "CashTransferred_HO_In": "CashTransferred_HO_Out",
                "CashTransferred_HO_Out": "CashTransferred_HO_In"
            }
            rev_event_type = reversal_ev_map.get(orig_ev_type, "ExpenseReversed")
            
            new_id = str(uuid.uuid4())
            rev_event = DomainEvent(
                event_id=str(uuid.uuid4()),
                aggregate_id=new_id,
                aggregate_type="Treasury",
                event_type=rev_event_type,
                payload={
                    "branch": branch_val,
                    "officer": officer_val,
                    "amount": amount,
                    "reference": new_id,
                    "narration": f"REVERSAL of {orig_ev_type} ({original_tx_id}). Reason: {reason} (by {reversed_by})"
                }
            )
            operations = [{
                "type": "insert",
                "table": "event_store",
                "record": {
                    "event_id": rev_event.event_id,
                    "aggregate_id": rev_event.aggregate_id,
                    "aggregate_type": rev_event.aggregate_type,
                    "event_type": rev_event.event_type,
                    "version": rev_event.version,
                    "payload": rev_event.payload,
                    "status": "Completed"
                }
            }]
            tx_id, post_op = FinancialPostingEngine.post_event(uow, rev_event, defer_commit=True)
            operations.append(post_op)
            uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()
            
            try:
                b_id = cls._resolve_branch_id(uow, str(branch_val)) if not str(branch_val).startswith("0000") and len(str(branch_val)) < 36 else branch_val
                uow.cashbook.rebuild_projection(uow, b_id, date.today())
            except Exception:
                pass
            return new_id

        orig = res.data[0]
        orig_type = orig.get("transaction_type")
        amount = float(orig.get("amount") or 0.0)
        branch_id = orig.get("branch_id")
        officer_id = orig.get("officer_id")

        reversal_map = {
            "HO_TRANSFER_IN": ("HO_TRANSFER_OUT", "CashTransferred_HO_Out"),
            "HO_TRANSFER_OUT": ("HO_TRANSFER_IN", "CashTransferred_HO_In"),
            "INTER_BRANCH_IN": ("INTER_BRANCH_OUT", "CashTransferred_HO_Out"),
            "INTER_BRANCH_OUT": ("INTER_BRANCH_IN", "CashTransferred_HO_In"),
            "INTER_AREA_IN": ("INTER_AREA_OUT", "CashTransferred_HO_Out"),
            "INTER_AREA_OUT": ("INTER_AREA_IN", "CashTransferred_HO_In"),
            "BANK_DEPOSIT": ("BANK_WITHDRAWAL", "BankWithdrawn"),
            "BANK_WITHDRAWAL": ("BANK_DEPOSIT", "BankDeposited"),
            "OFFICE_EXPENSE": ("OFFICE_EXPENSE", "ExpenseReversed"),
            "SALARY": ("SALARY", "SalaryReversed"),
            "FLOAT": ("FLOAT", "ExpenseReversed"),
            "VAULT_ADJUSTMENT": ("VAULT_ADJUSTMENT", "ExpenseReversed")
        }
        
        comp_tx_type, rev_event_type = reversal_map.get(orig_type, ("OFFICE_EXPENSE", "ExpenseReversed"))
        new_id = str(uuid.uuid4())
        today_date = date.today()
        p_date_str = today_date.isoformat()

        operations = []

        operations.append({
            "type": "insert",
            "table": "treasury_transactions",
            "record": {
                "id": new_id,
                "posting_date": p_date_str,
                "branch_id": branch_id,
                "officer_id": officer_id,
                "transaction_type": comp_tx_type,
                "amount": amount,
                "reference": f"REV-{original_tx_id[:8]}",
                "remarks": f"REVERSAL of {orig_type} #{original_tx_id[:8]}. Reason: {reason} (by {reversed_by})"
            }
        })

        rev_event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=new_id,
            aggregate_type="Treasury",
            event_type=rev_event_type,
            payload={
                "branch": branch_id,
                "officer": officer_id,
                "amount": amount,
                "reference": new_id,
                "narration": f"REVERSAL of Treasury {orig_type} ({original_tx_id}). Reason: {reason}",
                "transaction_type": comp_tx_type,
                "classification": rev_event_type
            }
        )

        operations.append({
            "type": "insert",
            "table": "event_store",
            "record": {
                "event_id": rev_event.event_id,
                "aggregate_id": rev_event.aggregate_id,
                "aggregate_type": rev_event.aggregate_type,
                "event_type": rev_event.event_type,
                "version": rev_event.version,
                "payload": rev_event.payload,
                "status": "Completed"
            }
        })

        tx_id, post_op = FinancialPostingEngine.post_event(uow, rev_event, defer_commit=True)
        operations.append(post_op)

        uow.client.rpc("atomic_execute_operations", {"p_operations": operations}).execute()

        try:
            uow.cashbook.rebuild_projection(uow, branch_id, today_date)
        except Exception:
            pass

        return new_id
