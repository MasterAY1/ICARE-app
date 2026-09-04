"""
Portfolio schemas.
"""
from typing import List, Dict, Any, Optional
from pydantic import BaseModel


class PortfolioMetrics(BaseModel):
    total_clients: int = 0
    total_active_credit: float = 0.0
    total_outstanding: float = 0.0
    total_fixed_repayment: float = 0.0
    total_paid: float = 0.0
    collection_rate: float = 0.0
    par_30_amount: float = 0.0
    par_30_count: int = 0


class GroupPortfolioItem(BaseModel):
    group_name: str
    total_clients: int
    total_savings_balance: float
    total_active_loan: float
    total_outstanding_balance: float
    total_fixed_repayment: float
    total_paid: float


class ClientPortfolioItem(BaseModel):
    client_id: str
    client_code: str
    client_name: str
    group_name: str
    savings_balance: float
    active_loan: float
    outstanding_balance: float
    status: str


class PortfolioResponse(BaseModel):
    metrics: PortfolioMetrics
    groups: List[GroupPortfolioItem] = []
    clients: List[ClientPortfolioItem] = []
