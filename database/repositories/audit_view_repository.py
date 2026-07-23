"""
SupabaseAuditViewRepository — Phase 8.1
Provides read-only access to virtual audit ledgers across Fee, Treasury, Savings,
Loans, Collection Performance, and Cashbook sub-systems.
Supports strict parameter filtering (branch_id, officer_id, client_id, date_from, date_to).
"""
from typing import List, Dict, Any, Optional
from datetime import date
from database.repositories.base_repository import BaseRepository


class SupabaseAuditViewRepository(BaseRepository):
    """Read-only repository for Audit Center virtual ledgers."""

    def __init__(self, client):
        super().__init__(client)

    # -------------------------------------------------------------------------
    # 1. Fee Audit Ledgers (backed by public.fees via fee_type)
    # -------------------------------------------------------------------------
    def get_fee_ledger(
        self,
        fee_type: str,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        client_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch fee records for a specific fee_type with optional filters."""
        query = self.client.table("fees").select("*")
        if fee_type and fee_type != "ALL":
            query = query.eq("fee_type", fee_type)
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if client_id:
            query = query.eq("client_id", client_id)
        if date_from:
            query = query.gte("posting_date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("posting_date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    # -------------------------------------------------------------------------
    # 2. Treasury Audit Ledgers (backed by public.treasury_transactions)
    # -------------------------------------------------------------------------
    def get_treasury_ledger(
        self,
        transaction_type: str,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch treasury movement records for a specific transaction_type."""
        query = self.client.table("treasury_transactions").select("*")
        if transaction_type and transaction_type != "ALL":
            if isinstance(transaction_type, list):
                query = query.in_("transaction_type", transaction_type)
            else:
                query = query.eq("transaction_type", transaction_type)
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if date_from:
            query = query.gte("posting_date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("posting_date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    # -------------------------------------------------------------------------
    # 3. Operational Loan Audit Ledgers
    # -------------------------------------------------------------------------
    def get_loan_disbursements(
        self,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch disbursed/active/completed loan records."""
        query = self.client.table("loans").select("*").in_("status", ["Disbursed", "Active", "Completed", "Closed"])
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if date_from:
            query = query.gte("date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    def get_loan_repayments(
        self,
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        client_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch repayment records from public.repayments."""
        query = self.client.table("repayments").select("*")
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if client_id:
            query = query.eq("client_id", client_id)
        if date_from:
            query = query.gte("date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    # -------------------------------------------------------------------------
    # 4. Savings Audit Ledgers
    # -------------------------------------------------------------------------
    def get_savings_ledger(
        self,
        savings_table: str,  # "individual_savings", "group_savings", "laps_savings"
        branch_id: Optional[str] = None,
        officer_id: Optional[str] = None,
        date_from: Optional[date] = None,
        date_to: Optional[date] = None,
        limit: int = 200
    ) -> List[Dict[str, Any]]:
        """Fetch savings records from specified savings ledger table."""
        if savings_table not in ["individual_savings", "group_savings", "laps_savings", "internal_savings"]:
            raise ValueError(f"Invalid savings table: {savings_table}")

        query = self.client.table(savings_table).select("*")
        if branch_id and branch_id != "All":
            query = query.eq("branch_id", branch_id)
        if officer_id and officer_id != "All":
            query = query.eq("officer_id", officer_id)
        if date_from:
            query = query.gte("posting_date", date_from.isoformat() if isinstance(date_from, date) else date_from)
        if date_to:
            query = query.lte("posting_date", date_to.isoformat() if isinstance(date_to, date) else date_to)

        query = query.order("created_at", desc=True).limit(limit)
        res = query.execute()
        return res.data or []

    # -------------------------------------------------------------------------
    # Read-only mutation safeguards
    # -------------------------------------------------------------------------
    def create(self, entity: Any) -> Any:
        raise NotImplementedError("Audit views are strictly read-only.")

    def update(self, entity: Any) -> Any:
        raise NotImplementedError("Audit views are strictly read-only.")

    def delete(self, id: str) -> bool:
        raise NotImplementedError("Audit views are strictly read-only.")
