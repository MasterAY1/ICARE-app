import uuid
from datetime import date, datetime
from database.repositories.unit_of_work import SupabaseUnitOfWork
from domain.entities.event_store import DomainEvent
from services.posting_engine import FinancialPostingEngine

class TreasuryService:
    @staticmethod
    def _resolve_branch_id(uow: SupabaseUnitOfWork, branch_name: str) -> str:
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
    def _resolve_officer_id(uow: SupabaseUnitOfWork, username: str) -> str:
        if not username:
            return "00000000-0000-0000-0000-000000000000"
        try:
            res = uow.client.table("app_users").select("id").eq("username", username).execute()
            if res.data:
                return res.data[0]["id"]
        except Exception:
            pass
        return "00000000-0000-0000-0000-000000000000"

    @classmethod
    def post_treasury_transaction(cls, uow: SupabaseUnitOfWork, tx_type: str, amount: float, branch: str, officer: str, reference: str = None, remarks: str = None) -> str:
        if amount <= 0:
            raise ValueError("Amount must be greater than zero.")

        branch_id = cls._resolve_branch_id(uow, branch)
        officer_id = cls._resolve_officer_id(uow, officer)

        # 1. Persist operational data
        res = uow.client.table("treasury_transactions").insert({
            "posting_date": date.today().isoformat(),
            "branch_id": branch_id,
            "officer_id": officer_id,
            "transaction_type": tx_type,
            "amount": amount,
            "reference": reference or "",
            "remarks": remarks or ""
        }).execute()
        
        if not res.data:
            raise ValueError("Failed to insert treasury transaction record")
            
        record_id = res.data[0]["id"]

        # 2. Audit log
        uow.audit.log_action(
            user=officer,
            role="Credit Officer",
            action=f"Treasury Transaction: {tx_type}",
            table_name="treasury_transactions",
            record_id=record_id,
            old_value=None,
            new_value={"amount": amount}
        )

        # 3. Resolve event type
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
            "INTER_BRANCH_OUT": "CashTransferred_HO_Out"
        }
        event_type = mapping.get(tx_type, "ExpenseRecorded")

        # 4. Create Event & Post
        event = DomainEvent(
            event_id=str(uuid.uuid4()),
            aggregate_id=record_id,
            aggregate_type="Treasury",
            event_type=event_type,
            payload={
                "branch": branch,
                "officer": officer,
                "amount": amount,
                "reference": reference or record_id,
                "narration": remarks or f"Treasury {tx_type} transaction."
            }
        )
        uow.event_store.append(event)
        FinancialPostingEngine.post_event(uow, event)

        return record_id
