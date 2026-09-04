"""
Collections schemas.
"""
from typing import List, Optional
from pydantic import BaseModel


class CollectionSheetMember(BaseModel):
    client_id: str
    client_code: str
    client_name: str
    loan_product: str
    active_credit: float
    remaining_balance: float
    expected_repayment: float
    savings_balance: float
    is_asset: bool = False


class CollectionSheetResponse(BaseModel):
    group_name: str
    date: str
    meeting_day: str
    is_open: bool
    open_reason: str
    members: List[CollectionSheetMember] = []
