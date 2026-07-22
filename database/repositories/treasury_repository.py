from typing import List, Optional, Dict, Any
from datetime import date, datetime
from database.repositories.base_repository import BaseRepository

class TreasuryTransactionRepository(BaseRepository):
    """Repository for branch-level treasury transactions backed by treasury_transactions table"""
    def __init__(self, client):
        super().__init__(client)
        self.table_name = "treasury_transactions"

    def create_treasury_entry(
        self,
        branch_id: str,
        transaction_type: str,
        amount: float,
        officer_id: Optional[str] = None,
        source_branch: Optional[str] = None,
        destination_branch: Optional[str] = None,
        reference: Optional[str] = None,
        remarks: Optional[str] = None,
        posting_date: Optional[date] = None
    ) -> Dict[str, Any]:
        p_date = (posting_date or date.today()).isoformat()
        payload = {
            "branch_id": branch_id,
            "officer_id": officer_id or "00000000-0000-0000-0000-000000000000",
            "transaction_type": transaction_type,
            "amount": float(amount),
            "source_branch": source_branch,
            "destination_branch": destination_branch,
            "reference": reference or f"TREASURY-{transaction_type}-{datetime.now().strftime('%Y%m%d%H%M%S')}",
            "remarks": remarks or f"{transaction_type} branch treasury movement",
            "created_at": datetime.now().isoformat()
        }
        res = self.client.table(self.table_name).insert(payload).execute()
        return res.data[0] if res.data else payload

    def find_by_branch_and_date(
        self,
        branch_id: str,
        posting_date: date,
        transaction_type: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        query = self.client.table(self.table_name).select("*").eq("branch_id", branch_id)
        if transaction_type:
            query = query.eq("transaction_type", transaction_type)
        start_ts = f"{posting_date.isoformat()}T00:00:00"
        end_ts = f"{posting_date.isoformat()}T23:59:59"
        query = query.gte("created_at", start_ts).lte("created_at", end_ts)
        res = query.execute()
        return res.data or []

class BankDepositRepository(BaseRepository):
    """CO & Branch Bank Deposit repository"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_deposit(self, branch_id: str, officer_id: str, amount: float, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id,
            officer_id=officer_id,
            transaction_type="BANK_DEPOSIT",
            amount=amount,
            reference=reference,
            remarks=remarks,
            posting_date=posting_date
        )

class BankWithdrawalRepository(BaseRepository):
    """CO & Branch Bank Withdrawal repository"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_withdrawal(self, branch_id: str, officer_id: str, amount: float, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id,
            officer_id=officer_id,
            transaction_type="BANK_WITHDRAWAL",
            amount=amount,
            reference=reference,
            remarks=remarks,
            posting_date=posting_date
        )

class OfficeExpenseRepository(BaseRepository):
    """Branch Treasury Office Expenses repository"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_expense(self, branch_id: str, officer_id: str, amount: float, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id,
            officer_id=officer_id,
            transaction_type="OFFICE_EXPENSE",
            amount=amount,
            reference=reference,
            remarks=remarks,
            posting_date=posting_date
        )

class FundTransferRepository(BaseRepository):
    """Branch Treasury Head Office & Inter-Branch Transfers repository"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_transfer(self, branch_id: str, transaction_type: str, amount: float, officer_id: str = None, source_branch: str = None, destination_branch: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id,
            officer_id=officer_id,
            transaction_type=transaction_type,
            amount=amount,
            source_branch=source_branch,
            destination_branch=destination_branch,
            reference=reference,
            remarks=remarks,
            posting_date=posting_date
        )
