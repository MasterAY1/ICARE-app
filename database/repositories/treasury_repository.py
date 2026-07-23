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

class StaffSalaryRepository(BaseRepository):
    """Staff Salary payments repository — treasury_transactions with type STAFF_SALARY"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_salary(self, branch_id: str, officer_id: str, amount: float, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="STAFF_SALARY", amount=amount,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def find_by_branch_and_date(self, branch_id: str, posting_date: date):
        return self.treasury_repo.find_by_branch_and_date(branch_id, posting_date, "STAFF_SALARY")

class HeadOfficeTransferRepository(BaseRepository):
    """Head Office fund transfers — treasury_transactions with type HO_TRANSFER_IN / HO_TRANSFER_OUT"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_transfer_in(self, branch_id: str, amount: float, officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="HO_TRANSFER_IN", amount=amount,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def create_transfer_out(self, branch_id: str, amount: float, officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="HO_TRANSFER_OUT", amount=amount,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def find_by_branch_and_date(self, branch_id: str, posting_date: date, direction: str = None):
        t_type = direction if direction in ("HO_TRANSFER_IN", "HO_TRANSFER_OUT") else None
        return self.treasury_repo.find_by_branch_and_date(branch_id, posting_date, t_type)

class BranchTransferRepository(BaseRepository):
    """Inter-branch fund transfers — treasury_transactions with type BRANCH_TRANSFER_IN / BRANCH_TRANSFER_OUT"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_transfer_in(self, branch_id: str, amount: float, source_branch: str = None, officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="BRANCH_TRANSFER_IN", amount=amount,
            source_branch=source_branch,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def create_transfer_out(self, branch_id: str, amount: float, destination_branch: str = None, officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="BRANCH_TRANSFER_OUT", amount=amount,
            destination_branch=destination_branch,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def find_by_branch_and_date(self, branch_id: str, posting_date: date, direction: str = None):
        t_type = direction if direction in ("BRANCH_TRANSFER_IN", "BRANCH_TRANSFER_OUT") else None
        return self.treasury_repo.find_by_branch_and_date(branch_id, posting_date, t_type)

class OtherAreaTransferRepository(BaseRepository):
    """Transfers to other operational areas — treasury_transactions with type OTHER_AREA_TRANSFER"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_transfer(self, branch_id: str, amount: float, destination_branch: str = None, officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="OTHER_AREA_TRANSFER", amount=amount,
            destination_branch=destination_branch,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def find_by_branch_and_date(self, branch_id: str, posting_date: date):
        return self.treasury_repo.find_by_branch_and_date(branch_id, posting_date, "OTHER_AREA_TRANSFER")

class AssetProgramRepository(BaseRepository):
    """Asset program funding — treasury_transactions with type ASSET_PROGRAM"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_funding(self, branch_id: str, amount: float, officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="ASSET_PROGRAM", amount=amount,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def find_by_branch_and_date(self, branch_id: str, posting_date: date):
        return self.treasury_repo.find_by_branch_and_date(branch_id, posting_date, "ASSET_PROGRAM")

class ProductFinanceRepository(BaseRepository):
    """Product finance funding — treasury_transactions with type PRODUCT_FINANCE"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_funding(self, branch_id: str, amount: float, officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type="PRODUCT_FINANCE", amount=amount,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def find_by_branch_and_date(self, branch_id: str, posting_date: date):
        return self.treasury_repo.find_by_branch_and_date(branch_id, posting_date, "PRODUCT_FINANCE")

class CashbookAdjustmentRepository(BaseRepository):
    """Manual cashbook adjustments — treasury_transactions with type CASHBOOK_ADJUSTMENT"""
    def __init__(self, client):
        super().__init__(client)
        self.treasury_repo = TreasuryTransactionRepository(client)

    def create_adjustment(self, branch_id: str, amount: float, direction: str = "IN", officer_id: str = None, reference: str = None, remarks: str = None, posting_date: date = None):
        adj_type = "CASHBOOK_ADJUSTMENT_IN" if direction == "IN" else "CASHBOOK_ADJUSTMENT_OUT"
        return self.treasury_repo.create_treasury_entry(
            branch_id=branch_id, officer_id=officer_id,
            transaction_type=adj_type, amount=amount,
            reference=reference, remarks=remarks, posting_date=posting_date
        )

    def find_by_branch_and_date(self, branch_id: str, posting_date: date):
        return self.treasury_repo.find_by_branch_and_date(branch_id, posting_date)
