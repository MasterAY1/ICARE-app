from typing import List, Optional, Dict, Any
from datetime import date, datetime
from database.repositories.base_repository import BaseRepository

class BaseFeeRepository(BaseRepository):
    """Base repository for operational fee ledgers backed by public.fees table"""
    def __init__(self, client, fee_type: str):
        super().__init__(client)
        self.table_name = "fees"
        self.fee_type = fee_type

    def create_fee_entry(
        self,
        branch_id: str,
        officer_id: str,
        amount: float,
        fee_type: Optional[str] = None,
        client_id: Optional[str] = None,
        loan_id: Optional[str] = None,
        reference: Optional[str] = None,
        narration: Optional[str] = None,
        posting_date: Optional[date] = None
    ) -> Dict[str, Any]:
        target_fee_type = fee_type or self.fee_type
        p_date = (posting_date or date.today()).isoformat()
        payload = {
            "branch_id": branch_id,
            "officer_id": officer_id,
            "fee_type": target_fee_type,
            "amount": float(amount),
            "client_id": client_id,
            "loan_id": loan_id,
            "reference": reference or f"{target_fee_type}-{datetime.now().strftime('%Y%m%d%H%M%S')}",
            "remarks": narration or f"{target_fee_type} transaction",
            "created_at": datetime.now().isoformat()
        }
        res = self.client.table(self.table_name).insert(payload).execute()
        return res.data[0] if res.data else payload

    def find_by_branch_and_date(
        self,
        branch_id: str,
        posting_date: date,
        officer_id: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        query = self.client.table(self.table_name).select("*").eq("branch_id", branch_id).eq("fee_type", self.fee_type)
        if officer_id:
            query = query.eq("officer_id", officer_id)
        start_ts = f"{posting_date.isoformat()}T00:00:00"
        end_ts = f"{posting_date.isoformat()}T23:59:59"
        query = query.gte("created_at", start_ts).lte("created_at", end_ts)
        res = query.execute()
        return res.data or []

    def get_total_amount(
        self,
        branch_id: str,
        posting_date: date,
        officer_id: Optional[str] = None
    ) -> float:
        entries = self.find_by_branch_and_date(branch_id, posting_date, officer_id)
        return sum(float(e.get("amount", 0.0)) for e in entries)


class ProcessingFeeRepository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="PROCESSING_FEE")

class PassbookRepository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="PASSBOOK")

class CreditFormRepository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="CREDIT_FORM")

class CreditFormDamageRepository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="CREDIT_FORM_DAMAGE")

class BonusRepository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="BONUS")

class MiscFeeRepository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="MISC_FEE")

class ContingencyRepository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="CONTINGENCY")

class Markup11Repository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="MARKUP_11")

class Markup20Repository(BaseFeeRepository):
    def __init__(self, client):
        super().__init__(client, fee_type="MARKUP_20")
