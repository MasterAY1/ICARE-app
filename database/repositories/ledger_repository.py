from typing import List, Optional
from datetime import date
from domain.entities.ledger import FinancialTransaction, LedgerEntry
from interfaces.ledger_repository import LedgerRepository
from database.repositories.base_repository import BaseRepository
from core.exceptions import RepositoryError

class SupabaseLedgerRepository(BaseRepository[LedgerEntry], LedgerRepository):
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "financial_ledger_entries"

    def create_transaction(self, tx: FinancialTransaction, entries: List[LedgerEntry]) -> str:
        # Validate Debit = Credit
        debits = sum(e.amount for e in entries if e.side == "Debit")
        credits = sum(e.amount for e in entries if e.side == "Credit")
        if abs(debits - credits) > 1e-6:
            raise RepositoryError(f"Unbalanced transaction: Debits ({debits}) must equal Credits ({credits})")

        # Create financial transaction header
        tx_data = {
            "posting_date": tx.posting_date.isoformat() if hasattr(tx.posting_date, "isoformat") else tx.posting_date,
            "branch_id": tx.branch_id,
            "officer_id": tx.officer_id,
            "narration": tx.narration,
            "reference": tx.reference,
            "status": tx.status,
            "reversal_of": tx.reversal_of,
            "currency_code": tx.currency_code
        }
        if tx.transaction_id:
            tx_data["transaction_id"] = tx.transaction_id
        if tx.event_id:
            tx_data["event_id"] = tx.event_id

        # Prepare entries payload
        entries_data = []
        for e in entries:
            entries_data.append({
                "branch_id": e.branch_id or tx.branch_id,
                "account_code": e.account_code,
                "side": e.side,
                "amount": float(e.amount),
                "aggregate_type": e.aggregate_type,
                "aggregate_id": e.aggregate_id
            })

        payload = {
            "header_payload": tx_data,
            "entries_payload": entries_data
        }

        try:
            res = self.client.rpc("post_financial_transaction", payload).execute()
            if not res.data:
                raise RepositoryError("Failed to execute atomic financial posting RPC")
            return res.data
        except Exception as ex:
            raise RepositoryError(f"Atomic financial posting failed: {str(ex)}")

    def get_ledger_entries(self, branch_id: Optional[str] = None, account_code: Optional[str] = None) -> List[LedgerEntry]:
        query = self.client.table(self.table_name).select("*")
        if branch_id:
            query = query.eq("branch_id", branch_id)
        if account_code:
            query = query.eq("account_code", account_code)
            
        res = query.execute()
        entries = []
        for r in res.data:
            entries.append(LedgerEntry(
                entry_id=str(r.get("entry_id")),
                transaction_id=str(r.get("transaction_id")),
                branch_id=str(r.get("branch_id")),
                account_code=str(r.get("account_code")),
                side=str(r.get("side")),
                amount=float(r.get("amount")),
                aggregate_type=str(r.get("aggregate_type")),
                aggregate_id=str(r.get("aggregate_id")),
                created_at=r.get("created_at")
            ))
        return entries

    def find_transaction_by_id(self, transaction_id: str) -> Optional[FinancialTransaction]:
        res = self.client.table("financial_transactions").select("*").eq("transaction_id", transaction_id).execute()
        if res.data:
            r = res.data[0]
            # Parse date string safely
            p_date_str = r.get("posting_date")
            p_date = date.fromisoformat(p_date_str) if p_date_str else date.today()
            return FinancialTransaction(
                transaction_id=str(r.get("transaction_id")),
                event_id=str(r.get("event_id")) if r.get("event_id") else None,
                posting_date=p_date,
                branch_id=str(r.get("branch_id")),
                officer_id=str(r.get("officer_id")) if r.get("officer_id") else None,
                narration=r.get("narration"),
                reference=r.get("reference"),
                status=str(r.get("status")),
                reversal_of=str(r.get("reversal_of")) if r.get("reversal_of") else None,
                currency_code=str(r.get("currency_code")),
                created_at=r.get("created_at")
            )
        return None

    def get_transaction_entries(self, transaction_id: str) -> List[LedgerEntry]:
        res = self.client.table(self.table_name).select("*").eq("transaction_id", transaction_id).execute()
        entries = []
        for r in res.data:
            entries.append(LedgerEntry(
                entry_id=str(r.get("entry_id")),
                transaction_id=str(r.get("transaction_id")),
                branch_id=str(r.get("branch_id")),
                account_code=str(r.get("account_code")),
                side=str(r.get("side")),
                amount=float(r.get("amount")),
                aggregate_type=str(r.get("aggregate_type")),
                aggregate_id=str(r.get("aggregate_id")),
                created_at=r.get("created_at")
            ))
        return entries

    # Enforce Ledger Immutability
    def update(self, entity: LedgerEntry):
        raise NotImplementedError("Immutability Violation: Ledger entries cannot be updated.")

    def delete(self, id: str) -> bool:
        raise NotImplementedError("Immutability Violation: Ledger entries cannot be deleted.")
